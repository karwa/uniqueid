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

#if canImport(Darwin)

  import Darwin

  @usableFromInline
  internal var _uuidv6GeneratorStateLock: UnsafeMutablePointer<os_unfair_lock> = {
    let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
    lock.initialize(to: os_unfair_lock())
    return lock
  }()

  @inlinable
  internal func withExclusiveGeneratorState<T>(_ body: (inout UUIDv6GeneratorState) -> T) -> T {
    os_unfair_lock_lock(_uuidv6GeneratorStateLock)
    let returnValue = body(&_uuidv6GeneratorState)
    os_unfair_lock_unlock(_uuidv6GeneratorStateLock)
    return returnValue
  }

#elseif canImport(Glibc)

  import Glibc

  @usableFromInline
  internal var _uuidv6GeneratorStateLock: UnsafeMutablePointer<pthread_mutex_t> = {
    let mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    mutex.initialize(to: pthread_mutex_t())

    var attrs = pthread_mutexattr_t()
    guard pthread_mutexattr_init(&attrs) == 0 else { fatalError("Failed to create pthread_mutexattr_t") }
    // Use adaptive spinning before calling in to the kernel (GNU extension).
    let _ = pthread_mutexattr_settype(&attrs, CInt(PTHREAD_MUTEX_ADAPTIVE_NP))
    guard pthread_mutex_init(mutex, &attrs) == 0 else { fatalError("Failed to create pthread_mutex_t") }
    pthread_mutexattr_destroy(&attrs)

    return mutex
  }()

  @inlinable
  internal func withExclusiveGeneratorState<T>(_ body: (inout UUIDv6GeneratorState) -> T) -> T {
    pthread_mutex_lock(_uuidv6GeneratorStateLock)
    let returnValue = body(&_uuidv6GeneratorState)
    pthread_mutex_unlock(_uuidv6GeneratorStateLock)
    return returnValue
  }

#else

  #error("Unsupported platform")

#endif

extension UniqueID {

