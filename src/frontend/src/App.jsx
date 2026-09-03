import { BrowserRouter, Routes, Route, Navigate, NavLink } from 'react-router-dom'
import { AuthProvider, useAuth } from './context/AuthContext'
import Login from './pages/Login'
import Billing from './pages/Billing'
import Tasks from './pages/Tasks'
import './App.css'

function Layout({ children }) {
  const { user, logout } = useAuth()
  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">Billing & Tasks</div>
        <nav className="nav-links">
          <NavLink
            to="/billing"
            className={({ isActive }) => (isActive ? 'active' : '')}
          >
            Billing
          </NavLink>
          <NavLink
            to="/tasks"
            className={({ isActive }) => (isActive ? 'active' : '')}
          >
            Tasks
          </NavLink>
          <div className="user-pill">
            <span className="avatar">{user?.name?.[0] || 'U'}</span>
            <span>{user?.name || 'User'}</span>
            <button type="button" onClick={logout} className="logout-btn">
              Logout
            </button>
          </div>
        </nav>
      </header>
      <main className="page">{children}</main>
    </div>
  )
}

function ProtectedRoute({ children }) {
  const { token } = useAuth()
  return token ? children : <Navigate to="/login" replace />
}

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/" element={<Login />} />
          <Route
            path="/billing"
            element={
              <ProtectedRoute>
                <Layout>
                  <Billing />
                </Layout>
              </ProtectedRoute>
            }
          />
          <Route
            path="/tasks"
            element={
              <ProtectedRoute>
                <Layout>
                  <Tasks />
                </Layout>
              </ProtectedRoute>
            }
          />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  )
}

export default App
