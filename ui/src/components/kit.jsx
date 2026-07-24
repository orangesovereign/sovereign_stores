/* Shared Sovereign UI kit (docs/04): monogram, stat tiles, status chips,
   extra icons. Minimal geometric SVGs only. */

const base = {
  width: 16, height: 16, viewBox: '0 0 16 16',
  fill: 'none', stroke: 'currentColor', strokeWidth: 1.5,
  strokeLinecap: 'round', strokeLinejoin: 'round',
}

export const IconShield = () => (
  <svg {...base}><path d="M8 2l5 1.8v3.4c0 3.2-2 5.6-5 6.8-3-1.2-5-3.6-5-6.8V3.8z" /></svg>
)
export const IconBank = () => (
  <svg {...base}><path d="M2.5 6.5L8 3l5.5 3.5M3.5 6.5v5M6.5 6.5v5M9.5 6.5v5M12.5 6.5v5M2.5 13h11" /></svg>
)
export const IconClock = () => (
  <svg {...base}><circle cx="8" cy="8" r="5.5" /><path d="M8 5v3.2l2.2 1.3" /></svg>
)
export const IconLedger = () => (
  <svg {...base}><rect x="3.5" y="2.5" width="9" height="11" /><path d="M6 5.5h4M6 8h4M6 10.5h2.5" /></svg>
)
export const IconAlert = () => (
  <svg {...base}><circle cx="8" cy="8" r="5.5" /><path d="M8 5.2v3.4M8 10.8v.2" /></svg>
)
export const IconPlus = () => (
  <svg {...base}><path d="M8 3.5v9M3.5 8h9" /></svg>
)
export const IconChevron = () => (
  <svg {...base}><path d="M6 3.5L10.5 8 6 12.5" /></svg>
)
export const IconStore = () => (
  <svg {...base}><path d="M3 6.5L4 3h8l1 3.5M3.5 6.5V13h9V6.5M6.5 13V9.5h3V13" /></svg>
)
export const IconPulse = () => (
  <svg {...base}><path d="M2 8.5h2.6l1.6-4 2.6 7 1.6-3h3.6" /></svg>
)

export function Monogram({ text, size }) {
  return (
    <div className={'monogram' + (size === 'sm' ? ' monogram--sm' : '')}>
      <span>{(text || '?').slice(0, 2)}</span>
    </div>
  )
}

export function StatTile({ icon, label, value, sub, tone }) {
  return (
    <div className={'tile' + (tone ? ' tile--' + tone : '')}>
      <span className="tile__icon">{icon}</span>
      <div className="tile__body">
        <span className="tile__label">{label}</span>
        <span className="tile__value">{value}</span>
        {sub && <span className="tile__sub">{sub}</span>}
      </div>
    </div>
  )
}

const CHIP = {
  open: { text: 'Open', cls: 'chip--open' },
  closed: { text: 'Closed', cls: 'chip--closed' },
  repossessed: { text: 'Repossessed', cls: 'chip--danger chip--fill' },
  tax_delinquent: { text: 'Tax Delinquent', cls: 'chip--danger' },
  inactive_warning: { text: 'Inactive Warning', cls: 'chip--warn' },
  current: { text: 'Current', cls: 'chip--open' },
  delinquent: { text: 'Delinquent', cls: 'chip--danger' },
}

export function StatusChip({ status }) {
  const c = CHIP[status] || { text: status, cls: 'chip--closed' }
  return <span className={'chip ' + c.cls}>{c.text}</span>
}

export const fmtMoney = (n) => {
  const v = Math.round((Number(n) || 0) * 100) / 100
  const sign = v < 0 ? '-' : ''
  return sign + '$' + Math.abs(v).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

export function fmtAgo(dateStr) {
  if (!dateStr) return '—'
  const then = new Date(String(dateStr).replace(' ', 'T'))
  if (isNaN(then)) return String(dateStr)
  const days = Math.floor((Date.now() - then.getTime()) / 86400000)
  if (days <= 0) return 'Today'
  if (days === 1) return 'Yesterday'
  return days + 'd ago'
}
