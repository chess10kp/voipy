# VoiceAgent MVP — Webhook Payload Reference (P1)

This document confirms the webhook payload shape(s), audio formats, and metadata for the VoiceAgent voice pipeline so M1.1–M1.2 can implement the webhook endpoint and handler against a known spec. It covers WhatsApp Cloud API (inbound audio) and 11Labs (post-call and custom LLM semantics).

---

## 1. Recommended integration path for M1

**Use Path A: WhatsApp Cloud API as the webhook source for inbound voice.**

- **Who sends to our webhook:** Meta (WhatsApp Cloud API) when a user sends an audio/voice message to our business number.
- **What we receive:** Raw audio message payload (`audio.id` / `audio.url`, `mime_type`, sender `from`, etc.). Our server downloads the media, calls 11Labs STT, then runs the rest of the pipeline (LLM, tools, TTS) and sends voice back via WhatsApp Cloud API.
- **11Labs role:** STT and TTS APIs only. We do **not** use an 11Labs “voice webhook” for inbound audio; 11Labs is not in the middle for the real-time loop.

If we used **Path B** (11Labs in the middle), we would receive **text** via Custom LLM (OpenAI-style) requests, not audio—see section 3.

---

## 2. WhatsApp Cloud API — Inbound audio message payload

**Source:** [WhatsApp Cloud API – Audio messages webhook reference](https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks/reference/messages/audio/)

### Top-level structure

| Field   | Type   | Description |
|--------|--------|-------------|
| `object` | string | `"whatsapp_business_account"` |
| `entry`  | array  | One or more entries (WABA / phone number scope) |

### Per entry

| Path | Type | Description |
|------|------|-------------|
| `entry[].id` | string | WhatsApp Business Account ID |
| `entry[].changes` | array | List of changes (e.g. `field` = `"messages"`) |
| `entry[].changes[].field` | string | `"messages"` for message events |
| `entry[].changes[].value` | object | Payload for this change (see below) |

### `value` (when `field` is `"messages"`)

| Path | Type | Description |
|------|------|-------------|
| `value.metadata.phone_number_id` | string | Business phone number ID |
| `value.contacts` | array | Optional; items have `wa_id`, `profile.name` |
| `value.messages` | array | One item per incoming message |

### Audio message in `value.messages[]`

| Path | Type | Description |
|------|------|-------------|
| `from` | string | **WhatsApp user ID (sender).** Use for session keying (M4). |
| `id` | string | Message ID |
| `timestamp` | string | Unix timestamp (string) |
| `type` | string | `"audio"` for audio/voice messages |
| `audio` | object | Media and metadata (see below) |

### `audio` object

| Field | Type | Description |
|-------|------|-------------|
| `mime_type` | string | e.g. `"audio/ogg; codecs=opus"` for voice notes |
| `sha256` | string | Hash of the media asset |
| `id` | string | **Media ID** — use with Media API if `url` is absent or expired |
| `url` | string | Optional — lookaside download URL (may be present in webhook) |
| `voice` | boolean | `true` for voice note, `false` for other audio |

### Retrieving the audio file

- **If `audio.url` is present:** Send `GET {audio.url}` with header `Authorization: Bearer <ACCESS_TOKEN>` to download the file.
- **If only `audio.id` is present:** Call `GET https://graph.facebook.com/v21.0/{audio.id}` with `Authorization: Bearer <ACCESS_TOKEN>` to get a temporary URL, then GET that URL with the same token to download.

All media access requires a valid WhatsApp Cloud API access token.

### Example (minimal)

```json
{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "102290129340398",
      "changes": [
        {
          "value": {
            "metadata": { "phone_number_id": "106540352242922" },
            "contacts": [{ "wa_id": "16505551234" }],
            "messages": [
              {
                "from": "16505551234",
                "id": "wamid.xxx",
                "timestamp": "1744344496",
                "type": "audio",
                "audio": {
                  "mime_type": "audio/ogg; codecs=opus",
                  "sha256": "wvqXMe6n7n1W0zphvLPoLj+s/NtKqmr3zZ7YzTP7xFI=",
                  "id": "1908647269898587",
                  "url": "https://lookaside.fbsbx.com/whatsapp_business/attachments/?mid=...",
                  "voice": true
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}
```

