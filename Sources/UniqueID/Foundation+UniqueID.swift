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

#if !NO_FOUNDATION_COMPAT

  import Foundation

  extension UUID {

    /// Losslessly convert a `UniqueID` to a Foundation `UUID`.
    ///
    /// The bytes of the UniqueID are preserved exactly.
    /// Both random (v4) and time-ordered (v6) IDs are supported.
    ///
    @inlinable
    public init(_ uniqueID: UniqueID) {
      self.init(uuid: uniqueID.bytes)
    }
  }

  extension UniqueID {

    /// Losslessly convert a Foundation `UUID` to a `UniqueID`.
    ///
    /// The bytes of the Foundation UUID are preserved exactly.
    /// By default, Foundation generates random UUIDs (v4).
    ///
    @inlinable
    public init(_ uuid: Foundation.UUID) {
      self.init(bytes: uuid.uuid)
    }
  }

  // Note: 'Date' might move in to the standard library and increase precision to capture this timestamp exactly.
  // https://forums.swift.org/t/pitch-clock-instant-date-and-duration/52451

  extension UniqueID.TimeOrdered {

    /// The timestamp of the UUID. Note that this has at most 100ns precision.
    ///
    /// ```swift
    /// let id = UniqueID("1EC5FE44-E511-6910-BBFA-F7B18FB57436")!
    /// id.components(.timeOrdered)?.timestamp
    /// // ✅ "2021-12-18 09:24:31 +0000"
    /// ```
    ///
    @inlinable
    public var timestamp: Date {
      Date(timeIntervalSince1970: TimeInterval(_uuid_timestamp_to_unix(timestamp: rawTimestamp)) / 10_000_000)
    }
  }

#endif  // NO_FOUNDATION_COMPAT
