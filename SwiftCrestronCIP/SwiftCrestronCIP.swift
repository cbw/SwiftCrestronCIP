//
//  SwiftCrestronCIP
//  Copyright 2021 Chris Wilson (chris@chrisbwilson.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
//  documentation files (the "Software"), to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
//  and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions
//  of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
//  TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
//  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

import CocoaAsyncSocket

extension Array where Element == UInt8 {
    func hexString(spacing: String) -> String {
        var hexString: String = ""
        var currentCount = self.count
        for byte in self {
            hexString.append(String(format: "0x%02X", byte))
            currentCount -= 1
            if currentCount > 0 {
                hexString.append(spacing)
            }
        }
        return hexString
    }
}

public enum SignalType: String {
    case digital = "D"
    case analog = "A"
    case serial = "S"
}

public enum DebugLevel {
    case off
    case moderate
    case high
}

public typealias CIPSignalHandler = (_ signalType: SignalType, _ joinId: UInt16, _ value: Any) -> Void

/// Implements the Crestron CIP protocol, managing communication with a control processor
public class CIPConnection: NSObject, GCDAsyncSocketDelegate {

    // MARK: Instance Constants/Variables
    
    // Control processor hostname or IP address
    let host: String

    // Control processor TCP port
    let port: UInt16 = 41794

    // IPID of the Xpanel device this client should use
    let ipid: UInt8
    
    // Automatically reconnect on disconnect
    var reconnectOnDisconnect = true

    // Controls the debug level. "moderate" will enable printing events, while "high" will print
    // packet/message content
    public var debugLevel: DebugLevel = .off

    // Tracks the TCP connection status of the socket to the control processor. This is
    // readable publicly, but only mutable within the class
    public private(set) var connected = false

    // Tracks the registration status of the control processor. This is readable publicly,
    // but only mutable within the class
    public private(set) var registered = false

    // Timer for sending heartbeat messages to the control processor
    var heartbeatTimer: Timer?

    // Timer for connection retries
    var connectRetryTimer: Timer?

    // Transmit queue for sending messages to the control processor
    let txQueue = DispatchQueue(label: "CIPTxQueue")

    // Callback queue for dispatching callbacks on join subscriptions
    let callbackQueue = DispatchQueue(label: "CIPRxCallbackQueue")

    // Delay to pace transmit packets
    let txPacingDelay = 0.001

    // Dictionary to store callbacks for when signal subscriptions are registered. The key is
    // a concatenation of the raw value of the signal type enum, and the join ID (e.g.
    // "D42" for digital join 42). The value is an array, allowing for more than one callback
    // per join.
    var signalCallbacks: [ String: [CIPSignalHandler] ] = [:]

    // TCP socket for communicating with the control processor
    lazy var socket: GCDAsyncSocket = {
        let socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        return socket
    }()

    // MARK: -
    // MARK: Initializers
    
    /**
     Instantiates the SwiftCrestronCIP class

     - Parameters:
        - withControlSystemHost: The hostname or IP address of the control system.
        - ipid: The IPID of the Xpanel this client should use.
        - port: The TCP port of the control system (defaults to 41794).
        - debugLevel: enables debugging (defaults to `.off`)
     */
    public init (withControlSystemHost host: String,
                 ipid: UInt8,
                 port: UInt16 = 41794,
                 debugLevel: DebugLevel = .off) {
        self.host = host
        self.ipid = ipid
    }
    
    // MARK: -
    // MARK: Socket delegate functions

    /**
     Sends data down the TCP connection to the control processor.
     
     - Parameter _: The data to be sent.
     */
    private func send(_ datagram: Data) {
        socket.write(datagram, withTimeout: 2, tag: 0)
    }

    /**
     Socket delegate method called when a connection is established.
     
     - Parameters:
        - sock: The async socket object.
        - didConnectToHost: The host to which the connection was established.
        - port: The port number of the connection.
     */
    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("didConnectToHost \(host):\(port)\n")

        connected = true

        // Cancel connect retry timer
        DispatchQueue.main.async {
            self.connectRetryTimer?.invalidate()
            self.connectRetryTimer = nil
        }

