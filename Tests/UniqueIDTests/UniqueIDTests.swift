// Copyright The swift-UniqueID Contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest

@testable import UniqueID

final class UniqueIDTests: XCTestCase {}


// ------------------------------------------
// MARK: - Basic properties and conformances.
// ------------------------------------------


extension UniqueIDTests {

  func testInitWithBytes() {

    // These are actually the same type.
    let src: UniqueID.Bytes = Foundation.UUID().uuid
    let uuid = UniqueID(bytes: src)
    withUnsafeBytes(of: src) { srcBytes in
      uuid.withUnsafeBytes {
        XCTAssert($0.elementsEqual(srcBytes))
      }
    }
    // Also, we know that Foundation's UUIDs are version 4.
    XCTAssertEqual(uuid.version, 4)
  }

  func testInitWithBytesSequence() {

    let random = (0..<16).map { _ in UInt8.random(in: 0 ... .max) }
    guard let uuid = UniqueID(bytes: random) else {
      XCTFail()
      return
    }
    uuid.withUnsafeBytes {
      XCTAssert($0.elementsEqual(random))
    }
  }

  func testVersion() {

    // v4
    for _ in 0..<100 {
      let uuid = UniqueID.random()
      XCTAssertEqual(uuid.version, 4)
    }
    // v6
    for _ in 0..<100 {
      let uuid = UniqueID.timeOrdered()
      XCTAssertEqual(uuid.version, 6)
    }
    // Fake UUIDv2 (manually set the version bits).
    do {
      var uuidBytes = UniqueID.random().bytes
      uuidBytes.6 = (uuidBytes.6 & 0xF) | 0x20
      let fakeUUID = UniqueID(bytes: uuidBytes)
      XCTAssertEqual(fakeUUID.version, 2)
    }
    // Non-standard variants should return 'nil' for version.
    do {
      var uuidBytes = UniqueID.random().bytes
      uuidBytes.8 = (uuidBytes.8 & 0x1F) | 0xC0  // 0b110X_XXXX is Microsoft backward compatibility variant.
      let fakeUUID = UniqueID(bytes: uuidBytes)
      XCTAssertNil(fakeUUID.version)
    }
  }

  func testEquatableHashable() {

    let n = 100_000

    var ids = [UniqueID]()
    ids.reserveCapacity(n)

    func testUniqueIDs(_ createID: () -> UniqueID) {
      withoutActuallyEscaping(createID) { createID in
        ids.append(contentsOf: (0..<n).lazy.map { _ in createID() })
      }
      XCTAssertEqual(ids.count, n)

      // Since these are unique IDs, they are, well.. unique.
      let uniqued = Set(ids)
      XCTAssertEqual(uniqued.count, n)
      // Positively affirm that Equatable does find every ID.
      for id in ids {
        XCTAssert(uniqued.contains(id))
      }

      ids.removeAll(keepingCapacity: true)
      XCTAssertEqual(ids.count, 0)
    }

    testUniqueIDs { .random() }
    testUniqueIDs { .timeOrdered() }
    testUniqueIDs { .timeOrdered(node: 99) }
  }

  func testComparable() {

    var ids = (0..<100).map { _ in UniqueID.timeOrdered() }

    // Time-ordered IDs are almost always sorted already; but this isn't a formal guarantee,
    // because time itself is not sorted 😅 - i.e. the system clock may jump backwards
    // by a few nanoseconds during time adjustments.
    // We have safeguards to keep generating unique IDs when that happens, but the timestamps
    // use the new time and hence may compare as less than a previous ID.
    ids.sort()

    var iter = ids.makeIterator()
    var lastUUID = iter.next()!
    while let thisUUID = iter.next() {
      // UUIDs are sorted by their bytes.
      XCTAssertLessThan(lastUUID, thisUUID)
      lastUUID.withUnsafeBytes { last in
        thisUUID.withUnsafeBytes { this in
          XCTAssert(last.lexicographicallyPrecedes(this))
        }
      }
      // For time-ordered IDs, this is the same as sorting by timestamp.
      XCTAssertLessThanOrEqual(
        lastUUID.components(.timeOrdered)!.rawTimestamp, thisUUID.components(.timeOrdered)!.rawTimestamp
      )
      lastUUID = thisUUID
    }
  }

  #if swift(>=5.5) && canImport(_Concurrency)
    func testSendable() {
      func requiresSendable<T: Sendable>(_: T) {}
      requiresSendable(UniqueID.timeOrdered())
    }
  #endif

  func testCodable() throws {

    guard #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) else {
      throw XCTSkip("JSONEncoder.OutputFormatting.sortedKeys requires iOS 11 or newer")
    }

    struct TypeWithUniqueID: Equatable, Codable {
      var name: String
      var id: UniqueID
    }

