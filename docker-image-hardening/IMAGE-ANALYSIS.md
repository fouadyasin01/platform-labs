# Docker Image Security Analysis

## Overview

This project demonstrates the hardening of a Node.js container image by comparing an intentionally naive baseline image with a production-oriented optimized image.

The optimized image uses a pinned Alpine-based Node.js image, a multi-stage build, production-only dependencies, a non-root application user, a `.dockerignore`, runtime package cleanup, Alpine security updates, and a Docker HEALTHCHECK.

## 1. Estimated Image Size Reduction

The baseline image uses `FROM node:latest` as the intentionally unoptimized reference image.


Measured image sizes:

| Image | Size |
|---|---:|
| Baseline | 426.61 MB |
| Optimized | 58.62 MB |
| Reduction | 367.99 MB |
| Percentage reduction | 86.26% |

The optimized image is therefore **86.26% smaller** than the baseline image.

The reduction is achieved through the use of a minimal Alpine-based runtime, multi-stage construction, production-only dependencies, removal of unnecessary runtime package-management tooling, and exclusion of unnecessary files from the Docker build context.

### Size Evidence

The exact measured values are preserved in:

- `baseline/image-size.txt`
- `optimized/image-size.txt`

## 2. Multi-Stage Build and Attack Surface

The optimized Dockerfile separates dependency installation from the final runtime image.

The dependency stage uses npm to install the application's production dependencies. The runtime stage receives only the files required to run the application.

This prevents build-time tooling and unnecessary build dependencies from being carried into the production image.

The runtime stage also removes npm and Corepack because the application only requires the Node.js runtime to execute `server.js`.

Reducing the number of installed components reduces the potential attack surface and limits the amount of software that needs to be maintained and scanned in production.

### Dockerfile Evidence

The implementation is available in:

- `optimized/Dockerfile`

The original intentionally naive implementation is available in:

- `baseline/Dockerfile`

## 3. Non-Root Execution and Privilege Escalation

The optimized image creates a dedicated application user:

- User: `appuser`
- UID: `1001`
- Group: `appgroup`
- GID: `1001`

The container explicitly switches to this user:

```dockerfile
USER 1001
```

Running the application as a non-root user limits the privileges available to a compromised application process.

If an attacker exploits an application vulnerability, the resulting process does not have root privileges inside the container. This reduces the potential impact of container-level privilege escalation and limits access to protected system resources.

### User Evidence

- `baseline/container-user.txt`
- `optimized/container-user.txt`

## 4. Build Context Protection

The optimized image includes a `.dockerignore` that excludes unnecessary or sensitive content from the Docker build context, including:

- `node_modules`
- `.git`
- tests
- environment files
- npm debug logs
- documentation files

This prevents local development artifacts and unnecessary files from being included in the Docker build context.

### `.dockerignore` Evidence

- `optimized/.dockerignore`

## 5. Vulnerability Scanning

Trivy was used to establish a vulnerability baseline and validate the hardened image.

### Baseline Results

The baseline image contained:

- **325 total HIGH/CRITICAL vulnerabilities**
- **309 HIGH**
- **16 CRITICAL**

### Optimized Results

The final optimized image contained:

- **0 HIGH**
- **0 CRITICAL**

The final optimized scan therefore reduced the HIGH/CRITICAL vulnerability count from **325 to 0**.

The optimized Trivy scan also reported zero vulnerabilities for the Alpine OS target and zero findings across the scanned application Node.js packages.

### Scan Evidence

- `baseline/trivy-high-critical.txt`
- `optimized/trivy-high-critical.txt`

## 6. CI Vulnerability Scanning

Trivy can be integrated into a CI pipeline after building the Docker image.

A CI job can fail when HIGH or CRITICAL vulnerabilities are detected:

```bash
trivy image --exit-code 1 --severity HIGH,CRITICAL node-app:optimized
```

A typical CI flow is:

1. Build the Docker image.
2. Scan the resulting image with Trivy.
3. Fail the pipeline if HIGH or CRITICAL vulnerabilities are detected.
4. Allow deployment only after the security gate passes.

## 7. Handling a Base-Image CVE With No Fix Available

If a vulnerability is found in the base image and no fixed version is currently available, it should not simply be ignored.

The recommended process is:

1. Identify the affected package and CVE.
2. Determine whether the vulnerable component is actually required at runtime.
3. Check for a newer supported base image or alternative minimal base image.
4. Remove the affected component if it is unnecessary and safe to remove.
5. Assess whether the vulnerability is exploitable in the application's actual runtime context.
6. Apply appropriate compensating controls where possible.
7. Document the vulnerability, impact, mitigation, and any temporary risk acceptance.
8. Continue monitoring the upstream project for an official fix.

A vulnerability without an available fix should therefore be handled as a documented risk rather than silently suppressed.

## 8. Hardening Summary

The optimized image implements:

- Pinned Alpine-based Node.js image instead of `node:latest`
- Multi-stage Docker build
- Production-only dependencies
- Removal of npm and Corepack from the runtime image
- Dedicated non-root UID `1001`
- Minimal runtime contents
- `.dockerignore`
- Alpine security package upgrades
- Docker HEALTHCHECK
- `NODE_ENV=production`
- Trivy vulnerability scanning

### Final Measured Outcome

| Security / Efficiency Metric | Baseline | Optimized |
|---|---:|---:|
| Image size | 426.61 MB | 58.62 MB |
| Size reduction | — | 86.26% |
| HIGH vulnerabilities | 309 | 0 |
| CRITICAL vulnerabilities | 16 | 0 |
| HIGH + CRITICAL | 325 | 0 |

The final optimized image is **86.26% smaller** than the baseline and reduced the recorded HIGH/CRITICAL vulnerability count from **325 to 0**.

## 9. Evidence Map

All supporting evidence is kept inside this project:

```text
docker-image-hardening/
├── app/
│   ├── package.json
│   ├── package-lock.json
│   └── server.js
├── baseline/
│   ├── Dockerfile
│   ├── container-user.txt
│   ├── image-size.txt
│   └── trivy-high-critical.txt
├── optimized/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── container-user.txt
│   ├── image-size.txt
│   └── trivy-high-critical.txt
└── IMAGE-ANALYSIS.md
```

The evidence files are intentionally separated from the analysis so the measured results can be independently reviewed.

