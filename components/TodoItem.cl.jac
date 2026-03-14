"""Todo item component with priority and sub-todos."""

def:pub TodoItem(
    todo: dict, allTodos: list, onToggle: any, onDelete: any, onAddSubTodo: any
) -> any {
    subTodos = allTodos.filter(
        lambda t: any  -> bool { return t.parent_id == todo.id; }
    );
    priority = todo.priority or "medium";
    badgeClass = "todo-badge todo-badge-high"
    if priority == "high"
    else ("todo-badge todo-badge-medium" if priority == "medium" else "todo-badge todo-badge-low");

    return
        <div className="todo-item-wrapper">
            <div className="todo-item">
                <input
                    type="checkbox"
                    checked={todo.completed}
                    onChange={lambda -> None { onToggle(todo.id);}}
                    className="todo-checkbox"
                />
                <span className={("todo-title-completed" if todo.completed else "todo-title")}>
                    {todo.title}
                </span>
                <span className={badgeClass}>
                    {priority}
                </span>
                <button
                    onClick={lambda -> None { onDelete(todo.id);}}
                    className="todo-delete-btn"
                >
                    ×
                </button>
            </div>
            {(
                <div className="sub-todo-container">
                    {subTodos.map(
                        lambda st: any  -> any { return
                            <TodoItem
                                key={st.id}
                                todo={st}
                                allTodos={allTodos}
                                onToggle={onToggle}
                                onDelete={onDelete}
                                onAddSubTodo={onAddSubTodo}
                            />; }
                    )}
                </div>
            )
            if subTodos.length > 0
            else None}
        </div>;
}
