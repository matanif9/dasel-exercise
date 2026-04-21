# dasel — Exercise

Package `dasel` v3.3.1 with Melange, build a container image with apko, and prove it works.

## CVE-2026-33320

**dasel v3.3.1 is affected by CVE-2026-33320** (GHSA-4FCP-JXH7-23X8, CVSS 6.2 Medium).

- **Type**: Denial of Service via unbounded YAML alias expansion (CWE-674)
- **Root cause**: `parsing/yaml/yaml_reader.go` — `UnmarshalYAML` recursively resolves
  `AliasNode` by calling itself with no expansion limit, bypassing go-yaml v4's built-in
  alias expansion protection.
- **Fix**: Source-level patch (`patches/fix-cve-2026-33320.patch`) applied before the
  build. Adds `maxExpansionDepth=32` and `maxExpansionBudget=1000` limits to the YAML
  reader, matching the approach used in the v3.3.2 release (PR #531).

## Project Structure

```
dasel-exercise/
├── melange/
│   ├── dasel.yaml                  # Melange package definition
│   └── patches/
│       └── fix-cve-2026-33320.patch  # CVE fix patch
├── apko/
│   └── dasel.yaml                  # apko image definition
├── tests/
│   └── test.sh                     # Image test script
├── packages/                       # Melange output — APKs written here (git-ignored)
├── melange.rsa                     # Signing private key (git-ignored)
├── melange.rsa.pub                 # Signing public key (used by apko)
└── README.md
```

## Prerequisites

- Docker (used to run melange and apko — no local install needed)
- bash (for the test script — on Windows use Git Bash or WSL)

## Platform Notes

### macOS (Intel)

No changes needed. Replace `$(pwd -W)` with `${PWD}` in all `docker run` commands if
you copied them from the Windows variant — on Mac `${PWD}` works directly.

### macOS (Apple Silicon — M1/M2/M3)

Three places need updating for `arm64`:

1. **`apko/dasel.yaml`** — change `x86_64` to `aarch64`:
   ```yaml
   archs:
     - aarch64
   ```

2. **Melange build command** — change `--arch amd64` to `--arch arm64`

3. **apko build command** — change `--arch amd64` to `--arch arm64`

The loaded image tag becomes `dasel:test-arm64`, so pass that to the test script:
```bash
bash tests/test.sh dasel:test-arm64
```

### Windows

Use Git Bash or WSL. Replace `${PWD}` with `$(pwd -W)` in all `docker run -v` flags
so Docker Desktop receives a Windows-style path:
```bash
-v "$(pwd -W)":/work
```

## How the Package and Image Connect

After `melange build`, APK files land in `./packages/`. The `apko/dasel.yaml` references
this directory via `@local /work/packages` in its `repositories` list, so apko installs
the locally built `dasel` APK rather than anything from upstream.

Both the Wolfi signing key and the locally generated `melange.rsa.pub` are listed in
`keyrings` so apko can verify the package signature.

## Build and Test

Run all commands from the root of this repository.

### 1. Generate signing keypair

```bash
docker run --rm -v "${PWD}":/work \
  cgr.dev/chainguard/melange keygen
```

This writes `melange.rsa` (private) and `melange.rsa.pub` (public) to the current directory.

### 2. Build the APK package

```bash
docker run --rm --privileged \
  -v "${PWD}":/work \
  cgr.dev/chainguard/melange build melange/dasel.yaml \
  --arch amd64 \
  --signing-key melange.rsa \
  --out-dir packages
```

APKs are written to `./packages/x86_64/`.

### 3. Run the package test (optional)

```bash
docker run --rm --privileged \
  -v "${PWD}":/work \
  cgr.dev/chainguard/melange test melange/dasel.yaml \
  --arch amd64 \
  --keyring-append melange.rsa.pub
```

### 4. Build the container image

```bash
docker run --rm \
  -v "${PWD}":/work \
  cgr.dev/chainguard/apko build apko/dasel.yaml \
  dasel:test dasel.tar \
  --arch amd64
```

This writes `dasel.tar` (an OCI image tarball).

### 5. Load the image into Docker

```bash
docker load < dasel.tar
```

Docker will print the loaded image name, e.g. `dasel:test-amd64`.

### 6. Run the test script

```bash
bash tests/test.sh dasel:test-amd64
```

The test script verifies:
1. The `dasel` binary is present and runnable (`dasel version`)
2. JSON querying works — extracts `name` from a JSON object and asserts the value
3. YAML modification works — updates a key value with `--root` and asserts the output

Note: dasel v3 changed the CLI — use `-i` (not `-r`) for input format, `--root` to output
the full document after modification, and selectors without a leading dot (e.g. `name` not `.name`).

## Future Enhancements

**Full CI/CD Automation**: Instead of manually executing build commands, I would implement an automated pipeline (e.g., using Jenkins or GitHub Actions). This pipeline would trigger on every code push, build the container images using Melange and apko, execute the test suite (test.sh), and upon success, push the final image to a centralized Container Registry.

**Automated Vulnerability Scanning**: While the specific CVE was patched in this assignment, ensuring continuous security is critical. I would integrate automated scanning tools into the pipeline to inspect the image post-build. This ensures a "Zero-CVE" baseline by identifying any known vulnerabilities before the image reaches production.

**Built-in Multi-Architecture Support**: Currently, the target architecture (e.g., amd64 or arm64) must be specified manually during the build process. I would enhance the configuration to support concurrent cross-compilation for all major architectures. This would result in a multi-arch manifest, allowing users to pull the image and automatically receive the version compatible with their hardware.

**AI-Powered Remediation**: I would integrate an AI agent into the development workflow to monitor for new vulnerability reports. The AI could analyze the source code, automatically generate the required security patches, and open a Pull Request to update the build configuration, significantly reducing the time-to-fix.
