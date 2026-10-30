#!/usr/bin/env bash
# Build only the Linux simulator and its native OpenSSL module. Dependencies
# are installed by runtime.yml; this script never installs host packages.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_WORK="${1:?Usage: build-runtime.sh <empty-work-directory> <output-directory>}"
RUNTIME_OUT="${2:?Usage: build-runtime.sh <empty-work-directory> <output-directory>}"
mkdir -p "$RUNTIME_WORK" "$RUNTIME_OUT"
RUNTIME_WORK="$(realpath "$RUNTIME_WORK")"
RUNTIME_OUT="$(realpath "$RUNTIME_OUT")"
test -z "$(ls -A "$RUNTIME_WORK")" || { echo 'Build directory must be empty' >&2; exit 1; }
MANIFEST="${REPO_ROOT}/runtime/sources.json"
VERSION="$(jq -r .packageVersion "$MANIFEST")"
BUILD="$(jq -r .solar2d.build "$MANIFEST")"
YEAR="$(jq -r .solar2d.year "$MANIFEST")"
PKG="${RUNTIME_WORK}/solar2d-runtime-${VERSION}"

checkout_source() {
  local source_key="$1" source_dir="$2" source_repo source_commit
  source_repo="$(jq -r ".${source_key}.repository" "$MANIFEST")"
  source_commit="$(jq -r ".${source_key}.commit" "$MANIFEST")"
  git init "$source_dir"
  git -C "$source_dir" remote add origin "$source_repo"
  git -C "$source_dir" -c gc.auto=0 fetch --depth 1 origin "$source_commit"
  git -C "$source_dir" checkout --detach FETCH_HEAD
  test "$(git -C "$source_dir" rev-parse HEAD)" = "$source_commit"
  git -C "$source_dir" submodule update --init --recursive --depth 1
  git -C "$source_dir" submodule status --recursive | tee "${RUNTIME_OUT}/${source_key}-submodules.txt"
  if rg '^[-+U]' "${RUNTIME_OUT}/${source_key}-submodules.txt"; then
    echo 'Submodule source differs from its pinned commit' >&2
    exit 1
  fi
}

df -h "$RUNTIME_WORK"
checkout_source solar2d "${RUNTIME_WORK}/solar2d"
checkout_source openssl "${RUNTIME_WORK}/openssl"
while IFS=$'\t' read -r module_path module_commit; do
  test "$(git -C "${RUNTIME_WORK}/openssl/${module_path}" rev-parse HEAD)" = "$module_commit"
done < <(jq -r '.openssl.submodules | to_entries[] | [.key,.value] | @tsv' "$MANIFEST")

mkdir -p "$PKG/Resources/plugin" "$PKG/licenses"
cp "$MANIFEST" "$PKG/sources.json"
: > "$PKG/patches.sha256"
for patch_file in "${REPO_ROOT}/patches/"*.patch "${REPO_ROOT}/runtime/patches/"*.patch; do
  git -C "${RUNTIME_WORK}/solar2d" apply "$patch_file"
  (cd "$REPO_ROOT" && sha256sum "${patch_file#"$REPO_ROOT/"}") >> "$PKG/patches.sha256"
done
df -h "$RUNTIME_WORK"
BUILD_NUMBER="$BUILD" YEAR="$YEAR" cmake -S "${RUNTIME_WORK}/solar2d" -B "${RUNTIME_WORK}/build" \
  -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "${RUNTIME_WORK}/build" --target Solar2DSimulator --parallel 2

# Use the simulator's Lua headers. The binding resolves Lua symbols from the
# executable, which exports them; a second Lua runtime must not be linked.
cmake -S "${RUNTIME_WORK}/openssl" -B "${RUNTIME_WORK}/openssl-build" \
  -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_DISABLE_FIND_PACKAGE_LuaJIT=TRUE \
  -DLUA_INCLUDE_DIR="${RUNTIME_WORK}/solar2d/external/lua-5.1.3/src" \
  -DLUA_LIBRARY="$(pkg-config --variable=libdir lua5.1)/liblua5.1.so" \
  -DBUILD_LINK_LUA_LIBRARIES=OFF
cmake --build "${RUNTIME_WORK}/openssl-build" --parallel 2
if readelf -d "${RUNTIME_WORK}/openssl-build/openssl.so" | rg 'NEEDED.*liblua'; then
  echo 'Native module must use the simulator Lua runtime' >&2
  exit 1
fi

cp "${RUNTIME_WORK}/build/Solar2DSimulator" "$PKG/"
cp -a "${RUNTIME_WORK}/build/Resources/." "$PKG/Resources/"
cp "${RUNTIME_WORK}/solar2d/platform/resources/"*.lua "$PKG/Resources/"
cp "${RUNTIME_WORK}/openssl-build/openssl.so" "$PKG/Resources/plugin/"
cp "${REPO_ROOT}/runtime/plugin/openssl.lua" "$PKG/Resources/plugin/"
cp "${REPO_ROOT}/runtime/Solar2DSimulator.sh" "$PKG/"
chmod +x "$PKG/Solar2DSimulator.sh"
cp "${REPO_ROOT}/runtime/README.md" "$PKG/README.md"
cp "${RUNTIME_WORK}/openssl/LICENSE" "$PKG/licenses/lua-openssl.txt"
cp "${RUNTIME_WORK}/openssl/deps/lua-compat/LICENSE" "$PKG/licenses/lua-compat.txt"
cp "${RUNTIME_WORK}/openssl/deps/auxiliar/auxiliar.c" "$PKG/licenses/lua-auxiliar.c"
cp "${RUNTIME_WORK}/openssl/deps/auxiliar/subsidiar.c" "$PKG/licenses/lua-subsidiar.c"
cp "${RUNTIME_WORK}/solar2d/LICENSE.md" "$PKG/licenses/solar2d.txt"
cp "${RUNTIME_OUT}/"*-submodules.txt "$PKG/"

{
  date -u '+builtAt=%Y-%m-%dT%H:%M:%SZ'
  printf 'packageSource=%s\n' "$(git -C "$REPO_ROOT" rev-parse HEAD)"
  printf 'architecture=%s\n' "$(uname -m)"
  cat /etc/os-release
  cc --version | head -1
  c++ --version | head -1
  cmake --version | head -1
  openssl version
  dpkg-query -W libssl3 libcurl4 libsdl2-2.0-0 libstdc++6 libc6
} > "$PKG/build-receipt.txt"
ldd "$PKG/Solar2DSimulator" "$PKG/Resources/plugin/openssl.so" > "$PKG/runtime-libraries.txt"
if rg 'not found' "$PKG/runtime-libraries.txt"; then exit 1; fi
cat "$PKG/build-receipt.txt"
du -sh "$PKG" "${RUNTIME_WORK}/build" "${RUNTIME_WORK}/openssl-build"
df -h "$RUNTIME_WORK"
ARCHIVE="solar2d-runtime-linux-${VERSION}.tar.gz"
tar -czf "${RUNTIME_OUT}/${ARCHIVE}" -C "$RUNTIME_WORK" "solar2d-runtime-${VERSION}"
(cd "$RUNTIME_OUT" && sha256sum "$ARCHIVE" > "${ARCHIVE}.sha256")
cp "$PKG/build-receipt.txt" "$RUNTIME_OUT/"
cp "$MANIFEST" "$RUNTIME_OUT/sources.json"
cat "${RUNTIME_OUT}/${ARCHIVE}.sha256"
