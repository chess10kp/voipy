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
        </main>
    </div>;
}
