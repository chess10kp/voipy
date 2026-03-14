# voipy

A Jac client-side application with React support.

## Project Structure

```
voipy/
├── jac.toml              # Project configuration
├── main.jac              # Main application entry
├── components/           # Reusable components
│   └── Button.cl.jac     # Example Jac component
├── assets/               # Static assets (images, fonts, etc.)
└── build/                # Build output (generated)
```

## Getting Started

Start the development server:

```bash
jac start main.jac
```

### Dual-server setup: MCP wrapper (optional)

To expose Voipy as an MCP server for AI/agent tools:

1. **Start the Jac Scale server** (HTTP API for walkers):

   ```bash
   jac start main.jac --port 8080
   ```

2. **Install Python deps** (if needed): `pip install mcp httpx`

3. **Start the MCP wrapper server** (calls the Jac API and exposes MCP tools):

   ```bash
   export JAC_API_URL=http://localhost:8080   # optional; default is 8080
   python mcp_wrapper.py
   ```

   MCP runs by default on port **8001** (set `MCP_PORT` to change). Connect clients to the streamable HTTP URL (e.g. `http://localhost:8001`).

4. **Tools exposed**: `get_all_profiles`, `get_profile`, `setup_profile`, `follow_user`, `unfollow_user`, `load_feed`, `get_trending`, `create_tweet`, `delete_tweet`, `like_tweet`, `add_comment`, `get_channels`, `get_channel_detail`, `create_channel`, `join_channel`, `leave_channel`, `create_channel_tweet`, `get_chat_messages`, `chat_message`, `ping`.

## Components

Create Jac components in `components/` as `.cl.jac` files and import them:

```jac
cl import from .components.Button { Button }
```

## Adding Dependencies

Add npm packages with the --cl flag:

```bash
jac add --cl react-router-dom
```
