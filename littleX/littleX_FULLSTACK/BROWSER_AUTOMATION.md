# Voipy Browser Automation Guide

This guide explains how to use the integrated browser automation features in Voipy.

## Overview

Voipy now includes a powerful browser automation system that allows you to:
- Control a visible Chrome browser directly from the web UI
- Automate web interactions (navigate, click, type, extract text)
- Take screenshots of browser sessions
- Use the browser automation tools via MCP clients (Claude Desktop, Cursor, etc.)

## Architecture

```
Website UI → HTTP Requests → MCP Server → Playwright → Visible Browser
                                                ↓
                              MCP Clients → MCP Server → Playwright → Visible Browser
```

## Quick Start

### 1. Install Dependencies

```bash
# Install Playwright and its browsers
pip install playwright
playwright install chromium

# Install MCP dependencies (already in jac.toml)
pip install httpx mcp playwright
```

### 2. Start the Servers

Option A: Use the startup script (Recommended)
```bash
cd /home/sigma/projects/repos/voipy/littleX/littleX_FULLSTACK
./run_servers.sh
```

Option B: Start manually
```bash
# Terminal 1: Start Jac server
cd /home/sigma/projects/repos/voipy/littleX/littleX_FULLSTACK
jac start main.jac --port 8080

# Terminal 2: Start MCP wrapper
cd /home/sigma/projects/repos/voipy/littleX/littleX_FULLSTACK
export JAC_API_URL="http://localhost:8080"
python3 mcp_wrapper.py
```

### 3. Access the Application

Open your browser and navigate to:
```
http://localhost:8080
```

## Using Browser Automation from Website UI

### Step 1: Open Browser Panel

1. Log in to Voipy
2. Click the "🌐 Browser" button in the left sidebar
3. The browser automation panel will slide in from the right

### Step 2: Create Browser Session

1. In the Browser Automation panel, click "Open Browser"
2. A visible Chrome browser will launch (not headless for maximum visual impact!)
3. Wait for the browser to be ready
4. The action log will show: "Session Created"

### Step 3: Navigate to a Website

1. Enter a URL in the "Navigation" field (e.g., `https://example.com`)
2. Click "Navigate"
3. The browser will navigate to the URL
4. The action log will show the page title

### Step 4: Interact with the Page

#### Click Elements
1. Find a CSS selector for an element (e.g., `button.submit`, `#login-btn`, `.nav-item`)
2. Enter the selector in the "Interaction" field
3. Click "Click"
4. The browser will click the element

#### Type Text
1. Enter a CSS selector for an input field
2. Enter the text to type in the text field
3. Click "Type"
4. The text will be entered into the field

#### Extract Text
1. Click "Extract Page Text"
2. All text from the page will be extracted
3. The action log will show the extracted content

### Step 5: Take Screenshots

1. After navigating or interacting, click "📸 Take Screenshot"
2. A screenshot of the current browser state will appear in the UI
3. Screenshots are perfect for:
   - Showing automation results
   - Debugging interactions
   - Visual demonstrations

### Step 6: Close Browser

1. Click "Close Browser" to terminate the session
2. All browser resources will be cleaned up

## Using Browser Automation from MCP Clients

### Available Tools

The MCP server exposes these browser automation tools:

1. **browser_create_session** - Create a new browser session
   - Parameters: `session_id` (string), `headless` (boolean, default: false)
   - Example: `{"session_id": "demo", "headless": false}`

2. **browser_navigate** - Navigate to a URL
   - Parameters: `session_id` (string), `url` (string)
   - Example: `{"session_id": "demo", "url": "https://example.com"}`

3. **browser_click** - Click an element
   - Parameters: `session_id` (string), `selector` (string)
   - Example: `{"session_id": "demo", "selector": "button.submit"}`

4. **browser_type** - Type text into an input
   - Parameters: `session_id` (string), `selector` (string), `text` (string)
   - Example: `{"session_id": "demo", "selector": "input#email", "text": "test@example.com"}`

5. **browser_screenshot** - Take a screenshot
   - Parameters: `session_id` (string), `full_page` (boolean, default: false)
   - Returns: Base64-encoded PNG image
   - Example: `{"session_id": "demo", "full_page": true}`

6. **browser_extract_text** - Extract text from page
   - Parameters: `session_id` (string), `selector` (string, optional)
   - Returns: Extracted text content
   - Example: `{"session_id": "demo", "selector": "body"}`

7. **browser_wait_for** - Wait for element to appear
   - Parameters: `session_id` (string), `selector` (string), `timeout` (integer, default: 5000)
   - Example: `{"session_id": "demo", "selector": ".loading", "timeout": 10000}`

8. **browser_evaluate** - Execute JavaScript
   - Parameters: `session_id` (string), `js_code` (string)
   - Returns: Result of JavaScript execution
   - Example: `{"session_id": "demo", "js_code": "document.title"}`

9. **browser_get_url** - Get current URL
   - Parameters: `session_id` (string)
   - Returns: Current URL and page title
   - Example: `{"session_id": "demo"}`

