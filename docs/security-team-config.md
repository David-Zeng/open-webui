# OpenWebUI Security & Team Configuration Guide

Reference for configuring OpenWebUI securely for a small startup team (5–20 users).

---

## 1. Authentication Hardening

| Variable | Recommended | Purpose |
|----------|-------------|---------|
| `WEBUI_SECRET_KEY` | Strong random string | JWT signing key — **must set** |
| `ENABLE_PASSWORD_VALIDATION` | `True` | Enforce strong passwords |
| `PASSWORD_VALIDATION_REGEX_PATTERN` | default | Min 8 chars, upper/lower/digit/special char |
| `PASSWORD_VALIDATION_HINT` | Custom hint string | User-friendly hint shown on signup |
| `JWT_EXPIRES_IN` | `8h` or `1d` | Shorter than default `4w` for security |
| `WEBUI_SESSION_COOKIE_SECURE` | `true` | Require HTTPS for session cookies |
| `WEBUI_SESSION_COOKIE_SAME_SITE` | `strict` | CSRF protection |

Default password regex: `^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}$`

---

## 2. User Registration Control

| Variable | Recommended | Purpose |
|----------|-------------|---------|
| `ENABLE_INITIAL_ADMIN_SIGNUP` | `True` → then `False` | Bootstrap first admin, then lock down |
| `ENABLE_SIGNUP` | `False` | Disable self-registration after initial setup |
| `DEFAULT_USER_ROLE` | `pending` | New users require admin approval |
| `PENDING_USER_OVERLAY_TITLE` | Custom message | Shown to pending users |
| `PENDING_USER_OVERLAY_CONTENT` | Custom message | Instructions for pending users (e.g. "Contact admin@yourco.com") |

---

## 3. User Permissions to Lock Down

Set these to `False` for a tighter team environment:

```bash
# Sharing
USER_PERMISSIONS_CHAT_ALLOW_PUBLIC_SHARING=False
USER_PERMISSIONS_WORKSPACE_MODELS_ALLOW_SHARING=False
USER_PERMISSIONS_WORKSPACE_MODELS_ALLOW_PUBLIC_SHARING=False
USER_PERMISSIONS_WORKSPACE_KNOWLEDGE_ALLOW_PUBLIC_SHARING=False
USER_PERMISSIONS_WORKSPACE_PROMPTS_ALLOW_PUBLIC_SHARING=False
USER_PERMISSIONS_WORKSPACE_TOOLS_ALLOW_PUBLIC_SHARING=False
USER_PERMISSIONS_NOTES_ALLOW_PUBLIC_SHARING=False

# Advanced features (enable selectively)
USER_PERMISSIONS_FEATURES_API_KEYS=False
USER_PERMISSIONS_FEATURES_AUTOMATIONS=False
USER_PERMISSIONS_FEATURES_DIRECT_TOOL_SERVERS=False
```

Useful features to keep enabled for teams:
- `USER_PERMISSIONS_FEATURES_WEB_SEARCH=True`
- `USER_PERMISSIONS_FEATURES_FOLDERS=True`
- `USER_PERMISSIONS_FEATURES_NOTES=True`
- `USER_PERMISSIONS_FEATURES_CHANNELS=True`

---

## 4. API Keys (Programmatic Access)

Disabled by default. Enable only if CI/CD or integrations need it:

```bash
ENABLE_API_KEYS=True
ENABLE_API_KEY_ENDPOINT_RESTRICTIONS=True
API_KEYS_ALLOWED_ENDPOINTS=/api/v1/chats,/api/v1/completions
```

Users also need `USER_PERMISSIONS_FEATURES_API_KEYS=True` to create their own keys.

---

## 5. Audit Logging

```bash
ENABLE_AUDIT_LOGS_FILE=True
AUDIT_LOG_LEVEL=METADATA          # Options: NONE | METADATA | REQUEST | REQUEST_RESPONSE
AUDIT_LOGS_FILE_PATH=/data/audit.log
AUDIT_LOG_FILE_ROTATION_SIZE=10MB
ENABLE_AUDIT_GET_REQUESTS=False   # Set True for full read audit trail
# AUDIT_EXCLUDED_PATHS=/chats,/chat,/folders   # default exclusions
```

---

## 6. SSO / Identity Provider (Optional)

### Option A: OAuth (Google / Microsoft / GitHub)

