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
