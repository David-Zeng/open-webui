# HANDOFF — CLIProxyAPI Installation Runbook

_Agent-facing guide: replicate this setup in any repo/environment. Written from a completed real deployment (Oct 2026). No secrets included._

## What you're installing

**CLIProxyAPI** (`router-for-me/CLIProxyAPI`, MIT, Go) — a self-hosted gateway that bridges **subscription OAuth accounts** (ChatGPT/Codex, Claude Code, Gemini CLI, Kimi, Grok, Antigravity) into OpenAI/Anthropic/Gemini-compatible local API endpoints. Lets clients (e.g. Open WebUI) use subscription quota instead of pay-per-token API billing. Docs: <https://help.router-for.me/>

Key facts:
- Image: `eceasy/cli-proxy-api:latest` (multi-arch incl. arm64)
- Main API port: `8317` (OpenAI/Anthropic/Gemini-compatible endpoints)
- Its own client API keys authenticate callers — **not** your provider credentials
- OAuth token files land in `auths/` (portable — can be copied between hosts)
- Unofficial bridge: account-ban/risk-control risk exists; keep usage personal and human-scale

## Prerequisites

- Container runtime: docker **or** podman (+ compose provider; for podman, point `DOCKER_HOST` at the machine socket and use the docker compose binary)
- An account with Codex access (ChatGPT Plus/Pro/Business/Enterprise/Education — Plus works; limits are per-plan)
- Outbound internet from the container (model-catalog refresh hits raw.githubusercontent.com)

## Step 1 — Generate keys

```bash
echo "api-key:  $(openssl rand -hex 24)"   # proxy client key (what clients like Open WebUI use)
echo "mgmt-key: $(openssl rand -hex 16)"   # management panel login key
```

## Step 2 — Files (in the deploy directory)

`cliproxy/config.yaml` (v8 layout — full reference: `config.example.yaml` in the image at `/CLIProxyAPI/config.example.yaml`):

```yaml
server:
  host: ""
  port: 8317
access:
  api-keys:
    - "<API_KEY_FROM_STEP_1>"
oauth:
  auth-dir: "~/.cli-proxy-api"
management:
  secret-key: "<MGMT_KEY_FROM_STEP_1>"
  allow-remote: true   # REQUIRED behind container NAT / SSH tunnels; see gotcha G1
requests:
  payload:
    # Optional: force reasoning effort per model variant. Disjoint patterns so precedence never matters.
    # Ladder: none → low → medium → high → xhigh → max (model-dependent).
    override:
      - models: [{name: "gpt-*-luna", protocol: "openai"}, {name: "gpt-*-luna", protocol: "codex"}]
        params: {"reasoning.effort": "max"}
      - models: [{name: "gpt-*-terra", protocol: "openai"}, {name: "gpt-*-terra", protocol: "codex"}]
        params: {"reasoning.effort": "medium"}
      - models: [{name: "gpt-*-sol", protocol: "openai"}, {name: "gpt-*-sol", protocol: "codex"},
                 {name: "gpt-*-astra", protocol: "openai"}, {name: "gpt-*-astra", protocol: "codex"}]
        params: {"reasoning.effort": "low"}
```

`docker-compose.cliproxy.yaml` — two variants:

**A) Join an existing compose project** (recommended when a client like Open WebUI runs there — container-to-container, no published ports needed):

```yaml
services:
  cli-proxy-api:
    image: eceasy/cli-proxy-api:latest
    container_name: cli-proxy-api
    volumes:
      - ./cliproxy/config.yaml:/CLIProxyAPI/config.yaml
      - ./cliproxy/auths:/root/.cli-proxy-api
      - ./cliproxy/logs:/CLIProxyAPI/logs
    ports:
      - "127.0.0.1:8317:8317"   # publish ONLY for host-side clients / panel access
      - "127.0.0.1:1455:1455"   # OAuth callback port (needed for browser OAuth via tunnel)
    restart: unless-stopped
```

**B) Standalone** — same service block, no need for the base compose file.

```bash
mkdir -p cliproxy/auths cliproxy/logs
# write both files, then:
docker compose -f docker-compose.yml -f docker-compose.cliproxy.yaml up -d cli-proxy-api
# (standalone: docker compose -f docker-compose.cliproxy.yaml up -d)
```

⚠️ Do NOT pass `--env-file` unless it exists (failure mode: compose aborts with "couldn't find env file").

## Step 3 — OAuth login (attach the subscription)

Two paths:

