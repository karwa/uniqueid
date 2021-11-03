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


// -------------------------------------
// MARK: - Creation
// -------------------------------------


import Atomics

@usableFromInline
internal struct UUIDv6GeneratorState {

  @usableFromInline
  internal var timestamp: UInt64

  @usableFromInline
  internal var sequence: UInt16

  init() {
    self.timestamp = 0
    // Seed the value, so sequence numbers start from a random spot.
    // Adds another little bit of spatial uniqueness, while preserving locality.
    var rng = SystemRandomNumberGenerator()
    self.sequence = rng.next() & 0x3FFF
  }
}

@usableFromInline
internal var _uuidv6GeneratorState = UUIDv6GeneratorState()
@usableFromInline
internal let _uuidv6GeneratorStateLock = UnsafeAtomic<Bool>.create(false)

@inlinable
internal func withExclusiveGeneratorState<T>(_ body: (inout UUIDv6GeneratorState) -> T) -> T {
  while !_uuidv6GeneratorStateLock.weakCompareExchange(
    expected: false, desired: true, successOrdering: .relaxed, failureOrdering: .relaxed
  ).exchanged {}
  atomicMemoryFence(ordering: .acquiring)
  let returnValue = body(&_uuidv6GeneratorState)
  atomicMemoryFence(ordering: .releasing)
  _uuidv6GeneratorStateLock.store(false, ordering: .relaxed)
  return returnValue
}

extension UniqueID {

  /// Generates a new UUID sortable by creation time, using the system's random number generator.
  ///
  /// This function generates version 6 UUIDs, which are currently in [draft form][UUIDv6-draft-02].
  /// They ensure uniqueness in time and space using 3 components:
  /// 1. An embedded timestamp, taken from the system clock with 100ns resolution.
  /// 2. A 14-bit sequence number, which is a synchronized process-wide counter ensuring UUIDs within each 100ns timestamp are unique.
  /// 3. A 48-bit node identifier, which distinguishes UUIDs in space. Typically, these are random or pseudo-random bits, but an application-specific
  ///   identifier may also be used.
  ///
  /// Version 6 UUIDs are similar to version 1 UUIDs from RFC-4122, except that their timestamps are stored in a manner friendly for sorting and filtering,
  /// and their better locality improves the performance of many databases and data structures. They are highly resistant to collisions, and can incorporate
  /// externally-derived identifiers for even greater collision guarantees in the context of a particular distributed system or application.
  ///
  /// [UUIDv6-draft-02]: https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02
  ///
  @inlinable
  public static func timeOrdered() -> UniqueID {
    var rng = SystemRandomNumberGenerator()
    return timeOrdered(using: &rng)
  }

  /// Generates a new UUID sortable by creation time, using the given random number generator.
  ///
  /// This function generates version 6 UUIDs, which are currently in [draft form][UUIDv6-draft-02].
  /// They ensure uniqueness in time and space using 3 components:
  /// 1. An embedded timestamp, taken from the system clock with 100ns resolution.
  /// 2. A 14-bit sequence number, which is a synchronized process-wide counter ensuring UUIDs within each 100ns timestamp are unique.
  /// 3. A 48-bit node identifier, which distinguishes UUIDs in space. Typically, these are random or pseudo-random bits, but an application-specific
  ///   identifier may also be used.
  ///
  /// Version 6 UUIDs are similar to version 1 UUIDs from RFC-4122, except that their timestamps are stored in a manner friendly for sorting and filtering,
  /// and their better locality improves the performance of many databases and data structures. They are highly resistant to collisions, and can incorporate
  /// externally-derived identifiers for even greater collision guarantees in the context of a particular distributed system or application.
  ///
  /// [UUIDv6-draft-02]: https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02
  ///
  /// - parameters:
  ///   - rng: The random number generator used to create a node identifier.
  ///
  @inlinable
  public static func timeOrdered<RNG>(using rng: inout RNG) -> UniqueID where RNG: RandomNumberGenerator {
    // Set the IEEE 802 multicast bit for random node-IDs, as recommended by RFC-4122.
    let node = rng.next() | 0x0000_0100_0000_0000
    return timeOrdered(node: node)
  }

