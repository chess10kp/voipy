# VoiceAgent — Product Requirements Document
**Voice-Driven Browser Automation Agent | MVP | Hackathon Draft | March 2026**

---

## 1. Overview

VoiceAgent is a voice-driven browser automation agent that lets users accomplish multi-step web tasks through a natural WhatsApp voice conversation. The user speaks a request, an LLM interprets the intent, Playwright executes browser actions, and the results are spoken back — all without the user ever touching a browser.

The key differentiator is not single-lookup capability, but **chained, stateful workflows** where each action depends on the result of the previous one. For example: searching for flights, cross-referencing hotel availability at the destination, and summarizing options — all from a single spoken request.

---

## 2. Problem Statement

Existing voice assistants (Siri, Google Assistant) handle simple factual queries but fail at multi-step web tasks that require navigating real websites, filling forms, and synthesizing results across sources. Users without reliable hands-on device access — or who simply prefer voice — have no tool capable of executing these workflows on their behalf.

---

## 3. Goals & Non-Goals

### MVP Goals
- Accept a voice request via WhatsApp using the 11Labs integration
- Transcribe speech to text and pass intent to an LLM agent
- LLM decomposes request into a sequence of Playwright browser actions
- Playwright executes actions and returns structured results
- LLM synthesizes results into a natural language response
- Response is spoken back to the user via 11Labs TTS on WhatsApp
- Support at least one focused multi-step vertical for the demo

### Non-Goals (MVP)
- Account login or authenticated sessions on third-party sites
- CAPTCHA solving
- Persistent memory across separate WhatsApp conversations
- Mobile app or web dashboard
- Multi-user support or auth

---

## 4. System Architecture

### High-Level Flow

```
WhatsApp Voice → 11Labs STT → Web Server → LLM Agent ⟷ Playwright MCP
                                                ↓
                            11Labs TTS → WhatsApp Voice
```

The LLM is not called once — it runs in a **ReAct-style loop**, receiving tool results and deciding the next action until the workflow is complete.

### Step-by-Step

1. User sends a WhatsApp voice message
2. 11Labs WhatsApp integration transcribes speech to text (STT)
3. Transcribed text is sent to the web server as a webhook payload
4. Web server passes text to the LLM agent with conversation history and system prompt
5. LLM decides the next Playwright action and calls the appropriate MCP tool
6. Playwright MCP executes the browser action and returns a result
7. LLM receives the result and either calls the next tool or produces a final answer
8. Final answer is sent to 11Labs TTS and returned as a voice message on WhatsApp

### Component Breakdown

| Component | Technology | Responsibility |
|---|---|---|
| Voice I/O | 11Labs WhatsApp Integration | STT inbound, TTS outbound via WhatsApp |
| Web Server | Node.js / Python (TBD) | Webhook receiver, orchestration layer |
| LLM Agent | TBD (Claude / GPT-4o) | Intent parsing, tool selection, response synthesis |
| Browser Automation | Playwright MCP | Website navigation, search, data extraction |
| State Store | In-memory / Redis | Conversation history, workflow state per session |

### Agent Loop Detail

- Receive user message + conversation history
- Reason about what action to take next
- Call a Playwright MCP tool (navigate, click, extract, search, etc.)
- Receive tool result
- Repeat until enough information is gathered
- Synthesize a final natural language answer
- Return answer to the voice layer

---

## 5. MVP Demo Vertical

### Travel Planning Assistant

This vertical is chosen because it naturally requires multi-step chaining where each step depends on the previous result.

**Example Workflow:**

1. User asks: *"Find me flights from New York to London next Friday under $800"*
2. Agent navigates to a flight search site and queries the route and date
3. Agent extracts the top 3 options with prices, airlines, and durations
4. Agent cross-references hotel availability in London for the same dates
5. Agent summarizes: best flight option + estimated hotel range
6. User hears a spoken summary and can ask follow-up questions

**Why this works for a demo:**
- 3–4 distinct browser actions in a single workflow
- Clear dependency chain — hotel search depends on flight dates found in step 2
- Result is immediately tangible and useful to any audience
- Follow-up questions ("What about Sunday instead?") test stateful memory

---

## 6. State & Memory Management

Each WhatsApp session maintains a conversation context object containing:
- Full message history (user + agent turns)
- Current workflow stage and intermediate results
- Entities extracted so far (destinations, dates, constraints)

For MVP, state is held **in-memory keyed by WhatsApp sender ID**. It persists for the duration of a session and is cleared after a configurable inactivity timeout (e.g., 30 minutes).

---

## 7. Error Handling & Edge Cases

