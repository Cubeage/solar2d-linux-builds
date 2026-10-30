#!/usr/bin/env python3
"""Boot the packaged runtime, including missing-module and entropy failures."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile


def boot(package: Path, destination: Path, name: str, preload: Path | None = None,
         device_id: str | None = None, expected_device_id: str = "") -> tuple[int, dict]:
    app = destination / name
    shutil.copytree(Path(__file__).resolve().parents[1] / "tests/runtime-fixture", app)
    receipt = destination / f"{name}.json"
    env = dict(os.environ, SOLAR2D_SMOKE_RECEIPT=str(receipt))
    # Never inherit an unrelated runner's identity into these local fixtures.
    env.pop("SOLAR2D_DEVICE_ID", None)
    env["SOLAR2D_EXPECTED_DEVICE_ID"] = expected_device_id
    if device_id is not None:
        env["SOLAR2D_DEVICE_ID"] = device_id
    if preload:
        env["LD_PRELOAD"] = str(preload)
    with (destination / f"{name}.log").open("w") as log:
        process = subprocess.Popen([str(package / "Solar2DSimulator.sh"), str(app)],
                                   env=env, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            code = process.wait(timeout=40)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise RuntimeError(f"{name}: runtime timed out; see {log.name}") from None
    if not receipt.is_file():
        raise RuntimeError(f"{name}: exit {code} without receipt; see {destination / (name + '.log')}")
    result = json.loads(receipt.read_text())
    print(json.dumps({"case": name, "exit": code, **result}), flush=True)
    return code, result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    package = args.package.resolve()
    destination = (args.output or Path(tempfile.mkdtemp(prefix="solar2d-smoke-"))).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    print(f"Smoke receipts: {destination}", flush=True)
    code, result = boot(package, destination, "positive")
    assert code == 0 and result["ok"] is True, "packaged runtime boot failed"

    # Fresh native processes must expose the supplied retained identity through
    # the real system.getInfo API. No Lua replacement or generated fallback.
    retained = "simulator-fixture-0123456789abcdef"
    for name, supplied, expected in [
        ("retained-device", retained, retained),
        ("retained-device-restart", retained, retained),
        ("distinct-device", "simulator-fixture-other", "simulator-fixture-other"),
        ("maximum-device", "x" * 128, "x" * 128),
        ("empty-device", "", ""),
        ("invalid-device", "simulator fixture", ""),
        ("oversized-device", "x" * 129, ""),
    ]:
        code, result = boot(package, destination, name, device_id=supplied, expected_device_id=expected)
        assert code == 0 and result["ok"] is True, f"{name}: native device identity mismatch"
        assert result["detail"]["deviceIdentity"] is True, result

    module = package / "Resources/plugin/openssl.so"
    disabled = module.with_suffix(".disabled")
    module.rename(disabled)
    try:
        code, result = boot(package, destination, "missing-module")
        assert code != 0 and result["ok"] is False, "missing module was accepted"
        assert "OpenSSL" in result["detail"] or "openssl" in result["detail"], result
    finally:
        disabled.rename(module)

    # Make the actual linked crypto function report failure. The fixture must
    # reject it without receiving bytes from a fallback implementation.
    fault_source = destination / "entropy-unavailable.c"
    fault_source.write_text("int RAND_bytes(unsigned char *buffer, int length) { return 0; }\n")
    fault_library = destination / "entropy-unavailable.so"
    subprocess.run(["cc", "-shared", "-fPIC", str(fault_source), "-o", str(fault_library)], check=True)
    code, result = boot(package, destination, "entropy-unavailable", fault_library)
    assert code != 0 and result["ok"] is False, "failed entropy was accepted"
    assert "secure entropy unavailable" in result["detail"], result


if __name__ == "__main__":
    main()