**Path A — copy portable token files (fastest, no browser dance):**
If OAuth was already completed on another machine: `scp <src>/cliproxy/auths/codex-*.json <host>:…/cliproxy/auths/`. The container's file watcher picks them up automatically; `/v1/models` populates within seconds.

**Path B — management panel:**
1. Reach the panel: `http://127.0.0.1:8317/management.html` (direct if port published locally; else `ssh -L 8317:127.0.0.1:8317 -L 1455:127.0.0.1:1455 <host>` and open on your machine)
2. Login with the management key → provider OAuth (e.g. Codex) → approve in browser
3. The OpenAI consent redirects the browser to `http://localhost:1455/...` — **that callback port must be published/tunneled** (gotcha G2), and it lands on the machine running the browser, not the server

Verify: `docker logs cli-proxy-api | grep -i "auth files"` → expect `1 clients (1 auth files…)`.

## Step 4 — Verify

```bash
KEY=<API_KEY>; URL=http://127.0.0.1:8317   # or service name from a co-deployed container
curl -s -o /dev/null -w '%{http_code}\n' $URL/                                        # 200
curl -s -H "Authorization: Bearer $KEY" $URL/v1/models | head -c 300                  # model list
curl -s -o /dev/null -w '%{http_code}\n' $URL/v1/models                               # 401 (auth enforced)
# co-deployed client connectivity (open-webui image has python3):
docker exec open-webui python3 -c "import urllib.request,json; r=urllib.request.Request('http://cli-proxy-api:8317/v1/models',headers={'Authorization':'Bearer $KEY'}); print(len(json.load(urllib.request.urlopen(r))['data']))"
```

`/v1/models` empty before OAuth = normal. 401 without key = correct.

## Step 5 — Integrate with Open WebUI

Admin Panel → Settings → Connections → OpenAI API → **+**:
- URL: `http://cli-proxy-api:8317/v1` if co-deployed on the same compose network (**service name, NOT localhost**); `http://<host>:8317/v1` if host-side
- Key: the proxy client key (`access.api-keys`)

## Gotcha catalog (all hit in the real deployment)

- **G1 — Management login 403 "remote management disabled":** container NAT makes traffic arrive from a gateway IP, not localhost → set `management.allow-remote: true` (ports stay localhost-published; secret still required, even for localhost).
- **G2 — OAuth "this site can't be reached":** the consent flow redirects the browser to `localhost:1455` (and provider-specific callback ports) — publish/tunnel them or the redirect dies.
- **G3 — `curl -I` returns 404 on /management.html:** HEAD isn't registered on that route — **use GET** (`curl -s`) for verification. Not an outage.
- **G4 — Config file mutates behind you:** the server rewrites `config.yaml` on panel saves (bcrypt-hashes the management secret, re-serializes). Re-read the file before scripted edits (`sed` patterns may no longer match).
- **G5 — Hot-reload vs recreate:** config edits hot-reload via the file watcher (no downtime). Use `--force-recreate` only when reload timing must be exact — it takes the container down for a few seconds.
- **G6 — ARM hosts:** image is multi-arch, but verify on first pull; if missing, build from source on the host.
- **G7 — Browser LAN access (macOS Sequoia+):** per-app **Local Network permission** gates LAN IPs; apps appear in the permission list lazily (only after triggering the prompt). Firefox may never appear without updating it first. Chrome/Safari usually fine. Terminal `curl` is a separate grant.
- **G8 — Podman specifics:** machine may be stopped after idle (`podman machine start`); use the machine API socket as `DOCKER_HOST` with the docker compose binary.

## Security checklist

- [ ] Ports published on `127.0.0.1` only — never `0.0.0.0` unless the LAN is explicitly trusted (that choice exposes both API and panel to LAN; keys are the only barrier)
- [ ] Strong client key + management key (rotate on leak — client key spend = subscription quota)
- [ ] No public-web path: if a reverse proxy / Cloudflare tunnel exists, verify its ingress rules don't route the proxy ports; verify with an external TCP probe (e.g. `check-host.net/check-tcp?host=<PUBLIC_IP>:8317` — async API, poll the result) — expect timeouts
- [ ] Personal use only; never share the endpoint/key (account sharing = clearest ToS violation → ban risk)
- [ ] Stop at the first 403/verification challenge from upstream rather than retrying through it

## Where this was validated

Full write-up incl. research sources, policy caveats, Pi deployment specifics: `GPT_PLUS_API_PROXY.md` in this repo. Deployed config template: `cliproxy/config.example.yaml`.
