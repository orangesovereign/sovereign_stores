/* =====================================================================
   SOVEREIGN STORES · COMMERCE BUREAU (docs/04 screen 3)
   Server administration: directory, store detail + actions, government
   fund, event log, tax administration, inactivity monitor, county
   letters. Commerce Analytics arrives in Phase 5.
   ===================================================================== */

import { useEffect, useRef, useState } from 'react'
import { post } from '../nui.js'
import {
  Monogram, StatTile, StatusChip, fmtMoney, fmtAgo,
  IconStore, IconBank, IconAlert, IconClock, IconLedger, IconPulse, IconPlus, IconChevron, IconShield,
} from './kit.jsx'

/* Why a chartered store isn't being assessed — shown in place of a state
   chip so the screen explains itself (ledger Phase 4 T1). */
const EXCLUDE_LABEL = {
  no_owner: 'NO OWNER',
  no_levy: 'NO LEVY',
  repossessed: 'REPOSSESSED',
}
const EXCLUDE_WHY = {
  no_owner: 'Nobody holds this charter — assign an owner before the county can bill it.',
  no_levy: 'Purchase price × tax rate comes to nothing. Set both on the store detail.',
  repossessed: 'The county already holds this property.',
}

const SECTIONS = [
  { key: 'directory', label: 'Store Directory' },
  { key: 'detail', label: 'Store Detail' },
  { key: 'fund', label: 'Government Fund' },
  { key: 'events', label: 'Event Log' },
  { key: 'tax', label: 'Tax Administration' },
  { key: 'inactivity', label: 'Inactivity Monitor' },
  { key: 'letters', label: 'County Letters' },
  { key: 'analytics', label: 'Commerce Analytics' },
]

