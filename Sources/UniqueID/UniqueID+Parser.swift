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

extension UniqueID {

  /// Parses a UUID from its string representation.
  ///
  /// This parser accepts a string of 32 ASCII hex characters.
  /// It is quite lenient, accepting any number of dashes (`"-"`) to break the string up in to chunks of
  /// evenly-sized units. Additionally, the UUID may be surrounded by curly braces ("Microsoft style").
  ///
  /// For example, all of the following parse successfully:
  ///
  /// - `1EC3A5FB-6FE9-64D8-8004-C750087BF2DB` (standard)
  /// - `{1ec3a5fb-6fe9-64d8-8004-c750087bf2db}` (curly braces)
  /// - `1ec3A5fB-6fE9-64d8-8004-c750087Bf2Db` (mixed case)
  /// - `1ec3a5fb6fe964d88004c750087bf2db` (no dashes)
  /// - `1E-C3-A5-FB-6F-E9-64-D8-80-04-C7-50-08-7B-F2-DB` (lots of dashes)
  ///
  @inlinable
  public init?<StringType>(
    _ string: StringType
  ) where StringType: StringProtocol, StringType.UTF8View: BidirectionalCollection {
    let parsed = string.utf8.withContiguousStorageIfAvailable { UniqueID(utf8: $0) } ?? UniqueID(utf8: string.utf8)
    guard let parsed = parsed else {
      return nil
    }
    self = parsed
  }

  /// Parses a UUID from its string representation, provided as a collection of UTF-8 code-units.
  ///
  /// This parser accepts a string of 32 ASCII hex characters.
  /// It is quite lenient, accepting any number of dashes (`"-"`) to break the string up in to chunks of
  /// evenly-sized units. Additionally, the UUID may be surrounded by curly braces ("Microsoft style").
  /// For example, all of the following parse successfully:
  ///
  /// - `1EC3A5FB-6FE9-64D8-8004-C750087BF2DB` (standard)
  /// - `{1ec3a5fb-6fe9-64d8-8004-c750087bf2db}` (curly braces)
  /// - `1ec3A5fB-6fE9-64d8-8004-c750087Bf2Db` (mixed case)
  /// - `1ec3a5fb6fe964d88004c750087bf2db` (no dashes)
  /// - `1E-C3-A5-FB-6F-E9-64-D8-80-04-C7-50-08-7B-F2-DB` (lots of dashes)
  ///
  /// > Note:
  /// > This is not the same as constructing a UUID from its raw bytes.
  /// > The bytes provided to this function must contain a formatted UUID string.
  ///
  @inlinable @inline(never)
  public init?<UTF8Bytes>(
    utf8: UTF8Bytes
  ) where UTF8Bytes: BidirectionalCollection, UTF8Bytes.Element == UInt8 {

    var utf8 = utf8[...]
    // Trim curly braces.
    if utf8.first == 0x7B /* "{" */ {
      guard utf8.last == 0x7D /* "}" */ else {
        return nil
      }
      utf8 = utf8.dropFirst().dropLast()
    }
    // Parse the bytes.
    var uuid = UniqueID.null.bytes
    let success = withUnsafeMutableBytes(of: &uuid) { uuidBytes -> Bool in
      var i = utf8.startIndex
      for storagePosition in 0..<16 {
        while i < utf8.endIndex, utf8[i] == 0x2D /* "-" */ {
          utf8.formIndex(after: &i)
        }
        guard let parsedByte = utf8.parseByte(at: &i) else {
          return false
        }
        uuidBytes[storagePosition] = parsedByte
      }
      return i == utf8.endIndex
    }
    guard success else { return nil }
    self = UniqueID(bytes: uuid)
  }
}

@usableFromInline internal let DC: Int8 = -1
// swift-format-ignore
@usableFromInline internal let _parseHex_table: [Int8] = [
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC, // 48 invalid chars.
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC,
    00, 01, 02, 03, 04, 05, 06, 07, 08, 09, // numbers 0-9
    DC, DC, DC, DC, DC, DC, DC,             // 7 invalid chars from ':' to '@'
    10, 11, 12, 13, 14, 15,                 // uppercase A-F
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC, // 20 invalid chars G-Z
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC,                 // 6 invalid chars from '[' to '`'
    10, 11, 12, 13, 14, 15,                 // lowercase a-f
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC, // 20 invalid chars g-z
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC,                     // 5 invalid chars from '{' to '(delete)'
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC, // 128 non-ASCII chars.
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC, DC, DC, DC,
    DC, DC, DC, DC, DC, DC, DC,
]

/// Returns the numeric value of the hex digit `ascii`, if it is a hex digit (0-9, A-F, a-f).
///
@inlinable
internal func asciiToHex(_ ascii: UInt8) -> UInt8? {
  let numericValue = _parseHex_table.withUnsafeBufferPointer { $0[Int(ascii)] }
  return numericValue < 0 ? nil : UInt8(bitPattern: numericValue)
}

extension Collection where Element == UInt8 {

  @inlinable
  internal func parseByte(at i: inout Index) -> UInt8? {
    guard i < endIndex, let firstNibble = asciiToHex(self[i]) else { return nil }
    formIndex(after: &i)
    guard i < endIndex, let secondNibble = asciiToHex(self[i]) else { return nil }
    formIndex(after: &i)
    return (firstNibble &<< 4) | secondNibble
  }
}
