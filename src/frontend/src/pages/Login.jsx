import { useState } from 'react'
import { useAuth } from '../context/AuthContext'
import '../App.css'

export default function Login() {
  const [isSignUp, setIsSignUp] = useState(false)
  const [name, setName] = useState('')
  const [email, setEmail] = useState('tpg@example.com')
  const [password, setPassword] = useState('password')
  const [error, setError] = useState('')
  const { login, register } = useAuth()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    try {
      if (isSignUp) await register(name, email, password)
      else await login(email, password)
    } catch (err) {
      setError(err.message)
    }
  }

  return (
    <div className="login-page">
      <div className="login-left">
        <div>
          <h1>
            Autonomous <br />
            <span>Billing & Task</span> <br />
            Platform
          </h1>
          <p>
            Manage subscriptions, track usage, and stay on top of your work in
            one clean workspace.
          </p>
        </div>
        <ul className="feature-list">
          <li className="feature-item">
            <div className="feature-icon">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
              </svg>
            </div>
            <div>
              <h3>Automated Billing Cycles</h3>
              <p>Track renewal dates and usage with real-time insights.</p>
            </div>
          </li>
          <li className="feature-item">
            <div className="feature-icon">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <circle cx="12" cy="12" r="10" />
                <path d="M12 6v6l4 2" />
              </svg>
            </div>
            <div>
              <h3>Smart Task Tracking</h3>
              <p>Organize priorities and monitor progress in one place.</p>
            </div>
          </li>
          <li className="feature-item">
            <div className="feature-icon">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                <circle cx="12" cy="12" r="3" />
              </svg>
            </div>
            <div>
              <h3>Always-on Reliability</h3>
              <p>Secure, mock-first architecture ready for production.</p>
            </div>
          </li>
        </ul>
        <div className="login-footer">© 2024 BillingCycle. All rights reserved.</div>
      </div>
      <div className="login-right">
        <form className="login-box" onSubmit={handleSubmit}>
          <h2>{isSignUp ? 'Create Account' : 'Welcome Back'}</h2>
          <p className="login-sub">
            {isSignUp
              ? 'Sign up to start managing your account.'
              : 'Sign in to your account to continue'}
          </p>
          {isSignUp && (
            <div className="form-field">
              <label>Full name</label>
              <input
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
            </div>
          )}
          <div className="form-field">
            <label>Email Address</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
          <div className="form-field">
            <label>Password</label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>
          <label className="checkbox">
            <input type="checkbox" defaultChecked /> Keep me signed in
          </label>
          {error && <p className="error-text">{error}</p>}
          <button type="submit" className="btn">
            {isSignUp ? 'Sign Up' : 'Sign In'}
          </button>
          <div className="login-toggle">
            {isSignUp ? 'Already have an account? ' : "Don't have an account? "}
            <button type="button" onClick={() => setIsSignUp((v) => !v)}>
              {isSignUp ? 'Sign In' : 'Sign Up'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
