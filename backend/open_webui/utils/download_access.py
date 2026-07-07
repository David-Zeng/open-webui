"""
Blocks non-admin users from downloading files/chat exports unless their
request's source IP matches an admin-configured allowlist. Admins are always
exempt. Mirrors the shape of utils/auth.py's get_current_user_by_api_key
endpoint-restriction check: a Config-backed, comma-separated allowlist,
enforced inline in request-handling code, empty-list-means-unrestricted
(fail-open by default, same convention as ENABLE_API_KEYS_ENDPOINT_RESTRICTIONS).

Reads request.client.host directly — already confirmed correct in production
via Caddy's default X-Forwarded-For + uvicorn's --forwarded-allow-ips (see
docs/plans/2026-07-07-download-ip-allowlist.md for the live verification).
Do not read X-Forwarded-For here directly: uvicorn's ProxyHeadersMiddleware
already did that rewrite once, upstream of this code, and re-parsing it here
would trust a client-supplied header a second time for no benefit.
"""

import ipaddress
import logging

from fastapi import HTTPException, Request, status

from open_webui.constants import ERROR_MESSAGES

log = logging.getLogger(__name__)


def _parse_allowlist(allowlist: str) -> list[ipaddress.IPv4Network | ipaddress.IPv6Network]:
    networks = []
    for entry in allowlist.split(','):
        entry = entry.strip()
        if not entry:
            continue
        try:
            networks.append(ipaddress.ip_network(entry, strict=False))
        except ValueError:
            log.warning(f'Skipping malformed DOWNLOAD_IP_ALLOWLIST entry: {entry!r}')
    return networks


def check_download_ip_allowed(request: Request, user, allowlist: str) -> None:
    """Raise HTTPException(403) if user is non-admin and not in the IP allowlist.

    No-op (returns None) if user is admin, or if allowlist is empty (feature off).
    """
    if user.role == 'admin':
        return

    if not allowlist.strip():
        return

    networks = _parse_allowlist(allowlist)
    if not networks:
        # Every entry was malformed — treat as if the list were empty (fail-open),
        # consistent with "empty allowlist = unrestricted." An admin who typos
        # their entire allowlist gets a loud warning in logs, not a silent lockout.
        log.warning('DOWNLOAD_IP_ALLOWLIST has no valid entries after parsing — allowing all')
        return

    client_host = request.client.host if request.client else None
    if not client_host:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=ERROR_MESSAGES.ACCESS_PROHIBITED)

    try:
        client_ip = ipaddress.ip_address(client_host)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=ERROR_MESSAGES.ACCESS_PROHIBITED)

    if not any(client_ip in network for network in networks):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=ERROR_MESSAGES.ACCESS_PROHIBITED)