10. **browser_list_sessions** - List all active browser sessions
    - Returns: List of all sessions with their URLs and headless status

11. **browser_close_session** - Close a specific session
    - Parameters: `session_id` (string)
    - Example: `{"session_id": "demo"}`

12. **browser_close_all** - Close all browser sessions
    - No parameters required

### MCP Client Configuration

#### Claude Desktop

Add to Claude Desktop configuration:

```json
{
  "mcpServers": {
    "voipy-browser": {
      "command": "python3",
      "args": ["/home/sigma/projects/repos/voipy/littleX/littleX_FULLSTACK/mcp_wrapper.py"],
      "env": {
        "JAC_API_URL": "http://localhost:8080"
      }
    }
  }
}
```

#### Cursor IDE

Add to Cursor MCP configuration:

```json
{
  "mcpServers": {
    "voipy": {
      "command": "python3",
      "args": ["/home/sigma/projects/repos/voipy/littleX/littleX_FULLSTACK/mcp_wrapper.py"],
      "cwd": "/home/sigma/projects/repos/voipy/littleX/littleX_FULLSTACK",
      "env": {
        "JAC_API_URL": "http://localhost:8080",
        "MCP_PORT": "8001"
      }
    }
  }
}
```

## Tips for Finding CSS Selectors

### Browser DevTools
1. Right-click on an element in the browser
2. Select "Inspect"
3. In the Elements panel, right-click the element
4. Choose "Copy" → "Copy selector"

### Common Selectors
- **ID**: `#submit-button`
- **Class**: `.primary-button`, `.nav-link`
- **Tag**: `button`, `input[type="text"]`
- **Combined**: `button.submit-btn[data-action="save"]`
- **Attribute**: `[data-testid="login"]`

### Selector Examples
```
button.primary           # Class selector
#email-input           # ID selector
input[type="text"]   # Attribute selector
nav > a               # Child selector
article:first-child      # Pseudo-class
```

## Use Cases

### 1. Automated Testing
```javascript
// Example: Test login flow
1. Navigate to https://example.com/login
2. Type email into #email
3. Type password into #password
4. Click button.submit
5. Take screenshot to verify success
```

### 2. Data Scraping
```javascript
// Example: Extract product information
1. Navigate to e-commerce site
2. Extract text from .product-list
3. Parse results
4. Create tweet with findings
```

### 3. Interactive Demonstrations
```javascript
// Example: Show off website features
1. Navigate to your site
2. Click navigation items
3. Fill out forms
4. Take screenshots at each step
5. Share screenshots with audience
```

### 4. AI Assistant Integration
```javascript
// Example: Let AI interact with websites
1. User asks AI to "search for X"
2. AI navigates to search engine
3. AI types search query
4. AI extracts results
5. AI summarizes findings
```

## Troubleshooting

### Browser Won't Start
- Ensure Playwright is installed: `pip install playwright`
- Ensure browsers are installed: `playwright install chromium`
- Check logs: `tail -f logs/mcp_server.log`

### Click Fails
- Verify CSS selector is correct
- Use browser_devtools to find selectors
- Add wait before click if element loads dynamically
- Check action log for error details

### Screenshot Fails
- Ensure browser session is active
- Check if page has loaded
- Verify browser has permissions to capture screen

### MCP Client Can't Connect
- Ensure MCP server is running
- Check port configuration (default: 8001)
- Verify JAC_API_URL environment variable
- Check firewall settings

## Advanced Features

### Multiple Sessions
You can create multiple browser sessions with different IDs:
- Session A: "main_session" - for general browsing
- Session B: "test_session" - for automated testing
- Session C: "demo_session" - for demonstrations

Each session is isolated with its own browser context.

### JavaScript Evaluation
Use `browser_evaluate` for advanced interactions:
```javascript
// Scroll to bottom
window.scrollTo(0, document.body.scrollHeight);

// Get all links
Array.from(document.querySelectorAll('a')).map(a => a.href);

// Execute custom logic
document.querySelectorAll('.product').forEach(p => {
    p.style.border = '2px solid red';
});
```

### Wait Strategies
For dynamic content, use `browser_wait_for`:
```javascript
// Wait up to 10 seconds for element
browser_wait_for(session_id="demo", selector=".loaded-content", timeout=10000)
```

## Security Notes

- Browser sessions are isolated per client
- Each session has its own browser context (cookies, local storage)
- Sessions are not shared between MCP clients
- Close sessions when done to free resources
- Be careful with `browser_evaluate` - execute only trusted JavaScript

## Performance Tips

- Use specific CSS selectors for better performance
- Wait for elements before interacting
- Close unused sessions
- Use full_page screenshots only when needed
- Batch multiple actions when possible

## Support

For issues or questions:
- Check logs in the `logs/` directory
- Use `browser_list_sessions` to see active sessions
- Refer to Playwright documentation: https://playwright.dev
- MCP Protocol: https://modelcontextprotocol.io

---

Enjoy the power of visible browser automation in Voipy! 🌐
