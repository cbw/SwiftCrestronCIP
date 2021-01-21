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

import Foundation

public enum CIPMessageError: Error {
    case invalidJoinNumber
    case invalidStringLength
}

/// `CIPMessage` provides functions to construct CIP messages for the three join types.
struct CIPMessage {

    /// Utility function to create an array of bytes from data
    static private func makeByteArray<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
        withUnsafeBytes(of: value.bigEndian, Array.init)
    }

    /**
     Construct the message to set a digital join.

     This function constructs the message to set a digital join high or low, and supports standard or button-style joins.

     - Parameters:
        - onJoinID: The join ID of the signal.
        - setHigh: Boolean value of if the signal should be set high (will be set low if false).
        - buttonStyle: If this is a button-style join, defaults to false.
     */
    static func makeDigitalJoinMessage(onJoinID joinID: UInt16,
                                       setHigh: Bool,
                                       buttonStyle: Bool = false) throws -> Data {
        if joinID < 1 || joinID > 4000 {
            throw CIPMessageError.invalidJoinNumber
        }

        let cipJoinID = joinID - 1
        var byteArray: [UInt8] = [0x05, 0x00, 0x06, 0x00, 0x00, 0x03, 0x00]

        if buttonStyle { byteArray[6] = 0x27 }

        var packedJoin = (cipJoinID / 256) + ((cipJoinID % 256) * 256)

        if !setHigh {
            packedJoin |= 0x80
        }

        byteArray += self.makeByteArray(from: packedJoin)
        return(Data(byteArray))
    }

    /**
     Construct the message to set an analog join.

     This function constructs the message to set an analog join to a value.

     - Parameters:
        - onJoinID: The join ID of the signal.
        - value: UInt16 value to which the join will be set.
     */
    static func makeAnalogJoinMessage(onJoinID joinID: UInt16, value: UInt16) throws -> Data {
        if joinID < 1 || joinID > 4000 {
            throw CIPMessageError.invalidJoinNumber
        }

        let cipJoinID = joinID - 1
        var byteArray: [UInt8] = [0x05, 0x00, 0x08, 0x00, 0x00, 0x05, 0x14]

        byteArray += self.makeByteArray(from: cipJoinID)
        byteArray += self.makeByteArray(from: value)
        return(Data(byteArray))
    }

    /**
     Construct the message to send a serial join.

     This function constructions the message to send  a string to a serial join.

     - Parameters:
        - onJoinID: The join ID of the signal.
        - string: The string to send.
     */
    static func makeSerialJoinMessage(onJoinID joinID: UInt16, value: String) throws -> Data {
        if joinID < 1 || joinID > 4000 {
            throw CIPMessageError.invalidJoinNumber
        }

        if value.count > 255 || value.count < 1 {
            throw CIPMessageError.invalidStringLength
        }

        let cipJoinID = joinID - 1
        var byteArray: [UInt8] = [0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x34]

        let messageLengthByteArray = self.makeByteArray(from: UInt16(8 + value.count))
        let payloadLength = self.makeByteArray(from: UInt16(4 + value.count))

        if messageLengthByteArray.count == 2 {
            byteArray[1] = messageLengthByteArray[0]
            byteArray[2] = messageLengthByteArray[1]
        }

        if payloadLength.count == 2 {
            byteArray[5] = payloadLength[0]
            byteArray[6] = payloadLength[1]
        }

        byteArray += self.makeByteArray(from: cipJoinID)
        byteArray.append(UInt8(0x03))
        byteArray += value.compactMap { UInt8($0.asciiValue!) }

        return(Data(byteArray))
    }
}
