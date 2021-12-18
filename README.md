# UniqueID

UUIDv4 and v6\* generation in Swift.

[[Documentation](https://karwa.github.io/uniqueid/main/documentation/uniqueid)]

A UUID is an identifier that is unique across both space and time, with respect to the space of all UUIDs. They are used for multiple purposes, from tagging objects with an extremely short lifetime, to reliably identifying very persistent objects across a network.

`UniqueID` supports any 128-bit UUID, and is fully compatible with Foundation's `UUID`.
It also includes features to generate 2 kinds of ID:

- **Random**: As defined in [RFC-4122][RFC-4122-UUIDv4] (UUIDv4).

  A 128-bit identifier, consisting of 122 random bits.
  These are the most common form of UUIDs; for example, they are the ones Foundation's `UUID` type creates
  by default. To generate a random UUID, call the static `random()` function.

  ```swift
  for _ in 0..<3 {
    print(UniqueID.random())
  }

  "DFFC75B4-C92F-4DA9-97CA-7F0EEF067FF2"
  "67E5F28C-5083-4908-BD69-D7E27C8BABA4"
  "3BA8EEF0-DFBE-4AE0-A646-E165FCA9054C"
  ```

- **Time-Ordered**: Generated according to a [draft update of RFC-4122][UUIDv6-draft-02] (UUIDv6).

  A 128-bit identifier, consisting of a 60-bit timestamp with 100ns precision, a 14-bit sequencing number seeded
  from random bits, and a 48-bit node ID (which may also be random bits). To generate a time-ordered UUID,
  call the static `timeOrdered()` function.

  ```swift
  for _ in 0..<3 {
    print(UniqueID.timeOrdered())
  }
  
  "1EC3C81E-A361-658C-BB38-65AAEF71CFCF"
  "1EC3C81E-A361-6F6E-BB38-6DE69B9BCA1B"
  "1EC3C81E-A362-698C-BB38-050642A95C73"
   |------------- --| |--| |----------|
       timestamp       sq      node
  ```

  As you can see, time-ordered UUIDs generated in sequence share a common prefix (from the timestamp), yet
  retain high collision avoidance. This allows the use of sorted data structures and algorithms
  such as binary search, as an alternative to hash tables. They are far more efficient than random UUIDs for use
  as database primary keys.

> Tip:
> Random and Time-Ordered UUIDs may coexist in the same database.
> They have different version numbers, so they are guaranteed to never collide.

[RFC-4122-UUIDv4]: https://datatracker.ietf.org/doc/html/rfc4122#section-4.4
[UUIDv6-draft-02]: https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02

# Using UniqueID in your project

To use this package in a SwiftPM project, you need to set it up as a package dependency:

```swift
// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "MyPackage",
  dependencies: [
    .package(
      url: "https://github.com/karwa/uniqueid",
      .upToNextMajor(from: "1.0.0")
    )
  ],
  targets: [
    .target(
      name: "MyTarget",
      dependencies: [
        .product(name: "UniqueID", package: "uniqueid")
      ]
    )
  ]
)
```

And with that, you're ready to start using `UniqueID`. One way to get easily experiment with time-ordered (v6) UUIDs is to use Foundation compatibility to simply change how you create UUIDs:

```swift
import Foundation
import UniqueID

// Change from UUID() to UUID(.timeOrdered()).
struct MyRecord {
  var id: UUID = UUID(.timeOrdered())
  var name: String
}

// Read the timestamp by converting to UniqueID.
let uniqueID = UniqueID(myRecord.id)
print(uniqueID.components(.timeOrdered)?.timestamp)
```

Bear in mind that v6 UUIDs are not yet an official standard, and the layout may change before it becomes an approved internet standard. This implementation aligns with draft 02, from 7 October 2021. Check the latest status [here](https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02).


## Why new UUIDs?

The IETF draft has a really good summary of why using time-ordered UUIDs can be beneficial. You should read it - at least [the "Background" section](https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02#section-2).

> A lot of things have changed in the time since UUIDs were originally
> created.  Modern applications have a need to use (and many have
> already implemented) UUIDs as database primary keys.
>
> The motivation for using UUIDs as database keys stems primarily from
> the fact that applications are increasingly distributed in nature.
> Simplistic "auto increment" schemes with integers in sequence do not
> work well in a distributed system since the effort required to
> synchronize such numbers across a network can easily become a burden.
> The fact that UUIDs can be used to create unique and reasonably short
> values in distributed systems without requiring synchronization makes
> them a good candidate for use as a database key in such environments.
>
> However some properties of RFC4122 UUIDs are not well suited to
> this task.  First, most of the existing UUID versions such as UUIDv4
> have poor database index locality.  Meaning new values created in
> succession are not close to each other in the index and thus require
> inserts to be performed at random locations.  The negative
> performance effects of which on common structures used for this
> (B-tree and its variants) can be dramatic.  As such newly inserted
> values SHOULD be time-ordered to address this.

Previous time-ordered UUIDs, such as version 1 UUIDs from RFC-4122, store their timestamps in a convoluted format, so you can't just sort UUIDs based on their bytes and arrive at a time-sorted list of UUIDs. Version 6 improves on that.

Let's compare 10 UUIDv4s against 10 UUIDv6s:

```
for _ in 0..<10 {
  print(UniqueID.random())
}

DFFC75B4-C92F-4DA9-97CA-7F0EEF067FF2
67E5F28C-5083-4908-BD69-D7E27C8BABA4
3BA8EEF0-DFBE-4AE0-A646-E165FCA9054C
DF92B4B0-F5EE-42E5-9577-A9FC373C71A4
A2F8DD26-D513-4AE6-9E5C-58363885CCB6
BB0B5841-2BC0-49E2-BC5C-362CC34D7225
B08AF1F7-E2D3-4175-913D-369140612FF5
A453FB62-DF71-436F-9AC1-0414793DFA16
485EEB84-A4BA-44FE-BE3B-AD90390B0523
8A9AE1FA-4104-442C-B459-8F682E77F2F4
``` 

```
for _ in 0..<10 {
  print(UniqueID.timeOrdered())
}

1EC3C81E-A35C-69E2-BB38-EDDC5E7E5F5E
1EC3C81E-A361-658C-BB38-65AAEF71CFCF
1EC3C81E-A361-6F6E-BB38-6DE69B9BCA1B
1EC3C81E-A362-698C-BB38-050642A95C73
1EC3C81E-A363-6152-BB38-F105ED78927F
1EC3C81E-A363-6A94-BB38-4DAB2CAE46CD
1EC3C81E-A364-63D6-BB38-6114031916EF
1EC3C81E-A364-6D04-BB38-435A854C2E42
1EC3C81E-A365-66AA-BB38-03504FA2F6FE
1EC3C81E-A365-6F74-BB38-1F5AE9E10389
```

Both lists are unique, and unique with respect to each other, but the time-ordered ones, naturally, came out in order of creation time. We can even extract the embedded timestamp - in this case, it says the UUID was created on the 3rd of November, 2021 at 08:42:01 UTC (down to 100ns precision, theoretically).

The combination of temporal and spacial components means these UUIDs are still robust to collisions - a new 60-bit universe exists every 100ns, and the IDs within that universe are still alloted based on random bits with high entropy. It's tempting to think you might be paying a high cost in collisions for the ease of use, but it's not as simple as that.