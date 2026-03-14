#!/usr/bin/env python3
"""
MCP Wrapper Server for Voipy with Browser Automation.

Calls the Jac Scale HTTP API (walker endpoints) and exposes them as MCP tools.
Includes Playwright-based browser automation for visible browser control.
Run after starting the Jac server: jac start main.jac --port 8080

Usage:
    export JAC_API_URL=http://localhost:8080   # optional, default 8080
    export MCP_PORT=8001                   # optional, default 8001
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
playwright_instance = None


# Global Playwright instance
async def get_playwright():
    global playwright_instance
    if playwright_instance is None:
        playwright_instance = await async_playwright().start()
    return playwright_instance


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


mcp = FastMCP("Voipy")


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
    """List all channels with member count and whether the current user is a member. Requires session auth."""
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


# ---- Browser Automation Tools ----
@mcp.tool()
async def browser_create_session(
    session_id: str = "default", headless: bool = False
) -> str:
    """Create a new visible browser session. Use headless=False for visually impressive demos."""
    try:
        pw = await get_playwright()
        browser = await pw.chromium.launch(
            headless=headless, args=["--start-maximized"]
        )
        context = await browser.new_context(
            viewport={"width": 1920, "height": 1080},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        )
        page = await context.new_page()

        browser_sessions[session_id] = {
            "browser": browser,
            "context": context,
            "page": page,
            "headless": headless,
        }

        return json.dumps(
            {
                "status": "success",
                "session_id": session_id,
                "headless": headless,
                "message": f"Browser session '{session_id}' created successfully",
            }
        )
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool()
async def browser_navigate(session_id: str = "default", url: str = "") -> str:
    """Navigate to a URL in the specified browser session."""
    if session_id not in browser_sessions:
        return json.dumps({"error": f"Session '{session_id}' not found"})

    try:
        page = browser_sessions[session_id]["page"]
        await page.goto(url, wait_until="networkidle", timeout=30000)

        return json.dumps(
            {
                "status": "success",
                "session_id": session_id,
                "url": url,
                "title": await page.title(),
            }
        )
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool()
async def browser_click(session_id: str = "default", selector: str = "") -> str:
    """Click an element matching the CSS selector."""
    if session_id not in browser_sessions:
        return json.dumps({"error": f"Session '{session_id}' not found"})

    try:
        page = browser_sessions[session_id]["page"]
        await page.click(selector, timeout=10000)

        return json.dumps(
            {
                "status": "success",
                "session_id": session_id,
                "selector": selector,
                "action": "clicked",
            }
        )
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool()
async def browser_type(
    session_id: str = "default", selector: str = "", text: str = ""
) -> str:
    """Type text into an input field matching the CSS selector."""
    if session_id not in browser_sessions:
        return json.dumps({"error": f"Session '{session_id}' not found"})

    try:
        page = browser_sessions[session_id]["page"]
        await page.fill(selector, text)

        return json.dumps(
            {
                "status": "success",
                "session_id": session_id,
                "selector": selector,
                "text": text,
            }
        )
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool()
async def browser_screenshot(
    session_id: str = "default", full_page: bool = False
) -> str:
    """Take a screenshot and return as base64-encoded string."""
    if session_id not in browser_sessions:
        return json.dumps({"error": f"Session '{session_id}' not found"})

    try:
        page = browser_sessions[session_id]["page"]
        screenshot_bytes = await page.screenshot(full_page=full_page)
        screenshot_base64 = base64.b64encode(screenshot_bytes).decode("utf-8")

        return json.dumps(
            {
                "status": "success",
                "session_id": session_id,
                "screenshot": f"data:image/png;base64,{screenshot_base64}",
                "size": len(screenshot_bytes),
            }
        )
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool()
async def browser_extract_text(session_id: str = "default", selector: str = "") -> str:
    """Extract text from the page or a specific element."""
    if session_id not in browser_sessions:
        return json.dumps({"error": f"Session '{session_id}' not found"})

    try:
        page = browser_sessions[session_id]["page"]

        if selector:
            text = await page.inner_text(selector)
            element_info = {
                "selector": selector,
                "text": text,
                "element_count": await page.locator(selector).count(),
            }
        else:
            text = await page.inner_text("body")
            element_info = {
                "selector": "body",
                "text": text,
                "title": await page.title(),
                "url": page.url,
            }

        return json.dumps(
            {"status": "success", "session_id": session_id, **element_info}
        )
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool()
async def browser_wait_for(
    session_id: str = "default", selector: str = "", timeout: int = 5000
) -> str:
    """Wait for an element to appear on the page."""
    if session_id not in browser_sessions:
        return json.dumps({"error": f"Session '{session_id}' not found"})

    try:
        page = browser_sessions[session_id]["page"]
        await page.wait_for_selector(selector, timeout=timeout)

        return json.dumps(
            {
                "status": "success",
                "session_id": session_id,
                "selector": selector,
                "found": True,
            }
        )
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool()
async def browser_evaluate(session_id: str = "default", js_code: str = "") -> str:
    """Execute JavaScript and return the result."""
    if session_id not in browser_sessions:
        return json.dumps({"error": f"Session '{session_id}' not found"})

    try:
        page = browser_sessions[session_id]["page"]
        result = await page.evaluate(js_code)

        return json.dumps(
            {"status": "success", "session_id": session_id, "result": result}
        )
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool()
async def browser_get_url(session_id: str = "default") -> str:
    """Get the current URL of the browser session."""
    if session_id not in browser_sessions:
        return json.dumps({"error": f"Session '{session_id}' not found"})

    try:
        page = browser_sessions[session_id]["page"]
        url = page.url

        return json.dumps(
            {
                "status": "success",
                "session_id": session_id,
                "url": url,
                "title": await page.title(),
            }
        )
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool()
async def browser_list_sessions() -> str:
    """List all active browser sessions."""
    return json.dumps(
        {
            "status": "success",
            "sessions": [
                {
                    "session_id": sid,
                    "headless": sess["headless"],
                    "url": sess["page"].url,
                }
                for sid, sess in browser_sessions.items()
            ],
        }
    )


@mcp.tool()
async def browser_close_session(session_id: str = "default") -> str:
    """Close a specific browser session."""
    if session_id not in browser_sessions:
        return json.dumps({"error": f"Session '{session_id}' not found"})

    try:
        session = browser_sessions[session_id]
        await session["page"].close()
        await session["context"].close()
        await session["browser"].close()

        del browser_sessions[session_id]

        return json.dumps(
            {
                "status": "success",
                "session_id": session_id,
                "message": f"Session '{session_id}' closed successfully",
            }
        )
    except Exception as e:
        return json.dumps({"error": str(e)})


@mcp.tool()
async def browser_close_all() -> str:
    """Close all browser sessions."""
    closed_count = 0
    errors = []

    for session_id in list(browser_sessions.keys()):
        try:
            session = browser_sessions[session_id]
            await session["page"].close()
            await session["context"].close()
            await session["browser"].close()
            del browser_sessions[session_id]
            closed_count += 1
        except Exception as e:
            errors.append(f"{session_id}: {str(e)}")

    return json.dumps(
        {"status": "success", "closed_count": closed_count, "errors": errors}
    )


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
    import sys

    port = int(os.environ.get("MCP_PORT", "8001"))

    if len(sys.argv) > 1 and "--port" in sys.argv:
        port_idx = sys.argv.index("--port")
        if port_idx + 1 < len(sys.argv):
            port = int(sys.argv[port_idx + 1])

    print(f"Starting MCP server on port {port}...")
    mcp.run(transport="streamable-http")
