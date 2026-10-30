# Cubeage Solar2D Linux

Cubeage Solar2D Linux produces Linux Solar2DBuilder artifacts for Android builds and source-pinned Solar2D simulator packages for Lua application jobs. It owns the source patch set, package scripts, smoke fixtures, release workflows and published tarballs.

Lifecycle: `production`
Layer: `tooling`

## Goals

- Produce Linux Solar2DBuilder packages for self-hosted or GitHub Actions Android build pipelines.
- Track upstream Solar2D releases and apply the repository patch set needed for Linux Android builds.
- Publish reproducible release artifacts with smoke evidence and release readback.
- Package the actual Linux simulator, Resources and native OpenSSL binding for on-demand Lua application jobs.

## Non-Goals

- This repository does not own the upstream Solar2D runtime, game source code, or Android app release behavior.
- This repository does not own consumer CI workflows beyond the published package contracts.
- This repository does not own central CI runner, enterprise release bot, or platform preview behavior.

## Boundaries

The machine-readable source of truth is [.doctrine/project.json](.doctrine/project.json). Agents must keep this repository as a build-tool artifact producer and route game-specific build behavior to consuming game repositories.

## Public Surfaces

- Linux build script in `scripts/build.sh`.
- Solar2D Linux patch set under `patches/`.
- Release workflow in `.github/workflows/build.yml`.
- GitHub Release tarball `solar2dbuilder-linux-<BUILD>.tar.gz`.
- Source manifest `runtime/sources.json`, runtime build and smoke scripts, and `.github/workflows/runtime.yml`.
- Separate runtime release `runtime-<version>` with `solar2d-runtime-linux-<version>.tar.gz`.

## Delivery

Release changes require upstream Solar2D version evidence, patch application proof, package smoke output, GitHub Release asset readback, and downstream compatibility notes. Published artifacts are externally consumable; recovery is normally a forward-fix release, release deletion/deprecation when safe, or staged channel halt rather than source revert alone.
