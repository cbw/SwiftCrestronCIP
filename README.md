# SwiftCrestronCIP
[![License](https://img.shields.io/github/license/cbw/SwiftCrestronCIP)](https://github.com/cbw/SwiftCrestronCIP/blob/master/LICENSE)

### A Swift package for communicating with Crestron control processors via the Crestron over IP (CIP) protocol.

#### NOTICE: This module is not produced, endorsed, maintained or supported by Crestron Electronics Incorporated. 'XPanel', 'Smart Graphics' and 'SIMPL Windows' are all trademarks of Crestron. The author is not affiliated in any way with Crestron.

This Swift module was inspired by [Katherine Lenae's Python CIP client](https://github.com/klenae/python-cipclient).

This is a Swift-based socket client that facilitates communications with a Crestron control processor using the Crestron-over-IP (CIP) protocol. Familiarity with and access to Crestron's development tools, processes and terminology are required to configure the control processor in a way that allows this module to be used.

## Sample Programs

The [CIPSampleApp Swift application](./CIPSampleApp) demonstrates the use of this package. See the `README` file for information on building and running. The sample app requires the counterpart [Crestron sample program](./Crestron%20Sample%20Program) to be running on a Creston control system.

## Usage

To use this package, first import it into your application:

```
import SwiftCrestronCIP
```

### Connecting

You will need to initialize the class, and define the connection parameters for your control system:

```
let cipConnection = CIPConnection(withControlSystemHost: "192.168.1.2",
                                  ipid: 0x01,
                                  debugLevel: .off,
                                  connectionStateChangeCallback: connectionStateCallback,
                                  registrationStateChangeCallback: registrationStateCallback)
```

Be sure you specify the correct hostname or IP address for your control system, and the IPID for the Xpanel device you wish to use for the connection.

The debugLevel parameter allows you to set increasing levels of debug to the console. `.off` disables logging, `.low` prints major events and errors, `.moderate` logs all events, and `.high` includes the full contents of messages to and from the control system.

### Subscribing to Signals

You can register one (or more) callback closures to be called whenever a join message is received from the control processor. Be aware, these are called even when an update request is made, and all signals are refreshed. Handle this accordingly in terms of managing your state. My preference is to use [ReSwift](https://github.com/ReSwift/ReSwift) for managing state centrally (as is done in the Swift sample program).

To make a subscription call the `subscribe` function:

```
cipConnection.subscribe(signalType: .digital, joinID: 1, callback: genericCIPCallback)
```

This call subscribes to digital join 1, and calls `genericCIPCallback` when the join is received. The callback must match the function signaure:

```
(_ signalType: SignalType, _ joinId: UInt16, _ value: Any) -> Void
```

The value of the join is sent as an `Any` type, which you'll need to force cast to the correct value type based on the `signalType`. A `.digital` maps to `Bool`, `.analog` to `UInt16`, and `.serial` to `String`.

### Sending Signals

#### Digital Joins

Digital joins are sent using `setDigitalJoin()`:

```
cipConnection.setDigitalJoin(1, high: true, buttonStyle: false)
```

The first parameter is the join ID. The `high` parameter determines the signal level (`true` to set the signal high, `false` to set it low). The optional `buttonStyle` parameter (defaults to `false`) identifies the signal as standard or button-style.

There are a few convenience functions for digital joins:

```
cipConnection.press(1)
cipConnection.release(1)
cipConnection.pulse(1)
```

These three functions send press, release, and pulse (shorthand for calling `press()` followed by `release()`) messages on the specified join number.

#### Analog Joins

Analog joins are sent using `setAnalog()`:

```
cipConnection.setAnalog(1, value: foo)
```

The first parameter is the join ID, and the second is a `UInt16` value.

#### Serial Joins

To send strings to a serial join, use `sendSerial()`:

```
cipConnection.sendSerial(1, string: foo)
```

The first parameter is the join ID, and the second is a `String` value.

### Finding more information

This is just a quick glance of how to use this package. For more documentation, see [SwiftCrestronCIP/SwiftCrestronCIP.swift](./blob/main/SwiftCrestronCIP/SwiftCrestronCIP.swift), and for example usage, the [CIPSampleApp Swift application](./CIPSampleApp).
