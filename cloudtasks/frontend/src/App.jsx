import { useEffect, useState } from "react";
import "./App.css";

const API_URL = "/api";

function App() {
  const [tasks, setTasks] = useState([]);
  const [title, setTitle] = useState("");

  async function loadTasks() {
    const response = await fetch(`${API_URL}/tasks`);
    const data = await response.json();
    setTasks(data);
  }

  async function addTask(event) {
    event.preventDefault();

    if (!title.trim()) return;

    await fetch(`${API_URL}/tasks`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ title }),
    });

    setTitle("");
    loadTasks();
  }

  async function toggleTask(task) {
    await fetch(`${API_URL}/tasks/${task.id}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        completed: !task.completed,
      }),
    });

    loadTasks();
  }

  async function deleteTask(id) {
    await fetch(`${API_URL}/tasks/${id}`, {
      method: "DELETE",
    });

    loadTasks();
  }

  useEffect(() => {
    loadTasks();
  }, []);

  return (
    <div className="app">
      <div className="container">
        <header>
          <h1>CloudTasks</h1>
          <p>Simple task management for the cloud.</p>
        </header>

        <form onSubmit={addTask} className="task-form">
          <input
            type="text"
            placeholder="What needs to be done?"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
          />

          <button type="submit">Add Task</button>
        </form>

        <div className="tasks">
          {tasks.length === 0 ? (
            <p className="empty">No tasks yet.</p>
          ) : (
            tasks.map((task) => (
              <div className="task" key={task.id}>
                <label>
                  <input
                    type="checkbox"
                    checked={task.completed}
                    onChange={() => toggleTask(task)}
                  />

                  <span className={task.completed ? "completed" : ""}>
                    {task.title}
                  </span>
                </label>

                <button
                  className="delete"
                  onClick={() => deleteTask(task.id)}
                >
                  Delete
                </button>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

export default App;
