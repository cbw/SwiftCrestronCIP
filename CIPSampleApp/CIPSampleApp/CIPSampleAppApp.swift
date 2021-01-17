//
//  CIPSampleAppApp.swift
//  CIPSampleApp
//
//  Created by Chris Wilson on 1/16/21.
//

import SwiftUI
import SwiftCrestronCIP
import ReSwift

// Connection to the control system
let cipConnection = CIPConnection(withControlSystemHost: "192.168.11.2",
                                  ipid: 0x1F,
                                  debugLevel: .low,
                                  connectionStateChangeCallback: connectionStateCallback,
                                  registrationStateChangeCallback: registrationStateCallback)

// MARK: -
// MARK: Join Number Constants

private enum DigitalJoinIn: UInt16 {
    case SwiftPress1FB = 1
    case SwiftPress2FB = 2
}

private enum DigitalJoinOut: UInt16 {
    case SwiftPress1 = 1
    case SwiftPress2 = 2
}

private enum AnalogJoinIn: UInt16 {
    case SwiftAnalog1 = 1
}

private enum AnalogJoinOut: UInt16 {
    case SwiftAnalog1 = 1
}

private enum SerialJoinIn: UInt16 {
    case SwiftSerialEcho1 = 1
}

private enum SerialJoinOut: UInt16 {
    case SwiftSerial1 = 1
}

// MARK: -
// MARK: Redux App State

struct AppState: StateType {
    var swiftPress1: Bool = false
    var swiftPress2: Bool = false
    var swiftAnalog1: UInt16 = 0
    var swiftSerialEcho1: String?
    var connectionState: ConnectionState = .disconnected
    var registeredWithProcessor: Bool = false
}

// MARK: -
// MARK: Redux Actions

struct UpdateStateFromCIPEvent: Action {
    let joinType: SignalType
    let joinID: UInt16
    let value: Any
}

struct Digital1Pressed: Action {
}

struct Digital2Pressed: Action {
}

struct AnalogValue1Changed: Action {
    let value: UInt16
}

struct Serial1Send: Action {
    let value: String
}

struct ConnectionStateChange: Action {
    let value: ConnectionState
}

struct RegistrationStateChange: Action {
    let value: Bool
}

struct Connect: Action {
}

struct Disconnect: Action {
}


// MARK: -
// MARK: Redux Reducers

func appReducer(action: Action, state: AppState?) -> AppState {
    var state = state ?? AppState()
    
    switch action {
    case _ as ReSwiftInit:
        break
    case let action as UpdateStateFromCIPEvent:
        switch action.joinType {
        case .digital:
            switch action.joinID {
            case DigitalJoinIn.SwiftPress1FB.rawValue:
                if action.value as! Bool {
                    state.swiftPress1 = action.value as! Bool
                } else {
                    state.swiftPress1 = false
                }
            case DigitalJoinIn.SwiftPress2FB.rawValue:
                if action.value as! Bool {
                    state.swiftPress2 = action.value as! Bool
                } else {
                    state.swiftPress2 = false
                }
            default:
                break
            }
        case .analog:
            switch action.joinID {
            case AnalogJoinIn.SwiftAnalog1.rawValue:
                state.swiftAnalog1 = action.value as! UInt16
            default:
                break
            }
        case .serial:
            switch action.joinID {
            case SerialJoinIn.SwiftSerialEcho1.rawValue:
                state.swiftSerialEcho1 = action.value as? String
            default:
                break
            }
        }
    case _ as Digital1Pressed:
        cipConnection.pulse(DigitalJoinOut.SwiftPress1.rawValue)
    case _ as Digital2Pressed:
        cipConnection.pulse(DigitalJoinOut.SwiftPress2.rawValue)
    case let action as AnalogValue1Changed:
        cipConnection.setAnalog(AnalogJoinOut.SwiftAnalog1.rawValue, value: action.value)
    case let action as Serial1Send:
        cipConnection.sendSerial(SerialJoinOut.SwiftSerial1.rawValue, string: action.value)
    case let action as ConnectionStateChange:
        state.connectionState = action.value
    case let action as RegistrationStateChange:
        state.registeredWithProcessor = action.value
    case _ as Connect:
        DispatchQueue.main.async {
            cipConnection.connect()
        }
    case _ as Disconnect:
        DispatchQueue.main.async {
            cipConnection.disconnect()
        }
    default:
        break
    }
    
    return state
}

// MARK: -
// MARK: Redux Store

let appStore = Store(
    reducer: appReducer,
    state: nil,
    middleware: [])

// MARK: -
// MARK: ObservableState to allow Reduct bindings to SwiftUI

public class ObservableState<T>: ObservableObject where T: StateType {
    
    // MARK: Public properties
    
    @Published public var current: T
    
    // MARK: Private properties
    
    private var store: Store<T>
    
    // MARK: Lifecycle
    
    public init(store: Store<T>) {
        self.store = store
        self.current = store.state
        
        store.subscribe(self)
    }
    
    deinit {
        store.unsubscribe(self)
    }
    
    // MARK: Public methods
    
    public func dispatch(_ action: Action) {
        store.dispatch(action)
    }
    
    public func dispatch(_ action: Action) -> () -> Void {
        {
            self.store.dispatch(action)
        }
    }
}

extension ObservableState: StoreSubscriber {
    
    // MARK: - <StoreSubscriber>
    
    public func newState(state: T) {
        DispatchQueue.main.async {
            self.current = state
        }
    }
}

// MARK: -
// MARK: CIP Callback Handler

let genericCIPCallback: (_ signalType: SignalType, _ joinId: UInt16, _ value: Any)  -> Void = {signalType, joinID, value in
    appStore.dispatch(UpdateStateFromCIPEvent(joinType: signalType, joinID: joinID, value: value))
}

// MARK: -
// MARK: Connection/registration state handlers

let connectionStateCallback: (_ state: Any)  -> Void = {state in
    appStore.dispatch(ConnectionStateChange(value: state as! ConnectionState))
}

let registrationStateCallback: (_ state: Any)  -> Void = {state in
    appStore.dispatch(RegistrationStateChange(value: state as! Bool))

}

// MARK: -
// MARK: SwiftUI App

@main
struct CIPSampleAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().onAppear(perform: {
                // Add subscriptions before connecting so that we will receive the current state
                // during the on-connect update. This makes sure the app initializes with current
                // data without having to request it.
                cipConnection.subscribe(signalType: .digital, joinID: DigitalJoinIn.SwiftPress1FB.rawValue, callback: genericCIPCallback)
                cipConnection.subscribe(signalType: .digital, joinID: DigitalJoinIn.SwiftPress2FB.rawValue, callback: genericCIPCallback)
                cipConnection.subscribe(signalType: .analog, joinID: AnalogJoinIn.SwiftAnalog1.rawValue, callback: genericCIPCallback)
                cipConnection.subscribe(signalType: .serial, joinID: SerialJoinIn.SwiftSerialEcho1.rawValue, callback: genericCIPCallback)

                cipConnection.connect()
                
                Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { timer in
                    if (cipConnection.registered) {
                        cipConnection.sendUpdateRequest()
                    }
                }
            })
        }
    }
}
