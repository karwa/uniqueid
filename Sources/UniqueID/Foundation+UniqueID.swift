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

import Foundation

extension UUID {

  /// Losslessly convert a `UniqueID` to a Foundation `UUID`.
  ///
  @inlinable
  public init(_ uniqueID: UniqueID) {
    self.init(uuid: uniqueID.bytes)
  }
}

extension UniqueID {

  /// Losslessly convert a Foundation `UUID` to a `UniqueID`.
  ///
  @inlinable
  public init(_ uuid: Foundation.UUID) {
    self.init(bytes: uuid.uuid)
  }
}

// Note: 'Date' will move in to the standard library and increase precision to capture this timestamp exactly.
// https://forums.swift.org/t/pitch-clock-instant-date-and-duration/52451

extension UniqueID.TimeOrdered {

  /// The timestamp of the UUID. Note that this has at most 100ns precision.
  ///
  @inlinable
  public var timestamp: Date {
    Date(timeIntervalSince1970: TimeInterval(_uuid_timestamp_to_unix(timestamp: rawTimestamp)) / 10_000_000)
  }
}