  /// Generates a new UUID sortable by creation time, using the system's random number generator.
  ///
  /// This function generates version 6 UUIDs, which are currently in [draft form][UUIDv6-draft-02].
  /// They ensure uniqueness in time and space using 3 components:
  ///
  /// 1. A 60-bit embedded timestamp, taken from the system clock with 100ns resolution.
  /// 2. A 14-bit sequence number, which is a synchronized counter ensuring uniqueness even if the clock is adjusted.
  /// 3. A 48-bit node identifier, which distinguishes UUIDs in space.
  ///    Typically, these are random bits, but an application-specific identifier may also be used.
  ///
  /// ```swift
  /// for _ in 0..<5 {
  ///   print(UniqueID.timeOrdered())
  /// }
  ///
  /// "1EC5FEC5-F35E-6C08-B6CE-27381D0BBB75"
  /// "1EC5FEC5-F360-659E-B6CE-6F4CD8641BCC"
  /// "1EC5FEC5-F360-69EA-B6CE-212F47E81DBA"
  /// "1EC5FEC5-F360-6DA0-B6CE-13C650E0F431"
  /// "1EC5FEC5-F361-61A6-B6CE-3FD9EDD8DB87"
  ///  |------------- --| |--| |----------|
  ///      timestamp       sq      node
  /// ```
  ///
  /// Version 6 UUIDs are similar to version 1 UUIDs from RFC-4122, except that their timestamps are stored
  /// in a sorting- and filtering-friendly manner, and their better locality improves the performance of
  /// many databases and data structures. They are highly resistant to collisions, and can incorporate
  /// externally-derived identifiers for even greater guarantees in distributed systems or applications.
  ///
  /// > Note:
  /// > The uniqueness of these IDs depends on the quality of the system clock, and the system's random number generator.
  /// > See [`SystemRandomNumberGenerator`](https://developer.apple.com/documentation/swift/systemrandomnumbergenerator)
  /// > for more information.
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
  ///
  /// 1. A 60-bit embedded timestamp, taken from the system clock with 100ns resolution.
  /// 2. A 14-bit sequence number, which is a synchronized counter ensuring uniqueness even if the clock is adjusted.
  /// 3. A 48-bit node identifier, which distinguishes UUIDs in space.
  ///    Typically, these are random bits, but an application-specific identifier may also be used.
  ///
  /// ```swift
  /// var rng = MyRandomNumberGenerator()
  /// for _ in 0..<5 {
  ///   print(UniqueID.timeOrdered(using: &rng))
  /// }
  ///
  /// "1EC5FEC5-F35E-6C08-B6CE-27381D0BBB75"
  /// "1EC5FEC5-F360-659E-B6CE-6F4CD8641BCC"
  /// "1EC5FEC5-F360-69EA-B6CE-212F47E81DBA"
  /// "1EC5FEC5-F360-6DA0-B6CE-13C650E0F431"
  /// "1EC5FEC5-F361-61A6-B6CE-3FD9EDD8DB87"
  ///  |------------- --| |--| |----------|
  ///      timestamp       sq      node
  /// ```
  ///
  /// Version 6 UUIDs are similar to version 1 UUIDs from RFC-4122, except that their timestamps are stored
  /// in a sorting- and filtering-friendly manner, and their better locality improves the performance of
  /// many databases and data structures. They are highly resistant to collisions, and can incorporate
  /// externally-derived identifiers for even greater guarantees in distributed systems or applications.
  ///
  /// > Note:
  /// > The uniqueness of these IDs depends on the properties of the given random number generator.
  /// > A poor-quality generator may result in more collisions, and a seedable generator can be used in testing
  /// > to generate repeatable IDs.
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
  ///
  /// 1. A 60-bit embedded timestamp, taken from the system clock with 100ns resolution.
  /// 2. A 14-bit sequence number, which is a synchronized counter ensuring uniqueness even if the clock is adjusted.
  /// 3. A 48-bit node identifier, which distinguishes UUIDs in space.
  ///    Typically, these are random bits, but an application-specific identifier may also be used.
  ///
  /// The following example demonstrates using a custom node ID, which is derived from a user and device ID which
  /// our backend guarantees is unique. In this case, we use a 36-bit user ID (sufficient for more than 68 billion users),
  /// an 8-bit device ID (for 256 devices per user), and 4-bit process ID (for 16 processes per device per user).
  ///
  /// ```swift
  /// // Combine unique information in to a 48-bit number.
  /// // These IDs are guaranteed unique by a backend service.
  /// let nodeID = makeNodeID(
  ///   userID:    currentUserID,
  ///   deviceID:  currentDeviceID,
  ///   processID: currentProcessID
  /// )
  ///
  /// for _ in 0..<5 {
  ///   print(UniqueID.timeOrdered(node: nodeID))
  /// }
  ///
  /// "1EC5FEC5-F35E-6C08-B6CE-38FC91741020"
  /// "1EC5FEC5-F360-659E-B6CE-38FC91741020"
  /// "1EC5FEC5-F360-69EA-B6CE-38FC91741020"
  /// "1EC5FEC5-F360-6DA0-B6CE-38FC91741020"
  /// "1EC5FEC5-F361-61A6-B6CE-38FC91741020"
  ///  |------------- --| |--| |-------|-||
  ///      timestamp       sq     user  d p
  /// ```
  ///
  /// Provided our backend system is reliable at keeping these user/device/process IDs unique, we are able
  /// to create far more robust IDs at much larger scale than is possible with random (v4) UUIDs, with all of the
  /// benefits to database performance that come with time-ordered IDs. Many distributed systems and applications
  /// are able to offer these kinds of IDs basically "for free" anyway.
  ///
  /// Note that using a stable node identifier limits the number of unique IDs within each 100ns timestamp to 16,384
  /// (the number of unique sequence numbers). This usually isn't a problem - 16K UUIDs per 100ns is
  /// an extremely high frequency.
  ///
  /// [UUIDv6-draft-02]: https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02
  ///
  /// - parameters:
  ///   - node: A node identifier, used to distinguish UUIDs in space
  ///           (e.g. across processes/machines, tracking different sequence numbers).
  ///           This may be an sequence of random or pseudo-random bits, or a value with meaning to your application
  ///           (e.g. a combined user/device ID). Only the bottom 48 bits will be used.
  ///
  @inlinable
  public static func timeOrdered(node: UInt64) -> UniqueID {
    let timestamp = _get_system_timestamp()
    // TODO: Consider an API for stable node identifiers to use their own (perhaps Thread/Task-local) sequence counters.
    //       This will stop the counter overflowing too quickly. Also, the sequence counter might want to work
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
  /// This function generates version 6 UUIDs, which are currently in [draft form][UUIDv6-draft-02].
  /// They ensure uniqueness in time and space using 3 components:
  ///
  /// 1. A 60-bit embedded timestamp, taken from the system clock with 100ns resolution.
  /// 2. A 14-bit sequence number, which is a synchronized counter ensuring uniqueness even if the clock is adjusted.
  /// 3. A 48-bit node identifier, which distinguishes UUIDs in space.
  ///    Typically, these are random bits, but an application-specific identifier may also be used.
  ///
  /// Version 6 UUIDs are similar to version 1 UUIDs from RFC-4122, except that their timestamps are stored
  /// in a sorting- and filtering-friendly manner, and their better locality improves the performance of
  /// many databases and data structures. They are highly resistant to collisions, and can incorporate
  /// externally-derived identifiers for even greater guarantees in distributed systems or applications.
  ///
  /// Creating a UUID with a particular timestamp can be helpful when filtering UUIDs to ranges of time.
  /// For example, all UUIDs greater than `1EC3B396-11B7-6818-8000-000000000000` were created after
  /// 2021-11-01 17:30:17 (UTC).
  ///
  /// [UUIDv6-draft-02]: https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02
  ///
  /// - parameters:
  ///   - rawTimestamp: The timestamp, as a number of 100ns intervals from 00:00:00 October 15, 1582.
  ///                   Only the least significant 60 bits will be used.
  ///   - sequence:     The sequence number. Only the least significant 12 bits will be used. The default is 0.
  ///   - node:         The node ID. Only the least significant 48 bits will be used. The default is 0.
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
  /// To construct a view, initialize a value using a `UniqueID`, or use the ``UniqueID/UniqueID/components(_:)``
  /// function. The following example demonstrates using this view to read the timestamp from a time-ordered UUID.
  ///
  /// ```swift
  /// let id = UniqueID("1EC5FE44-E511-6910-BBFA-F7B18FB57436")!
  /// id.components(.timeOrdered)?.timestamp
  /// // ✅ "2021-12-18 09:24:31 +0000"
  /// ```
  ///
  /// ## Topics
  ///
  /// ### UUID Components
  ///
  /// - ``timestamp``
  /// - ``rawTimestamp``
  /// - ``sequence``
  /// - ``node``
  ///
  public struct TimeOrdered: UniqueID.Components {

    public let uuid: UniqueID

    @inlinable
    public init?(_ uuid: UniqueID) {
      guard uuid.version == 6 else { return nil }
      self.uuid = uuid
    }

    /// The timestamp of this UUID, as a number of 100ns intervals since 00:00:00 October 15, 1582.
    ///
    /// Note that only the least-significant 60 bits are used.
    ///
    /// ```swift
    /// let id = UniqueID("1EC5FE44-E511-6910-BBFA-F7B18FB57436")!
    /// //                 ^^^^^^^^ ^^^^  ^^^
    /// id.components(.timeOrdered)?.rawTimestamp
    /// // ✅ 138591122712762640 (0x1EC5FE44E511910)
    ///
    /// // To convert to the Unix epoch, subtract the magic number.
    /// // Note that this is still a number of 100ns intervals.
    /// let relativeTo1970 = id.components(.timeOrdered)!.rawTimestamp &- (0x01B2_1DD2_1381_4000 as UInt64)
    ///
    /// // To convert to a Foundation TimeInterval, divide by 10_000_000.
    /// let date = Date(timeIntervalSince1970: TimeInterval(relativeTo1970) / 10_000_000)
    /// // ✅ "2021-12-18 09:24:31 +0000"
    /// ```
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

    /// The sequence number of this UUID. This is generally just an opaque number.
    ///
    /// Note that only the least-significant 14 bits are used.
    ///
    /// ```swift
    /// let id = UniqueID("1EC5FE44-E511-6910-BBFA-F7B18FB57436")!
    /// //                                    ^^^^
    /// id.components(.timeOrdered)?.sequence
    /// // ✅ 15354 (0x3BFA)
    /// ```
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

    /// The node identifier of this UUID. This may be random, or it may have some context-specific meaning.
    ///
    /// Note that only the least-significant 48 bits are used.
    ///
    /// ```swift
    /// let id = UniqueID("1EC5FE44-E511-6910-BBFA-F7B18FB57436")!
    /// //                                         ^^^^^^^^^^^^
    /// id.components(.timeOrdered)?.node
    /// // ✅ 272341992305718 (0xF7B18FB57436)
    /// ```
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
