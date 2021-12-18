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

  /// Returns a `String` representation of this UUID.
  ///
  /// By default, this function returns a standard 8-4-4-4-12 UUID string in uppercase.
  ///
  /// ```swift
  /// let id = UniqueID.random()
  ///
  /// print(id.serialized()) // "67E5F28C-5083-4908-BD69-D7E27C8BABA4"
  /// print(id)              // Same as above.
  ///
  /// print(id.serialized(lowercase: true))
  /// // "67e5f28c-5083-4908-bd69-d7e27c8baba4"
  ///
  /// print(id.serialized(separators: false))
  /// // "67E5F28C50834908BD69D7E27C8BABA4"
  ///
  /// print(id.serialized(lowercase: true, separators: false))
  /// // "67e5f28c50834908bd69d7E27c8baba4"
  /// ```
  ///
  /// - parameters:
  ///   - lowercase:  Whether to use lowercase hexadecimal characters in the result.
  ///                 If `false`, the result will be uppercased. The default is `false`.
  ///   - separators: Whether the result should be in the standard 8-4-4-4-12 format, with `"-"` separators
  ///                 between groups. The default is `true`.
  ///
  public func serialized(
    lowercase: Bool = false, separators: Bool = true
  ) -> String {
    let length = 32 + (separators ? 4 : 0)
    if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
      return String(unsafeUninitializedCapacity: length) { buffer in
        serialize(into: buffer, lowercase: lowercase, separators: separators)
      }
    } else {
      let utf8 = Array<UInt8>(unsafeUninitializedCapacity: length) { buffer, count in
        count = serialize(into: buffer, lowercase: lowercase, separators: separators)
      }
      return String(decoding: utf8, as: UTF8.self)
    }
  }

  internal func serialize(
    into buffer: UnsafeMutableBufferPointer<UInt8>,
    lowercase: Bool, separators: Bool
  ) -> Int {
    // format = 8-4-4-4-12
    withUnsafeBytes { octets in
      var i = 0
      // 8:
      for octetPosition in 0..<4 {
        i = buffer.writeHex(octets[octetPosition], at: i, lowercase: lowercase)
      }
      if separators {
        i = buffer.writeDash(at: i)
      }
      // 4:
      for octetPosition in 4..<6 {
        i = buffer.writeHex(octets[octetPosition], at: i, lowercase: lowercase)
      }
      if separators {
        i = buffer.writeDash(at: i)
      }
      // 4:
      for octetPosition in 6..<8 {
        i = buffer.writeHex(octets[octetPosition], at: i, lowercase: lowercase)
      }
      if separators {
        i = buffer.writeDash(at: i)
      }
      // 4:
      for octetPosition in 8..<10 {
        i = buffer.writeHex(octets[octetPosition], at: i, lowercase: lowercase)
      }
      if separators {
        i = buffer.writeDash(at: i)
      }
      // 12:
      for octetPosition in 10..<16 {
        i = buffer.writeHex(octets[octetPosition], at: i, lowercase: lowercase)
      }
      return i
    }
  }
}

extension UnsafeMutableBufferPointer where Element == UInt8 {

  internal func writeHex_uppercase(_ value: UInt8, at i: Index) -> Index {
    let table: StaticString = "0123456789ABCDEF"
    table.withUTF8Buffer { table in
      self[i] = table[Int(value &>> 4)]
      self[i &+ 1] = table[Int(value & 0xF)]
    }
    return i &+ 2
  }

  internal func writeHex_lowercase(_ value: UInt8, at i: Index) -> Index {
    let table: StaticString = "0123456789abcdef"
    table.withUTF8Buffer { table in
      self[i] = table[Int(value &>> 4)]
      self[i &+ 1] = table[Int(value & 0xF)]
    }
    return i &+ 2
  }

  internal func writeHex(_ value: UInt8, at i: Index, lowercase: Bool) -> Index {
    lowercase ? writeHex_lowercase(value, at: i) : writeHex_uppercase(value, at: i)
  }

  internal func writeDash(at i: Index) -> Index {
    self[i] = 0x2D
    return i &+ 1
  }
}
