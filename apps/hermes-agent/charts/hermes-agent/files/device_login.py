#!/usr/bin/env python3
"""Interactive provider login for a Hermes Agent chart init container.

Two flow kinds are supported:

* ``github`` performs GitHub's RFC 8628 device grant and stores one token in
  ``$HERMES_HOME/.env`` (the existing GitHub Copilot behavior).
* ``openai-codex`` follows Hermes' version-pinned OpenAI Codex device-code
  exchange and delegates persistence to ``hermes_cli.auth._save_codex_tokens``.
  That upstream helper preserves and atomically updates ``auth.json``, including
  the credential pool and refresh-token chain.

Both flows print the verification URL and user code to the init-container logs
and can additionally deliver them to Discord or Telegram. Authorization codes, PKCE
verifiers, access tokens, refresh tokens, and API keys are never printed.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

FLOW_KIND = os.getenv("DEVICE_FLOW_KIND", "github").strip().lower()
CLIENT_ID = os.getenv("OAUTH_CLIENT_ID", "").strip()
SCOPE = os.getenv("OAUTH_SCOPE", "read:user").strip()
AUTH_HOST = os.getenv("AUTH_HOST", "github.com").strip().rstrip("/")
TOKEN_ENV = os.getenv("TOKEN_ENV", "").strip()
VALIDATE_URL = os.getenv("VALIDATE_URL", "").strip()
NOTIFY = os.getenv("NOTIFY", "discord").strip().lower()
BOT_TOKEN = os.getenv("DISCORD_BOT_TOKEN", "").strip()
CHANNEL_ID = os.getenv("DISCORD_HOME_CHANNEL", "").strip()
LOGIN_LABEL = os.getenv("LOGIN_LABEL", "").strip()
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_HOME_CHANNEL", "").strip()
HERMES_HOME = Path(os.getenv("HERMES_HOME", "/opt/data"))
TIMEOUT = int(os.getenv("LOGIN_TIMEOUT_SECONDS", "870"))
FORCE_RELOGIN = os.getenv("FORCE_RELOGIN", "false").strip().lower() == "true"
CHOWN_UID = int(os.getenv("CHOWN_UID", "-1"))
CHOWN_GID = int(os.getenv("CHOWN_GID", "-1"))

DEVICE_CODE_URL = f"https://{AUTH_HOST}/login/device/code"
ACCESS_TOKEN_URL = f"https://{AUTH_HOST}/login/oauth/access_token"
DISCORD_API = "https://discord.com/api/v10"
TELEGRAM_API = "https://api.telegram.org"
OPENAI_CODEX_ISSUER = os.getenv(
    "OPENAI_CODEX_ISSUER", "https://auth.openai.com"
).strip().rstrip("/")


def _decode_json(raw: bytes) -> dict[str, Any]:
    value = json.loads(raw.decode())
    if not isinstance(value, dict):
        raise ValueError("response was not a JSON object")
    return value


def _post_form(url: str, fields: dict[str, Any]) -> dict[str, Any]:
    data = urllib.parse.urlencode(fields).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Accept": "application/json",
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": "hermes-device-login/2.0",
        },
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return _decode_json(resp.read())


def _post_json_status(
    url: str, payload: dict[str, Any]
) -> tuple[int, dict[str, Any], dict[str, str]]:
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "hermes-device-login/2.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.status, _decode_json(resp.read()), dict(resp.headers.items())
    except urllib.error.HTTPError as exc:
        try:
            body = _decode_json(exc.read())
        except Exception:  # noqa: BLE001 - the status remains actionable
            body = {}
        return exc.code, body, dict(exc.headers.items())


def _post_form_status(
    url: str, fields: dict[str, Any]
) -> tuple[int, dict[str, Any], dict[str, str]]:
    req = urllib.request.Request(
        url,
        data=urllib.parse.urlencode(fields).encode(),
        headers={
            "Accept": "application/json",
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": "hermes-device-login/2.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.status, _decode_json(resp.read()), dict(resp.headers.items())
    except urllib.error.HTTPError as exc:
        try:
            body = _decode_json(exc.read())
        except Exception:  # noqa: BLE001 - the status remains actionable
            body = {}
        return exc.code, body, dict(exc.headers.items())


def discord_post(content: str) -> None:
    """Best-effort delivery of a verification message to Discord."""
    if NOTIFY != "discord":
        return
    if not (BOT_TOKEN and CHANNEL_ID):
        print("  [discord] bot token / channel not set - skipping post")
        return
    req = urllib.request.Request(
        f"{DISCORD_API}/channels/{CHANNEL_ID}/messages",
        data=json.dumps({"content": content}).encode(),
        headers={
            "Authorization": f"Bot {BOT_TOKEN}",
            "Content-Type": "application/json",
            "User-Agent": "hermes-device-login/2.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            print(f"  [discord] posted message (HTTP {resp.status})")
    except urllib.error.HTTPError as exc:
        print(f"  [discord] post FAILED HTTP {exc.code}")
    except Exception as exc:  # noqa: BLE001
        print(f"  [discord] post FAILED: {exc}")


def telegram_post(content: str) -> None:
    """Best-effort delivery of a verification message to Telegram.

    Uses sendMessage only (never getUpdates), so it cannot conflict with the
    agent's own long polling on the same bot token. The token is part of the
    request URL, so failures log the error class only, never the URL.
    """
    if NOTIFY != "telegram":
        return
    if not (TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID):
        print("  [telegram] bot token / home channel not set - skipping post")
        return
    req = urllib.request.Request(
        f"{TELEGRAM_API}/bot{TELEGRAM_BOT_TOKEN}/sendMessage",
        data=json.dumps(
            {
                "chat_id": TELEGRAM_CHAT_ID,
                "text": content,
                "disable_web_page_preview": True,
            }
        ).encode(),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "hermes-device-login/2.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            print(f"  [telegram] posted message (HTTP {resp.status})")
    except urllib.error.HTTPError as exc:
        print(f"  [telegram] post FAILED HTTP {exc.code}")
    except Exception as exc:  # noqa: BLE001
        print(f"  [telegram] post FAILED: {type(exc).__name__}")


def _for_label() -> str:
    """Name the release in a prompt, so parallel logins can be told apart."""
    return f" for {LOGIN_LABEL}" if LOGIN_LABEL else ""


def notify_post(content: str) -> None:
    """Deliver a verification message through the configured notify channel."""
    if NOTIFY == "discord":
        discord_post(content)
    elif NOTIFY == "telegram":
        telegram_post(content)


def _notification_ready() -> bool:
    if NOTIFY == "discord" and not (BOT_TOKEN and CHANNEL_ID):
        print("ERROR: NOTIFY=discord requires DISCORD_BOT_TOKEN and DISCORD_HOME_CHANNEL.")
        return False
    if NOTIFY == "telegram" and not (TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID):
        print("ERROR: NOTIFY=telegram requires TELEGRAM_BOT_TOKEN and TELEGRAM_HOME_CHANNEL.")
        return False
    return True


def _chown(path: Path) -> None:
    if CHOWN_UID < 0 and CHOWN_GID < 0:
        return
    try:
        os.chown(path, CHOWN_UID, CHOWN_GID)
        print(f"  chowned {path} to {CHOWN_UID}:{CHOWN_GID}")
    except OSError as exc:
        print(f"  WARNING: could not chown {path}: {exc}")


def read_env_token() -> str:
    env_path = HERMES_HOME / ".env"
    if not env_path.exists():
        return ""
    for line in env_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.strip().startswith(f"{TOKEN_ENV}="):
            return line.split("=", 1)[1].strip()
    return ""


def token_is_valid(token: str) -> bool:
    """Treat only an explicit 401/403 validation response as invalid."""
    if not token:
        return False
    if not VALIDATE_URL:
        return True
    req = urllib.request.Request(
        VALIDATE_URL,
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/json",
            "User-Agent": "hermes-device-login/2.0",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status == 200
    except urllib.error.HTTPError as exc:
        return exc.code not in (401, 403)
    except Exception:  # noqa: BLE001 - transient network errors must not block startup
        return True


def write_env_token(token: str) -> None:
    """Upsert TOKEN_ENV in $HERMES_HOME/.env, preserving other keys."""
    HERMES_HOME.mkdir(parents=True, exist_ok=True)
    env_path = HERMES_HOME / ".env"
    lines: list[str] = []
    if env_path.exists():
        lines = env_path.read_text(encoding="utf-8", errors="replace").splitlines()
    out = [ln for ln in lines if not ln.strip().startswith(f"{TOKEN_ENV}=")]
    out.append(f"{TOKEN_ENV}={token}")
    env_path.write_text("\n".join(out) + "\n", encoding="utf-8")
    try:
        os.chmod(env_path, 0o600)
    except OSError:
        pass
    _chown(env_path)
    print(f"  wrote {TOKEN_ENV} to {env_path}")


def run_github_device_flow() -> int:
    if not _notification_ready():
        return 2

    print(f"Starting GitHub device flow (client={CLIENT_ID}, host={AUTH_HOST}) ...")
    dev = _post_form(DEVICE_CODE_URL, {"client_id": CLIENT_ID, "scope": SCOPE})
    device_code = dev.get("device_code")
    user_code = dev.get("user_code")
    verification_uri = dev.get("verification_uri", f"https://{AUTH_HOST}/login/device")
    interval = max(int(dev.get("interval", 5)), 1)
    expires_in = int(dev.get("expires_in", 900))
    if not device_code or not user_code:
        print("ERROR: GitHub device flow did not return a code.")
        return 1

    print(f"  user_code={user_code}  verify={verification_uri}  expires_in={expires_in}s")
    notify_post(
        f"{TOKEN_ENV} login required{_for_label()}:\n"
        f"1. Open: {verification_uri}\n"
        f"2. Enter code: {user_code}\n"
        f"(valid ~{expires_in // 60} min; phone-friendly)"
    )

    print("  waiting for authorization ...")
    deadline = time.monotonic() + min(TIMEOUT, expires_in)
    token = ""
    while time.monotonic() < deadline:
        time.sleep(interval + 1)
        try:
            res = _post_form(
                ACCESS_TOKEN_URL,
                {
                    "client_id": CLIENT_ID,
                    "device_code": device_code,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                },
            )
        except Exception as exc:  # noqa: BLE001
            print(f"  poll error (will retry): {exc}")
            continue

        if res.get("access_token"):
            token = str(res["access_token"])
            print("  AUTHORIZED. Access token received.")
            break

        err = res.get("error", "")
        if err == "authorization_pending":
            continue
        if err == "slow_down":
            interval = int(res.get("interval", interval + 5))
            continue
        if err in ("expired_token", "access_denied"):
            print(f"  ERROR: {err}")
            notify_post(f"Login failed{_for_label()}: {err}. The pod will retry.")
            return 1
        print(f"  poll returned error: {err or 'unknown response'}")

    if not token:
        print("  ERROR: timed out waiting for authorization")
        notify_post(f"Login timed out{_for_label()}. The pod will retry.")
        return 1

    write_env_token(token)
    notify_post(f"Login complete{_for_label()}. The agent is starting.")
    return 0


def _codex_native() -> tuple[str, str, Any, Any]:
    """Load the version-pinned Hermes Codex constants and persistence helpers."""
    from hermes_cli.auth import (  # type: ignore[import-not-found]
        CODEX_OAUTH_CLIENT_ID,
        CODEX_OAUTH_TOKEN_URL,
        _save_codex_tokens,
        resolve_codex_runtime_credentials,
    )

    return (
        str(CODEX_OAUTH_CLIENT_ID),
        str(CODEX_OAUTH_TOKEN_URL),
        _save_codex_tokens,
        resolve_codex_runtime_credentials,
    )


def _existing_codex_state(resolve_credentials: Any) -> str:
    try:
        resolved = resolve_credentials(refresh_if_expiring=True)
    except Exception as exc:  # noqa: BLE001 - Hermes raises its version-specific AuthError
        code = str(getattr(exc, "code", "") or "")
        if bool(getattr(exc, "relogin_required", False)):
            print(
                "Existing OpenAI Codex credentials require login "
                f"({code or 'not logged in'})."
            )
            return "login"
        print(
            "ERROR: existing OpenAI Codex credentials could not be refreshed "
            f"({code or 'temporary auth error'}); refusing to replace them."
        )
        return "error"
    return "usable" if str(resolved.get("api_key", "") or "").strip() else "login"


def _retry_after(headers: dict[str, str]) -> int | None:
    raw = headers.get("Retry-After") or headers.get("retry-after")
    try:
        return max(1, min(int(raw), 60)) if raw is not None else None
    except (TypeError, ValueError):
        return None


def run_openai_codex_flow() -> int:
    try:
        client_id, token_url, save_tokens, resolve_credentials = _codex_native()
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: pinned Hermes image does not expose OpenAI Codex auth support: {exc}")
        return 2

    if not FORCE_RELOGIN:
        existing_state = _existing_codex_state(resolve_credentials)
        if existing_state == "usable":
            print("Existing OpenAI Codex credentials are usable - skipping device flow.")
            return 0
        if existing_state == "error":
            return 1
    if FORCE_RELOGIN:
        print("FORCE_RELOGIN=true - starting a fresh OpenAI Codex login.")
    if not _notification_ready():
        return 2

    usercode_url = f"{OPENAI_CODEX_ISSUER}/api/accounts/deviceauth/usercode"
    poll_url = f"{OPENAI_CODEX_ISSUER}/api/accounts/deviceauth/token"
    verification_url = f"{OPENAI_CODEX_ISSUER}/codex/device"

    print("Starting OpenAI Codex device flow ...")
    device_data: dict[str, Any] = {}
    for attempt in range(1, 5):
        try:
            status, device_data, headers = _post_json_status(
                usercode_url, {"client_id": client_id}
            )
        except Exception as exc:  # noqa: BLE001
            print(f"ERROR: failed to request OpenAI Codex device code: {exc}")
            return 1
        if status != 429:
            break
        if attempt == 4:
            print("ERROR: OpenAI rate-limited the device-code request (HTTP 429).")
            return 1
        delay = _retry_after(headers) or min(2**attempt, 60)
        print(f"  OpenAI rate-limited login; retrying in {delay}s ...")
        time.sleep(delay)

    if status != 200:
        print(f"ERROR: OpenAI device-code request returned HTTP {status}.")
        return 1

    user_code = str(device_data.get("user_code", "") or "")
    device_auth_id = str(device_data.get("device_auth_id", "") or "")
    interval = max(3, int(device_data.get("interval", 5)))
    if not user_code or not device_auth_id:
        print("ERROR: OpenAI device-code response was incomplete.")
        return 1

    print(f"  user_code={user_code}  verify={verification_url}")
    notify_post(
        f"OpenAI Codex login required{_for_label()}:\n"
        f"1. Open: {verification_url}\n"
        f"2. Enter code: {user_code}\n"
        "(valid for about 15 minutes; phone-friendly)"
    )
    print("  waiting for authorization ...")

    deadline = time.monotonic() + min(TIMEOUT, 15 * 60)
    exchange: dict[str, Any] | None = None
    while time.monotonic() < deadline:
        time.sleep(interval)
        try:
            poll_status, poll_data, _ = _post_json_status(
                poll_url,
                {"device_auth_id": device_auth_id, "user_code": user_code},
            )
        except Exception as exc:  # noqa: BLE001
            print(f"  poll error (will retry): {exc}")
            continue
        if poll_status == 200:
            exchange = poll_data
            break
        if poll_status in (403, 404):
            continue
        print(f"ERROR: OpenAI device auth polling returned HTTP {poll_status}.")
        return 1

    if exchange is None:
        print("ERROR: OpenAI Codex login timed out.")
        notify_post(f"OpenAI Codex login timed out{_for_label()}. The pod will retry.")
        return 1

    authorization_code = str(exchange.get("authorization_code", "") or "")
    code_verifier = str(exchange.get("code_verifier", "") or "")
    if not authorization_code or not code_verifier:
        print("ERROR: OpenAI authorization response was incomplete.")
        return 1

    try:
        token_status, tokens, _ = _post_form_status(
            os.getenv("OPENAI_CODEX_TOKEN_URL", "").strip() or token_url,
            {
                "grant_type": "authorization_code",
                "code": authorization_code,
                "redirect_uri": f"{OPENAI_CODEX_ISSUER}/deviceauth/callback",
                "client_id": client_id,
                "code_verifier": code_verifier,
            },
        )
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: OpenAI Codex token exchange failed: {exc}")
        return 1
    if token_status != 200:
        print(f"ERROR: OpenAI Codex token exchange returned HTTP {token_status}.")
        return 1

    access_token = str(tokens.get("access_token", "") or "")
    refresh_token = str(tokens.get("refresh_token", "") or "")
    if not access_token or not refresh_token:
        print("ERROR: OpenAI Codex token exchange did not return both token types.")
        return 1

    last_refresh = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    try:
        save_tokens(
            {"access_token": access_token, "refresh_token": refresh_token},
            last_refresh,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: Hermes could not persist OpenAI Codex credentials: {exc}")
        return 1

    auth_path = HERMES_HOME / "auth.json"
    if auth_path.exists():
        _chown(auth_path)
    print(f"  wrote OpenAI Codex credentials to {auth_path}")
    notify_post(f"OpenAI Codex login complete{_for_label()}. The agent is starting.")
    return 0


def check_native() -> int:
    """Check that this Hermes image still provides what the Codex login imports.

    The Codex flow borrows constants and a private persistence helper from
    ``hermes_cli.auth``. A Hermes release that renames or moves them would break
    the login for every user, and the unit tests mock the import. The chart's
    Helm test runs this mode so an image bump is caught in CI and by ``helm test``.
    """
    try:
        _codex_native()
    except Exception as exc:  # noqa: BLE001 - any import problem means the contract broke
        print(
            "FAIL: this Hermes image no longer provides the OpenAI Codex helpers "
            f"the device login imports from hermes_cli.auth ({type(exc).__name__}: {exc})"
        )
        return 1
    print("OK: hermes_cli.auth provides the OpenAI Codex helpers the device login imports.")
    return 0


def main() -> int:
    if "--check-native" in sys.argv[1:]:
        return check_native()
    if FLOW_KIND == "openai-codex":
        return run_openai_codex_flow()
    if FLOW_KIND not in ("github", "github-copilot"):
        print(f"ERROR: unsupported DEVICE_FLOW_KIND={FLOW_KIND!r}")
        return 2
    if not CLIENT_ID or not TOKEN_ENV:
        print("ERROR: OAUTH_CLIENT_ID and TOKEN_ENV are required for GitHub device flow.")
        return 2

    existing = read_env_token()
    if existing and not FORCE_RELOGIN and token_is_valid(existing):
        print(f"Existing {TOKEN_ENV} is present and valid - skipping device flow.")
        return 0
    if existing and FORCE_RELOGIN:
        print("FORCE_RELOGIN=true - ignoring existing token.")
    elif existing:
        print("Existing token is invalid - re-running device flow.")
    return run_github_device_flow()


if __name__ == "__main__":
    sys.exit(main())
