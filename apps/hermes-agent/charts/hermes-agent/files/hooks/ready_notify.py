"""Post one line to Discord or Telegram when the Hermes gateway has started.

The chart seeds this file as a ``gateway:startup`` hook (see
``readyNotify`` in values.yaml). It runs inside the gateway process, so the
bot credentials are already in the environment: ``DISCORD_BOT_TOKEN`` with
``DISCORD_HOME_CHANNEL``, or ``TELEGRAM_BOT_TOKEN`` with
``TELEGRAM_HOME_CHANNEL``. ``READY_NOTIFY`` picks the channel and
``READY_NOTIFY_LABEL`` names the release. Without ``READY_NOTIFY`` the hook does
nothing. Tokens are never logged: the Telegram token is part of the request URL,
so failures log the error class only.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import urllib.error
import urllib.request

logger = logging.getLogger("hooks.ready-notify")

TELEGRAM_API = "https://api.telegram.org"
DISCORD_API = "https://discord.com/api/v10"


def build_message(label: str, platforms: list[str]) -> str:
    who = label or "The agent"
    where = f" and is connected to {', '.join(platforms)}" if platforms else ""
    return f"{who} is ready{where}. It will answer messages now."


def _request(channel: str, text: str) -> urllib.request.Request | None:
    if channel == "telegram":
        token = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
        chat = os.getenv("TELEGRAM_HOME_CHANNEL", "").strip()
        if not (token and chat):
            logger.warning("telegram bot token / home channel not set - skipping")
            return None
        return urllib.request.Request(
            f"{TELEGRAM_API}/bot{token}/sendMessage",
            data=json.dumps({"chat_id": chat, "text": text}).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
    if channel == "discord":
        token = os.getenv("DISCORD_BOT_TOKEN", "").strip()
        chat = os.getenv("DISCORD_HOME_CHANNEL", "").strip()
        if not (token and chat):
            logger.warning("discord bot token / home channel not set - skipping")
            return None
        return urllib.request.Request(
            f"{DISCORD_API}/channels/{chat}/messages",
            data=json.dumps({"content": text}).encode(),
            headers={
                "Authorization": f"Bot {token}",
                "Content-Type": "application/json",
                "User-Agent": "hermes-ready-notify/1.0",
            },
            method="POST",
        )
    logger.warning("unknown READY_NOTIFY channel %r - skipping", channel)
    return None


def send(channel: str, text: str) -> bool:
    """Best-effort delivery. Returns True when the platform accepted the message."""
    request = _request(channel, text)
    if request is None:
        return False
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            logger.info("posted ready message to %s (HTTP %s)", channel, response.status)
            return True
    except urllib.error.HTTPError as exc:
        logger.warning("ready message to %s FAILED HTTP %s", channel, exc.code)
    except Exception as exc:  # noqa: BLE001
        logger.warning("ready message to %s FAILED: %s", channel, type(exc).__name__)
    return False


async def handle(event_type: str, context: dict) -> None:
    channel = os.getenv("READY_NOTIFY", "").strip().lower()
    if not channel:
        return
    label = os.getenv("READY_NOTIFY_LABEL", "").strip()
    platforms = [str(p) for p in ((context or {}).get("platforms") or [])]
    # urllib blocks, so keep it off the gateway's event loop.
    await asyncio.to_thread(send, channel, build_message(label, platforms))
