// swift-tools-version:5.5

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

import PackageDescription

// This package recognizes the conditional compilation flags listed below.
// To use enable them, uncomment the corresponding lines or define them
// from the package manager command line:
//
//     swift build -Xswiftc -DNO_FOUNDATION_COMPAT
var settings: [SwiftSetting]? = [

  // Do not depend on Foundation.
  //
  // This removes:
  // - UUID <-> UniqueID conversion APIs.
  // - UUID timestamps as 'Date' (but Date will soon join the standard library).
  //.define("NO_FOUNDATION_COMPAT"),

]

if settings?.isEmpty == true { settings = nil }

let package = Package(
    name: "UniqueID",
    products: [
      .library(name: "UniqueID", targets: ["UniqueID"]),
    ],
    dependencies: [
      .package(name: "swift-atomics", url: "https://github.com/apple/swift-atomics", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
      .target(
        name: "UniqueID",
        dependencies: [.product(name: "Atomics", package: "swift-atomics")],
        swiftSettings: settings),
      .testTarget(
        name: "UniqueIDTests",
        dependencies: ["UniqueID"],
        swiftSettings: settings),
    ]
)
