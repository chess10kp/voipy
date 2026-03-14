#!/usr/bin/env python3
"""
Test script for Voipy Browser Automation

Tests the MCP wrapper server's browser tools.
Run this after starting both Jac server and MCP wrapper.
"""

import json
import time
import httpx

MCP_PORT = "8001"
MCP_BASE_URL = f"http://localhost:{MCP_PORT}/tools"

print("=" * 60)
print("Voipy Browser Automation Test Suite")
print("=" * 60)
print()


def call_tool(tool_name: str, params: dict) -> dict:
    """Call an MCP tool and return the response."""
    url = f"{MCP_BASE_URL}/{tool_name}"
    print(f"\n→ Calling: {tool_name}")
    print(f"  Params: {json.dumps(params, indent=2)}")

    try:
        response = httpx.post(url, json=params, timeout=30.0)
        response.raise_for_status()
        result = response.json()
        print(f"  ✓ Success")
        return result
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return {"error": str(e)}


print("[Test 1/7] Create Browser Session")
print("-" * 40)
result = call_tool(
    "browser_create_session", {"session_id": "test_session", "headless": False}
)
if "error" in result:
    print(f"  ✗ Failed to create session: {result['error']}")
    exit(1)

print(f"\n  Status: {result.get('status', 'unknown')}")
print(f"  Session ID: {result.get('session_id', 'unknown')}")
print(f"  Headless: {result.get('headless', 'unknown')}")
time.sleep(2)

print("\n[Test 2/7] Navigate to Example.com")
print("-" * 40)
result = call_tool(
    "browser_navigate", {"session_id": "test_session", "url": "https://example.com"}
)
if "error" in result:
    print(f"  ✗ Failed to navigate: {result['error']}")
else:
    print(f"  URL: {result.get('url', 'unknown')}")
    print(f"  Title: {result.get('title', 'unknown')}")

time.sleep(2)

print("\n[Test 3/7] Extract Page Text")
print("-" * 40)
result = call_tool(
    "browser_extract_text", {"session_id": "test_session", "selector": ""}
)
if "error" not in result:
    text = result.get("text", "")
    print(f"  Text length: {len(text)} characters")
    print(f"  Preview: {text[:100]}...")
    print(f"  Page Title: {result.get('title', 'unknown')}")

print("\n[Test 4/7] Get Current URL")
print("-" * 40)
result = call_tool("browser_get_url", {"session_id": "test_session"})
if "error" not in result:
    print(f"  URL: {result.get('url', 'unknown')}")
    print(f"  Title: {result.get('title', 'unknown')}")

print("\n[Test 5/7] Take Screenshot")
print("-" * 40)
result = call_tool(
    "browser_screenshot", {"session_id": "test_session", "full_page": False}
)
if "error" not in result:
    print(f"  Screenshot size: {result.get('size', 0)} bytes")
    print(f"  Data URL length: {len(result.get('screenshot', ''))} characters")
    print("  ✓ Screenshot captured successfully!")

time.sleep(1)

print("\n[Test 6/7] List Active Sessions")
print("-" * 40)
result = call_tool("browser_list_sessions", {})
if "error" not in result:
    sessions = result.get("sessions", [])
    print(f"  Active sessions: {len(sessions)}")
    for session in sessions:
        print(f"    - {session['session_id']}: {session['url'] or 'No URL'}")

print("\n[Test 7/7] Close Browser Session")
print("-" * 40)
result = call_tool("browser_close_session", {"session_id": "test_session"})
if "error" not in result:
    print(f"  ✓ Session closed: {result.get('message', 'unknown')}")

print("\n" + "=" * 60)
print("Test Suite Complete!")
print("=" * 60)

print("\nNext Steps:")
print("1. Open http://localhost:8080 in your browser")
print("2. Log in to Voipy")
print("3. Click the '🌐 Browser' button")
print("4. Open a browser session")
print("5. Navigate to any website")
print("6. Interact with the page")
print("7. Take screenshots to show results!")
print("\nFor more information, see BROWSER_AUTOMATION.md")
