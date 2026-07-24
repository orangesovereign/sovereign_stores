/* =====================================================================
   SOVEREIGN STORES · COMMERCE BUREAU (docs/04 screen 3)
   Server administration: directory, store detail + actions, government
   fund, event log. Tax Administration / Analytics / Inactivity Monitor
   arrive with the Phase 4 schedulers.
   ===================================================================== */

import { useEffect, useRef, useState } from 'react'
import { post } from '../nui.js'
import {
  Monogram, StatTile, StatusChip, fmtMoney, fmtAgo,
  IconStore, IconBank, IconAlert, IconClock, IconLedger, IconPulse, IconPlus, IconChevron, IconShield,
} from './kit.jsx'

const SECTIONS = [
  { key: 'directory', label: 'Store Directory' },
  { key: 'detail', label: 'Store Detail' },
  { key: 'fund', label: 'Government Fund' },
  { key: 'events', label: 'Event Log' },
  { key: 'tax', label: 'Tax Administration', soon: true },
  { key: 'analytics', label: 'Commerce Analytics', soon: true },
  { key: 'inactivity', label: 'Inactivity Monitor', soon: true },
]

export default function Bureau({ initial }) {
  const [ov, setOv] = useState(initial)          // { tiles, directory }
  const [section, setSection] = useState('directory')
  const [detail, setDetail] = useState(null)
  const [fund, setFund] = useState(null)
  const [events, setEvents] = useState(null)
  const [assigning, setAssigning] = useState(false)
  const [q, setQ] = useState('')
  const [toast, setToast] = useState(null)
  const toastTimer = useRef(null)

  const say = (kind, text) => {
    clearTimeout(toastTimer.current)
    setToast({ kind, text })
    toastTimer.current = setTimeout(() => setToast(null), 3000)
  }

  const refreshOverview = async () => {
    const res = await post('adminOverview')
    if (res?.ok) setOv(res)
  }

  const openDetail = async (id) => {
    const res = await post('adminStore', { id })
    if (res?.ok) { setDetail(res); setSection('detail') }
    else say('bad', 'Could not load that store.')
  }

  const openSection = async (key) => {
    if (SECTIONS.find((s) => s.key === key)?.soon) return
    if (key === 'fund') { const r = await post('adminFund'); if (r?.ok) setFund(r) }
    if (key === 'events') { const r = await post('adminEvents'); if (r?.ok) setEvents(r) }
    if (key === 'directory') refreshOverview()
    setSection(key)
  }

  const act = async (id, action, payload, okMsg) => {
    const res = await post('adminAction', { id, action, payload })
    if (res?.ok) {
      say('good', okMsg || 'Done.')
      await openDetail(id)
      refreshOverview()
      return true
    }
    say('bad', 'Refused: ' + (res?.error || 'no response'))
    return false
  }

  const needle = q.trim().toLowerCase()
  const rows = (ov?.directory || []).filter((r) =>
    !needle ||
    (r.name || '').toLowerCase().includes(needle) ||
    (r.owner || '').toLowerCase().includes(needle) ||
    (r.code || '').toLowerCase().includes(needle))

  return (
    <div className="panel bureau">
      <div className="bureau__cols">
        <aside className="rail">
          <div className="rail__id">
            <Monogram text="SC" />
            <div>
              <div className="rail__eyebrow">Territorial Office</div>
              <div className="rail__title">Commerce Bureau</div>
            </div>
          </div>
          <div className="rail__user">
            <span className="rail__usericon"><IconShield /></span>
            <div>
              <div className="rail__username">Administrator</div>
              <div className="rail__userrole">Chief Commerce Officer</div>
            </div>
          </div>
          <div className="rail__label">Workspace</div>
          <nav className="rail__nav">
            {SECTIONS.map((s) => (
              <button
                key={s.key}
                className={'rail__item' + (section === s.key ? ' on' : '') + (s.soon ? ' soon' : '')}
                onClick={() => openSection(s.key)}
                disabled={s.soon}
              >
                <span>{s.label}</span>
                {s.key === 'directory' && ov?.tiles && <i className="rail__badge">{ov.tiles.stores}</i>}
                {s.soon && <i className="rail__soon">Phase 4</i>}
              </button>
            ))}
          </nav>
          <button className="rail__close" onClick={() => post('adminClose')}>✕ Close panel</button>
        </aside>

        <main className="deck">
          <header className="deck__head">
            <div>
              <div className="deck__eyebrow">Server Administration</div>
              <h1 className="deck__title">{SECTIONS.find((s) => s.key === section)?.label}</h1>
            </div>
            <button className="primary" onClick={() => setAssigning(true)}><IconPlus /> Assign Store</button>
          </header>

          {toast && <div className={`toast toast--${toast.kind}`}>{toast.text}</div>}

          {section === 'directory' && ov?.tiles && (
            <>
              <div className="tiles">
                <StatTile icon={<IconStore />} label="Player Stores" value={ov.tiles.stores}
                  sub={`${ov.tiles.open} currently open`} />
                <StatTile icon={<IconBank />} label="Government Fund" value={fmtMoney(ov.tiles.fund)} />
                <StatTile icon={<IconAlert />} label="Delinquent" value={ov.tiles.delinquent}
                  tone={ov.tiles.delinquent > 0 ? 'danger' : null} />
                <StatTile icon={<IconClock />} label="Inactivity Flags" value={ov.tiles.inactivityFlags} />
              </div>

              <div className="sheetcard">
                <div className="sheetcard__bar">
                  <div>
                    <span className="sheetcard__eyebrow">All Player Businesses</span>
                    <h2 className="sheetcard__title">Store Directory</h2>
                  </div>
                  <input className="search" placeholder="Search stores or owners…" value={q} onChange={(e) => setQ(e.target.value)} />
                </div>
                {rows.length === 0 ? (
                  <div className="empty">{ov.directory.length === 0
                    ? 'No player stores yet — press Assign Store to charter the first one.'
                    : 'Nothing matches that search.'}</div>
                ) : (
                  <table className="dtable">
                    <thead><tr><th>Code</th><th>Store</th><th>Category</th><th>Owner</th><th>Status</th><th>Last Login</th><th /></tr></thead>
                    <tbody>
                      {rows.map((r) => (
                        <tr key={r.id} onClick={() => openDetail(r.id)}>
                          <td>{r.code ? <span className="codechip">{r.code}</span> : <span className="dim">—</span>}</td>
                          <td><b>{r.name}</b><span className="subline">Player Store</span></td>
                          <td className="dim">{r.category}</td>
                          <td>{r.owner || <span className="dim">—</span>}</td>
                          <td><StatusChip status={r.flag !== 'none' ? r.flag : r.status} /></td>
                          <td className="dim">{fmtAgo(r.lastLogin)}</td>
                          <td className="chev"><IconChevron /></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>
            </>
          )}

          {section === 'detail' && (detail?.ok
            ? <Detail data={detail} act={act} say={say} />
            : <div className="empty">Pick a store from the directory.</div>)}

          {section === 'fund' && fund?.ok && (
            <div className="sheetcard">
              <div className="sheetcard__bar">
                <div>
                  <span className="sheetcard__eyebrow">County Treasury</span>
                  <h2 className="sheetcard__title">{fmtMoney(fund.balance)}</h2>
                </div>
              </div>
              <table className="dtable">
                <thead><tr><th>Type</th><th>Amount</th><th>Balance</th><th>Store</th><th>Note</th><th>When</th></tr></thead>
                <tbody>
                  {fund.history.map((h, i) => (
                    <tr key={i} className="norow">
                      <td>{h.type}</td>
                      <td className={h.amount >= 0 ? 'pos' : 'neg'}>{(h.amount >= 0 ? '+' : '') + fmtMoney(h.amount)}</td>
                      <td className="dim">{fmtMoney(h.balance_after)}</td>
                      <td className="dim">{h.ref_store_id || '—'}</td>
                      <td className="dim">{h.note || '—'}</td>
                      <td className="dim">{fmtAgo(h.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {section === 'events' && events?.ok && (
            <div className="sheetcard">
              <div className="sheetcard__bar">
                <div>
                  <span className="sheetcard__eyebrow">Everything, server-wide</span>
                  <h2 className="sheetcard__title">Event Log</h2>
                </div>
              </div>
              <table className="dtable">
                <thead><tr><th>Store</th><th>Event</th><th>Actor</th><th>Target</th><th>When</th></tr></thead>
                <tbody>
                  {events.events.map((e, i) => (
                    <tr key={i} className="norow">
                      <td>{e.store_name || <span className="dim">county</span>}</td>
                      <td><b>{e.kind}</b></td>
                      <td className="dim">{e.actor_charid || 'system'}</td>
                      <td className="dim">{e.target_charid || '—'}</td>
                      <td className="dim">{fmtAgo(e.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <footer className="deck__foot">
            <span>Sovereign County Commerce Bureau · Live server overview</span>
            <span>All figures shown in dollars</span>
          </footer>
        </main>
      </div>

      {assigning && (
        <AssignStore
          onClose={() => setAssigning(false)}
          onDone={async (id) => { setAssigning(false); await refreshOverview(); if (id) openDetail(id) }}
          say={say}
        />
      )}
    </div>
  )
}

/* ── Store detail ─────────────────────────────────────────────────── */

function Detail({ data, act, say }) {
  const s = data.store
  const [armReposs, setArmReposs] = useState(false)

  return (
    <>
      <div className="detailhead">
        <div className="detailhead__id">
          {s.code ? <span className="codechip codechip--lg">{s.code}</span> : <Monogram text={s.name} size="sm" />}
          <div>
            <h2 className="detailhead__name">{s.name}</h2>
            <span className="subline">{s.category} · store #{s.id}</span>
          </div>
        </div>
        <StatusChip status={s.taxState === 'delinquent' ? 'tax_delinquent' : s.status} />
      </div>

      <div className="tiles">
        <StatTile icon={<IconLedger />} label="Operating Ledger" value={fmtMoney(s.balances.operating)} />
        <StatTile icon={<IconBank />} label="Tax Reserve" value={fmtMoney(s.balances.tax)}
          sub={`rate ${s.taxRate}% of ${fmtMoney(s.purchasePrice)}`} />
        <StatTile icon={<IconPulse />} label="Owner" value={s.owner ? s.owner.name : '—'}
          sub={s.owner ? 'last login ' + fmtAgo(s.owner.lastLogin) : 'unassigned'} />
        <StatTile icon={<IconClock />} label="Staff" value={data.staff.length}
          sub={s.inactivityExemptUntil ? 'exempt until ' + s.inactivityExemptUntil : null} />
      </div>

      <div className="cols2">
        <div className="sheetcard">
          <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">Ownership & Levies</span>
            <h2 className="sheetcard__title">Bureau Actions</h2></div></div>
          <div className="actions">
            <FindAction label="Assign owner" onPick={(c) => act(s.id, 'assign_owner', { charid: c.charid }, 'Owner assigned.')} />
            <FindAction label="Force-transfer to" onPick={(c) => act(s.id, 'transfer', { charid: c.charid }, 'Transferred.')} />
            <AskAction label="Set code" hint={s.code || 'BWM'} placeholder="3 letters"
              onSubmit={(v) => act(s.id, 'set_code', { code: v }, 'Code set.')} />
            <AskAction label="Set purchase price" hint={String(s.purchasePrice)} placeholder="$"
              onSubmit={(v) => act(s.id, 'set_price', { price: v }, 'Price recorded.')} />
            <AskAction label="Set tax rate" hint={String(s.taxRate)} placeholder="%/month"
              onSubmit={(v) => act(s.id, 'set_tax_rate', { rate: v }, 'Tax rate set.')} />
            <AskAction label="Ledger adjustment" placeholder="signed $, operating"
              onSubmit={(v) => act(s.id, 'adjust', { amount: v }, 'Adjustment written.')} />
            <AskAction label="Inactivity exemption" placeholder="YYYY-MM-DD"
              onSubmit={(v) => act(s.id, 'exempt_inactivity', { untilDate: v }, 'Exemption set.')} />
            <button onClick={() => act(s.id, 'force_close', {}, 'Closed.')}>Force close</button>
            <button
              className={'danger' + (armReposs ? ' armed' : '')}
              onClick={() => {
                if (!armReposs) { setArmReposs(true); setTimeout(() => setArmReposs(false), 4000); return }
                setArmReposs(false)
                act(s.id, 'repossess', { reason: 'admin repossession' }, 'Repossessed — ledgers swept to the fund.')
              }}
            >
              {armReposs ? 'Click again to repossess' : 'Repossess'}
            </button>
          </div>
        </div>

        <div className="sheetcard">
          <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">Roster</span>
            <h2 className="sheetcard__title">Staff</h2></div></div>
          {data.staff.length === 0 ? (
            <div className="empty">No co-owner or employees.</div>
          ) : (
            <table className="dtable">
              <thead><tr><th>Name</th><th>Role</th><th>Permissions</th></tr></thead>
              <tbody>
                {data.staff.map((e) => (
                  <tr key={e.charid} className="norow">
                    <td><b>{e.name}</b></td>
                    <td className="dim">{e.role}</td>
                    <td className="dim">{e.role === 'coowner' ? 'all' : (e.permLabels || []).join(', ') || 'none'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      <div className="cols2">
        <div className="sheetcard">
          <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">Operating account</span>
            <h2 className="sheetcard__title">Recent Ledger</h2></div></div>
          <LedgerTable rows={data.ledger} />
        </div>
        <div className="sheetcard">
          <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">Store history</span>
            <h2 className="sheetcard__title">Events</h2></div></div>
          <table className="dtable">
            <tbody>
              {data.events.map((e, i) => (
                <tr key={i} className="norow">
                  <td><b>{e.kind}</b></td>
                  <td className="dim">{e.actor_charid || 'system'}</td>
                  <td className="dim">{fmtAgo(e.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  )
}

function LedgerTable({ rows }) {
  if (!rows || rows.length === 0) return <div className="empty">No transactions yet.</div>
  return (
    <table className="dtable">
      <thead><tr><th>Type</th><th>Amount</th><th>Balance</th><th>When</th></tr></thead>
      <tbody>
        {rows.map((h, i) => (
          <tr key={i} className="norow">
            <td>{h.type}</td>
            <td className={h.amount >= 0 ? 'pos' : 'neg'}>{(h.amount >= 0 ? '+' : '') + fmtMoney(h.amount)}</td>
            <td className="dim">{fmtMoney(h.balance_after)}</td>
            <td className="dim">{fmtAgo(h.created_at)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}

/* ── Inline single-value action (window.prompt is dead in CEF) ────── */

function AskAction({ label, hint, placeholder, onSubmit }) {
  const [open, setOpen] = useState(false)
  const [value, setValue] = useState('')

  if (!open) return <button onClick={() => { setValue(hint || ''); setOpen(true) }}>{label}…</button>
  const go = () => { setOpen(false); if (value.trim() !== '') onSubmit(value.trim()) }
  return (
    <div className="finder">
      <input autoFocus className="search" placeholder={placeholder || ''} value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Enter') go() }} />
      <button className="finder__hit" onClick={go}>Apply</button>
      <button className="finder__cancel" onClick={() => setOpen(false)}>Cancel</button>
    </div>
  )
}

/* ── Character search action ──────────────────────────────────────── */

function FindAction({ label, onPick }) {
  const [open, setOpen] = useState(false)
  const [q, setQ] = useState('')
  const [results, setResults] = useState([])
  const timer = useRef(null)

  const search = (value) => {
    setQ(value)
    clearTimeout(timer.current)
    timer.current = setTimeout(async () => {
      const res = await post('adminFind', { query: value })
      setResults(res?.ok ? res.results : [])
    }, 250)
  }

  if (!open) return <button onClick={() => setOpen(true)}>{label}…</button>
  return (
    <div className="finder">
      <input autoFocus className="search" placeholder="Character name…" value={q} onChange={(e) => search(e.target.value)} />
      {results.map((r) => (
        <button key={r.charid} className="finder__hit"
          onClick={() => { setOpen(false); setQ(''); setResults([]); onPick(r) }}>
          {r.name} <span className="dim">· {fmtAgo(r.lastLogin)}</span>
        </button>
      ))}
      <button className="finder__cancel" onClick={() => { setOpen(false); setQ(''); setResults([]) }}>Cancel</button>
    </div>
  )
}

/* ── Assign Store form ────────────────────────────────────────────── */

function AssignStore({ onClose, onDone, say }) {
  const [form, setForm] = useState({
    name: '', category: 'general', code: '', price: '', rate: '', useMyPosition: true,
  })
  const [owner, setOwner] = useState(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)   // shown INSIDE the modal — deck toasts hide behind it
  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.type === 'checkbox' ? e.target.checked : e.target.value }))

  const submit = async () => {
    if (busy) return
    if (form.name.trim().length < 3) return setError('The store needs a real name.')
    setBusy(true)
    setError(null)
    const res = await post('adminCreate', {
      name: form.name.trim(), category: form.category,
      code: form.code.trim().toUpperCase(), price: form.price, rate: form.rate,
      ownerCharid: owner?.charid, useMyPosition: form.useMyPosition,
    })
    setBusy(false)
    if (res?.ok) {
      say('good', res.warning === 'code_taken'
        ? 'Chartered — but that code is already taken. Set a different one from the store detail.'
        : 'Store chartered.')
      onDone(res.id)
    } else {
      setError('Refused: ' + (res?.error || 'no response'))
    }
  }

  return (
    <div className="modal__scrim" onClick={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className="modal">
        <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">Charter a business</span>
          <h2 className="sheetcard__title">Assign Store</h2></div></div>
        <div className="form">
          <label>Store name<input value={form.name} onChange={set('name')} placeholder="Blackwater Mercantile" /></label>
          <div className="form__row">
            <label>Category
              <select value={form.category} onChange={set('category')}>
                <option value="general">General Store</option>
                <option value="fishing">Fishing</option>
                <option value="pelts">Pelt Trader</option>
                <option value="butcher">Butcher</option>
                <option value="saloon">Saloon</option>
                <option value="tailor">Tailor</option>
              </select>
            </label>
            <label>Code (3 letters)<input value={form.code} onChange={set('code')} maxLength={3} placeholder="BWM" /></label>
          </div>
          <div className="form__row">
            <label>Purchase price ($)<input type="number" value={form.price} onChange={set('price')} placeholder="1500" /></label>
            <label>Tax rate (%/month)<input type="number" value={form.rate} onChange={set('rate')} placeholder="5" /></label>
          </div>
          <label className="form__owner">Owner (optional)
            {owner
              ? <button className="finder__hit" onClick={() => setOwner(null)}>{owner.name} ✕</button>
              : <FindAction label="Find character" onPick={setOwner} />}
          </label>
          <label className="form__check">
            <input type="checkbox" checked={form.useMyPosition} onChange={set('useMyPosition')} />
            Register counter at my current position
          </label>
        </div>
        {error && <div className="toast toast--bad" style={{ margin: '12px 0 0' }}>{error}</div>}
        <div className="modal__foot">
          <button onClick={onClose}>Cancel</button>
          <button className="primary" disabled={busy} onClick={submit}>{busy ? 'Filing…' : 'Charter the store'}</button>
        </div>
      </div>
    </div>
  )
}
