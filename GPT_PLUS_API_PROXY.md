# Using ChatGPT Plus with Open WebUI — Research Notes

_Researched Oct 3, 2026. Sources: official OpenAI docs, GitHub, community discussions._

## TL;DR

- A **ChatGPT Plus subscription cannot be used as an OpenAI API credential**. ChatGPT subscriptions and API usage are billed separately.
- Open WebUI requires an **OpenAI API key** (separate API billing) for the built-in OpenAI provider.
- Community proxies exist that expose a ChatGPT/Codex **subscription** as an OpenAI-compatible local API endpoint. **CLIProxyAPI** is the most popular and actively maintained. These are unofficial and carry account risk.

## Official position (OpenAI)

- Plus is for the ChatGPT app; **API usage is separate and billed independently** — [What is ChatGPT Plus?](https://help.openai.com/en/articles/6950777-what-is-chatgpt-plus)
- API requests require an API key billed to an API org/project — [API reference](https://developers.openai.com/api/reference)
- "Sign in with ChatGPT" is an authorized allowance-sharing flow for **eligible participating tools** only — not a general API gateway.
- Terms prohibit account sharing and automated extraction/circumvention — [Terms of Use](https://openai.com/policies/terms-of-use/)

## Community proxy options (filtered: alive + most stars, as of Oct 2026)

| # | Repo | Stars | Last commit | Notes |
|---|------|------:|-------------|-------|
| 1 | [router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) | ~54k | Oct 2, 2026 | Codex OAuth → OpenAI-compatible endpoint; multi-provider |
| 2 | [decolua/9router](https://github.com/decolua/9router) | ~30k | Oct 1, 2026 | CLIProxyAPI-inspired gateway |
| 3 | [automazeio/vibeproxy](https://github.com/automazeio/vibeproxy) | ~3.4k | Oct 3, 2026 | macOS app wrapping CLIProxyAPI |
| 4 | [itsmylife44/CLIProxyAPI-Dashboard](https://github.com/itsmylife44/CLIProxyAPI-Dashboard) | ~260 | Oct 2, 2026 | Management UI for CLIProxyAPI |

Dead/risky (do not use): `acheong08/revChatGPT` (archived 2023), `pandora-next` (taken down by GitHub for ToS violation).

## CLIProxyAPI analysis

**What it does**
- Self-hosted Go gateway (MIT license). Translates between protocols: serves OpenAI-compatible endpoints (Chat Completions + Responses), Anthropic Messages, Gemini formats.
- Upstream accounts: Codex OAuth, Claude Code OAuth, Gemini channels, Grok Build OAuth.
- OAuth login via CLI; it issues its **own client API keys** for callers (these are not your upstream provider keys).
- Docs/user guide: https://help.router-for.me/

**Open WebUI integration**
1. Run CLIProxyAPI locally (binary or Docker; check repo releases).
2. Authenticate your ChatGPT/Codex account via its CLI OAuth flow.
3. In Open WebUI: Settings → Connections → add an OpenAI-compatible connection with the proxy's local base URL (e.g. `http://localhost:<port>/v1`) and the proxy's client key.
4. Note: protocol-compatible, not native — some API features may not map cleanly.

**Security hardening**
- Example config defaults to binding **all interfaces** — bind to `127.0.0.1` instead.
- Set a client API key; protect the OAuth token files; do not expose the management endpoint remotely.

## Community sentiment (anecdotal, unverified)

- ✅ Widely reported working with ChatGPT/Codex subscriptions; derivatives explicitly target them.
- ⚠️ 403s/blocks: users report accounts getting 403s after use ([discussion #1975](https://github.com/router-for-me/CLIProxyAPI/discussions/1975)); some say these are risk-control challenges rather than bans.
- ⚠️ Reliability: reports of "overload" responses through the proxy while direct access worked ([discussion #5887](https://github.com/router-for-me/CLIProxyAPI/discussions/5887)).
- ❓ Model behavior: unverified debate about degraded responses for third-party clients ([discussion #3937](https://github.com/router-for-me/CLIProxyAPI/discussions/3937)).

## Risk summary

| Route | Risk | Support |
|-------|------|---------|
| OpenAI API key in Open WebUI | Normal API billing costs | Fully supported |
| CLIProxyAPI (Codex/ChatGPT OAuth) | Account ban/403 risk, breakage, ToS gray area | Unofficial, at your own risk |
| Reverse-engineered web proxies | High ban + legal/ToS risk, mostly dead | None |

**Recommendation:** for production use an API key; CLIProxyAPI only for personal/experimental use, local-only, with one dedicated account.

## Tested local integration (Oct 2026)

Verified on podman (machine + compose provider) with `docker-compose.cliproxy.yaml`:

- `eceasy/cli-proxy-api:latest` starts via compose; config + `auths/` mounted from `cliproxy/`
- `GET /v1/models` with the proxy client key → model list (gpt-6.x / gpt-5.x / gpt-image / codex-auto-review) after Codex OAuth login
- Without key → 401; management API enforces its secret
- Gotchas encountered:
  - Management panel login fails with 403 "remote management disabled" behind container NAT → set `management.allow-remote: true` (ports stay localhost-published)
  - OAuth callback redirects to `localhost:1455` (and similar ports for other providers) → those callback ports must be published (see compose override)
  - The server rewrites `config.yaml` on save (hashes the management secret); expect the file to change format after first save

## Remote-server deployment

Files: `docker-compose.cliproxy.yaml` + `cliproxy/config.yaml` (create from `cliproxy/config.example.yaml` — regenerate both keys), empty `cliproxy/auths/` and `cliproxy/logs/`.

```bash
docker compose -f docker-compose.yaml -f docker-compose.cliproxy.yaml up -d cli-proxy-api
```

Attach the OAuth token (either):
- **Copy the token file** from a machine where OAuth login already worked: `scp cliproxy/auths/codex-*.json server:…/cliproxy/auths/` — tokens are portable; the container watches the auth dir
- **Or SSH-tunnel login:** `ssh -L 8317:127.0.0.1:8317 -L 1455:127.0.0.1:1455 <server>` → open `http://127.0.0.1:8317/management.html` → management key → provider OAuth (tunneling `1455` makes the `localhost:1455` callback work)

Then in Open WebUI (server's admin UI): Connections → OpenAI → add connection with
- Base URL `http://cli-proxy-api:8317/v1` — **service name, not localhost** (container-to-container over the compose network; no published ports needed)
- API key: the proxy's own client key (`access.api-keys`)

Remote cautions: never publish `8317`/`8085` on `0.0.0.0`; keep `allow-remote` semantics understood (tunnel access needs it); rotate the client key if it leaks — it can spend the linked subscription quota. Real keys and token files are gitignored (`cliproxy/config.yaml`, `cliproxy/auths/`, `cliproxy/logs/`).

## Pi deployment — deployed & verified (Oct 2026)

Deployed to the Pi (`pi@10.1.1.148`) alongside the existing OWUI stack:

- **Location:** `/home/pi/git_repo/gcp_service/instances/rpi/rpi4_4gb_148/` — `cli-proxy-api` joins the `rpi4_4gb_148` compose project (`open-webui-app1`, `ollama`, `litellm`, `redis`, `pipelines`, `open-terminal`) via the `-f docker-compose.cliproxy.yaml` override; survives Watchtower/restarts
- **Shipped:** production `cliproxy/config.yaml` (fresh keys, gitignored), OAuth token file copied into `cliproxy/auths/` (portable — picked up by the container's file watcher)
- **Verified:** `1 clients (1 auth files)` at startup; `/v1/models` → 14 Codex models; 401 without key; `open-webui-app1 → http://cli-proxy-api:8317/v1` connectivity confirmed (14 models container-to-container)

**Reasoning effort rule** (`requests.payload.override` in config.yaml): forces `reasoning.effort: max` on `*luna`, `gpt-5.6*`, `gpt-6*` (both `openai` + `codex` protocol entries cover incoming/upstream interpretation). Hot-reload confirmed; verified loaded via mgmt API (`reasoning.effort":"max"`). Effort ladder per OpenAI docs: `none → low → medium → high → xhigh → max` (model-dependent; luna supports all). A/B note: easy prompts floor out adaptively (~30 reasoning tokens at either `high` or `max`) — the difference only shows on hard tasks. `max` accepted upstream without error. Image models are not matched.

**Security verification (public-web risk: zero):**
- Port bindings published LAN-wide on `0.0.0.0` (user choice: trusted home LAN)
- Internet side verified closed: external TCP probes from 6 check-host.net vantage points (CA/SI/UA/IR/PL/SE) all timed out on `115.70.50.145:8317` and `:1455` — no router port-forward/UPnP exposure
- Cloudflare tunnel (token-based; ingress lives in the CF dashboard) maps **only** `openwebui.dzzz.ink/*` → `host.docker.internal:3001` (verified in dashboard) — proxy ports are not routed to any public hostname
- Residual: LAN users with the client key can spend Plus quota — keep keys private; rotate in `cliproxy/config.yaml` + OWUI connection settings if leaked

**Ops notes:**
- Management panel: `http://10.1.1.148:8317/management.html` (LAN) or via `ssh -L 8317:127.0.0.1:8317 pi@10.1.1.148`; login key = `management.secret-key` in `cliproxy/config.yaml`
- OWUI connection: base URL `http://cli-proxy-api:8317/v1`, key = `access.api-keys` entry
- Config edits hot-reload (file watcher); the server rewrites config.yaml on panel saves (bcrypt-hashes the management secret) — re-check file format after edits
- Logs: `docker logs cli-proxy-api` on the Pi; model catalog auto-refreshes every 3h
