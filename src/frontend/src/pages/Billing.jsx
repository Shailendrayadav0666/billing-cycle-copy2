import { useCallback, useEffect, useState } from 'react'
import { useAuth } from '../context/AuthContext'
import '../App.css'

function InfoIcon() {
  return (
    <svg
      className="info-icon"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <circle cx="12" cy="12" r="10" />
      <line x1="12" y1="16" x2="12" y2="12" />
      <line x1="12" y1="8" x2="12.01" y2="8" />
    </svg>
  )
}

function UsageIcon({ id }) {
  const iconStyle = { width: 18, height: 18, color: '#475569' }
  if (id === 'chat-credits') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={iconStyle}>
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
      </svg>
    )
  }
  if (id === 'chatbots') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={iconStyle}>
        <rect x="3" y="11" width="18" height="10" rx="2" />
        <circle cx="8" cy="7" r="1" />
        <circle cx="16" cy="7" r="1" />
        <path d="M12 11v10" />
      </svg>
    )
  }
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={iconStyle}>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="16" y1="13" x2="8" y2="13" />
      <line x1="16" y1="17" x2="8" y2="17" />
    </svg>
  )
}

function IncludedUsageCard({ data }) {
  return (
    <div className="extra-card">
      <div className="extra-title">
        {data.title} <InfoIcon />
      </div>
      {data.items.map((item) => (
        <div key={item.id} className="extra-row">
          <div className="extra-row-header">
            <span>{item.label}</span>
            <span>{item.used_percent}% used</span>
          </div>
          <div className="usage-bar">
            <div
              className="usage-bar-fill"
              style={{ width: `${Math.min(100, item.used_percent)}%` }}
            />
          </div>
          <div className="extra-row-footer">Resets in {item.resets_in}</div>
        </div>
      ))}
    </div>
  )
}

function OnDemandUsageCard({ data }) {
  return (
    <div className="extra-card">
      <div className="extra-title">
        {data.title} <InfoIcon />
      </div>
      <div className="extra-row-space">
        <span className="extra-mute">Remaining balance</span>
        <span className={`extra-value ${data.remaining_balance.startsWith('-') ? 'negative' : ''}`}>
          {data.remaining_balance}
        </span>
      </div>
      <div className="extra-row-space">
        <span className="extra-mute">
          Your on-demand usage <InfoIcon />
        </span>
        <span className="extra-value">{data.your_usage}</span>
      </div>
      <p className="extra-notice">{data.notice}</p>
    </div>
  )
}

function UpgradeModal({ preview, loading, error, onConfirm, onCancel }) {
  return (
    <div className="upgrade-modal-backdrop">
      <div className="upgrade-modal">
        <h3>Upgrade to Premium</h3>
        {loading && <p>Loading preview...</p>}
        {preview && !loading && (
          <div className="upgrade-modal-body">
            <p>
              Current plan: <strong>{preview.current_plan}</strong> ($20/mo)
            </p>
            <p>
              New plan: <strong>{preview.new_plan}</strong> ($40/mo)
            </p>
            <p>Days remaining in current cycle: {preview.days_remaining}</p>
            <p>
              You will be charged <strong>${preview.prorated_charge.toFixed(2)}</strong> today
            </p>
            <p>
              Next renewal price: ${preview.next_renewal_price.toFixed(2)}/month starting{' '}
              {preview.renew_at}
            </p>
          </div>
        )}
        {error && <p className="upgrade-modal-error">{error}</p>}
        <div className="upgrade-modal-actions">
          <button onClick={onCancel} disabled={loading}>
            Cancel
          </button>
          <button
            className="upgrade-modal-confirm"
            onClick={onConfirm}
            disabled={loading || !preview}
          >
            Confirm Upgrade
          </button>
        </div>
      </div>
    </div>
  )
}