---

## 3. 11Labs “webhook” semantics (no inbound audio from 11Labs)

### Post-call webhooks

- 11Labs sends POST requests to a configured URL **after** a conversation ends (e.g. `post_call_transcription`).
- Use case: analytics, CRM, follow-up. **Not** for the real-time voice loop (user spoke → run pipeline).
- For M1, post-call webhooks do **not** replace the need for an inbound audio endpoint; we use WhatsApp Cloud API (Path A) for that.
- If we use post-call webhooks later, confirm the exact JSON schema and event types from the ElevenLabs docs or dashboard (e.g. post-call webhooks in Conversational AI / Agents platform).

### Custom LLM (11Labs → our server)

When 11Labs Conversational AI is configured with a **custom LLM** (our backend URL):

- 11Labs sends **OpenAI-compatible** HTTP requests to our server: **Chat Completions** (`/v1/chat/completions`) or **Responses** (`/v1/responses`).
- We receive **text** (user/assistant messages in the request body), **not** raw audio; 11Labs performs STT before calling us.
- We must respond with **Server-Sent Events** (`Content-Type: text/event-stream`), e.g. `data: {json}\n\n` and end with `data: [DONE]\n\n`.

So the “11Labs webhook payload” for “user just spoke” is **not** an audio payload — it is an **OpenAI-style Chat Completions / Responses request**. For inbound **audio** in the MVP, the only payload we rely on is **WhatsApp’s** (section 2).

---

## 4. Audio formats for the pipeline

### Inbound (WhatsApp → our webhook)

- **Voice messages:** Typically **OGG with Opus** — `audio/ogg; codecs=opus` (see `audio.mime_type` in the payload).
- Other audio types may have different `mime_type` values.

### 11Labs STT (our server → 11Labs)

- 11Labs Speech-to-Text supports **OGG and Opus** among other formats (MP3, WAV, M4A, FLAC, WebM, AAC, AIFF).
- **No conversion needed** for WhatsApp voice: we can pass the downloaded OGG/Opus bytes (or file) to 11Labs STT (e.g. `scribe_v2` as in [call.jac](littleX_FULLSTACK/call.jac)).
- Reference: [What audio formats do you support? – ElevenLabs](https://help.elevenlabs.io/hc/en-us/articles/15754340124305-What-audio-formats-do-you-support)

### 11Labs TTS → WhatsApp (outbound)

- 11Labs TTS output format is configurable (e.g. MP3).
- WhatsApp Cloud API **sending** audio supports: **MP3** (audio/mpeg), **OGG** (audio/ogg with Opus), **AAC**, **AMR**, **MP4 audio** (m4a). Max size 16 MB.
- Using **MP3** from 11Labs TTS for outbound WhatsApp is supported and straightforward.

---

## 5. Official documentation URLs

Use these for implementing M1.2 (webhook handler), M1.3 (STT), M1.4 (TTS), and M1.5 (outbound WhatsApp).

### WhatsApp Cloud API

- [Audio messages webhook reference](https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks/reference/messages/audio/) — inbound audio payload.
- [Incoming webhook payload (overview)](https://developers.facebook.com/documentation/business-messaging/whatsapp/reference/webhooks/whatsapp-incoming-webhook-payload) — full webhook structure.
- [Media / Retrieve media](https://developers.facebook.com/docs/whatsapp/cloud-api/media/) — downloading by `audio.id` or `audio.url`.
- [Send audio messages](https://developers.facebook.com/docs/whatsapp/cloud-api/messages/audio-messages/) — outbound audio format and API.

### 11Labs

- [Speech to Text](https://elevenlabs.io/docs/speech-to-text) — STT API (input formats, models).
- [Text to Speech](https://elevenlabs.io/docs/text-to-speech) — TTS API (output formats).
- [What audio formats do you support?](https://help.elevenlabs.io/hc/en-us/articles/15754340124305-What-audio-formats-do-you-support) — STT/TTS format support.
- Conversational AI: Custom LLM and post-call webhooks — use the current ElevenLabs docs or dashboard for exact request/response and webhook schemas (URLs may change).

---

*P1 deliverable: confirmed payload shapes, metadata, audio formats, and doc links for M1 implementation.*