```bash
ENABLE_OAUTH_SIGNUP=True
OAUTH_ALLOWED_DOMAINS=yourcompany.com      # Restrict to your domain
OAUTH_AUTO_REDIRECT=True                   # Skip login form
ENABLE_OAUTH_ROLE_MANAGEMENT=True
OAUTH_ADMIN_ROLES=admin
OAUTH_ALLOWED_ROLES=user,admin
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=True
```

### Option B: LDAP (Active Directory / OpenLDAP)

```bash
ENABLE_LDAP=True
LDAP_SERVER_HOST=ldap.yourcompany.com
LDAP_SERVER_PORT=636
LDAP_USE_TLS=True
LDAP_VALIDATE_CERT=True
LDAP_APP_DN=cn=service-account,dc=yourcompany,dc=com
LDAP_APP_PASSWORD=<service account password>
LDAP_SEARCH_BASE=ou=users,dc=yourcompany,dc=com
LDAP_SEARCH_FILTER=(memberOf=cn=staff,ou=groups,dc=yourcompany,dc=com)
LDAP_ATTRIBUTE_FOR_USERNAME=uid
LDAP_ATTRIBUTE_FOR_MAIL=mail
ENABLE_LDAP_GROUP_MANAGEMENT=True
```

`LDAP_SEARCH_FILTER` is appended as an additional `(&...)` clause alongside the username match built from `LDAP_ATTRIBUTE_FOR_USERNAME` — it is not a template and does not take a `{0}`-style placeholder. Leave it empty to match on username alone, or use it to further restrict logins to a group/OU as shown above.

### Option C: Trusted Reverse Proxy Headers (Tailscale / Nginx SSO)

```bash
WEBUI_AUTH_TRUSTED_EMAIL_HEADER=X-Remote-User-Email
WEBUI_AUTH_TRUSTED_NAME_HEADER=X-Remote-User-Name
WEBUI_AUTH_TRUSTED_ROLE_HEADER=X-Remote-User-Role
```

---

## 7. Admin Controls

| Variable | Default | Recommendation |
|----------|---------|----------------|
| `ENABLE_ADMIN_CHAT_ACCESS` | `True` | Keep `True` for compliance/audit |
| `ENABLE_ADMIN_EXPORT` | `True` | Keep `True` for data portability |
| `ENABLE_ADMIN_ANALYTICS` | `True` | Keep `True` for usage visibility |
| `SHOW_ADMIN_DETAILS` | `True` | Set `False` to hide admin email on login page |
| `BYPASS_MODEL_ACCESS_CONTROL` | `False` | Keep `False` to restrict models per user/group |
| `BYPASS_RETRIEVAL_ACCESS_CONTROL` | `False` | Keep `False` for knowledge base isolation |

---

## 8. Rate Limiting

Built-in: **15 login attempts per 3 minutes** (sliding window). No configuration required — enforced automatically on the sign-in endpoint, using Redis if available.

---

## 9. Minimal `.env` Starter

```bash
# ── Core Auth ────────────────────────────────────────────────
WEBUI_AUTH=True
WEBUI_SECRET_KEY=<generate: openssl rand -hex 32>
ENABLE_PASSWORD_VALIDATION=True
JWT_EXPIRES_IN=8h

# ── Cookie Security ──────────────────────────────────────────
WEBUI_SESSION_COOKIE_SECURE=true
WEBUI_SESSION_COOKIE_SAME_SITE=strict

# ── Registration (run once with INITIAL_ADMIN=True, then flip) ──
ENABLE_INITIAL_ADMIN_SIGNUP=False
ENABLE_SIGNUP=False
DEFAULT_USER_ROLE=pending

# ── Audit ────────────────────────────────────────────────────
ENABLE_AUDIT_LOGS_FILE=True
AUDIT_LOG_LEVEL=METADATA

# ── Restrict Sharing & Advanced Features ─────────────────────
USER_PERMISSIONS_CHAT_ALLOW_PUBLIC_SHARING=False
USER_PERMISSIONS_WORKSPACE_MODELS_ALLOW_PUBLIC_SHARING=False
USER_PERMISSIONS_FEATURES_API_KEYS=False
USER_PERMISSIONS_FEATURES_AUTOMATIONS=False
USER_PERMISSIONS_FEATURES_DIRECT_TOOL_SERVERS=False
```

---

## Config Locations

| Type | Location | Notes |
|------|----------|-------|
| Environment variables | `backend/open_webui/env.py` | Set in `.env` / `docker-compose.yml`; read at startup |
| Runtime/persistent config | `backend/open_webui/config.py` | Changeable live via Admin Panel → Settings (no restart needed) |
| Per-user permissions | Admin Panel → Users | Override defaults per user or group |
