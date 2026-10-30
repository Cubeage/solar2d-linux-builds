#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
export ALSOFT_DRIVERS="${ALSOFT_DRIVERS:-null}"
if [ -n "${DISPLAY:-}" ]; then
  exec "${DIR}/Solar2DSimulator" "$@"
fi
exec xvfb-run -a "${DIR}/Solar2DSimulator" "$@"