| Scenario | Handling Strategy |
|---|---|
| Site unreachable / timeout | Agent informs user and suggests an alternative source |
| Ambiguous user request | Agent asks a clarifying question before acting |
| Workflow takes > 15 seconds | Agent sends interim audio: "Still working on it..." |
| No results found | Agent reports back clearly and offers to retry with different parameters |
| CAPTCHA encountered | Agent stops, informs user, suggests manual fallback |
| LLM tool call loop exceeds limit | Hard cap at 10 tool calls; agent summarises what it found so far |

---

## 8. Technical Constraints & Risks

**Latency** — Each Playwright action adds 2–5 seconds. A 3-step workflow could take 10–20 seconds end-to-end. Interim audio feedback is essential to prevent the user from thinking the call dropped.

**Site Variability** — Public websites change their DOM structure frequently. For the demo, target 2–3 known stable sites and test them the morning of demo day.

**11Labs Webhook Reliability** — The server must be publicly reachable (ngrok or a deployed instance). Do not rely on localhost for the demo.

**LLM Model Choice** — The model needs strong tool-use capabilities and low latency. Claude 3.5 Sonnet or GPT-4o are the recommended candidates. Avoid reasoning models (o1 etc.) due to added latency in a real-time voice context.

---

## 9. MVP Milestones

| Milestone | Description | Priority |
|---|---|---|
| M1: Voice Loop | WhatsApp voice in → STT → text out, TTS → voice back. No agent. | P0 |
| M2: Single Action | LLM receives text, calls one Playwright action, returns result. | P0 |
| M3: Chained Workflow | LLM runs multi-step loop across 2+ Playwright actions. | P0 |
| M4: State & Follow-ups | Conversation history retained; follow-up questions work. | P1 |
| M5: Interim Feedback | Agent sends audio updates during long-running workflows. | P1 |
| M6: Demo Polish | Error handling, stable selectors, fallback messages. | P1 |

---

## 10. Out of Scope for MVP

- User authentication or login on third-party sites
- Persistent cross-session memory
- Web UI or dashboard
- Multi-user or team features
- Handling paywalled or subscription-gated content
- Mobile app

---

## 11. Open Questions

- **LLM model:** Claude vs GPT-4o — benchmark latency before committing
- **Playwright MCP:** use the official `@playwright/mcp` server or build a custom one with targeted tools?
- **Web server language:** Node.js keeps the stack JS-native with Playwright; Python offers more LLM tooling
- **Deployment for demo day:** Railway / Render / Fly.io vs ngrok tunnel?
- **11Labs webhook format:** confirm the exact payload shape before building the server

---

*VoiceAgent MVP PRD — Hackathon Draft — March 2026*


## **Running LittleX on Local Environment**

**Prerequisites:** Python 3, Node.js, and [Jaseci](https://github.com/Jaseci-Labs/jaseci) (`pip install jaclang` and `jac serve` available).

### 1. Get the code

Either clone the LittleX repo:

```bash
git clone https://github.com/Jaseci-Labs/littleX.git
cd littlex
```

Or use the `littleX` folder from a parent repository (e.g. from repo root):

```bash
cd /path/to/parent-repo   # e.g. voipy
# All paths below use littleX/... when inside a parent repo
```

### 2. Install dependencies

From the **LittleX repo root** (or from the parent repo root, using `littleX/` prefixes):

```bash
pip install -r littleX_BE/requirements.txt
```

If LittleX is inside another repo:

```bash
pip install -r littleX/littleX_BE/requirements.txt
```

### 3. (Optional) Backend environment

For cloud/LLM features, set your API key:

```bash
cp littleX_BE/.env.example littleX_BE/.env
# Edit .env and set GEMINI_API_KEY (or other keys) as needed
```

If LittleX is inside another repo, use `littleX/littleX_BE/.env.example` and `littleX/littleX_BE/.env`.

### 4. Start the backend server

In one terminal, from the repo root:

```bash
jac serve littleX_BE/littleX.jac
```

If LittleX is inside another repo:

```bash
jac serve littleX/littleX_BE/littleX.jac
```

Keep this terminal open. Note the URL (e.g. `http://localhost:8000`).

### 5. Run the frontend

In a **second terminal**, from the repo root:

```bash
cd littleX_FE
npm i
npm run dev
```

If LittleX is inside another repo:

```bash
cd littleX/littleX_FE
npm i
npm run dev
```

Open the URL shown (e.g. `http://localhost:3000`). Use the app with the backend running in the other terminal.

### If the frontend (`littleX_FE`) is missing

If `littleX_FE` is empty or only has a `.next` folder, restore it from the upstream repo:

```bash
git clone --depth 1 https://github.com/Jaseci-Labs/littleX.git /tmp/littleX-upstream
rsync -a --exclude='.next' --exclude='node_modules' /tmp/littleX-upstream/littleX_FE/ littleX/littleX_FE/
```

Then run `npm i` and `npm run dev` from `littleX_FE` as in step 5.
