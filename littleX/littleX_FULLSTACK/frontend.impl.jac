"""Voipy - Frontend function implementations."""

import http;

impl app.loadData -> None {
    result = root spawn setup_profile(username=localStorage.getItem("lx_username") or "");
    myProfile = result.reports[0] if result.reports else None;
    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
    chatResult = root spawn get_chat_messages();
    messages = (chatResult.reports[0] if chatResult.reports and chatResult.reports[0] else []);
}

impl app.handleLogin -> None {
    authError = "";
    if not authUsername.trim() or not authPassword {
        authError = "Please fill in all fields";
        return;
    }
    authLoading = True;
    result = await jacLogin(authUsername, authPassword);
    authLoading = False;
    if result and (result["ok"] or result == True) {
        localStorage.setItem("lx_username", authUsername);
        isLoggedIn = True;
        authPassword = "";
        authError = "";
    } else {
        authError = (result["error"]["message"] if result and result["error"] and result["error"]["message"] else "Invalid username or password");
    }
}

impl app.handleSignup -> None {
    authError = "";
    if not authUsername.trim() or not authPassword {
        authError = "Please fill in all fields";
        return;
    }
    if authPassword.length < 4 {
        authError = "Password must be at least 4 characters";
        return;
    }
    authLoading = True;
    result = await jacSignup(authUsername, authPassword);
    authLoading = False;
    if result["ok"] or result["success"] {
        localStorage.setItem("lx_username", authUsername);
        isLoggedIn = True;
        authPassword = "";
        authError = "";
    } else {
        authError = (result["error"]["message"] if result["error"] and result["error"]["message"] else (result["error"] if result["error"] else "Signup failed"));
    }
}

impl app.handleLogout -> None {
    jacLogout();
    localStorage.removeItem("lx_username");
    isLoggedIn = False;
    myProfile = None;
    messages = [];
    chatInput = "";
    authUsername = "";
    authPassword = "";
    browserClose();
}

impl app.handleSendMessage -> None {
    if not chatInput.trim() {
        return;
    }
    text = chatInput.trim();
    chatInput = "";
    timestamp_ms = Date.now();
    user_id = "msg-" + String(timestamp_ms) + "-user";
    messages = messages + [{"id": user_id, "role": "user", "content": text}];
    assistant_id = "msg-" + String(timestamp_ms) + "-asst";
    result = await root spawn chat_message(content=text);
    response_content = (result.reports[0]["content"] if result and result.reports and result.reports[0] else "Sorry, the backend didn't respond.");
    messages = messages + [{"id": assistant_id, "role": "assistant", "content": response_content}];
}

impl app.openBrowserSession -> None {
    browserLoading = True;
    mcp_port = parseInt(localStorage.getItem("mcp_port") or "8001");
    mcp_url = "http://localhost:" + mcp_port + "/tools/browser_create_session";
    
    try {
        response = await http.post(mcp_url, json={"session_id": browserSessionId, "headless": browserHeadless});
        data = await response.json();
        
        if data["status"] == "success" {
            await logBrowserAction("Session Created", "Browser session '" + browserSessionId + "' opened");
        } else {
            await logBrowserAction("Session Failed", data["error"] if data["error"] else "Unknown error");
        }
    } except Exception {
    }
    
    browserLoading = False;
}

impl app.browserNavigate -> None {
    if not browserUrl.trim() {
        return;
    }
    
    browserLoading = True;
    mcp_port = parseInt(localStorage.getItem("mcp_port") or "8001");
    mcp_url = "http://localhost:" + mcp_port + "/tools/browser_navigate";
    
    try {
        response = await http.post(mcp_url, json={"session_id": browserSessionId, "url": browserUrl});
        data = await response.json();
        
        if data["status"] == "success" {
            await logBrowserAction("Navigate", "Navigated to " + browserUrl);
        } else {
            await logBrowserAction("Navigation Failed", data["error"] if data["error"] else "Unknown error");
        }
    } except Exception {
    }
    
    browserLoading = False;
}

impl app.browserClick -> None {
    if not browserSelector.trim() {
        return;
    }
    
