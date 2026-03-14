"""Voipy - Frontend declarations."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }
sv import from .server { setup_profile, get_profile }
import from "lucide-react" { LogOut, Send }
import from .components.AuthForm { AuthForm }
import "./global.css";

def:pub app() -> Any {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        authUsername: str = "",
        authPassword: str = "",
        authError: str = "",
        authLoading: bool = False,
        myProfile: Any = None,
        messages: list = [],
        chatInput: str = "",
        showBrowserPanel: bool = False,
        browserSessionId: str = "web_ui",
        browserUrl: str = "",
        browserSelector: str = "",
        browserText: str = "",
        browserLoading: bool = False,
        browserScreenshotUrl: str = "",
        browserActionLog: list = [],
        browserHeadless: bool = False;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            loadData();
        }
    }

    async def loadData() -> None;
    async def handleLogin() -> None;
    async def handleSignup() -> None;
    def handleLogout() -> None;
    async def handleSendMessage() -> None;
    
    async def openBrowserSession() -> None;
    async def browserNavigate() -> None;
    async def browserClick() -> None;
    async def browserType() -> None;
    async def browserScreenshot() -> None;
    async def browserExtractText() -> None;
    async def browserClose() -> None;
    async def logBrowserAction(action: str, details: str) -> None;

    if checkingAuth {
        return <div className="lx-loading">Loading...</div>;
    }

    if not isLoggedIn {
        return <AuthForm
            isSignup={isSignup}
            username={authUsername}
            password={authPassword}
            error={authError}
            loading={authLoading}
            onUsernameChange={lambda e: Any -> None { authUsername = e.target.value; }}
            onPasswordChange={lambda e: Any -> None { authPassword = e.target.value; }}
            onSubmit={lambda e: Any -> None { e.preventDefault(); if isSignup { handleSignup(); } else { handleLogin(); } }}
            onToggleMode={lambda -> None { isSignup = not isSignup; authError = ""; }}
        />;
    }

    profileUsername = myProfile.username if myProfile else "";
    displayUsername = profileUsername.split("@")[0] if profileUsername.includes("@") else profileUsername;

    return <div className="lx-root">
        <aside className="lx-sidebar-left lx-sidebar-minimal">
            <div className="lx-brand">
                <img src="/static/assets/voipy-logo.png" className="lx-brand-logo" alt="voipy" />
                <span className="lx-brand-name">VOIPY</span>
            </div>
            <div style={{"flex": "1"}} />
            <button 
                className={"lx-sidebar-logout " + ("lx-active" if showBrowserPanel else "")} 
                onClick={lambda -> None { showBrowserPanel = not showBrowserPanel; }} 
                title="Toggle Browser Panel"
            >
                <span>🌐 Browser</span>
            </button>
            <button className="lx-sidebar-logout" onClick={lambda -> None { handleLogout(); }} title={"Log out " + displayUsername}>
                <LogOut size={20} />
                <span>Log out</span>
            </button>
        </aside>

        <main className="lx-main lx-main-chat">
            <div className="lx-chat">
                <div className="lx-chat-header">
                    <span className="lx-chat-title">Chat</span>
                    <div className="lx-chat-header-right">
                        <span className="lx-chat-user">{displayUsername}</span>
                        <button className="lx-chat-logout-btn" onClick={lambda -> None { handleLogout(); }} title="Log out">
                            <LogOut size={18} />
                        </button>
                    </div>
                </div>
                <div className="lx-chat-messages">
                    {(
                        <div className="lx-chat-welcome">
                            <div className="lx-chat-welcome-title">How can I help you today?</div>
                            <div className="lx-chat-welcome-sub">Send a message to get started.</div>
                        </div>
                    ) if messages.length == 0 else None}
                    {[
                        <div key={m["id"]} className={"lx-chat-msg " + ("lx-chat-msg-user" if m["role"] == "user" else "lx-chat-msg-assistant")}>
                            <div className="lx-chat-msg-content">{m["content"]}</div>
                        </div>
                        for m in messages
                    ]}
                </div>
                <div className="lx-chat-input-wrap">
                    <textarea
                        className="lx-chat-input"
                        placeholder="Message Voipy..."
                        value={chatInput}
                        onChange={lambda e: Any -> None { chatInput = e.target.value; }}
                        onKeyDown={lambda e: Any -> None { if e.key == "Enter" and not e.shiftKey { e.preventDefault(); handleSendMessage(); } }}
                        rows={1}
                    />
                    <button
                        className="lx-chat-send"
                        disabled={not chatInput.trim()}
                        onClick={lambda -> None { handleSendMessage(); }}
                        title="Send"
                    >
                        <Send size={20} />
                    </button>
                </div>
            </div>

            {(
                <div className="lx-browser-panel">
                    <div className="lx-browser-header">
                        <span className="lx-browser-title">Browser Automation</span>
                        <button className="lx-browser-close" onClick={lambda -> None { showBrowserPanel = false; }}>✕</button>
                    </div>

                    <div className="lx-browser-controls">
                        <div className="lx-browser-section">
                            <h4>Session Control</h4>
                            <div className="lx-browser-actions">
                                <button 
                                    className="lx-browser-btn lx-browser-btn-primary"
                                    disabled={browserLoading}
                                    onClick={lambda -> None { openBrowserSession(); }}
                                >
                                    {("Opening..." if browserLoading else "Open Browser")}
                                </button>
                                <button 
                                    className="lx-browser-btn lx-browser-btn-danger"
                                    disabled={browserLoading}
                                    onClick={lambda -> None { browserClose(); }}
                                >
                                    Close Browser
                                </button>
                            </div>
                        </div>

                        <div className="lx-browser-section">
                            <h4>Navigation</h4>
                            <div className="lx-browser-input-group">
                                <input
                                    className="lx-browser-input"
                                    type="text"
                                    placeholder="Enter URL (e.g., https://example.com)"
                                    value={browserUrl}
                                    onChange={lambda e: Any -> None { browserUrl = e.target.value; }}
                                />
                                <button
                                    className="lx-browser-btn"
                                    disabled={browserLoading or not browserUrl.trim()}
                                    onClick={lambda -> None { browserNavigate(); }}
                                >
                                    Navigate
                                </button>
                            </div>
                        </div>

                        <div className="lx-browser-section">
                            <h4>Interaction</h4>
                            <div className="lx-browser-input-group">
                                <input
                                    className="lx-browser-input"
                                    type="text"
                                    placeholder="CSS Selector (e.g., button.submit, #id, .class)"
                                    value={browserSelector}
                                    onChange={lambda e: Any -> None { browserSelector = e.target.value; }}
                                />
                                <button
                                    className="lx-browser-btn"
                                    disabled={browserLoading or not browserSelector.trim()}
                                    onClick={lambda -> None { browserClick(); }}
                                >
                                    Click
                                </button>
                            </div>
                            <div className="lx-browser-input-group">
                                <input
                                    className="lx-browser-input"
                                    type="text"
                                    placeholder="Text to type"
                                    value={browserText}
                                    onChange={lambda e: Any -> None { browserText = e.target.value; }}
                                />
                                <button
                                    className="lx-browser-btn"
                                    disabled={browserLoading or not browserSelector.trim() or not browserText.trim()}
                                    onClick={lambda -> None { browserType(); }}
                                >
                                    Type
                                </button>
                            </div>
                            <button
                                className="lx-browser-btn lx-browser-btn-full"
                                disabled={browserLoading}
                                onClick={lambda -> None { browserExtractText(); }}
                            >
                                Extract Page Text
                            </button>
                            <button
                                className="lx-browser-btn lx-browser-btn-primary lx-browser-btn-full"
                                disabled={browserLoading}
                                onClick={lambda -> None { browserScreenshot(); }}
                            >
                                📸 Take Screenshot
                            </button>
                        </div>

                        {(
                            <div className="lx-browser-section">
                                <h4>Current View</h4>
                                {(
                                    <div className="lx-browser-screenshot">
                                        <img src={browserScreenshotUrl} alt="Browser view" />
                                    </div>
                                ) if browserScreenshotUrl else (
                                    <div className="lx-browser-placeholder">
                                        <span className="lx-browser-placeholder-icon">🌐</span>
                                        <span>No browser session active</span>
                                        <span className="lx-browser-placeholder-hint">Open a browser to start automation</span>
                                    </div>
                                )}
                            </div>
                        )}

                        {(
                            <div className="lx-browser-section">
                                <h4>Action Log</h4>
                                <div className="lx-browser-log">
                                    {[
                                        <div key={i} className="lx-browser-log-entry">
                                            <span className="lx-browser-log-time">{log["time"]}</span>
                                            <span className="lx-browser-log-action">{log["action"]}</span>
                                            <span className="lx-browser-log-details">{log["details"]}</span>
                                        </div>
                                        for (log, i) in browserActionLog.reverse()
                                    ]}
                                </div>
                            </div>
                        ) if browserActionLog.length > 0 else None}
                    </div>
                </div>
            ) if showBrowserPanel else None}
        </main>
    </div>;
}
