# VoiceAgent MVP — LLM Provider (P2 Decision)

## Decision: MiniMax-M2.5

The VoiceAgent pipeline uses **MiniMax-M2.5** as the LLM provider for the orchestration service (M2+). MiniMax exposes an **OpenAI-compatible** chat completions API, so the same code can use the OpenAI SDK with a custom base URL and API key.

---

## Configuration (hardcoded)

| Variable | Value |
|----------|--------|
| **MINIMAX_API_HOST** | `https://api.minimax.io` |
| **MINIMAX_API_KEY** | (see `voice_llm_config.json`) |

Base URL for the OpenAI SDK: `https://api.minimax.io/v1`.

---

## Using with the OpenAI SDK

The MiniMax text API is [OpenAI-compatible](https://platform.minimax.io/docs/api-reference/text-openai-api). Use the hardcoded config (or load from `voice_llm_config.json`).

### Example (Node.js)

```javascript
import OpenAI from 'openai';

const MINIMAX_API_HOST = 'https://api.minimax.io';
const MINIMAX_API_KEY = 'sk-cp-70kIZgYo4wGo9wSbgIsarM-IE1SJWFq70sN-XeqqF9F5WdNYawbX8TYUmTWb7on4EZy7otDqZcgyCVmV8Tq-iyKBuauCPhtwqQTAF0EzBYxJwS2PvgMMsBk';

const client = new OpenAI({
  baseURL: `${MINIMAX_API_HOST}/v1`,
  apiKey: MINIMAX_API_KEY,
});

const response = await client.chat.completions.create({
  model: 'MiniMax-M2.5',
  messages: [
    { role: 'system', content: 'You are a helpful assistant.' },
    { role: 'user', content: 'Hello!' },
  ],
});
```

### Example (Python)

```python
from openai import OpenAI

MINIMAX_API_HOST = "https://api.minimax.io"
MINIMAX_API_KEY = "sk-cp-70kIZgYo4wGo9wSbgIsarM-IE1SJWFq70sN-XeqqF9F5WdNYawbX8TYUmTWb7on4EZy7otDqZcgyCVmV8Tq-iyKBuauCPhtwqQTAF0EzBYxJwS2PvgMMsBk"

client = OpenAI(
    base_url=f"{MINIMAX_API_HOST}/v1",
    api_key=MINIMAX_API_KEY,
)

response = client.chat.completions.create(
    model="MiniMax-M2.5",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hello!"},
    ],
)
```

---

## Model Options

| Model                   | Context  | Use case                          |
|-------------------------|----------|-----------------------------------|
| **MiniMax-M2.5**        | 204,800  | Default; peak performance (~60 tps). |
| **MiniMax-M2.5-highspeed** | 204,800 | Faster output (~100 tps).         |

For tool use (M2/M3), use the `tools` parameter; `function_call` is not supported. See [Tool Use & Interleaved Thinking](https://platform.minimax.io/docs/api-reference/text-m2-function-call-refer) in MiniMax docs.

---

## References

- [MiniMax API Overview](https://platform.minimax.io/docs/api-reference/api-overview)
- [OpenAI-compatible Text API](https://platform.minimax.io/docs/api-reference/text-openai-api)
- [M2.1 Tool Use](https://platform.minimax.io/docs/api-reference/text-m2-function-call-refer)
