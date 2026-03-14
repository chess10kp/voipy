"""Todo App - Client-Side UI with priorities and sub-todos."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

import ".styles.css";

import from .components.TodoItem { TodoItem }
import from .components.AuthForm { AuthForm }

sv import from main { AddTodo, ListTodos, ToggleTodo, DeleteTodo }

def:pub app -> any {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        username: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False,
        todos: list = [],
        newTodoText: str = "",
        newPriority: str = "medium",
        todosLoading: bool = True;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            fetchTodos();
        }
    }

    async def fetchTodos -> None;
    async def addTodo -> None;
    async def addSubTodo(title: str, parentId: str) -> None;
    async def toggleTodo(todoId: str) -> None;
    async def deleteTodo(todoId: str) -> None;
    async def handleLogin -> None;
    async def handleSignup -> None;
    def handleLogout -> None;
    async def handleSubmit(e: any) -> None;
    def handleTodoKeyPress(e: any) -> None;
    def getRootTodos -> list;

    if checkingAuth {
        return
            <div className="app-loading">
                Loading...
            </div>;
    }

    if isLoggedIn {
        rootTodos = getRootTodos();
        return
            <div className="app-container">
                <div className="app-content">
                    <div className="card">
                        <div className="card-header">
                            <div>
                                <h1 className="app-title">
                                    TaskFlow
                                </h1>
                                <p className="app-subtitle">
                                    Organize tasks with priorities & sub-tasks
                                </p>
                            </div>
                            <button onClick={handleLogout} className="btn-signout">
                                Sign Out
                            </button>
                        </div>
                    </div>
                    <div className="card">
                        <div className="add-row">
                            <input
                                type="text"
                                value={newTodoText}
                                onChange={lambda e: any  -> None { newTodoText = e.target.value;}}
                                onKeyPress={handleTodoKeyPress}
                                placeholder="What needs to be done?"
                                className="todo-input"
                            />
                            <button
                                onClick={lambda -> None { addTodo();}}
                                className="btn-add"
                            >
                                Add
                            </button>
                        </div>
                        <div className="priority-row">
                            <span className="priority-label">
                                Priority:
                            </span>
                            <button
                                onClick={lambda -> None { newPriority = "high";}}
                                className={(
                                    "priority-btn priority-btn-high"
                                    if newPriority == "high"
                                    else "priority-btn"
                                )}
                            >
                                High
                            </button>
                            <button
                                onClick={lambda -> None { newPriority = "medium";}}
                                className={(
                                    "priority-btn priority-btn-medium"
                                    if newPriority == "medium"
                                    else "priority-btn"
                                )}
                            >
                                Medium
                            </button>
                            <button
                                onClick={lambda -> None { newPriority = "low";}}
                                className={(
                                    "priority-btn priority-btn-low"
                                    if newPriority == "low"
                                    else "priority-btn"
                                )}
                            >
                                Low
                            </button>
                        </div>
                    </div>
                    <div className="card">
                        {(
                            <div className="loading-message">
                                Loading tasks...
                            </div>
                        )
                        if todosLoading
                        else (
                            <div>
                                {(
                                    <div className="empty-message">
                                        No tasks yet. Add one above!
                                    </div>
                                )
                                if rootTodos.length == 0
                                else (
                                    <div>
                                        {[
                                            <TodoItem
                                                key={todo.id}
                                                todo={todo}
                                                allTodos={todos}
                                                onToggle={toggleTodo}
                                                onDelete={deleteTodo}
                                                onAddSubTodo={addSubTodo}
                                            /> for todo in rootTodos
                                        ]}
                                    </div>
                                )}
                            </div>
                        )}
                    </div>
                    <div className="remaining-count">
                        {todos.filter(
                            lambda t: any  -> bool { return not t.completed; }
                        ).length}items remaining
                    </div>
                </div>
            </div>;
    }

    return
        <AuthForm
            isSignup={isSignup}
            username={username}
            password={password}
            error={error}
            loading={loading}
            onUsernameChange={lambda e: any  -> None { username = e.target.value;}}
            onPasswordChange={lambda e: any  -> None { password = e.target.value;}}
            onSubmit={handleSubmit}
            onToggleMode={lambda -> None { isSignup = not isSignup;error = "";}}
        />;
}
