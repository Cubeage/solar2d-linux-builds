# Linux Solar2D simulator package

This package runs Lua applications with the actual Solar2D simulator, composer,
widget, event loop and generated Resources. It targets x86_64 Ubuntu 22.04
(glibc 2.35) or a compatible environment. It does not provide mobile native
plugins, app-store behavior or device parity.

Install the runtime dependencies in the job image:

```bash
apt-get update
apt-get install -y libcurl4 libfreetype6 libgl1 libglu1-mesa libgl1-mesa-dri \
  libglx-mesa0 libopenal1 libpng16-16 libjpeg8 libssl3 libsdl2-2.0-0 \
  zlib1g libstdc++6 xvfb xauth fonts-dejavu-core
```

Start one process per job:

```bash
/runtime/solar2d-runtime-2026.3731.2/Solar2DSimulator.sh /checkout/app
```

The wrapper starts Xvfb when DISPLAY is absent and defaults to software OpenGL
and a null audio device. An existing display and explicit graphics/audio
settings are respected. It preserves the caller's home and application data;
Solar2D stores sandbox data below `~/.Solar2D/Sandbox/<application-directory-name>`.
Use an isolated job environment and retain its private storage when restart
continuity is required. Launching an application executes its real startup
behavior, including any network calls it makes.

For an explicitly retained simulator identity, supply `SOLAR2D_DEVICE_ID` before
launch. The native `system.getInfo("deviceID")` returns that exact value in the
simulator only. Values must contain 1–128 ASCII letters, digits, `-`, `_`, `.` or
`:`. An absent, empty or invalid value preserves Linux's existing empty device
identifier; the package never generates a replacement. Other identifier APIs,
the builder and non-simulator applications keep their existing behavior.
Retain the same value across processes together with private application data.
This input is not an authentication credential or a synthetic-account grant;
the application and backend own identity admission and metric exclusion.

`require("plugin.openssl")` loads the packaged native lua-openssl binding through
a namespace loader. `openssl.random(length, true)` calls OpenSSL 3 `RAND_bytes`
and returns no random string when native entropy fails. The `true` argument is
accepted for existing callers; bytes always use the strong generator. This
contract does not promise every API from the older Corona OpenSSL/LuaSec plugin.

`sources.json` pins the Solar2D and binding source commits. The recursive
submodule receipts, applied patch hashes, compiler/system versions and linked
libraries accompany the package. System libraries remain distribution packages;
they are not copied from the build machine into this tarball.

Published runtime releases use a separate `runtime-<version>` tag and never
replace the builder's latest release. Verify the accompanying SHA-256 file
before extraction. Recovery is a new packaging revision; existing published
artifacts are not silently replaced.
