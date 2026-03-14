#!/usr/bin/env python3
"""
MCP Wrapper Server for Voipy.

Calls the Jac Scale HTTP API (walker endpoints) and exposes them as MCP tools.
Run after starting the Jac server: jac start main.jac --port 8080

Usage:
    export JAC_API_URL=http://localhost:8080   # optional, default 8080
    python mcp_wrapper.py

MCP endpoint: streamable HTTP on port 8001 (or use --port).
"""

import json
import os
import asyncio
from typing import Any, Optional, List
import base64

import httpx
from mcp.server.fastmcp import FastMCP
from playwright.async_api import async_playwright, Browser, Page, BrowserContext

JAC_API_URL = os.environ.get("JAC_API_URL", "http://localhost:8080").rstrip("/")

# Browser session management
browser_sessions = {}  # Maps session_id -> {"browser": Browser, "context": BrowserContext, "page": Page, "headless": bool}


def _call_walker(walker_name: str, **payload: Any) -> str:
    """POST to Jac walker endpoint and return response as JSON string."""
    url = f"{JAC_API_URL}/walker/{walker_name}"
    try:
        r = httpx.post(url, json=payload, timeout=30.0)
        r.raise_for_status()
        data = r.json()
        return json.dumps(data, indent=2)
    except httpx.HTTPStatusError as e:
        return json.dumps({"error": str(e), "response": e.response.text})
    except Exception as e:
        return json.dumps({"error": str(e)})


mcp = FastMCP(
    "Voipy",
    description="Voipy social app – MCP tools that call the Jac Scale HTTP API (profiles, feed, channels, chat).",
)


# ---- Profiles ----
@mcp.tool()
def get_all_profiles() -> str:
    """List all user profiles (id, username, bio). Requires no auth for :pub walker."""
    return _call_walker("get_all_profiles")


@mcp.tool()
def get_profile() -> str:
    """Get the current user's profile (username, bio, followers, following, tweets). Requires session auth."""
    return _call_walker("get_profile")


@mcp.tool()
def setup_profile(username: str = "", bio: str = "") -> str:
    """Create or update the current user's profile. Requires session auth."""
    return _call_walker("setup_profile", username=username, bio=bio)


@mcp.tool()
def follow_user(target_id: str) -> str:
    """Follow another user by their profile id. Requires session auth."""
    return _call_walker("follow_user", target_id=target_id)


@mcp.tool()
def unfollow_user(target_id: str) -> str:
    """Unfollow a user by their profile id. Requires session auth."""
    return _call_walker("unfollow_user", target_id=target_id)


# ---- Feed & tweets ----
@mcp.tool()
def load_feed(search_query: str = "") -> str:
    """Load the current user's feed (own tweets + from followed users). Optional search_query to filter. Requires session auth."""
    return _call_walker("load_feed", search_query=search_query)


@mcp.tool()
def get_trending() -> str:
    """Get top 8 trending hashtags and counts. No auth required."""
    return _call_walker("get_trending")


@mcp.tool()
def create_tweet(content: str) -> str:
    """Post a new tweet. Requires session auth."""
    return _call_walker("create_tweet", content=content)


@mcp.tool()
def delete_tweet(tweet_id: str) -> str:
    """Delete a tweet by id. Requires session auth; must own the tweet."""
    return _call_walker("delete_tweet", tweet_id=tweet_id)


@mcp.tool()
def like_tweet(tweet_id: str) -> str:
    """Like or unlike a tweet. Requires session auth."""
    return _call_walker("like_tweet", tweet_id=tweet_id)


@mcp.tool()
def add_comment(tweet_id: str, content: str) -> str:
    """Add a comment to a tweet. Requires session auth."""
    return _call_walker("add_comment", tweet_id=tweet_id, content=content)


# ---- Channels ----
@mcp.tool()
def get_channels() -> str:
    """List all channels with member count and whether current user is a member. Requires session auth."""
    return _call_walker("get_channels")


@mcp.tool()
def get_channel_detail(channel_id: str) -> str:
    """Get a channel's details and posts. Requires session auth."""
    return _call_walker("get_channel_detail", channel_id=channel_id)


@mcp.tool()
def create_channel(name: str, description: str = "") -> str:
    """Create a new channel. Requires session auth."""
    return _call_walker("create_channel", name=name, description=description)


@mcp.tool()
def join_channel(channel_id: str) -> str:
    """Join a channel by id. Requires session auth."""
    return _call_walker("join_channel", channel_id=channel_id)


@mcp.tool()
def leave_channel(channel_id: str) -> str:
    """Leave a channel. Requires session auth."""
    return _call_walker("leave_channel", channel_id=channel_id)


@mcp.tool()
def create_channel_tweet(channel_id: str, content: str) -> str:
    """Post a tweet to a channel. Requires session auth and channel membership."""
    return _call_walker("create_channel_tweet", channel_id=channel_id, content=content)


# ---- Chat ----
@mcp.tool()
def get_chat_messages() -> str:
    """Get the current user's chat messages. Requires session auth."""
    return _call_walker("get_chat_messages")


@mcp.tool()
def chat_message(content: str) -> str:
    """Send a chat message and get the assistant reply. Requires session auth."""
    return _call_walker("chat_message", content=content)


# ---- Meta ----
@mcp.tool()
def ping() -> str:
    """Check that the MCP wrapper and Jac API are reachable."""
    try:
        r = httpx.get(f"{JAC_API_URL}/", timeout=5.0)
        return json.dumps(
            {"mcp": "ok", "jac_url": JAC_API_URL, "jac_status": r.status_code}
        )
    except Exception as e:
        return json.dumps({"mcp": "ok", "jac_url": JAC_API_URL, "jac_error": str(e)})


if __name__ == "__main__":
    port = int(os.environ.get("MCP_PORT", "8001"))
    mcp.run(transport="streamable-http", host="0.0.0.0", port=port)
