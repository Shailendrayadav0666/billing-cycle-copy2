import { createContext, useContext, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [token, setToken] = useState(localStorage.getItem('token'))
  const navigate = useNavigate()

  useEffect(() => {
    if (!token) return
    fetch(`/api/users/me?email=${encodeURIComponent(token)}`)
      .then((r) => {
        if (!r.ok) throw new Error()
        return r.json()
      })
      .then(setUser)
      .catch(logout)
  }, [token])

  const store = (data) => {
    setToken(data.access_token)
    setUser(data.user)
    localStorage.setItem('token', data.access_token)
  }

  const login = async (email, password) => {
    const res = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(data.detail || 'Login failed')
    store(data)
    navigate('/billing')
  }

  const register = async (name, email, password) => {
    const res = await fetch('/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, email, password }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(data.detail || 'Sign up failed')
    store(data)
    navigate('/billing')
  }

  const logout = () => {
    setToken(null)
    setUser(null)
    localStorage.removeItem('token')
    navigate('/login')
  }

  return (
    <AuthContext.Provider value={{ user, token, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
