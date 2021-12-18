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

/// A Universally Unique IDentifier (UUID).
///
/// A UUID is an identifier that is unique across both space and time, with respect to the space of all UUIDs.
/// A UUID can be used for multiple purposes, from tagging objects with an extremely short lifetime,
/// to reliably identifying very persistent objects across a network.
///
/// `UniqueID` supports any 128-bit UUID, and includes features to generate 2 kinds of ID:
///
/// - **Random**: As defined in [RFC-4122][RFC-4122-UUIDv4] (UUIDv4).
///
///   A 128-bit identifier, consisting of 122 random bits.
///   These are the most common form of UUIDs; for example, they are the ones Foundation's `UUID` type creates
///   by default. To generate a random UUID, call the static ``random()`` function.
///
///   ```swift
///   for _ in 0..<3 {
///     print(UniqueID.random())
///   }
///   "DFFC75B4-C92F-4DA9-97CA-7F0EEF067FF2"
///   "67E5F28C-5083-4908-BD69-D7E27C8BABA4"
///   "3BA8EEF0-DFBE-4AE0-A646-E165FCA9054C"
///   ```
///
/// - **Time-Ordered**: Generated according to a [draft update of RFC-4122][UUIDv6-draft-02] (UUIDv6).
///
///   A 128-bit identifier, consisting of a 60-bit timestamp with 100ns precision, a 14-bit sequencing number seeded
///   from random bits, and a 48-bit node ID (which may also be random bits). To generate a time-ordered UUID,
///   call the static ``timeOrdered()`` function.
///
///   ```swift
///   for _ in 0..<3 {
///     print(UniqueID.timeOrdered())
///   }
///
///   "1EC3C81E-A361-658C-BB38-65AAEF71CFCF"
///   "1EC3C81E-A361-6F6E-BB38-6DE69B9BCA1B"
///   "1EC3C81E-A362-698C-BB38-050642A95C73"
///    |------------- --| |--| |----------|
///        timestamp       sq      node
///   ```
///
///   As you can see, time-ordered UUIDs generated in sequence share a common prefix (from the timestamp), yet
///   retain high collision avoidance. This allows the use of sorted data structures and algorithms
///   such as binary search, as an alternative to hash tables. They are far more efficient than random UUIDs for use
///   as database primary keys.
///
/// > Tip:
/// > Random and Time-Ordered UUIDs may coexist in the same database.
/// > They have different version numbers, so they are guaranteed to never collide.
///
///
/// ### Compatibility with Foundation UUID
///
///
/// `UniqueID` is fully compatible with Foundation's `UUID` type, including being compatible with UUIDs in serialized
/// JSON form. This makes it easy to experiment with time-ordered UUIDs in your application:
///
/// ```swift
/// // Change from `UUID()` to `UUID(.timeOrdered())`:
/// import Foundation
/// import UniqueID
///
/// struct MyRecord {
///   var id = UUID(.timeOrdered())  // <--
///   // Other properties...
/// }
/// ```
///
/// To construct a `UniqueID` from a Foundation `UUID`, simply initialize a value:
///
/// ```swift
/// import Foundation
/// import UniqueID
///
/// let foundationID = UUID()
/// let swiftID = UniqueID(foundationID)  // <--
/// ```
///
///
/// ### Reading UUID Components
///
///
/// Time-ordered UUIDs include components with meaningful values - such as the time they were generated.
/// To read these values, use the ``components(_:)`` function:
///
/// ```swift
/// let id = UniqueID("1EC5FE44-E511-6910-BBFA-F7B18FB57436")!
/// id.components(.timeOrdered)?.timestamp
/// // ✅ "2021-12-18 09:24:31 +0000"
/// ```
///
///
/// [RFC-4122-UUIDv4]: https://datatracker.ietf.org/doc/html/rfc4122#section-4.4
/// [UUIDv6-draft-02]: https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02
///
/// ## Topics
///
/// ### Generating a UUID
///
/// - ``random()``
/// - ``random(using:)``
/// - ``timeOrdered()``
/// - ``timeOrdered(using:)``
///
/// ### Converting from a Foundation UUID
///
/// - ``init(_:)-30hew``
///
/// ### Parsing a UUID String
///
/// - ``init(_:)-7p61g``
/// - ``init(utf8:)``
///
/// ### Obtaining a UUID's String Representation
///
/// - ``serialized(lowercase:separators:)``
///
/// ### UUIDs as Bytes
///
/// - ``init(bytes:)-6y0j``
/// - ``init(bytes:)-bnh6``
/// - ``bytes-swift.property``
/// - ``withUnsafeBytes(_:)``
///
/// ### Reading a UUID's Components
///
/// - ``components(_:)``
/// - ``TimeOrdered``
///
/// ### Advanced UUID Generation
///
/// - ``timeOrdered(node:)``
/// - ``timeOrdered(rawTimestamp:sequence:node:)``
///
/// ### Other
///
/// - ``version``
/// - ``null``
///
public struct UniqueID {