    browserLoading = True;
    mcp_port = parseInt(localStorage.getItem("mcp_port") or "8001");
    mcp_url = "http://localhost:" + mcp_port + "/tools/browser_click";
    
    try {
        response = await http.post(mcp_url, json={"session_id": browserSessionId, "selector": browserSelector});
        data = await response.json();
        
        if data["status"] == "success" {
            await logBrowserAction("Click", "Clicked element: " + browserSelector);
        } else {
            await logBrowserAction("Click Failed", data["error"] if data["error"] else "Unknown error");
        }
    } except Exception {
    }
    
    browserLoading = False;
}

impl app.browserType -> None {
    if not browserSelector.trim() or not browserText.trim() {
        return;
    }
    
    browserLoading = True;
    mcp_port = parseInt(localStorage.getItem("mcp_port") or "8001");
    mcp_url = "http://localhost:" + mcp_port + "/tools/browser_type";
    
    try {
        response = await http.post(mcp_url, json={"session_id": browserSessionId, "selector": browserSelector, "text": browserText});
        data = await response.json();
        
        if data["status"] == "success" {
            await logBrowserAction("Type", "Typed '" + browserText + "' into: " + browserSelector);
        } else {
            await logBrowserAction("Type Failed", data["error"] if data["error"] else "Unknown error");
        }
    } except Exception {
    }
    
    browserLoading = False;
}

impl app.browserScreenshot -> None {
    browserLoading = True;
    mcp_port = parseInt(localStorage.getItem("mcp_port") or "8001");
    mcp_url = "http://localhost:" + mcp_port + "/tools/browser_screenshot";
    
    try {
        response = await http.post(mcp_url, json={"session_id": browserSessionId, "full_page": True});
        data = await response.json();
        
        if data["status"] == "success" {
            browserScreenshotUrl = data["screenshot"];
            await logBrowserAction("Screenshot", "Captured full page screenshot");
        } else {
            await logBrowserAction("Screenshot Failed", data["error"] if data["error"] else "Unknown error");
        }
    } except Exception {
    }
    
    browserLoading = False;
}

impl app.browserExtractText -> None {
    browserLoading = True;
    mcp_port = parseInt(localStorage.getItem("mcp_port") or "8001");
    mcp_url = "http://localhost:" + mcp_port + "/tools/browser_extract_text";
    
    try {
        response = await http.post(mcp_url, json={"session_id": browserSessionId, "selector": ""});
        data = await response.json();
        
        if data["status"] == "success" {
            extracted_text = data["text"];
            if extracted_text.length > 500 {
                extracted_text = extracted_text.substring(0, 500) + "...";
            }
            await logBrowserAction("Extract Text", "Extracted page content");
        } else {
            await logBrowserAction("Extract Failed", data["error"] if data["error"] else "Unknown error");
        }
    } except Exception {
    }
    
    browserLoading = False;
}

impl app.browserClose -> None {
    mcp_port = parseInt(localStorage.getItem("mcp_port") or "8001");
    mcp_url = "http://localhost:" + mcp_port + "/tools/browser_close_session";
    
    try {
        response = await http.post(mcp_url, json={"session_id": browserSessionId});
        data = await response.json();
        
        if data["status"] == "success" {
            browserScreenshotUrl = "";
            browserUrl = "";
            browserSelector = "";
            browserText = "";
            await logBrowserAction("Session Closed", "Browser session '" + browserSessionId + "' terminated");
        } else {
            await logBrowserAction("Close Failed", data["error"] if data["error"] else "Unknown error");
        }
    } except Exception {
    }
}

impl app.logBrowserAction(action: str, details: str) -> None {
    timestamp = Reflect.construct(Date, []);
    time_str = timestamp.toLocaleTimeString("en-GB", {"hour": "2-digit", "minute": "2-digit"});
    
    logEntry = {
        "time": time_str,
        "action": action,
        "details": details
    };
    
    browserActionLog = browserActionLog + [logEntry];
    
    root spawn browser_interaction_log(action=action, details=details);
}
