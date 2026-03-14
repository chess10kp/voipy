# Voipy - Browser Automation for financial markets

A full-stack Jac application with React support and integrated browser automation capabilities.

## Features

- 🤖 **Browser Automation**: Control visible Chrome browsers for testing, scraping, and demos
- 🔌 **MCP Integration**: Expose all features via Model Context Protocol
- 🎨 **Modern UI**: Responsive design with dark theme

## Project Structure

```
voipy/
 ├── jac.toml              # Project configuration
 ├── main.jac              # Main application entry
 ├── server.jac             # Backend walkers (browser logging)
 ├── frontend.cl.jac         # React component declarations
 ├── frontend.impl.jac       # Frontend function implementations
 ├── mcp_wrapper.py         # MCP server with browser automation
 ├── components/           # Reusable React components
 ├── assets/               # Static assets (images, fonts, etc.)
 ├── global.css            # Global styles including browser panel
 ├── run_servers.sh         # Startup script for dual-server mode
 ├── test_browser.py       # Browser automation test suite
 ├── logs/                 # Server logs (generated)
 └── BROWSER_AUTOMATION.md  # Detailed browser automation guide
```

## Quick Start

### Option 1: Single Server (Simple)

Start just the web application:

```bash
cd /home/sigma/projects/repos/voipy/littleX/littleX_FULLSTACK
jac start main.jac
```

Access at: `http://localhost:8080`

### Option 2: Dual Server (Full Features)

Use the startup script for both web app + browser automation:

```bash
cd /home/sigma/projects/repos/voipy/littleX/littleX_FULLSTACK
./run_servers.sh
```

This starts:
- **Jac Scale Server** (port 8080): Web application 
- **MCP Wrapper Server** (port 8001): Browser automation + MCP tools

Access web app at: `http://localhost:8080`

## Browser Automation

Voipy includes powerful browser automation that allows you to:

### From Website UI
1. Click "🌐 Browser" in the left sidebar
2. Click "Open Browser" to launch a visible Chrome browser
3. Navigate to any website
4. Click elements, type text, extract data
5. Take screenshots for demonstrations
6. Close browser when done

### From MCP Clients (Claude, Cursor, etc.)

Connect to `http://localhost:8001` to access:
- Browser session management
- Navigation control
- Element interaction (click, type)
- Screenshot capture
- Text extraction
- JavaScript execution

**Available Tools:**
`browser_create_session`, `browser_navigate`, `browser_click`, `browser_type`, `browser_screenshot`, `browser_extract_text`, `browser_wait_for`, `browser_evaluate`, `browser_get_url`, `browser_list_sessions`, `browser_close_session`, `browser_close_all`


## Testing

Run the browser automation test suite:

```bash
cd /home/sigma/projects/repos/voipy/littleX/littleX_FULLSTACK
# Start servers first (in another terminal)
./run_servers.sh

# In a new terminal, run tests
python3 test_browser.py
```

## Documentation

- **Browser Automation Guide**: See `BROWSER_AUTOMATION.md` for detailed instructions
- **Logs**: Check `logs/` directory for server logs
- **MCP Protocol**: https://modelcontextprotocol.io

## Components

Create Jac components in `components/` as `.cl.jac` files:

```jac
cl import from .components.Button { Button }
```

## Adding Dependencies

### Python Dependencies
```bash
pip install playwright mcp httpx
playwright install chromium
```

### NPM Packages
```bash
jac add --cl react-router-dom
```

## Environment Variables

- `JAC_API_URL`: Jac server URL (default: `http://localhost:8080`)
- `MCP_PORT`: MCP server port (default: `8001`)
- `JAC_PORT`: Jac server port (default: `8080`)

## Troubleshooting

### Browser won't start
- Ensure Playwright is installed: `pip install playwright`
- Install browsers: `playwright install chromium`
- Check logs: `tail -f logs/mcp_server.log`

### MCP client can't connect
- Verify MCP server is running
- Check port configuration
- Ensure JAC_API_URL is correct

## License

MIT License - See project repository for details

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
