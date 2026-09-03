import { useEffect, useState } from 'react'
import { useAuth } from '../context/AuthContext'
import '../App.css'

export default function Tasks() {
  const { token } = useAuth()
  const [tasks, setTasks] = useState([])
  const [newTask, setNewTask] = useState('')

  const load = () => {
    fetch(`/api/tasks?email=${encodeURIComponent(token)}`)
      .then((r) => r.json())
      .then(setTasks)
  }

  useEffect(() => {
    load()
  }, [token])

  const add = async (e) => {
    e.preventDefault()
    if (!newTask.trim()) return
    await fetch('/api/tasks', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: token, title: newTask.trim() }),
    })
    setNewTask('')
    load()
  }

  return (
    <div className="page-card">
      <div className="tasks-header">
        <h2 className="section-title">Tasks</h2>
        <p className="section-sub">Your pending and completed work items</p>
      </div>
      <form className="add-task-form" onSubmit={add}>
        <input
          type="text"
          placeholder="Add a new task..."
          value={newTask}
          onChange={(e) => setNewTask(e.target.value)}
        />
        <button type="submit" title="Add task">+</button>
      </form>
      <ul className="tasks-list">
        {tasks.map((t) => (
          <li key={t.id} className="task-item">
            <div className="task-main">
              <h3>{t.title}</h3>
              <div className="task-meta">Due {t.due}</div>
            </div>
            <span className={`task-status ${t.status}`}>{t.status}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