  /// Generates a new UUID sortable by creation time, with a particular node identifier.
  ///
  /// This function generates version 6 UUIDs, which are currently in [draft form][UUIDv6-draft-02].
  /// They ensure uniqueness in time and space using 3 components:
  /// 1. An embedded timestamp, taken from the system clock with 100ns resolution.
  /// 2. A 14-bit sequence number, which is a synchronized process-wide counter ensuring UUIDs within each 100ns timestamp are unique.
  /// 3. A 48-bit node identifier, which distinguishes UUIDs in space. Typically, these are random or pseudo-random bits, but an application-specific
  ///   identifier may also be used.
  ///
  /// Version 6 UUIDs are similar to version 1 UUIDs from RFC-4122, except that their timestamps are stored in a manner friendly for sorting and filtering,
  /// and their better locality improves the performance of many databases and data structures. They are highly resistant to collisions, and can incorporate
  /// externally-derived identifiers for even greater collision guarantees in the context of a particular distributed system or application.
  ///
  /// Using a stable node identifier can guarantee collision avoidance in many applications - for example, 48 bits may be sufficient to create a combined
  /// `[ user ID | device ID | process counter ]` value, with user and device ID combinations being guaranteed unique by a server
  /// and reflecting that, at any particular time, a given user's device only has a limited number of processes generating IDs for your database.
  ///
  /// You don't necessarily need external co-ordination - a 47-bit random value has sufficient entropy for most applications, but for distributed systems and
  /// applications where collision probabilties are higher, it often doesn't cost much to get it. Note that using a stable node identifier limits the number of
  /// unique IDs within each 100ns timestamp to 16,384 (the number of unique sequence numbers), shared across all time-ordered UUIDs.
  /// This usually isn't a problem - 16K UUIDs per 100ns is an extremely high frequency.
  ///
  /// [UUIDv6-draft-02]: https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02
  ///
  /// - parameters:
  ///   - node: A node identifier, used to distinguish UUIDs in space (e.g. across processes/machines, tracking different sequence numbers).
  ///           This may be an sequence of random or pseudo-random bits, or a value with meaning to your application (e.g. a combined user/device ID).
  ///           Only the bottom 48 bits will be used.
  ///
  @inlinable
  public static func timeOrdered(node: UInt64) -> UniqueID {
    let timestamp = _get_system_timestamp()
    // TODO: Consider an API for stable node identifiers to use their own (perhaps Thread/Task-local) sequence counters.
    //       This will stop the couner overflowing too quickly. Also, the sequence counter might want to work
    //       differently if the clock goes back and we can't rely on the node-ID to provide uniqueness.
    let sequence = withExclusiveGeneratorState { state -> UInt16 in
      if state.timestamp >= timestamp {
        state.sequence &+= 1
      }
      state.timestamp = timestamp
      return state.sequence
    }
    return timeOrdered(rawTimestamp: _unix_to_uuid_timestamp(unix: timestamp), sequence: sequence, node: node)
  }

