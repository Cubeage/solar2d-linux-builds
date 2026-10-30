# Runtime source evidence

Primary sources read on 2026-10-30, 12:50–12:55 UTC:

- [Solar2D 3731](https://github.com/coronalabs/corona/tree/7dbc7cccdee81b0a900505b419fab6531650194a):
  the root CMake file includes the Linux build definition. The simulator is a
  separate target in `platform/linux/CMakeList.txt`, exports native Lua symbols,
  and links the SDL2/OpenGL/OpenAL/FreeType/PNG/JPEG/crypto/curl runtime.
- [Generated Resources](https://github.com/coronalabs/corona/blob/7dbc7cccdee81b0a900505b419fab6531650194a/platform/linux/CMakeResources.txt):
  skins, widget sheets, shared files, icon, headers and the homescreen are
  assembled at configure time. The package keeps that complete tree next to
  the simulator. Composer, timers, transitions and widget code are compiled
  from upstream modules by the Linux build.
- [Application entry point](https://github.com/coronalabs/corona/blob/7dbc7cccdee81b0a900505b419fab6531650194a/platform/linux/src/main.cpp):
  an existing directory or file argument starts the application with the actual
  runtime. The simulator sandbox is under the caller's home; the wrapper does
  not substitute that home or manage application identities.
- [Lua OpenSSL binding](https://github.com/zhaozg/lua-openssl/tree/affa98b319121f7575fc1706359c2e4fcd010501):
  the binding supports Lua 5.1 and OpenSSL 3. Its `random` implementation calls
  native `RAND_bytes` and propagates failure. Build it with the simulator's
  exact Lua headers and leave Lua symbols resolved by the executable.
- [Historical Corona plugin](https://github.com/coronalabs/com.coronalabs-plugin.openssl/tree/a004b2e4bc9809a0f4db21e05cdaf156f74e733a):
  the checked platform tree has no Linux binary. The checked source exports
  `random_bytes`, so that tree alone does not prove the newer `random` API.
  This runtime therefore declares its modern binding version explicitly and
  tests the exact `plugin.openssl` namespace and strong-byte call it supports.

The release source manifest records both top-level commits and the OpenSSL
submodule commits. The build verifies all recursive submodules against their
gitlinks, records applied patch hashes and captures system library/compiler
versions. System libraries retain the Ubuntu package lifecycle.

The runtime acceptance surface is a harmless local source application loaded
from an extracted tarball in a fresh job. A receipt requires real display
frames, timer and transition completion, Documents write/read and native
OpenSSL bytes. Separate boots must reject a missing module and a native entropy
failure. Process exit alone, a timeout or a builder version command cannot
satisfy runtime acceptance. Publication adds a fresh download, checksum/source
comparison and the same boot checks against the actual release asset.

The builder package is a separate compatibility surface. Its existing workflow,
scripts, patches and asset names remain supported, and the runtime release is
excluded from GitHub's latest-release selection.

The first native CI attempt, [41061549950](https://github.com/Cubeage/solar2d-linux-builds/actions/runs/41061549950),
compiled both simulator and binding successfully on 2026-10-30. Its extracted
package reached actual Lua execution but failed to load `plugin.openssl`.
The receipt's module search paths omitted installed Resources. The Linux
context appended Resources to the environment after the VM had already opened
`package`, leaving the VM's `package.path` unchanged. The runtime patch updates
that live table as well. It can be removed when the pinned upstream sets the
installed Resources path in the live VM and the same extracted-package check
passes. Builder builds do not apply runtime-specific patches.
