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

/// A type which exposes a view of the embedded information within certain UUIDs.
///
public protocol _UniqueIDComponents {
  init?(_ uuid: UniqueID)
}

// Note: Why '.components()' uses an @autoclosure:
//
// So, we want UniqueID.Components to be a protocol, and the user provides the type
// and we construct an instance. Normally you'd write that like this:
//
// func components<ViewType: Components>(_: ViewType.Type) -> ViewType?
//
// And the user would write:
//
// uuid.components(TimeOrderedComponents.self)?.timestamp
//
// But that kind of sucks. We'd like to take advantage of static-member syntax:
//
// uuid.components(.timeOrdered)?.timestamp
//
// Unfortunately, the regular way of expressing this doesn't work:
//
// extension UUID.Components where Self == TimeOrderedComponents {
//   public static var timeOrdered: Self { ... }
// }
//
// We would need to provide a dummy instance. And changing the type of the computed property `timeOrdered`
// to `Self.Type` or `TimeOrderedComponents.Type` doesn't work - the compiler doesn't like it.
// Hence, the workaround: use an @autoclosure parameter, which to the type-checker looks like it returns
// an instance (but really just fatalErrors). We don't need to create a dummy instance and
// we get static member syntax:
//
// func components<ViewType: Components>(_: @autoclosure () -> ViewType) -> ViewType? { ... }
//
// extension UniqueID.Components where Self == TimeOrderedComponents {
//   public static var timeOrdered: Self { fatalError("Not intended to be called") }
// }
//
// components(.timeOrdered)?.timestamp // works.

extension UniqueID {

  /// A view of the embedded information within certain UUIDs.
  ///
  public typealias Components = _UniqueIDComponents

  /// Returns a view of the embedded information within this UUID.
  ///
  /// The following example demonstrates extracting the timestamp from a time-ordered UUID.
  ///
  /// ```swift
  /// let id = UniqueID("1EC5FE44-E511-6910-BBFA-F7B18FB57436")!
  /// id.components(.timeOrdered)?.timestamp
  /// // ✅ "2021-12-18 09:24:31 +0000"
  /// ```
  ///
  @inlinable
  public func components<ViewType: Components>(_: @autoclosure () -> ViewType) -> ViewType? {
    ViewType(self)
  }
}