  public typealias Bytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
  )

  /// The bytes of this UUID.
  ///
  public let bytes: Bytes

  /// Creates a UUID with the given bytes.
  ///
  @inlinable
  public init(bytes: Bytes) {
    self.bytes = bytes
  }

  /// The null UUID, `00000000-0000-0000-0000-000000000000`.
  ///
  @inlinable
  public static var null: UniqueID {
    UniqueID(bytes: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
  }

  /// Creates a UUID with the given sequence of bytes. The sequence must contain exactly 16 bytes.
  ///
  @inlinable
  public init?<Bytes>(bytes: Bytes) where Bytes: Sequence, Bytes.Element == UInt8 {
    var uuid = UniqueID.null.bytes
    let bytesCopied = withUnsafeMutableBytes(of: &uuid) { uuidBytes in
      UnsafeMutableBufferPointer(
        start: uuidBytes.baseAddress.unsafelyUnwrapped.assumingMemoryBound(to: UInt8.self),
        count: 16
      ).initialize(from: bytes).1
    }
    guard bytesCopied == 16 else { return nil }
    self.init(bytes: uuid)
  }
}


// -------------------------------------
// MARK: - Standard protocols
// -------------------------------------


extension UniqueID: Equatable, Hashable, Comparable {

  @inlinable
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.withUnsafeBytes { lhsBytes in
      rhs.withUnsafeBytes { rhsBytes in
        lhsBytes.elementsEqual(rhsBytes)
      }
    }
  }

  @inlinable
  public func hash(into hasher: inout Hasher) {
    withUnsafeBytes { hasher.combine(bytes: $0) }
  }

  @inlinable
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.withUnsafeBytes { lhsBytes in
      rhs.withUnsafeBytes { rhsBytes in
        lhsBytes.lexicographicallyPrecedes(rhsBytes)
      }
    }
  }
}

#if swift(>=5.5) && canImport(_Concurrency)
  extension UniqueID: Sendable {}
#endif

extension UniqueID: CustomStringConvertible, LosslessStringConvertible {

  @inlinable
  public var description: String {
    serialized()
  }
}

extension UniqueID: Codable {

  @inlinable
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    guard let decoded = UniqueID(try container.decode(String.self)) else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid UUID string")
    }
    self = decoded
  }

  @inlinable
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(serialized())
  }
}


// -------------------------------------
// MARK: - Basic properties
// -------------------------------------


extension UniqueID {

  /// The version of this UUID, if it can be determined.
  ///
  @inlinable
  public var version: Int? {
    // Check the variant.
    guard (bytes.8 &>> 6) == 0b00000010 else { return nil }
    // Extract the version bits.
    return Int((bytes.6 & 0b1111_0000) &>> 4)
  }

  /// Invokes `body` with a pointer to the bytes of this UUID.
  ///
  /// ```swift
  /// let id = UniqueID.random()
  /// id.withUnsafeBytes { bytes in
  ///   // ... use 'bytes'
  /// }
  /// ```
  ///
  /// > Important:
  /// > The pointer provided to `body` must not escape the closure.
  ///
  @inlinable
  public func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
    try Swift.withUnsafeBytes(of: bytes, body)
  }
}
