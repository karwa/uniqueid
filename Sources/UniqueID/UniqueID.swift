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
/// A UUID can be used for multiple purposes, from tagging objects with an extremely short lifetime, to reliably identifying very persistent objects across a network.
///
/// `UniqueID` supports any 128-bit UUID, and includes features to generate 2 kinds of ID:
///
/// - **random**: As defined in [RFC-4122][RFC-4122-UUIDv4] (UUIDv4). A 128-bit identifier, consisting of 122 random or pseudo-random bits.
///   These are the most common form of UUIDs; for example, they are the ones Foundation's `UUID` type creates by default.
///   The idea is that because this is such a large number, the chance of a system observing a collision is so low that it can be safely ignored.
///   That said, they rely heavily on the amount of entropy in the random bits, and when a system is ingesting IDs created by distributed nodes or devices,
///   the chances of collision may be higher.
///
/// - **time-ordered**: Generated according to a [draft update of RFC-4122][UUIDv6-draft-02] (UUIDv6). A 128-bit identifier, consisting of a
///   fixed-precision timestamp, per-process sequencing number, and 47-bit node ID (which may be random or pseudo-random bits). Whilst RFC-4122
///   did include time-based UUIDs (UUIDv1), it ordered the bits such that they had poor locality and couldn't be sorted easily. UUIDv6 rearranges these bits,
///   which dramatically improves their usability as database keys. The node ID can be configured to provide even better resilience against collisions.
///
/// [RFC-4122-UUIDv4]: https://datatracker.ietf.org/doc/html/rfc4122#section-4.4
/// [UUIDv6-draft-02]: https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02
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
  /// The pointer provided to `body` must not escape the closure.
  ///
  @inlinable
  public func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
    try Swift.withUnsafeBytes(of: bytes, body)
  }
}
