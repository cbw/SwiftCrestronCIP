//
//  SwiftCrestronCIPTests.swift
//  SwiftCrestronCIPTests
//
//  Created by Chris Wilson on 1/1/21.
//

import XCTest
@testable import SwiftCrestronCIP

class SwiftCrestronCIPTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Utility function to create an array of bytes from data
    private static func makeByteArray(fromData data: Data) -> [UInt8] {
        var byteArray: [UInt8] = [ ]
        for byte in data {
            byteArray.append(byte)
        }
        return byteArray
    }

    func testCIPMessageMakeDigitalJoinMessage() throws {
        XCTAssertThrowsError(try CIPMessage.makeDigitalJoinMessage(onJoinID: 0, setHigh: true, buttonStyle: true),
                             "A CIPMessageError.invalidJoinNumber Error should have been thrown "
                                + "but no Error was thrown") { error in
            XCTAssertEqual(error as? CIPMessageError, CIPMessageError.invalidJoinNumber)
        }

        XCTAssertThrowsError(try CIPMessage.makeDigitalJoinMessage(onJoinID: 4001, setHigh: true, buttonStyle: true),
                             "A CIPMessageError.invalidJoinNumber Error should have been thrown "
                                + "but no Error was thrown") { error in
            XCTAssertEqual(error as? CIPMessageError, CIPMessageError.invalidJoinNumber)
        }

        XCTAssertNoThrow(try CIPMessage.makeDigitalJoinMessage(onJoinID: 1, setHigh: true, buttonStyle: true),
                         "No Error should have been thrown, but one was")

        var data: Data
        var expectedData: [UInt8]

        // Set join 1 high, button style
        data = try CIPMessage.makeDigitalJoinMessage(onJoinID: 1, setHigh: true, buttonStyle: true)
        expectedData = [0x05, 0x00, 0x06, 0x00, 0x00, 0x03, 0x27, 0x00, 0x00]
        XCTAssertEqual(SwiftCrestronCIPTests.makeByteArray(fromData: data), expectedData,
                       "Constructed message does not match expected data")

        // Set join 1 low, button style
        data = try CIPMessage.makeDigitalJoinMessage(onJoinID: 1, setHigh: false, buttonStyle: true)
        expectedData = [0x05, 0x00, 0x06, 0x00, 0x00, 0x03, 0x27, 0x00, 0x80]
        XCTAssertEqual(SwiftCrestronCIPTests.makeByteArray(fromData: data), expectedData,
                       "Constructed message does not match expected data")

        // Set join 1 high, normal style
        data = try CIPMessage.makeDigitalJoinMessage(onJoinID: 1, setHigh: true, buttonStyle: false)
        expectedData = [0x05, 0x00, 0x06, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00]
        XCTAssertEqual(SwiftCrestronCIPTests.makeByteArray(fromData: data), expectedData,
                       "Constructed message does not match expected data")

        // Set join 1 low, normal style
        data = try CIPMessage.makeDigitalJoinMessage(onJoinID: 1, setHigh: false, buttonStyle: false)
        expectedData = [0x05, 0x00, 0x06, 0x00, 0x00, 0x03, 0x00, 0x00, 0x80]
        XCTAssertEqual(SwiftCrestronCIPTests.makeByteArray(fromData: data), expectedData,
                       "Constructed message does not match expected data")

        // Set join 2000 high, button style
        data = try CIPMessage.makeDigitalJoinMessage(onJoinID: 2000, setHigh: true, buttonStyle: true)
        expectedData = [0x05, 0x00, 0x06, 0x00, 0x00, 0x03, 0x27, 0xCF, 0x07]
        XCTAssertEqual(SwiftCrestronCIPTests.makeByteArray(fromData: data), expectedData,
                       "Constructed message does not match expected data")

    }

    func testCIPMessageMakeAnalogJoinMessage() throws {
        XCTAssertThrowsError(try CIPMessage.makeAnalogJoinMessage(onJoinID: 0, value: UInt16(100)),
                             "A CIPMessageError.invalidJoinNumber Error should have been thrown "
                                + "but no Error was thrown") { error in
            XCTAssertEqual(error as? CIPMessageError, CIPMessageError.invalidJoinNumber)
        }

        XCTAssertThrowsError(try CIPMessage.makeAnalogJoinMessage(onJoinID: 4001, value: UInt16(100)),
                             "A CIPMessageError.invalidJoinNumber Error should have been thrown "
                                + "but no Error was thrown") { error in
            XCTAssertEqual(error as? CIPMessageError, CIPMessageError.invalidJoinNumber)
        }

        XCTAssertNoThrow(try CIPMessage.makeAnalogJoinMessage(onJoinID: 1, value: UInt16(100)),
                         "No Error should have been thrown, but one was")

        var data: Data
        var expectedData: [UInt8]

        // Set join 1 to 518
        data = try CIPMessage.makeAnalogJoinMessage(onJoinID: 1, value: UInt16(130))
        expectedData = [0x05, 0x00, 0x08, 0x00, 0x00, 0x05, 0x14, 0x00, 0x00, 0x00, 0x82]
        XCTAssertEqual(SwiftCrestronCIPTests.makeByteArray(fromData: data), expectedData,
                       "Constructed message does not match expected data")

        // Set join 1 to 0
        data = try CIPMessage.makeAnalogJoinMessage(onJoinID: 1, value: UInt16(0))
        expectedData = [0x05, 0x00, 0x08, 0x00, 0x00, 0x05, 0x14, 0x00, 0x00, 0x00, 0x00]
        XCTAssertEqual(SwiftCrestronCIPTests.makeByteArray(fromData: data), expectedData,
                       "Constructed message does not match expected data")

        // Set join 1 to 65535
        data = try CIPMessage.makeAnalogJoinMessage(onJoinID: 1, value: UInt16(65535))
        expectedData = [0x05, 0x00, 0x08, 0x00, 0x00, 0x05, 0x14, 0x00, 0x00, 0xFF, 0xFF]
        XCTAssertEqual(SwiftCrestronCIPTests.makeByteArray(fromData: data), expectedData,
                       "Constructed message does not match expected data")

    }

    func testCIPMessageMakeSerialJoinMessage() throws {
        XCTAssertThrowsError(try CIPMessage.makeSerialJoinMessage(onJoinID: 0, value: "foo"),
                             "A CIPMessageError.invalidJoinNumber Error should have been thrown "
                                + "but no Error was thrown") { error in
            XCTAssertEqual(error as? CIPMessageError, CIPMessageError.invalidJoinNumber)
        }

        XCTAssertThrowsError(try CIPMessage.makeSerialJoinMessage(onJoinID: 4001, value: "foo"),
                             "A CIPMessageError.invalidJoinNumber Error should have been thrown "
                                + "but no Error was thrown") { error in
            XCTAssertEqual(error as? CIPMessageError, CIPMessageError.invalidJoinNumber)
        }

        XCTAssertThrowsError(try CIPMessage.makeSerialJoinMessage(onJoinID: 1, value: ""),
                             "A CIPMessageError.invalidStringLength Error should have been thrown "
                                + "but no Error was thrown") { error in
            XCTAssertEqual(error as? CIPMessageError, CIPMessageError.invalidStringLength)
        }

        var longString = ""
        for _ in 1...256 {
            longString += "."
        }

        XCTAssertThrowsError(try CIPMessage.makeSerialJoinMessage(onJoinID: 1, value: longString),
                             "A CIPMessageError.invalidStringLength Error should have been thrown "
                                + "but no Error was thrown") { error in
            XCTAssertEqual(error as? CIPMessageError, CIPMessageError.invalidStringLength)
        }

        XCTAssertNoThrow(try CIPMessage.makeSerialJoinMessage(onJoinID: 1, value: "foo"),
                         "No Error should have been thrown, but one was")

        var data: Data
        var expectedData: [UInt8]

        // Send "foo" on join 1
        data = try CIPMessage.makeSerialJoinMessage(onJoinID: 1, value: "foo")
        expectedData = [0x12, 0x00, 0x0B, 0x00, 0x00, 0x00, 0x07, 0x34, 0x00, 0x00, 0x03, 0x66, 0x6F, 0x6F]
        XCTAssertEqual(SwiftCrestronCIPTests.makeByteArray(fromData: data), expectedData,
                       "Constructed message does not match expected data")

        // Send a 255 byte string on join 1
        longString = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin vel tortor at metus "
            + "varius volutpat eu id eros. In sed vehicula orci. Quisque facilisis ante leo, ut malesuada "
            + "arcu malesuada vel. Nullam sem arcu, iaculis dapibus lorem at, pulvinar volutpat."
        data = try CIPMessage.makeSerialJoinMessage(onJoinID: 1, value: longString)
        expectedData = [0x12, 0x01, 0x07, 0x00, 0x00, 0x01, 0x03, 0x34, 0x00, 0x00, 0x03, 0x4C, 0x6F, 0x72,
                        0x65, 0x6D, 0x20, 0x69, 0x70, 0x73, 0x75, 0x6D, 0x20, 0x64, 0x6F, 0x6C, 0x6F, 0x72,
                        0x20, 0x73, 0x69, 0x74, 0x20, 0x61, 0x6D, 0x65, 0x74, 0x2C, 0x20, 0x63, 0x6F, 0x6E,
                        0x73, 0x65, 0x63, 0x74, 0x65, 0x74, 0x75, 0x72, 0x20, 0x61, 0x64, 0x69, 0x70, 0x69,
                        0x73, 0x63, 0x69, 0x6E, 0x67, 0x20, 0x65, 0x6C, 0x69, 0x74, 0x2E, 0x20, 0x50, 0x72,
                        0x6F, 0x69, 0x6E, 0x20, 0x76, 0x65, 0x6C, 0x20, 0x74, 0x6F, 0x72, 0x74, 0x6F, 0x72,
                        0x20, 0x61, 0x74, 0x20, 0x6D, 0x65, 0x74, 0x75, 0x73, 0x20, 0x76, 0x61, 0x72, 0x69,
                        0x75, 0x73, 0x20, 0x76, 0x6F, 0x6C, 0x75, 0x74, 0x70, 0x61, 0x74, 0x20, 0x65, 0x75,
                        0x20, 0x69, 0x64, 0x20, 0x65, 0x72, 0x6F, 0x73, 0x2E, 0x20, 0x49, 0x6E, 0x20, 0x73,
                        0x65, 0x64, 0x20, 0x76, 0x65, 0x68, 0x69, 0x63, 0x75, 0x6C, 0x61, 0x20, 0x6F, 0x72,
                        0x63, 0x69, 0x2E, 0x20, 0x51, 0x75, 0x69, 0x73, 0x71, 0x75, 0x65, 0x20, 0x66, 0x61,
                        0x63, 0x69, 0x6C, 0x69, 0x73, 0x69, 0x73, 0x20, 0x61, 0x6E, 0x74, 0x65, 0x20, 0x6C,
                        0x65, 0x6F, 0x2C, 0x20, 0x75, 0x74, 0x20, 0x6D, 0x61, 0x6C, 0x65, 0x73, 0x75, 0x61,
                        0x64, 0x61, 0x20, 0x61, 0x72, 0x63, 0x75, 0x20, 0x6D, 0x61, 0x6C, 0x65, 0x73, 0x75,
                        0x61, 0x64, 0x61, 0x20, 0x76, 0x65, 0x6C, 0x2E, 0x20, 0x4E, 0x75, 0x6C, 0x6C, 0x61,
                        0x6D, 0x20, 0x73, 0x65, 0x6D, 0x20, 0x61, 0x72, 0x63, 0x75, 0x2C, 0x20, 0x69, 0x61,
                        0x63, 0x75, 0x6C, 0x69, 0x73, 0x20, 0x64, 0x61, 0x70, 0x69, 0x62, 0x75, 0x73, 0x20,
                        0x6C, 0x6F, 0x72, 0x65, 0x6D, 0x20, 0x61, 0x74, 0x2C, 0x20, 0x70, 0x75, 0x6C, 0x76,
                        0x69, 0x6E, 0x61, 0x72, 0x20, 0x76, 0x6F, 0x6C, 0x75, 0x74, 0x70, 0x61, 0x74, 0x2E]
        XCTAssertEqual(SwiftCrestronCIPTests.makeByteArray(fromData: data), expectedData,
                       "Constructed message does not match expected data")

        // Send "foo" on join 2000
        data = try CIPMessage.makeSerialJoinMessage(onJoinID: 2000, value: "foo")
        expectedData = [0x12, 0x00, 0x0B, 0x00, 0x00, 0x00, 0x07, 0x34, 0x07, 0xCF, 0x03, 0x66, 0x6F, 0x6F]
        XCTAssertEqual(SwiftCrestronCIPTests.makeByteArray(fromData: data), expectedData,
                       "Constructed message does not match expected data")

    }

}
