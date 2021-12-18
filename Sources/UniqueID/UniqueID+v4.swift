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

  /// Generates a new UUID with random bits from the system's random number generator.
  ///
  /// This function generates version 4 UUIDs, as defined by [RFC-4122][RFC-4122-UUIDv4].
  /// They are 128-bit identifiers, consisting of 122 random or pseudo-random bits, and are the most common form of UUIDs;
  /// for example, they are the ones Foundation's `UUID` type creates by default.
  ///
  /// ```swift
  /// for _ in 0..<5 {
  ///   print(UniqueID.random())
  /// }
  ///
  /// "BB0B5841-2BC0-49E2-BC5C-362CC34D7225"
  /// "B08AF1F7-E2D3-4175-913D-369140612FF5"
  /// "A453FB62-DF71-436F-9AC1-0414793DFA16"
  /// "485EEB84-A4BA-44FE-BE3B-AD90390B0523"
  /// "8A9AE1FA-4104-442C-B459-8F682E77F2F4"
  /// ```
  ///
  /// > Note:
  /// > The uniqueness of these IDs depends on the quality of the system's random number generator.
  /// > See [`SystemRandomNumberGenerator`](https://developer.apple.com/documentation/swift/systemrandomnumbergenerator)
  /// > for more information.
  ///
  /// [RFC-4122-UUIDv4]: https://datatracker.ietf.org/doc/html/rfc4122#section-4.4
  ///
  @inlinable
  public static func random() -> UniqueID {
    var rng = SystemRandomNumberGenerator()
    return random(using: &rng)
  }

  /// Generates a new UUID with random bits from the given random number generator.
  ///
  /// This function generates version 4 UUIDs, as defined by [RFC-4122][RFC-4122-UUIDv4].
  /// They are 128-bit identifiers, consisting of 122 random or pseudo-random bits, and are the most common form of UUIDs;
  /// for example, they are the ones Foundation's `UUID` type creates by default.
  ///
  /// ```swift
  /// var rng = MyRandomNumberGenerator()
  /// for _ in 0..<5 {
  ///   print(UniqueID.random(using: &rng))
  /// }
  ///
  /// "BB0B5841-2BC0-49E2-BC5C-362CC34D7225"
  /// "B08AF1F7-E2D3-4175-913D-369140612FF5"
  /// "A453FB62-DF71-436F-9AC1-0414793DFA16"
  /// "485EEB84-A4BA-44FE-BE3B-AD90390B0523"
  /// "8A9AE1FA-4104-442C-B459-8F682E77F2F4"
  /// ```
  ///
  /// > Note:
  /// > The uniqueness of these IDs depends on the properties of the given random number generator.
  /// > A poor-quality generator may result in more collisions, and a seedable generator can be used in testing
  /// > to generate repeatable IDs.
  ///
  /// [RFC-4122-UUIDv4]: https://datatracker.ietf.org/doc/html/rfc4122#section-4.4
  ///
  @inlinable
  public static func random<RNG>(using rng: inout RNG) -> UniqueID where RNG: RandomNumberGenerator {
    var bytes = UniqueID.null.bytes
    withUnsafeMutableBytes(of: &bytes) { dest in
      var random = rng.next()
      Swift.withUnsafePointer(to: &random) {
        dest.baseAddress!.copyMemory(from: UnsafeRawPointer($0), byteCount: 8)
      }
      random = rng.next()
      Swift.withUnsafePointer(to: &random) {
        dest.baseAddress!.advanced(by: 8).copyMemory(from: UnsafeRawPointer($0), byteCount: 8)
      }
    }
    // octet 6 = time_hi_and_version (high octet).
    // high 4 bits = version number.
    bytes.6 = (bytes.6 & 0xF) | 0x40
    // octet 8 = clock_seq_high_and_reserved.
    // high 2 bits = variant (10 = standard).
    bytes.8 = (bytes.8 & 0x3F) | 0x80
    return UniqueID(bytes: bytes)
  }
}