        socket.readData(withTimeout: -1, tag: 0)
    }

    /**
     Socket delegate method called when data is read from the socket.
     
     - Parameters:
        - sock: The async socket object.
        - didRead: The data read from the socket.
        - withTag: The data tag.
     */
    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: CLong) {
        socket.readData(withTimeout: -1, tag: 0)
        processData(data)
    }

    /**
     Socket delegate method called when the socket is disconnected.
     
     - Parameters:
        - sock: The async socket object.
        - withError: Optional error.
     */
    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("[SOCKET] Socket disconnected")
        connected = false
        registered = false

        // Cancel the heartbeat timer
        DispatchQueue.main.async {
            self.heartbeatTimer?.invalidate()
            self.heartbeatTimer = nil
        }

        // If reconnect is enabled, try to reconnect after a 1 second delay
        if reconnectOnDisconnect {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.connect()
            }
        }
    }

    /**
     Process data received on the socket.
     
     This function is called by the socket data read delegate function, and processes the received data. It verifies the packet
     length and payload length to ensure the integrity of the message, then calls `processPayload` if the verification
     passes.
     
     - Parameter _: The data read from the socket.
     */
    private func processData(_ data: Data) {
        var position = 0
        let length = data.count

        while position < length {
            if (length - position) < 4 {
                print("RX: [Error] packet is too short")
                break
            }

            let payloadLength = UInt16(data[position + 1] << 8) + UInt16(data[position + 2])
            let packetLength = payloadLength + 3

            if (length - position) < packetLength {
                print("RX: [Error] Packet length mismatch")
                break
            }

            let packetType = data[position]

            let payloadStart: Int = position + 3
            let payloadEnd: Int = position + 3 + Int(payloadLength)

            let payload = data[payloadStart..<payloadEnd]

            processPayload(packetType: packetType, payload: payload)
            position += Int(packetLength)

        }
    }

    // MARK: -
    // MARK: Connect and disconnect functions
    
    /**
     Initiates a connection to the control processor.
     
     This must be manually called the first time to connect to the processor, allowing for join subscriptions
     to be registered before the connection is established. As the control processor will send the current state
     of all joins upon connection, this allows the application to receive the current state upon connect.
     
     In the event of a disconnection (either through network interruption, or if the control processor or
     program restart), the class will automatically try and reestablish connection.
     */
    public func connect(reconnectOnDisconnect: Bool = true) {
        self.reconnectOnDisconnect = reconnectOnDisconnect

        if connected {
            print("[ERROR] Called connect() when already connected")
        }

        do {
            print("[CONNECT] Trying to connect to \(host):\(port)")
            try socket.connect(toHost: host, onPort: port, withTimeout: 2)
        } catch let error {
            print("[ERROR] Well that didn't go as planned... \(error)")
        }

        DispatchQueue.main.async {
            self.connectRetryTimer = Timer(timeInterval: 2.0,
                                           target: self,
                                           selector: #selector(self.fireConnectionRetryTimer),
                                           userInfo: nil,
                                           repeats: false)
            RunLoop.current.add(self.connectRetryTimer!, forMode: RunLoop.Mode.common)
        }
    }
    
    /**
     Disconnects from the control processor.
     */
    public func disconnect() {
        reconnectOnDisconnect = false
        registered = false
        socket.disconnect()
    }
    
    // MARK: -
    // MARK: Signal subscriptions
    
    /**
     Registers a callback closure to be called when a signal update is received.
     
     This allows the subscription to events from the control processor on a join ID of a particular type. Multiple callbacks can
     be registered to a single join. At this point, there is not a method to remove a join once subscribed.
     
     The callback signature provides the signal type and join ID so that a generic event handler function can be used to
     process the callback.
     
     Callbacks must be of the _CIPSignalHandler_ method signature:
     
         (_ signalType: SignalType, _ joinId: UInt16, _ value: Any) -> Void

     - Parameters:
        - signalType: The signal type of the join being subscribed.
        - joinID: The join ID being subscribed.
        - callback: The closure to call when a signal is received.
     */
    public func subscribe(signalType: SignalType, joinID: UInt16, callback: @escaping CIPSignalHandler) {
        print("Starting subscription... type: \(signalType.rawValue)")
        let joinTypeIDString: String = String(joinID) + signalType.rawValue
        if signalCallbacks[joinTypeIDString] == nil {
            print("Couldn't unwrap callback array")
            signalCallbacks[joinTypeIDString] = [CIPSignalHandler]()
        }

            signalCallbacks[joinTypeIDString]!.append(callback)
            print("CBArray: \(signalCallbacks[joinTypeIDString]!) [\(signalCallbacks.count)]")
            print("Deep in it: \(signalCallbacks[joinTypeIDString]!.count)")
    }
    
    // MARK: -
    // MARK: Message Sending
    
    /**
     Set a digital join.
     
     This function sets a digital join high or low, and supports standard or button-style joins. If the control processor is not
     connected and registered, it will silently fail.
     
     TODO: implement throwing an exception when a join is set while not connected and registered.
     
     - Parameters:
        - _: The join ID of the signal.
        - high: Boolean value of if the signal should be set high (will be set low if false).
        - buttonStyle: If this is a button-style join, defaults to false.
     */
    public func setDigitalJoin(_ joinID: UInt16, high: Bool, buttonStyle: Bool = false) {
        if !connected || !registered {
            print("[ERROR] call to setDigitalJoin while not connected or registered")
            return
        }

        txQueue.async {
            let cipJoinID = joinID - 1
            var byteArray: [UInt8] = [0x05, 0x00, 0x06, 0x00, 0x00, 0x03, 0x00]

            if buttonStyle { byteArray[6] = 0x27 }

            var packedJoin = (cipJoinID / 256) + ((cipJoinID % 256) * 256)

            if !high {
                packedJoin |= 0x80
            }

            byteArray += self.makeByteArray(from: packedJoin)
            print("[TX/DSIG] Setting join \(joinID) to \"\(high)\" (\(byteArray.hexString(spacing: ", ")))")

            self.send(Data(byteArray))
            Thread.sleep(forTimeInterval: self.txPacingDelay)
        }
    }

    /**
     Sets a button-style digital join high (press).
     
     This is a shorthand function for setting a button-style digital join high.
     
     TODO: implement throwing an exception when a join is set while not connected and registered.
     
     - Parameter _: The join ID of the signal.
     */
    public func press(_ joinID: UInt16) {
        setDigitalJoin(joinID, high: true, buttonStyle: true)
    }

    /**
     Sets a button-style digital join low (release).
     
     This is a shorthand function for setting a button-style digital join low.
     
     TODO: implement throwing an exception when a join is set while not connected and registered.
     
     - Parameter _: The join ID of the signal.
     */
    public func release(_ joinID: UInt16) {
        setDigitalJoin(joinID, high: false, buttonStyle: true)
    }

    /**
     Sends a pulse on a digital join.
     
     This is a shorthand function for setting a digital join high then low.
     
     TODO: implement throwing an exception when a join is set while not connected and registered.
     
     - Parameter _: The join ID of the signal.
     */
    public func pulse(_ joinID: UInt16) {
        press(joinID)
        release(joinID)
    }

    /**
     Sets an analog join to a value.
     
     This function sets an analog join to the specified value. If the control processor is not connected and registered, it will silently fail.
     
     TODO: implement throwing an exception when a join is set while not connected and registered.
     
     - Parameters:
        - _: The join ID of the signal.
        - value: UInt16 value to which the join will be set.
     */
    public func setAnalog(_ joinID: UInt16, value: UInt16) {
        if !connected || !registered {
            print("[ERROR] call to setAnalog while not connected or registered")
            return
        }

        txQueue.async {
            let cipJoinID = joinID - 1
            var byteArray: [UInt8] = [0x05, 0x00, 0x08, 0x00, 0x00, 0x05, 0x14]

            byteArray += self.makeByteArray(from: cipJoinID)
            byteArray += self.makeByteArray(from: value)
            // print("[TX/ASIG] Setting join \(joinID) to \"\(value)\" (\(byteArray.hexString(spacing: ", ")))")

            self.send(Data(byteArray))
            Thread.sleep(forTimeInterval: self.txPacingDelay)
        }
    }

    /**
     Sends a serial join.
     
     This function sends a string to a serial join. If the control processor is not connected and registered, it will silently fail.
     
     TODO: implement throwing an exception when a join is set while not connected and registered.
     
     - Parameters:
        - _: The join ID of the signal.
        - string: The string to send.
     */
    public func sendSerial(_ joinID: UInt16, string: String) {
        if !connected || !registered {
            print("[ERROR] call to sendSerial while not connected or registered")
            return
        }

        txQueue.async {
            let cipJoinID = joinID - 1
            var byteArray: [UInt8] = [0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x34]

            byteArray[2] = UInt8(8 + string.count)
            byteArray[6] = UInt8(4 + string.count)
            byteArray += self.makeByteArray(from: cipJoinID)
            byteArray.append(UInt8(0x03))
            byteArray += string.compactMap { UInt8($0.asciiValue!) }
            // print("[TX/SERIAL] Sending \"\(string)\" on serial join \(joinID) (\(byteArray.hexString(spacing: ", ")))")

            self.send(Data(byteArray))
            Thread.sleep(forTimeInterval: self.txPacingDelay)
        }
    }

    /**
     Sends an update request.
     
     This function sends an update request to the control processor, which will cause it to refresh the current state of all joins
     configured for this IPID's Xpanel symbol. If the control processor is not connected and registered, this function will
     silently fail.
     
     TODO: implement throwing an exception when a join is set while not connected and registered.
     */
    public func sendUpdateRequest() {
        if !connected || !registered {
            print("[ERROR] call to sendUpdateRequest while not connected or registered")
            return
        }

        txQueue.async {
            let byteArray: [UInt8] = [0x05, 0x00, 0x05, 0x00, 0x00, 0x02, 0x03, 0x00]
            print("[TX/UPDATE] Sending update request (\(byteArray.hexString(spacing: ", ")))")

            self.send(Data(byteArray))
            Thread.sleep(forTimeInterval: self.txPacingDelay)
        }
    }

    

    // MARK: -
    // MARK: Timers
    
    /**
     Called when the connection retry timer fires.
     
     In the event of a connection failure, a timer is established to retry the connection. When it expires,
     this function is called.
     
     - Parameter timer: Reference to the `Timer` that fired.
     */
    @objc
    func fireConnectionRetryTimer(timer: Timer) {
        self.connectRetryTimer = nil

        if !connected {
            print("[CONNECT] Not connected, retrying...")
            connect()
        }
    }
    
    /**
     Called when the heartbeat retry timer fires.
     
     When a connection is established and registration is successful, a timer is established to send a heartbeat message
     to the control processor every 15 seconds. When the socket is disconnected, this timer is invalidated.
     
     - Parameter timer: Reference to the `Timer` that fired.
     */
    @objc
    func fireHeartbeatTimer(timer: Timer) {
        if !connected || !registered {
            print("[ERROR] attempted to send heartbeat while not registered")
            return
        }

        txQueue.async {
            let heartbeatByteArray: [UInt8] = [0x0d, 0x00, 0x02, 0x00, 0x00]
            var datagram = Data()
            datagram.append(contentsOf: heartbeatByteArray)

            // print("[TX] Sending heartbeat: \(heartbeatByteArray.hexString(spacing: ", "))")
            self.send(datagram)
            Thread.sleep(forTimeInterval: self.txPacingDelay)
        }
    }

    
    // MARK: -
    // MARK: Message Processing
    
    /**
     Processes the payload of a received message.
     
     Based on the message type, calls the appropriate function to process the message.
     
     - Parameters:
        - packetType: The CIP message type.
        - payload: The payload data of the CIP message.
     */
    private func processPayload(packetType: UInt8, payload: Data) {
        // print("RX: command type \(packetType)")

        switch packetType {
        case 0x0D, 0x0E:
            // print("RX: heartbeat")
            // No action required, timer is sending outbound heartbeats
            break
        case 0x05:
            // print("RX: data")
            handleData(payload)
        case 0x12:
            // print("RX: serial join")
            handleSerialJoin(payload)
        case 0x0F:
            print("RX: registration request")
            handleRegistrationRequest()
        case 0x02:
            print("RX: registration result")
            handleRegistrationResponse(payload)
        case 0x03:
            print("RX: control system disconnect")
            self.registered = false
            socket.disconnect()
        default:
            print("RX: unknown packet")
        }
    }

    /**
     Dispatch callbacks for a received signal.
     
     This function iterates over the `callbacks` array for a given signal type and join ID. If there are registered callbacks,
     it makes the calls, sending through the signal type, join ID, and value received. Values are passed as an `Any` type,
     it is up to the called function to cast the value appropriately based on the signal type.
     
     - Parameters:
        - forJoinID: The join ID of the signal.
        - signalType: The signal type.
        - value: The signal value.
     */
    private func makeCallbacks(forJoinID joinID: UInt16, signalType: SignalType, value: Any) {
        let joinTypeIDString: String = String(joinID) + signalType.rawValue
        guard let callbacks = signalCallbacks[joinTypeIDString] else {
            print("[CBACK] callbacks array is nil for \"\(joinTypeIDString)\"")
            return
        }

        // print("[CBACK] [\(joinTypeIDString)] callbacks.count=\(callbacks.count)")

        for callback in callbacks {
            callback(signalType, joinID, value)
        }
    }

    /**
     Handles _data_ type messages from the control processor.
     
     Called by `ProcessPayload`, this function handles messages of _data_ type:
     
     * Digital joins
     * Analog joins
     * Update requests
     * Data time updates
     
     Digital and Analog joins are decoded in this function, and callbacks are dispatched. Update requests are
     forwarded on to `handleUpdateRequest`. Other message types are ignored.
     
     - Parameter _: The payload data of the message
     */
    private func handleData(_ payload: Data) {
        var byteArray: [UInt8] = [ ]
        for byte in payload {
            byteArray.append(byte)
        }
        let dataType = byteArray[3]

        switch dataType {
        case 0x00:
            let joinID = UInt16((((byteArray[5] & 0x7F) << 8) | byteArray[4]) + 1)
            let state: UInt8 = ((byteArray[5] & 0x80) >> 7) ^ 0x01

            print("[DATA] Digital Join ID \(joinID) = \(state)")
            makeCallbacks(forJoinID: joinID, signalType: .digital, value: state == 1)
        case 0x14:
            // print("[RX/ASIG] payload = \"\(byteArray.hexString(spacing: ", "))\"")
            let joinID = UInt16(((byteArray[4] << 8) | byteArray[5]) + 1)
            let value: UInt16 = UInt16(byteArray[6]) << 8 + UInt16(byteArray[7])

            print("[DATA] Analog Join ID \(joinID) = \(value)")
            makeCallbacks(forJoinID: joinID, signalType: .analog, value: value)
        case 0x03:
            print("[DATA] Update Request")
            handleUpdateRequest(byteArray)
        case 0x08:
            print("[DATA] Received date/time from processor")
        default:
            print("[DATA] Unknown data type received")
        }
    }

    /**
     Handles Serial join messages from the control processor.
     
     Called by `ProcessPayload`, this function handles messages with serial join updates, and calls the callbacks
     for the received join.
     
     - Parameter _: The payload data of the message
     */
    private func handleSerialJoin(_ payload: Data) {
        var byteArray: [UInt8] = [ ]
        for byte in payload {
            byteArray.append(byte)
        }

        let joinID = UInt16(((byteArray[5] << 8) | byteArray[6]) + 1)
        let value = String(bytes: byteArray[8...], encoding: String.Encoding.ascii)

        print("[SERIAL] Serial Join ID \(joinID) = \(value!)")
        makeCallbacks(forJoinID: joinID, signalType: .serial, value: value ?? "")
    }

    /**
     Handles _update_ type messages from the control processor.
     
     Called by `handleData`, this function handles data messages of _update_ subtype:
     
     * Standard update request
     * Mysterious penultimate update-response (no idea what that is)
     * End of query messages
     * End of query acknowledgement
     
     The end of query message receives a response, the others are ignored.
     
     - Parameter _: The payload data of the message
     */
    private func handleUpdateRequest(_ payloadBytes: [UInt8]) {
        switch payloadBytes[4] {
        case 0x00:
            print("[UPDATE] Standard update request")
        case 0x16:
            print("[UPDATE] Mysterious penultimate update-response")
        case 0x1c:
            print("[UPDATE] End of query")

            txQueue.async {
                let command: [UInt8] = [0x05, 0x00, 0x05, 0x00, 0x00, 0x02, 0x03, 0x1d]
                var datagram = Data()
                datagram.append(contentsOf: command)
                self.send(datagram)
                Thread.sleep(forTimeInterval: self.txPacingDelay)
                print("[TX] End of query response 1 of 2 sent")
            }

            txQueue.async {
                let command: [UInt8] = [0x0D, 0x00, 0x02, 0x00, 0x00]
                var datagram = Data()
                datagram.append(contentsOf: command)
                self.send(datagram)
                Thread.sleep(forTimeInterval: self.txPacingDelay)
                print("[TX] End of query response 2 of 2 sent")
            }
        case 0x1d:
            print("[UPDATE] End-of-query acknowledgement")
        default:
            print("[UPDATE] Unknown update request")
        }
    }

    /**
     Handles _registration request_ type messages from the control processor.
     
     Called by `ProcessPayload`, this function handles messages of _registration request_ type, and responds with
     a registration message including the IPID to register against.
     */
    private func handleRegistrationRequest() {
        txQueue.async {
            let registrationCommand: [UInt8] = [0x01, 0x00, 0x0b, 0x00, 0x00, 0x00, 0x00,
                                                0x00, self.ipid, 0x40, 0xff, 0xff, 0xf1, 0x01]
            var datagram = Data()
            datagram.append(contentsOf: registrationCommand)
            self.send(datagram)
            Thread.sleep(forTimeInterval: self.txPacingDelay)
            print("[TX] registration message sent")
        }
    }

    /**
     Handles _registration response_ type messages from the control processor.
     
     Called by `ProcessPayload`, this function handles messages of _registration response_ type. These messages indicate
     if the registration was successful, if an attempt to register against an unknown or invalid IPID was made, or if some other unknown
     error occurred.

     - Parameter _: The payload data of the message
     */
    private func handleRegistrationResponse(_ payload: Data) {
        var mutablePayload = payload
        var payloadBytes: [UInt8] = [ ]

        while !mutablePayload.isEmpty {
            payloadBytes.append(mutablePayload.popFirst()!)
        }

        if payloadBytes.count == 3 && payloadBytes[0] == 0xff && payloadBytes[1] == 0xff && payloadBytes[2] == 0x02 {
            print("[ERROR] Registration Error: IPID does not exist")
            socket.disconnect()
            return
        } else if payloadBytes.count == 4 &&
                    payloadBytes[0] == 0x00 &&
                    payloadBytes[1] == 0x00 &&
                    payloadBytes[2] == 0x00 &&
                    payloadBytes[3] == 0x1f {
            // DEBUG print("Registration Succeeded")

            txQueue.async {
                let registrationSuccessResponse: [UInt8] = [0x05, 0x00, 0x05, 0x00, 0x00, 0x02, 0x03, 0x00]
                var datagram = Data()
                datagram.append(contentsOf: registrationSuccessResponse)
                self.send(datagram)
                self.registered = true
                // DEBUG print("[TX] registration success response sent")
                Thread.sleep(forTimeInterval: self.txPacingDelay)
            }

            // Schedule heartbeat
            DispatchQueue.main.async {
                self.heartbeatTimer = Timer(timeInterval: 15.0,
                                            target: self,
                                            selector: #selector(self.fireHeartbeatTimer),
                                            userInfo: nil,
                                            repeats: true)
                RunLoop.current.add(self.heartbeatTimer!, forMode: RunLoop.Mode.common)
            }

            return
        } else {
            print("[ERROR] Registration Error: unknown response (\(payloadBytes)")
            socket.disconnect()
            return
        }
    }
    
    // MARK: -
    // MARK: Utility Functions

    /// Utility function to create an array of bytes from data
    private func makeByteArray<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
        withUnsafeBytes(of: value.bigEndian, Array.init)
    }

    
}
