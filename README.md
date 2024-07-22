# ISO Builder

## Prerequisites

This currently must be run on a Debian Bookwork (12) system. At some point, everything
should be moved to running inside a 'builder' Docker container, to make it more portable.

There should be two *seperate* volumes, which avoids your development environment tooling
accidentally starting to crawl through a chroot looking for things. On my (xrobau) system,
I have this isobuild folder checked out, and then a totally seperate /buildroot volume
where everything is compiled (this can be changed by setting the COREBUILD var in the
main Makefile). Nothing there is permanent, and is created on the fly.

# Building

`make iso` will ALWAYS build an iso, even if it already exists.

## Testing
`make isotest` builds an ISO if it needs to, and then creates a KVM instance to boot
that iso on. You can use `make isoclean` to delete the local storage of the VM to
test changes.

# Themes

TODO Documentation

# Packages

Themes can add packages, but the format of packages and how they work are still in flux.

The `core` package is responsible for installing and executing scripts and tools in the
meta folder of other packages, however the actual layout of meta and naming of hooks
has not been finalised.


