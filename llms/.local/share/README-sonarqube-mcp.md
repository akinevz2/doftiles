# SonarQube MCP Setup (self-contained local stack)

## Overview

A fully local SonarQube code-quality stack living in this package:

- `docker-compose.yml` — three services on `docker-llms_default`:
  - `sonarqube-db` (postgres:17-alpine)
  - `sonarqube` (Community Build, web on `localhost:9000`, bound `0.0.0.0`)
  - `sonar-mcp` (`sonarsource/sonarqube-mcp`, Streamable HTTP on `localhost:8080/mcp`, `/health` + `/info` probes)
- `.local/bin/bootstrap-sonarqube.sh` — idempotent fresh-instance provisioner: awaits UP,
  rotates the `admin` password off-default (0600 `shell/.cache/sonarqube.admin`),
  mints a **USER** token, validates it end-to-end, and writes the gitignored
  env file.

## OpenCode wiring

Configured in `.config/opencode/opencode.jsonc` (canonical) and mirrored into
`opencode.json` — all servers under `mcp.servers` (V2 shape):

- `sonarqube` — local stdio via `sonarqube-mcp-wrapper`: the wrapper resolves
  `SONARQUBE_TOKEN` at spawn time from the gitignored env file and runs a
  stdio-mode `sonarsource/sonarqube-mcp` container on the stack network
  (token never lives in any config file; the container reaches SonarQube by
  internal DNS `http://sonarqube:9000`)
- `github` — `github-mcp-wrapper` (token resolved from `gh auth login`, no
  stored secret)

No cloud servers are configured — everything runs on this workstation. The
`sonar-mcp` HTTP service (port 8080) stays up in the stack for other local
clients (curl, editors); OpenCode itself uses the wrapper.

## Credentials flow (transient, gitignored)

The shell package sources any `*.env` from `shell/.cache/` via the hook in
`shell/.bashrcx`. `shell/.cache/sonarqube.env` holds
`SONARQUBE_TOKEN`/`SONARQUBE_URL` (chmod 600, never committed — the dots
`.gitignore` covers `shell/.cache/`).

## Operation

```sh
cd ~/dots/llms
docker compose up -d          # start stack
bash .local/bin/bootstrap-sonarqube.sh   # after: fresh wipe (compose down -v), or re-run to verify
sonarqube-mcp-manager status  # container status helper
```

A personal token is instance-bound: a token minted on sonarcloud.io or a
previous install validates `false` here — bootstrap-sonarqube.sh mints one
that works.