export default function Billing() {
  const { token } = useAuth()
  const [data, setData] = useState(null)
  const [showUpgradeModal, setShowUpgradeModal] = useState(false)
  const [upgradePreview, setUpgradePreview] = useState(null)
  const [upgradeLoading, setUpgradeLoading] = useState(false)
  const [upgradeError, setUpgradeError] = useState(null)
  const [successBanner, setSuccessBanner] = useState(null)

  const fetchBilling = useCallback(() => {
    fetch(`/api/billing?email=${encodeURIComponent(token)}`)
      .then((r) => r.json())
      .then(setData)
  }, [token])

  useEffect(() => {
    fetchBilling()
  }, [fetchBilling])

  if (!data) {
    return (
      <div className="page-card">
        <p>Loading billing...</p>
      </div>
    )
  }

  const openUpgradeModal = () => {
    setShowUpgradeModal(true)
    setUpgradeError(null)
    setUpgradeLoading(true)
    fetch(`/api/billing/upgrade-preview?email=${encodeURIComponent(token)}`)
      .then(async (r) => {
        const body = await r.json()
        if (!r.ok) throw new Error(body.message || body.detail || 'Could not load preview')
        setUpgradePreview(body)
      })
      .catch((err) => setUpgradeError(err.message))
      .finally(() => setUpgradeLoading(false))
  }

  const closeUpgradeModal = () => {
    setShowUpgradeModal(false)
    setUpgradePreview(null)
    setUpgradeError(null)
  }

  const confirmUpgrade = () => {
    setUpgradeLoading(true)
    setUpgradeError(null)
    fetch('/api/billing/upgrade', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: token }),
    })
      .then(async (r) => {
        const body = await r.json()
        if (!r.ok) {
          throw new Error(`Payment failed: ${body.message || body.detail}. Your plan has not changed.`)
        }
        setSuccessBanner(`You're now on Premium! $${body.charge.toFixed(2)} was charged.`)
        closeUpgradeModal()
        fetchBilling()
      })
      .catch((err) => setUpgradeError(err.message))
      .finally(() => setUpgradeLoading(false))
  }

  return (
    <div className="page-card">
      <div className="billing-header">
        <div className="billing-titles">
          <h2>Plan & Billing</h2>
          <p>Manage your plan and payments</p>
        </div>
      </div>

      {successBanner && <p className="upgrade-success-banner">{successBanner}</p>}

      <p className="current-label">
        Current plan: <span className="standard-badge">{data.plan_name}</span>
      </p>

      <div className="plan-row">
        <div className="plan-card">
          <div className="plan-top">
            <div>
              <div className="plan-label">Monthly plan</div>
              <p className="plan-price">{data.price}</p>
            </div>
            <div className="badge-group">
              <span className="badge active">Active</span>
            </div>
          </div>
          {data.plan_name === 'Standard' && (
            <button className="upgrade-cta" onClick={openUpgradeModal}>
              Upgrade to Premium
            </button>
          )}
        </div>
        <div className="renew-card">
          <div className="renew-title">Renew at</div>
          <div className="renew-date">{data.renew_at}</div>
        </div>
      </div>

      {showUpgradeModal && (
        <UpgradeModal
          preview={upgradePreview}
          loading={upgradeLoading}
          error={upgradeError}
          onConfirm={confirmUpgrade}
          onCancel={closeUpgradeModal}
        />
      )}

      <div className="section-title">Usage</div>
      <p className="section-sub">Your usage is renewed every month</p>

      <div className="usage-grid">
        {data.usages.map((u) => (
          <div key={u.id} className="usage-card">
            <div className="tooltip">{u.help}</div>
            <div className="usage-icon">
              <UsageIcon id={u.id} />
            </div>
            <div className="usage-label">{u.label}</div>
            <div className="usage-value">
              {u.used} of {u.total}
            </div>
            <div className="usage-bar">
              <div
                className="usage-bar-fill"
                style={{
                  width: `${Math.min(100, (u.used / u.total) * 100)}%`,
                }}
              />
            </div>
          </div>
        ))}
      </div>

      <div className="usage-extras">
        <IncludedUsageCard data={data.included_usage} />
        <OnDemandUsageCard data={data.on_demand_usage} />
      </div>
    </div>
  )
}
