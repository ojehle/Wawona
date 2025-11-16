# Container Tool Notes

This document captures the key setup requirements and references for Apple's [`container`](https://github.com/apple/container) CLI, which we use to launch Linux Weston inside macOS `Containerization.framework` VMs.

## Prerequisites

- **Hardware:** Apple silicon (arm64) Mac. Intel systems are not supported.
- **Operating System:** macOS 26 is the officially supported release per the upstream README. The BUILDING notes indicate macOS 15 is the absolute minimum, but Apple only tests and fixes issues on macOS 26+.
- **Developer Tools:** Install Xcode 26 (or newer) and set it as the active developer directory:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app
  ```
  This also installs the Swift toolchain required by the build.
- **Command Line Tools:** Ensure `git`, `swift`, `xcodebuild`, and `make` are available on your PATH.
- **Location caveat:** Apple's docs describe a `vmnet` bug on macOS 26 when the repo lives under Desktop or Documents. Keep `~/Library/Caches/container-build`, `~/projects/container`, etc. outside those folders.

## Installation Options

1. **Signed package:** Download the latest `.pkg` from the [container releases](https://github.com/apple/container/releases), install it, then run `container system start`.
2. **Build from source (what `make container-client` automates):**
   ```bash
   git clone https://github.com/apple/container.git
   cd container
   BUILD_CONFIGURATION=release make all test integration
   BUILD_CONFIGURATION=release make install
   ```
   The build places binaries under `bin/<config>/staging/bin/` plus helper daemons in `bin/<config>/staging/libexec/`.

## Documentation Map

Apple ships extensive docs within the repo:

- `README.md` – high-level overview, supported platforms, install/uninstall workflow.
- `BUILDING.md` – required tools and `make` recipes (all/test/integration/install/protos).
- `docs/tutorial.md` – guided walkthrough building/publishing a sample image.
- `docs/how-to.md` – task-oriented guidance (volumes, networking, debugging, etc.).
- `docs/technical-overview.md` – architectural details of the CLI and helper VMs.
- `docs/command-reference.md` – exhaustive CLI reference for `container <subcommand>`.

When working from a release tag, always read the docs from the matching tag to avoid drift with `main`.

## Troubleshooting Tips

- Use `container system status` and `container system logs` to inspect the helper launchd services.
- The CLI stores user data under `~/Library/Containers/com.apple.container/`. Stop with `container system stop` before deleting or upgrading.
- The `uninstall-container.sh` script supports `-k` (keep user data) and `-d` (delete data).
- If builds fail inside our cached repo (`~/Library/Caches/container-build`), run `make container-client`, press `b`, or set `CONTAINER_FORCE_REBUILD=1` to wipe the cache before rebuilding.

These notes should keep our repo aligned with the upstream expectations while providing a quick lookup for future contributors. If Apple updates the requirements (new macOS/Xcode versions), revisit this file after reading the updated upstream docs.

