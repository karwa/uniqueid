# ``UniqueID``

UUIDv4 and v6\* generation in Swift.

## Overview

A UUID is an identifier that is unique across both space and time, with respect to the space of all UUIDs.
A UUID can be used for multiple purposes, from tagging objects with an extremely short lifetime,
to reliably identifying very persistent objects across a network.

`UniqueID` supports any 128-bit UUID, and is able to generate RFC-compliant random (v4) and time-ordered (v6) UUIDs.

➡️ **Visit the ``UniqueID/UniqueID`` type to get started.**

> Note:
> UUIDv6 is currently in draft form. This version of UniqueID aligns with [draft 2][UUIDv6-draft-02],
> dated 7 October 2021.

[UUIDv6-draft-02]: https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-02
