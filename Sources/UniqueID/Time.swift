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

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#else
  #error("Unsupported platform")
#endif

/// Returns the number of 100ns intervals from the Unix epoch to the current instant.
/// The value is limited to the least-significant 60 bits.
///
@inlinable
internal func _get_system_timestamp() -> UInt64 {
  let timestamp: UInt64
  if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
    var time = timespec()
    clock_gettime(CLOCK_REALTIME, &time)
    timestamp =
      (UInt64(bitPattern: Int64(time.tv_sec)) &* 10_000_000) &+ (UInt64(bitPattern: Int64(time.tv_nsec)) / 100)
  } else {
    var time = timeval()
    gettimeofday(&time, nil)
    timestamp =
      (UInt64(bitPattern: Int64(time.tv_sec)) &* 10_000_000) &+ (UInt64(bitPattern: Int64(time.tv_usec)) &* 10)
  }
  return timestamp & 0x0FFF_FFFF_FFFF_FFFF
}

/// Converts a 60-bit number of 100ns intervals from the Unix epoch (January 1, 1970)
/// to the UUID epoch (October 15, 1582).
///
@inlinable
internal func _unix_to_uuid_timestamp(unix: UInt64) -> UInt64 {
  unix &+ 0x01B2_1DD2_1381_4000
}

/// Converts a 60-bit number of 100ns intervals from the UUID epoch (October 15, 1582)
/// to the Unix epoch (January 1, 1970).
///
@inlinable
internal func _uuid_timestamp_to_unix(timestamp: UInt64) -> UInt64 {
  timestamp &- 0x01B2_1DD2_1381_4000
}