export default function Bureau({ initial }) {
  const [ov, setOv] = useState(initial)          // { tiles, directory }
  const [section, setSection] = useState('directory')
  const [detail, setDetail] = useState(null)
  const [fund, setFund] = useState(null)
  const [events, setEvents] = useState(null)
  const [tax, setTax] = useState(null)
  const [inactivity, setInactivity] = useState(null)
  const [letters, setLetters] = useState(null)
  const [analytics, setAnalytics] = useState(null)
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
    if (key === 'tax') { const r = await post('adminTax'); if (r?.ok) setTax(r) }
    if (key === 'inactivity') { const r = await post('adminInactivity'); if (r?.ok) setInactivity(r) }
    if (key === 'letters') { const r = await post('adminLetters'); if (r?.ok) setLetters(r) }
    if (key === 'analytics') { const r = await post('adminAnalytics', { days: 30 }); if (r) setAnalytics(r) }
    if (key === 'directory') refreshOverview()
    setSection(key)
  }

  /* Force a scheduler pass now. The cycles are DB-dated, so running one
     early is exactly what the county clerk does — not a debug hack. */
  const runCycle = async (which) => {
    const res = await post('adminRunCycle', { which })
    if (!res?.ok) return say('bad', 'The sweep could not run.')
    const r = res.report || {}
    say('good', which === 'inactivity'
      ? `Absence sweep: ${r.warned || 0} warned · ${r.seized || 0} seized.`
      : `Collection: ${r.paid || 0} paid · ${r.delinquent || 0} delinquent · ${r.seized || 0} seized.`)
    await openSection(which === 'inactivity' ? 'inactivity' : 'tax')
    refreshOverview()
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
                {s.soon && <i className="rail__soon">Phase 5</i>}
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

          {section === 'tax' && tax?.ok && (
            <>
              <div className="tiles">
                <StatTile icon={<IconBank />} label="Treasury" value={fmtMoney(tax.fund)} />
                <StatTile icon={<IconAlert />} label="Delinquent" value={tax.delinquent}
                  sub={`${tax.graceHours}h to settle`} tone={tax.delinquent > 0 ? "danger" : undefined} />
                <StatTile icon={<IconClock />} label="Cannot Cover" value={tax.atRisk}
                  sub="reserve + operating short" />
              </div>
              <div className="sheetcard">
                <div className="sheetcard__bar">
                  <div><span className="sheetcard__eyebrow">Every taxable charter</span>
                    <h2 className="sheetcard__title">Assessments</h2></div>
                  <button className="ghost" onClick={() => runCycle('tax')}>Run collection now</button>
                </div>
                {tax.rows.length === 0 ? (
                  <div className="empty">The county has chartered no player stores yet.</div>
                ) : (
                  <table className="dtable">
                    <thead><tr><th>Code</th><th>Store</th><th>Owner</th><th>Due</th><th>Amount</th><th>Reserve</th><th>State</th></tr></thead>
                    <tbody>
                      {tax.rows.map((r) => (
                        <tr key={r.id} className={'norow' + (r.exclude ? ' norow--muted' : '')}
                          onClick={() => openDetail(r.id)}>
                          <td>{r.code ? <span className="codechip">{r.code}</span> : '—'}</td>
                          <td><b>{r.name}</b>
                            {r.exclude === 'no_levy' && (
                              <span className="subline">
                                price {fmtMoney(r.purchasePrice)} · rate {Number(r.taxRate || 0)}%
                              </span>
                            )}
                          </td>
                          <td className="dim">{r.owner || '—'}</td>
                          <td className="dim">{r.exclude ? '—' : (r.dueDate || 'starting')}</td>
                          <td className="num">{r.exclude ? '—' : fmtMoney(r.amount)}</td>
                          <td className={'num ' + (r.exclude ? 'dim' : r.covered ? 'dim' : 'neg')}>
                            {r.exclude ? '—' : fmtMoney(r.reserve)}</td>
                          <td>
                            {r.exclude ? (
                              <span className="chip chip--closed" title={EXCLUDE_WHY[r.exclude]}>
                                {EXCLUDE_LABEL[r.exclude]}
                              </span>
                            ) : (
                              <span className={'chip chip--' + (r.state === 'delinquent' ? 'danger' : r.covered ? 'open' : 'warn')}>
                                {r.state === 'delinquent' ? 'DELINQUENT' : r.covered ? 'COVERED' : 'SHORT'}
                              </span>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
                <p className="mgmt__hint">
                  A store is only assessed once it has an owner AND a levy worth collecting
                  (purchase price × tax rate). Anything greyed above says which of those is missing.
                </p>
              </div>
              <div className="sheetcard">
                <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">Collected</span>
                  <h2 className="sheetcard__title">Collection History</h2></div></div>
                {tax.history.length === 0 ? <div className="empty">Nothing collected yet.</div> : (
                  <table className="dtable"><tbody>
                    {tax.history.map((h, i) => (
                      <tr key={i} className="norow">
                        <td><b>{h.store_name || ('#' + h.store_id)}</b></td>
                        <td className="num neg">{fmtMoney(h.amount)}</td>
                        <td className="dim">{fmtAgo(h.created_at)}</td>
                      </tr>
                    ))}
                  </tbody></table>
                )}
              </div>
            </>
          )}

          {section === 'inactivity' && inactivity?.ok && (
            <div className="sheetcard">
              <div className="sheetcard__bar">
                <div><span className="sheetcard__eyebrow">
                  Warning at {inactivity.warnDays} days · charter revoked at {inactivity.seizeDays}</span>
                  <h2 className="sheetcard__title">Absent Owners</h2></div>
                <button className="ghost" onClick={() => runCycle('inactivity')}>Run absence sweep</button>
              </div>
              {inactivity.rows.length === 0 ? (
                <div className="empty">Every charter has been minded recently.</div>
              ) : (
                <table className="dtable">
                  <thead><tr><th>Code</th><th>Store</th><th>Away</th><th>Days left</th><th>State</th><th></th></tr></thead>
                  <tbody>
                    {inactivity.rows.map((r) => (
                      <tr key={r.id} className="norow">
                        <td>{r.code ? <span className="codechip">{r.code}</span> : '—'}</td>
                        <td><b>{r.name}</b></td>
                        <td className="num">{r.days}d</td>
                        <td className={'num ' + (r.daysLeft <= 5 ? 'neg' : 'dim')}>{r.daysLeft}</td>
                        <td>
                          <span className={'chip chip--' + (r.exempt ? 'open' : r.daysLeft <= 5 ? 'danger' : 'warn')}>
                            {r.exempt ? 'EXEMPT' : r.daysLeft <= 5 ? 'AT RISK' : 'WARNED'}
                          </span>
                        </td>
                        <td><button onClick={() => openDetail(r.id)}>Open</button></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          )}

          {section === 'letters' && letters?.ok && (
            <div className="sheetcard">
              <div className="sheetcard__bar">
                <div><span className="sheetcard__eyebrow">
                  Post office: {letters.postoffice} · {letters.queued} awaiting delivery</span>
                  <h2 className="sheetcard__title">County Letters</h2></div>
              </div>
              <p className="mgmt__hint">
                Every notice the county writes is recorded here first, then handed to the post
                office. While its script-mail door is still shut, letters wait in the queue and
                owners are told in person — nothing is ever lost.
              </p>
              {letters.rows.length === 0 ? <div className="empty">The county has written nothing yet.</div> : (
                <table className="dtable">
                  <thead><tr><th>To</th><th>Subject</th><th>State</th><th>Written</th></tr></thead>
                  <tbody>
                    {letters.rows.map((l) => (
                      <tr key={l.id} className="norow">
                        <td className="dim">#{l.recipient_charid}</td>
                        <td><b>{l.subject}</b></td>
                        <td><span className={'chip chip--' + (l.status === 'sent' ? 'open' : 'warn')}>{l.status.toUpperCase()}</span></td>
                        <td className="dim">{fmtAgo(l.created_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          )}

          {section === 'analytics' && analytics && !analytics.ok && (
            <div className="sheetcard">
              <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">Not yet migrated</span>
                <h2 className="sheetcard__title">Commerce Analytics</h2></div></div>
              <div className="empty">
                The analytics record hasn't been created yet — run the <code>2026-07-30</code> block
                in <code>sql/upgrades.sql</code> and restart. Every store keeps trading meanwhile;
                only this dashboard waits.
              </div>
            </div>
          )}

          {section === 'analytics' && analytics?.ok && (() => {
            const max = Math.max(...analytics.series.map((d) => Math.max(d.sales, d.purchases)), 1)
            const t = analytics.totals
            return (
              <>
                <div className="tiles">
                  <StatTile icon={<IconPulse />} label="Sales" value={fmtMoney(t.sales)}
                    sub={`${t.units} goods · ${analytics.days} days`} />
                  <StatTile icon={<IconBank />} label="Tax Collected" value={fmtMoney(t.taxCollected)}
                    sub={`${analytics.days} days`} />
                  <StatTile icon={<IconLedger />} label="Wages Paid" value={fmtMoney(t.wages)}
                    sub="across all stores" />
                  <StatTile icon={<IconStore />} label="Buy-Order Spend" value={fmtMoney(t.buyOrderSpend)}
                    sub={`${t.buyOrderUnits} goods in`} />
                </div>

                <div className="sheetcard">
                  <div className="sheetcard__bar"><div>
                    <span className="sheetcard__eyebrow">Last {analytics.series.length} days · gross</span>
                    <h2 className="sheetcard__title">Commerce Over Time</h2></div></div>
                  <div className="bars bars--wide">
                    {analytics.series.map((d, i) => (
                      <div className="bars__col" key={i}>
                        <div className="bars__stack">
                          <div className="bars__bar" style={{ height: Math.max(2, (d.sales / max) * 100) + '%' }}
                            title={`sales ${fmtMoney(d.sales)}`} />
                          <div className="bars__bar bars__bar--buy" style={{ height: Math.max(0, (d.purchases / max) * 100) + '%' }}
                            title={`bought ${fmtMoney(d.purchases)}`} />
                        </div>
                        <span className="bars__day">{d.day}</span>
                      </div>
                    ))}
                  </div>
                  <div className="bars__foot">
                    <div><span className="subline">Sales (gold)</span><b className="pos">{fmtMoney(t.sales)}</b></div>
                    <div><span className="subline">Bought in (oxblood)</span><b className="neg">{fmtMoney(t.purchases)}</b></div>
                  </div>
                </div>

                <div className="cols2">
                  <div className="sheetcard">
                    <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">By gross</span>
                      <h2 className="sheetcard__title">Top Goods</h2></div></div>
                    {analytics.topItems.length === 0 ? <div className="empty">Nothing sold yet.</div> : (
                      <table className="dtable"><tbody>
                        {analytics.topItems.map((it, i) => (
                          <tr key={it.item} className="norow">
                            <td className="rank">{i + 1}</td>
                            <td><b>{it.item}</b><span className="subline">{it.units} sold</span></td>
                            <td className="num pos">{fmtMoney(it.gross)}</td>
                          </tr>
                        ))}
                      </tbody></table>
                    )}
                  </div>
                  <div className="sheetcard">
                    <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">By gross</span>
                      <h2 className="sheetcard__title">Busiest Stores</h2></div></div>
                    {analytics.topStores.length === 0 ? <div className="empty">No player-store sales yet.</div> : (
                      <table className="dtable"><tbody>
                        {analytics.topStores.map((st, i) => (
                          <tr key={st.store_id} className="norow" onClick={() => openDetail(st.store_id)}>
                            <td>{st.code ? <span className="codechip">{st.code}</span> : '—'}</td>
                            <td><b>{st.store_name || ('#' + st.store_id)}</b><span className="subline">{st.units} sold</span></td>
                            <td className="num pos">{fmtMoney(st.gross)}</td>
                          </tr>
                        ))}
                      </tbody></table>
                    )}
                  </div>
                </div>
              </>
            )
          })()}

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
                <option value="weapons">Gunsmith / Weapons</option>
                <option value="saloon">Saloon</option>
                <option value="nightclub">Nightclub</option>
                <option value="restaurant">Restaurant</option>
                <option value="bakery">Bakery</option>
                <option value="butcher">Butcher</option>
                <option value="fishing">Fishing</option>
                <option value="pelts">Pelt Trader</option>
                <option value="animals">Animals</option>
                <option value="mining">Mining</option>
                <option value="produce">Produce</option>
                <option value="tailor">Tailor</option>
                <option value="other">Other</option>
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
