# SwiftCrestronCIP
[![License](https://img.shields.io/github/license/cbw/SwiftCrestronCIP)](https://github.com/cbw/SwiftCrestronCIP/blob/master/LICENSE)

## Sample Swift application to demonstrate SwiftCrestronCIP

---

#### NOTICE: This module is not produced, endorsed, maintained or supported by Crestron Electronics Incorporated. 'XPanel', 'Smart Graphics' and 'SIMPL Windows' are all trademarks of Crestron. The author is not affiliated in any way with Crestron.

This Swift application provides an implentation of the SwiftCrestronCIP package. You must also install the [sample Crestron program])(../Crestron%20Sample%20Program) on a Crestron control processor.

Tested on iPhone iOS 14.3 talking to a Crestron CP3N processor from SIMPL v4.14.21, Crestron DB v202.00.001.00.

### Installation Steps

1. This project depends on [CocoaPods](https://cocoapods.org). Ensure you have CocoaPods installed.
2. Run `pod install` to install the necessary pods.
3. Open the generated `CIPSampleApp.xcworkspace` workspace in Xcode
4. In `CIPSampleAppApp.swift`, edit the "Connection to the control system" variable towards the top of the file to reflect your control system's IP address, and if you changed the IPID of the panel in the sample program.
5. Compile and run, and it should connect to your control system.

### Debugging

You can change the level of console logging by changing the `debugLevel` parameter in the `CIPConnection()` initializer. `.off` disables logging, `.low` prints major events and errors, `.moderate` logs all events, and `.high` includes the full contents of messages to and from the control system.
