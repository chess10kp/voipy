"""TaskFlow - Entry Point.

Combines server-side endpoints with client-side UI.
A modern todo app with hierarchical sub-todos and priorities.
"""

# Client-side UI
cl {
    import from frontend { app as ClientApp }

    def:pub app -> any {
        return
            <ClientApp />;
    }
}

node Todo {
    has id: str,
        title: str,
        completed: bool = False,
        priority: str = "medium",
        parent_id: str = "";
}

glob todo_counter: int = 0;

walker:priv AddTodo {
    has title: str,
        priority: str = "medium",
        parent_id: str = "";

    can create with Root entry {
        global todo_counter;
        todo_counter += 1;
        new_id = "todo_" + str(todo_counter);
        new_todo = here ++> Todo(
            id=new_id,
            title=self.title,
            completed=False,
            priority=self.priority,
            parent_id=self.parent_id
        );
        if new_todo {
            report new_todo[0];
        }
    }
}

walker:priv ListTodos {
    has todos: list = [];

    can collect with Root entry {
        visit [-->];
    }

    can gather with Todo entry {
        self.todos.append(
            {
                "id": here.id,
                "title": here.title,
                "completed": here.completed,
                "priority": here.priority,
                "parent_id": here.parent_id
            }
        );
    }

    can report_all with Root exit {
        report self.todos;
    }
}

walker:priv ToggleTodo {
    has todo_id: str;

    can search with Root entry {
        visit [-->];
    }

    can toggle with Todo entry {
        if here.id == self.todo_id {
            here.completed = not here.completed;
            report {"id": here.id, "completed": here.completed};
        }
    }
}

walker:priv DeleteTodo {
    has todo_id: str;

    can search with Root entry {
        visit [-->];
    }

    can delete with Todo entry {
        if here.id == self.todo_id or here.parent_id == self.todo_id {
            del here;
            report {"deleted": self.todo_id};
        }
    }
}