  /// Creates a UUID sortable by creation time, using the given component values.
  ///
  /// This function creates a version 6 UUID, which are currently in [draft form][UUIDv6-draft-02].
  /// They ensure uniqueness in time and space using 3 components:
  /// 1. An embedded timestamp, taken from the system clock with 100ns resolution.
  /// 2. A 14-bit sequence number, which is a synchronized process-wide counter ensuring UUIDs within each 100ns timestamp are unique.
  /// 3. A 48-bit node identifier, which distinguishes UUIDs in space. Typically, these are random or pseudo-random bits, but an application-specific
  ///   identifier may also be used.
  ///
  /// Version 6 UUIDs are similar to version 1 UUIDs from RFC-4122, except that their timestamps are stored in a manner friendly for sorting and filtering,
  /// and their better locality improves the performance of many databases and data structures. They are highly resistant to collisions, and can incorporate
  /// externally-derived identifiers for even greater collision guarantees in the context of a particular distributed system or application.
  ///
  /// Creating a UUID with a particular timestamp can be helpful when filtering UUIDs to ranges of time. For example, all UUIDs greater than
  /// `1EC3B396-11B7-6818-8000-000000000000` where created after 2021-11-01 17:30:17 (UTC).
  ///
  /// [UUIDv6-draft-02]: https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02
  ///
  /// - parameters:
  ///   - rawTimestamp: The timestamp, as a number of 100ns intervals from 00:00:00 October 15, 1582. Only the least significant 60 bits will be used.
  ///   - sequence:     The sequence number. Only the least significant 12 bits will be used. The default is 0.
  ///   - node:         The node ID. Only the least significant 48 bits will be used. The default is 0.
  ///
  /// - returns: A UUID, version 6, with the given component values.
  ///
  @inlinable
  public static func timeOrdered(rawTimestamp: UInt64, sequence: UInt16 = 0, node: UInt64 = 0) -> UniqueID {
    var timestampAndVersion = (rawTimestamp &<< 4).bigEndian
    Swift.withUnsafeMutableBytes(of: &timestampAndVersion) { timestamp_bytes in
      // Insert the 4 version bits in the top half of octet 6.
      timestamp_bytes[7] = timestamp_bytes[6] &<< 4 | timestamp_bytes[7] &>> 4
      timestamp_bytes[6] = 0x60 | timestamp_bytes[6] &>> 4
    }
    // Top 2 bits of octet 8 are the variant (0b10 = standard).
    let sequenceAndVariant = ((sequence & 0x3FFF) | 0x8000).bigEndian
    let nodeBE = node.bigEndian

    var _uuidStorage = UniqueID.null.bytes
    withUnsafeMutableBytes(of: &_uuidStorage) { bytes in
      Swift.withUnsafeBytes(of: timestampAndVersion) {
        bytes.baseAddress!.copyMemory(from: $0.baseAddress!, byteCount: 8)
      }
      Swift.withUnsafeBytes(of: sequenceAndVariant) {
        (bytes.baseAddress! + 8).copyMemory(from: $0.baseAddress!, byteCount: 2)
      }
      Swift.withUnsafeBytes(of: nodeBE) {
        (bytes.baseAddress! + 10).copyMemory(from: $0.baseAddress! + 2, byteCount: 6)
      }
    }
    return UniqueID(bytes: _uuidStorage)
  }
}


// -------------------------------------
// MARK: - UUID components
// -------------------------------------


extension UniqueID.Components where Self == UniqueID.TimeOrdered {
  public static var timeOrdered: Self { fatalError("Not intended to be called") }
}

extension UniqueID {

  /// The components of a time-ordered (version 6) UUID.
  ///
  public struct TimeOrdered: UniqueID.Components {

    public let uuid: UniqueID

    @inlinable
    public init?(_ uuid: UniqueID) {
      guard uuid.version == 6 else { return nil }
      self.uuid = uuid
    }

    /// The timestamp of this UUID, as a number of 100ns intervals since 00:00:00 October 15, 1582. Note that only the least-significant 60 bits are used.
    ///
    @inlinable
    public var rawTimestamp: UInt64 {
      var timestamp: UInt64 = 0
      Swift.withUnsafeMutableBytes(of: &timestamp) { timestamp_bytes in
        uuid.withUnsafeBytes { uuidBytes in
          timestamp_bytes.copyMemory(from: UnsafeRawBufferPointer(start: uuidBytes.baseAddress, count: 8))
        }
        // Remove the UUID version bits.
        timestamp_bytes[6] = timestamp_bytes[6] &<< 4 | timestamp_bytes[7] &>> 4
        timestamp_bytes[7] = timestamp_bytes[7] &<< 4
      }
      return (timestamp.bigEndian &>> 4)  // Widen to 64 bits
    }

    /// The sequence number of this UUID. This is generally just an opaque number. Note that only the least-significant 14 bits are used.
    ///
    @inlinable
    public var sequence: UInt16 {
      var clk_seq: UInt16 = 0
      withUnsafeMutableBytes(of: &clk_seq) { clk_seq_bytes in
        uuid.withUnsafeBytes { uuid_bytes in
          clk_seq_bytes.copyMemory(from: UnsafeRawBufferPointer(start: uuid_bytes.baseAddress! + 8, count: 2))
        }
      }
      return (clk_seq.bigEndian & 0x3FFF)  // Remove the variant bits.
    }

    /// The node identifier of this UUID. This may be random, or it may have some context-specific meaning. Note that only the least-significant 48 bits are used.
    ///
    @inlinable
    public var node: UInt64 {
      var node: UInt64 = 0
      Swift.withUnsafeMutableBytes(of: &node) { nodeID_bytes in
        uuid.withUnsafeBytes { uuidBytes in
          nodeID_bytes.baseAddress!.advanced(by: 2).copyMemory(from: uuidBytes.baseAddress! + 10, byteCount: 6)
        }
      }
      return node.bigEndian
    }
  }
}
