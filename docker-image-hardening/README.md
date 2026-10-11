# Docker Image Hardening

A production-oriented Node.js container hardening project demonstrating how to reduce image size, attack surface, and vulnerability exposure through Docker security best practices.

## Overview

This project compares an intentionally naive Node.js container image with a hardened production-oriented image.

The optimized image implements:

- Digest-pinned Node.js Alpine base image
- Multi-stage Docker build
- Production-only dependencies
- Non-root container execution
- Minimal runtime contents
- `.dockerignore`
- Runtime package cleanup
- Alpine security updates
- Docker `HEALTHCHECK`
- Trivy vulnerability scanning

## Project Structure

```text
docker-image-hardening/
├── app/
│   ├── package.json              # Node.js application metadata and production dependencies
│   ├── package-lock.json         # Locks exact dependency versions for reproducible npm installs
│   └── server.js                 # Express application with main and health-check endpoints
│
├── baseline/
│   ├── Dockerfile                # Intentionally naive Docker image used as the security baseline
│   ├── container-user.txt        # Records the user running the baseline container
│   ├── image-size.txt            # Records the measured baseline image size
│   └── trivy-high-critical.txt   # Baseline HIGH and CRITICAL vulnerability scan results
│
├── optimized/
│   ├── Dockerfile                # Hardened multi-stage production Docker image
│   ├── .dockerignore             # Excludes unnecessary and sensitive files from the build context
│   ├── container-user.txt        # Verifies non-root execution with UID 1001
│   ├── image-size.txt            # Records the measured optimized image size
│   └── trivy-high-critical.txt   # Final HIGH and CRITICAL vulnerability scan results
│
├── IMAGE-ANALYSIS.md             # Detailed security analysis, comparison, and measured results
└── README.md                     # Project overview, setup instructions, security controls, and results
```

## Baseline Image

The `baseline/` directory contains the intentionally naive Docker image used as the security and size baseline.

The baseline Dockerfile intentionally uses:

```dockerfile
FROM node:latest
```

It represents a simple, unoptimized container configuration used as the security and size baseline.

Build it with:

```bash
docker build -f baseline/Dockerfile -t node-app:baseline .
```

## Optimized Image

The `optimized/` directory contains the hardened production-oriented Docker image.

The production-oriented image uses:

- Node.js 22 Alpine
- Immutable base-image digest pinning
- Multi-stage construction
- `npm ci --omit=dev`
- Non-root UID `1001`
- Runtime removal of npm and Corepack
- Alpine security updates
- Docker `HEALTHCHECK`

Build it with:

```bash
docker build -f optimized/Dockerfile -t node-app:optimized .
```

Run it with:

```bash
docker run --rm -p 3000:3000 node-app:optimized
```

Application endpoints:

```text
http://localhost:3000/
http://localhost:3000/health
```

The `/health` endpoint returns:

```json
{
  "status": "healthy"
}
```

## Security Verification

### Verify Non-Root Execution

```bash
docker run --rm node-app:optimized id
```

Expected result:

```text
uid=1001(appuser) gid=1001(appgroup)
```

### Verify Image Size

```bash
docker image inspect node-app:optimized   --format '{{.Size}}'   | awk '{printf "%.2f MB\n", $1/1024/1024}'
```

Measured result:

```text
58.62 MB
```

### Scan with Trivy

```bash
trivy image --severity HIGH,CRITICAL node-app:optimized
```

Final result:

```text
HIGH:     0
CRITICAL: 0
```

## Results

| Metric | Baseline | Optimized |
|---|---:|---:|
| Image size | 426.61 MB | 58.62 MB |
| Size reduction | — | 86.26% |
| HIGH vulnerabilities | 309 | 0 |
| CRITICAL vulnerabilities | 16 | 0 |
| HIGH + CRITICAL | 325 | 0 |
| Container user | Root | UID 1001 |

The optimized image is **86.26% smaller** than the baseline image while eliminating the recorded HIGH and CRITICAL vulnerabilities from the final Trivy scan.

## CI Security Gate

Trivy can be integrated into a CI pipeline as a security gate:

```bash
trivy image --exit-code 1 --severity HIGH,CRITICAL node-app:optimized
```

A typical pipeline can:

1. Build the image.
2. Scan the image with Trivy.
3. Fail the pipeline if HIGH or CRITICAL vulnerabilities are found.
4. Deploy only after the security gate passes.

## Handling Unfixed CVEs

When a vulnerability exists in the base image and no fix is available:

1. Identify the affected package and CVE.
2. Determine whether the component is required at runtime.
3. Check for a newer supported base image.
4. Consider an alternative minimal base image.
5. Remove unnecessary vulnerable components where safe.
6. Assess exploitability in the application's runtime context.
7. Apply compensating controls where possible.
8. Document the remaining risk and monitor for an upstream fix.

Vulnerabilities without an available fix should be treated as documented security risks rather than silently suppressed.

## Detailed Analysis

See [`IMAGE-ANALYSIS.md`](IMAGE-ANALYSIS.md) for the detailed comparison, vulnerability analysis, security considerations, and evidence mapping.
