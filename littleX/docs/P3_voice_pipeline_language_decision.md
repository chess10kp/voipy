# P3: Web Server Language for Voice Pipeline — Decision

**Task:** Choose web server language for voice pipeline (Node.js vs Python).  
**Status:** Decided — **Python**

---

## Context

The voice pipeline is a **new orchestration service** that will:

- Expose a **public webhook** for 11Labs/WhatsApp inbound payloads
- Call **11Labs STT** (and optionally TTS) and **LLM** (Claude or GPT-4o)
- Act as **tool executor**: send LLM tool calls to the existing MCP server (`mcp_wrapper.py`) over HTTP (e.g. `http://localhost:8001`)
- Run a **ReAct loop**, **session store**, and **interim TTS**

Existing stack:

- **Jaseci (Jac)** at 8080 — app/walkers
- **Python** `mcp_wrapper.py` (FastMCP, Playwright) at 8001 — browser MCP tools
- **call.jac** uses **Python** `elevenlabs` client for STT (local recording → S3)

The orchestration service is separate from Jac; it only needs to call MCP over HTTP, so **either Node or Python can talk to the MCP server**.

---

## Comparison

| Criterion | Node.js | Python |
|-----------|---------|--------|
| **11Labs** | Official `@elevenlabs/elevenlabs-js` | Official `elevenlabs` (already in `jac.toml`, used in `call.jac`) |
| **LLM (Claude / OpenAI)** | Official SDKs (e.g. `@anthropic-ai/sdk`, `openai`) | Official SDKs (`anthropic`, `openai`) |
| **Webhooks / async** | Native async I/O; Express/Fastify | `asyncio` + FastAPI/Starlette — mature and sufficient |
| **MCP integration** | HTTP client to `localhost:8001` | HTTP client (e.g. `httpx`) to `localhost:8001` — same as `mcp_wrapper.py` |
| **Consistency with repo** | MCP and STT usage are Python | **Single language** for backend: MCP, Jac deps, and voice pipeline |
| **Reuse** | Cannot reuse `call.jac` / ElevenLabs pattern directly | Can mirror or share patterns with `call.jac` and `mcp_wrapper.py` |
| **Deployment** | Railway, Render, Fly.io support Node | Railway, Render, Fly.io support Python |

Both options are technically viable. The main differentiator is **consistency and reuse** in this repo.

---

## Decision: **Python**

**Reasons:**

1. **Single backend language** — MCP wrapper, Jac dependencies, and existing 11Labs usage are already Python. Keeping the voice orchestration in Python avoids a second runtime and mental context switch.
2. **Reuse and patterns** — STT pattern from `call.jac` (and the `elevenlabs` client) can be mirrored or refactored into the orchestration service; same ecosystem (httpx, asyncio, FastMCP-style tool calls).
3. **MCP is HTTP** — The orchestration service only needs to POST to MCP tool endpoints; no need for Node to “match” MCP. Python is already the language of the MCP server.
4. **Ecosystem** — FastAPI (or Starlette) gives async webhooks, clear docs, and easy deployment; Anthropic and OpenAI Python SDKs are first-class.

**Implementation outline for M1:**

- New **Python** service (e.g. `voice_pipeline/` or under `littleX_FULLSTACK/`): FastAPI (or similar) app, config (env), single public webhook route.
- Use `httpx` for async HTTP to 11Labs and to MCP (`http://localhost:8001`).
- Use official `elevenlabs` Python package for STT (and TTS) in the pipeline, consistent with `call.jac`.

---

## What we’re not choosing

- **Node.js** — No strong reason to introduce it here; Python covers all requirements and aligns with the rest of the backend.
- **Jac as the webhook server** — The task list and Implementation Gaps doc already recommend a dedicated Node or Python service for the voice pipeline; Jac remains for the app/walkers.

---

## Next steps

- **P1:** Confirm 11Labs webhook payload shape (unchanged).
- **M1.1:** Create the **Python** voice orchestration service (scaffold, config, public webhook endpoint) per this decision.