    struct TypeWithFoundationUUID: Equatable, Codable {
      var name: String
      var id: UUID
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    // Check that UniqueID encodes as expected.
    do {
      let value = TypeWithUniqueID(
        name: "some object", id: UniqueID("1EC3C488-F485-6F38-8000-7DA9862207F3")!
      )
      XCTAssertEqual(
        String(decoding: try encoder.encode(value), as: UTF8.self),
        #"""
        {
          "id" : "1EC3C488-F485-6F38-8000-7DA9862207F3",
          "name" : "some object"
        }
        """#
      )
    }
    // Check that we produce the same encoding as Foundation's UUID,
    // and that each can parse the other's output.
    do {
      for uniqueIDCreator in [UniqueID.random, UniqueID.timeOrdered] {
        for _ in 0..<100 {
          let uniqueID = uniqueIDCreator()

          let foundationValue = TypeWithFoundationUUID(name: "some object", id: UUID(uuid: uniqueID.bytes))
          let foundationData = try encoder.encode(foundationValue)
          let uniqueIDValue = TypeWithUniqueID(name: "some object", id: uniqueID)
          let uniqueIDData = try encoder.encode(uniqueIDValue)
          XCTAssertEqual(foundationData, uniqueIDData)

          let uniqueIDFromFoundation = try JSONDecoder().decode(TypeWithUniqueID.self, from: foundationData)
          let foundationFromUniqueID = try JSONDecoder().decode(TypeWithFoundationUUID.self, from: uniqueIDData)
          XCTAssertEqual(uniqueIDValue, uniqueIDFromFoundation)
          XCTAssertEqual(foundationValue, foundationFromUniqueID)
        }
      }
    }
  }
}


// -------------------------------------
// MARK: - Parsing and serialization.
// -------------------------------------


extension UniqueIDTests {

  func testParse() {

    // Stuff which should parse.

    let originUUID = UniqueID(
      bytes: (0x1E, 0xC3, 0xA5, 0xFB, 0x6F, 0xE9, 0x64, 0xD8, 0x80, 0x04, 0xC7, 0x50, 0x08, 0x7B, 0xF2, 0xDB)
    )

    for stringRepresentation in [
      "1EC3A5FB-6FE9-64D8-8004-C750087BF2DB",  // Standard 8-4-4-4-12
      "1ec3A5fB-6fE9-64d8-8004-c750087Bf2Db",  // Mixed case
      "{1EC3A5FB-6FE9-64D8-8004-C750087BF2DB}",  // Curly braces
      "1ec3a5fb6fe964d88004c750087bf2db",  // No dashes
      "1E-C3-A5-FB-6F-E9-64-D8-80-04-C7-50-08-7B-F2-DB",  // Lots of dashes
      "1E-C3-A5-FB-6F-E9---64-D8-8004C7-50---08-7B-F2-DB",  // Lots of dashes (2)
    ] {
      guard let parsed = UniqueID(stringRepresentation) else {
        XCTFail("Failed to parse \(stringRepresentation)")
        continue
      }
      XCTAssertEqual(originUUID, parsed)
    }

    // Stuff which shouldn't parse.

    for stringRepresentation in [
      "hello",  // Not a UUID
      "http://example.com/",  // Not a UUID (2)
      "(1EC3A5FB-6FE9-64D8-8004-C750087BF2DB)",  // Curved brackets
      "[1EC3A5FB-6FE9-64D8-8004-C750087BF2DB]",  // Square brackets
      "0",  // Not enough bytes
      "123",  // Not enough bytes (2)
      "1ec3a5fb6fe964d88004c750087bf2d",  // Not enough bytes (3)
      "1ec3a5fb6fe964d88004c750087bf2db0",  // Too many bytes
      "1ec3a5fb6fe964d88004c750087bf2db03",  // Too many bytes (2)
      "1E,C3,A5,FB,6F,E9,64,D8,80,04,C7,50,08,7B,F2,DB",  // Other characters between bytes
    ] {
      XCTAssertNil(UniqueID(stringRepresentation))
    }
  }

  func testSerialize() {

    let uniqueID = UniqueID(
      bytes: (0x1E, 0xC3, 0xA5, 0xFB, 0x6F, 0xE9, 0x64, 0xD8, 0x80, 0x04, 0xC7, 0x50, 0x08, 0x7B, 0xF2, 0xDB)
    )
    // Default serialization is 8-4-4-4-12, uppercase.
    XCTAssertEqual(uniqueID.serialized(), "1EC3A5FB-6FE9-64D8-8004-C750087BF2DB")
    XCTAssertEqual(uniqueID.description, "1EC3A5FB-6FE9-64D8-8004-C750087BF2DB")
    // This is the same as Foundation.
    XCTAssertEqual(Foundation.UUID(uuid: uniqueID.bytes).uuidString, uniqueID.serialized())
    XCTAssertEqual(Foundation.UUID(uuid: uniqueID.bytes).description, uniqueID.description)

    // Serialization options.
    XCTAssertEqual(uniqueID.serialized(lowercase: true), "1ec3a5fb-6fe9-64d8-8004-c750087bf2db")
    XCTAssertEqual(uniqueID.serialized(separators: false), "1EC3A5FB6FE964D88004C750087BF2DB")
    XCTAssertEqual(uniqueID.serialized(lowercase: true, separators: false), "1ec3a5fb6fe964d88004c750087bf2db")
  }

  func testReparse() {

    for _ in 0..<1000 {
      let id = UniqueID.random()
      func checkReparse(_ serialization: String) {
        let serialization = String(decoding: serialization.utf8, as: UTF8.self)
        let reparsed = UniqueID(serialization)
        XCTAssertEqual(id, reparsed)
      }
      checkReparse(id.serialized())
      checkReparse(id.serialized(lowercase: true))
      checkReparse(id.serialized(separators: false))
      checkReparse(id.serialized(lowercase: true, separators: false))
    }
  }
}


// -------------------------------------
// MARK: - Other
// -------------------------------------


extension UniqueIDTests {

  #if !NO_FOUNDATION_COMPAT

    func testFoundationCompat() {
      do {
        let uuid: UUID = UUID(.timeOrdered())
        let uniqueID: UniqueID = UniqueID(uuid)
        XCTAssertEqual(uniqueID.description, uuid.description)
      }
      do {
        let uuid = UUID()
        let uniqueID = UniqueID(uuid)
        XCTAssertEqual(uniqueID.description, uuid.description)
      }
    }

  #endif  // NO_FOUNDATION_COMPAT

  func testParseHexTable() {
    XCTAssertEqual(_parseHex_table.count, Int(UInt8.max))
  }
}
