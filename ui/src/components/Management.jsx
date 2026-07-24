/* =====================================================================
   SOVEREIGN STORES · STORE MANAGEMENT (docs/04 screen 2)
   Owner & co-owner controls; employees see what their flags allow.
   Sections: Overview · Stock & Storage · Employees · Ledgers · Storefront.
   ===================================================================== */

import { useRef, useState } from 'react'
import { post } from '../nui.js'
import { ItemArt } from './Storefront.jsx'
import {
  Monogram, StatTile, StatusChip, fmtMoney, fmtAgo,
  IconLedger, IconBank, IconPulse, IconClock, IconShield,
} from './kit.jsx'

const PERM_FLAGS = [
  { bit: 1, label: 'Stock' },
  { bit: 2, label: 'Deposit' },
  { bit: 4, label: 'Withdraw' },
  { bit: 8, label: 'Prices' },
  { bit: 16, label: 'Storefront' },
]
const hasPerm = (mask, bit) => ((mask || 0) & bit) !== 0

const SECTIONS = [
  { key: 'overview', label: 'Overview' },
  { key: 'stock', label: 'Stock & Storage', need: 1 },
  { key: 'staff', label: 'Employees', boss: true },
  { key: 'ledgers', label: 'Ledgers' },
  { key: 'storefront', label: 'Storefront', need: 16 },
]

export default function Management({ initial }) {
  const [data, setData] = useState(initial)
  const [section, setSection] = useState('overview')
  const [toast, setToast] = useState(null)
  const toastTimer = useRef(null)

  const say = (kind, text) => {
    clearTimeout(toastTimer.current)
    setToast({ kind, text })
    toastTimer.current = setTimeout(() => setToast(null), 3000)
  }

  const refresh = async () => {
    const res = await post('mgmtRefresh')
    if (res?.ok) setData(res)
  }

  const ERRS = {
    no_code: 'The Bureau must stamp a store code before guns can be sold here.',
    not_gunsmith: 'This store isn\'t licensed for firearms — only a Gunsmith/Weapons charter runs a gun counter.',
    use_weapon_listing: 'Weapons go on the gun counter — use List Weapon.',
    unknown_weapon: "That weapon isn't in the county catalog.",
    bad_model: "That cashier isn't on the approved list.",
    not_in_storage: "The back room doesn't hold that many.",
    not_on_shelf: "The shelf doesn't hold that many.",
    cant_carry: "You can't carry that much.",
    not_carried: "You aren't carrying that.",
    insufficient: "The ledger can't cover that.",
    no_permission: "You don't have the authority for that.",
  }

  const act = async (action, payload, okMsg) => {
    const res = await post('mgmtAction', { action, payload })
    if (res?.ok) { say('good', okMsg || 'Done.'); await refresh(); return true }
    say('bad', ERRS[res?.error] || 'Refused: ' + (res?.error || 'no response'))
    return false
  }

  const s = data.store
  const me = data.me
  const isBoss = me.role === 'owner' || me.role === 'coowner'

  const visible = SECTIONS.filter((sec) =>
    (!sec.boss || isBoss) && (!sec.need || isBoss || hasPerm(me.permissions, sec.need)))

  return (
    <div className="panel bureau">
      <div className="bureau__cols">
        <aside className="rail">
          <div className="rail__id">
            {s.code ? <span className="codechip codechip--lg">{s.code}</span> : <Monogram text={s.name} size="sm" />}
            <div>
              <div className="rail__eyebrow">{s.category}</div>
              <div className="rail__title">Store Management</div>
            </div>
          </div>
          <div className="rail__user">
            <span className="rail__usericon"><IconShield /></span>
            <div>
              <div className="rail__username">{me.name}</div>
              <div className="rail__userrole">{me.role === 'coowner' ? 'Co-Owner' : me.role.charAt(0).toUpperCase() + me.role.slice(1)}</div>
            </div>
          </div>
          <div className="rail__label">Workspace</div>
          <nav className="rail__nav">
            {visible.map((sec) => (
              <button key={sec.key} className={'rail__item' + (section === sec.key ? ' on' : '')}
                onClick={() => setSection(sec.key)}>
                <span>{sec.label}</span>
                {sec.key === 'staff' && <i className="rail__badge">{data.staff.length}/{data.maxEmployees + 1}</i>}
                {sec.key === 'stock' && <i className="rail__badge">{data.stock.length}</i>}
              </button>
            ))}
          </nav>
          <button className="rail__close" onClick={() => post('mgmtClose')}>✕ Close panel</button>
        </aside>

        <main className="deck">
          <header className="deck__head">
            <div>
              <div className="deck__eyebrow">Owner & Co-Owner Controls</div>
              <h1 className="deck__title">{visible.find((x) => x.key === section)?.label || s.name}</h1>
            </div>
            <div className="deck__headside">
              <StatusChip status={s.taxState === 'delinquent' ? 'tax_delinquent' : s.status} />
              {(isBoss || hasPerm(me.permissions, 16)) && (
                <button className={s.status === 'open' ? 'primary' : 'primary primary--go'}
                  onClick={() => act('set_status', { open: s.status !== 'open' },
                    s.status === 'open' ? 'Store closed.' : 'Store open for business.')}>
                  {s.status === 'open' ? 'Close Store' : 'Open Store'}
                </button>
              )}
            </div>
          </header>

          {toast && <div className={`toast toast--${toast.kind}`}>{toast.text}</div>}

          {section === 'overview' && <Overview data={data} />}
          {section === 'stock' && <StockView data={data} act={act} me={me} isBoss={isBoss} />}
          {section === 'staff' && isBoss && <StaffView data={data} act={act} me={me} />}
          {section === 'ledgers' && <LedgersView data={data} act={act} me={me} isBoss={isBoss} />}
          {section === 'storefront' && <StorefrontView data={data} act={act} />}

          <footer className="deck__foot">
            <span>{s.name}{s.code ? ' · Store Code ' + s.code : ''}</span>
            <span>All figures shown in dollars</span>
          </footer>
        </main>
      </div>
    </div>
  )
}

/* ── Overview ─────────────────────────────────────────────────────── */

function Overview({ data }) {
  const s = data.store
  const max = Math.max(...data.week.bars.map((b) => b.gross), 1)
  return (
    <>
      <div className="tiles">
        <StatTile icon={<IconLedger />} label="Operating Ledger" value={fmtMoney(s.balances.operating)} />
        <StatTile icon={<IconBank />} label="Tax Reserve" value={fmtMoney(s.balances.tax)}
          sub={s.taxRate > 0 ? `${s.taxRate}% of ${fmtMoney(s.purchasePrice)} monthly` : 'no levy set'} />
        <StatTile icon={<IconPulse />} label="Today's Sales" value={fmtMoney(data.today.sales)}
          sub={`${data.today.orders} customer order${data.today.orders === 1 ? '' : 's'}`} />
        <StatTile icon={<IconClock />} label="Staff" value={data.staff.length}
          sub={`of ${data.maxEmployees + 1} positions`} />
      </div>

      <div className="cols2">
        <div className="sheetcard">
          <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">Past seven days</span>
            <h2 className="sheetcard__title">Sales Activity</h2></div></div>
          <div className="bars">
            {data.week.bars.map((b) => (
              <div className="bars__col" key={b.day}>
                <div className="bars__bar" style={{ height: Math.max(4, (b.gross / max) * 100) + '%' }} />
                <span className="bars__day">{b.day.slice(3)}</span>
              </div>
            ))}
          </div>
          <div className="bars__foot">
            <div><span className="subline">Gross sales</span><b className="pos">{fmtMoney(data.week.gross)}</b></div>
            <div><span className="subline">Buy-order payouts</span><b className="neg">−{fmtMoney(data.week.payouts)}</b></div>
            <div><span className="subline">Net movement</span><b>{fmtMoney(data.week.net)}</b></div>
          </div>
        </div>

        <div className="sheetcard">
          <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">Latest activity</span>
            <h2 className="sheetcard__title">Recent Transactions</h2></div></div>
          {data.ledger.length === 0 ? <div className="empty">No transactions yet.</div> : (
            <table className="dtable"><tbody>
              {data.ledger.slice(0, 8).map((h, i) => (
                <tr key={i} className="norow">
                  <td><b>{h.type}</b>{h.note && <span className="subline">{h.note}</span>}</td>
                  <td className={h.amount >= 0 ? 'pos' : 'neg'}>{(h.amount >= 0 ? '+' : '') + fmtMoney(h.amount)}</td>
                  <td className="dim">{fmtAgo(h.created_at)}</td>
                </tr>
              ))}
            </tbody></table>
          )}
        </div>
      </div>
    </>
  )
}

/* ── Stock & Storage ──────────────────────────────────────────────── */

function StockView({ data, act, me, isBoss }) {
  const canPrice = isBoss || hasPerm(me.permissions, 8)
  const canStock = isBoss || hasPerm(me.permissions, 1)
  const [depositing, setDepositing] = useState(false)
  const [listing, setListing] = useState(false)
  const wlabel = (item) => (data.weaponCatalog || []).find((w) => w.name === item)?.label || item
  return (
    <div className="cols2">
      <div className="sheetcard">
        <div className="sheetcard__bar">
          <div><span className="sheetcard__eyebrow">What buyers see</span>
            <h2 className="sheetcard__title">Shelves</h2></div>
          {canStock && (
            <button className="ghost" onClick={() => setListing(true)}>List Product</button>
          )}
        </div>
        {data.stock.length === 0 ? <div className="empty">Nothing shelved — stock the shelves from the back room.</div> : (
          <table className="dtable">
            <thead><tr><th>Item</th><th>Qty</th><th>Price</th><th>Sale</th><th /></tr></thead>
            <tbody>
              {data.stock.map((r) => (
                <tr key={r.item} className="norow">
                  <td><b>{r.item.startsWith('WEAPON_') ? wlabel(r.item) : r.item}</b>
                    <span className="subline">{r.item.startsWith('WEAPON_') ? 'gun counter' : r.category}</span></td>
                  <td className="dim">{r.quantity}</td>
                  <td>{fmtMoney(r.price)}</td>
                  <td className="dim">{r.sale_percent ? r.sale_percent + '%' : '—'}</td>
                  <td>
                    <div className="actions actions--tight">
                      {canPrice && <AskInline label="Price" placeholder="$"
                        onSubmit={(v) => act('set_price', { item: r.item, price: v }, 'Price set.')} />}
                      {canPrice && (r.sale_percent
                        ? <button onClick={() => act('clear_sale', { item: r.item }, 'Sale ended.')}>End sale</button>
                        : <AskInline label="Sale" placeholder="% off, minutes (e.g. 20,120)"
                            onSubmit={(v) => {
                              const [pct, min] = v.split(',').map((x) => x.trim())
                              act('set_sale', { item: r.item, percent: pct, minutes: min }, 'Sale started.')
                            }} />)}
                      <AskInline label="Unshelve" placeholder="qty"
                        onSubmit={(v) => act('unshelve', { item: r.item, qty: v }, 'Moved to the back room.')} />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="sheetcard">
        <div className="sheetcard__bar">
          <div><span className="sheetcard__eyebrow">The physical goods</span>
            <h2 className="sheetcard__title">Back Room</h2></div>
          {canStock && (
            <button className="primary" onClick={() => setDepositing(true)}>Deposit from Satchel</button>
          )}
        </div>
        {data.storage.length === 0 ? <div className="empty">The back room is empty — deposit goods from your satchel.</div> : (
          <table className="dtable">
            <thead><tr><th /><th>Item</th><th>Qty</th><th /></tr></thead>
            <tbody>
              {data.storage.map((r, i) => (
                <tr key={r.name + ':' + i} className="norow">
                  <td style={{ width: 42 }}><ItemArt item={r.name} label={r.label} size="sm" /></td>
                  <td><b>{r.label || r.name}</b></td>
                  <td className="dim">{r.amount}</td>
                  <td>
                    <div className="actions actions--tight">
                      <AskInline label="Shelve" placeholder="qty, price (e.g. 5, 1.25)"
                        onSubmit={(v) => {
                          const [qty, price] = v.split(',').map((x) => x.trim())
                          act('shelve', { item: r.name, qty, price }, 'Shelved.')
                        }} />
                      <AskInline label="Take" placeholder="qty"
                        onSubmit={(v) => act('storage_take', { item: r.name, qty: v }, 'In your satchel.')} />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {depositing && (
        <SatchelPicker satchel={data.satchel || []} onClose={() => setDepositing(false)}
          onDeposit={(item, qty) => { setDepositing(false); act('storage_deposit', { item, qty }, 'Deposited.') }} />
      )}
      {listing && (
        <ProductPicker storage={data.storage || []} catalog={data.weaponCatalog || []}
          isGunStore={data.store.category === 'weapons'} hasCode={!!data.store.code}
          onClose={() => setListing(false)}
          onShelve={(item, qty, price) => { setListing(false); act('shelve', { item, qty, price }, 'Shelved.') }}
          onListWeapon={(weapon, qty, price) => { setListing(false); act('list_weapon', { weapon, qty, price }, 'On the gun counter.') }} />
      )}
    </div>
  )
}

/* List Product (owner ruling 2026-07-24): what a store can shelve is
   determined by its charter category. Every store lists from its back
   room; ONLY a weapons-category store also sees the county gun catalog
   (virtual listings, serial-stamped at sale — docs/05). */
function ProductPicker({ storage, catalog, isGunStore, hasCode, onClose, onShelve, onListWeapon }) {
  const [picked, setPicked] = useState(null)   // { kind, name, label, max?, base? }
  const [qty, setQty] = useState(1)
  const [price, setPrice] = useState('')

  const pickStorage = (r) => { setPicked({ kind: 'storage', name: r.name, label: r.label || r.name, max: r.amount }); setQty(r.amount); setPrice('') }
  const pickWeapon = (w) => { setPicked({ kind: 'weapon', name: w.name, label: w.label, max: 99 }); setQty(1); setPrice(String(w.base)) }

  const cappedQty = Math.min(qty, picked?.max || 1)
  const go = () => {
    if (price.trim() === '' || isNaN(Number(price))) return
    if (picked.kind === 'storage') onShelve(picked.name, cappedQty, price)
    else onListWeapon(picked.name, cappedQty, price)
  }

  return (
    <div className="modal__scrim" onClick={onClose}>
      <div className="modal modal--wide" onClick={(e) => e.stopPropagation()}>
        <div className="modal__eyebrow">Shelves · New Listing</div>
        <h2 className="modal__title">List Product</h2>

        <div className="picker__section">From the back room</div>
        {storage.length === 0 ? (
          <div className="empty">The back room is empty — deposit goods from your satchel first.</div>
        ) : (
          <div className="satchel">
            {storage.map((r, i) => (
              <button key={r.name + ':' + i}
                className={'satchel__slot' + (picked?.kind === 'storage' && picked.name === r.name ? ' on' : '')}
                onClick={() => pickStorage(r)}>
                <ItemArt item={r.name} label={r.label || r.name} size="sm" />
                <span className="satchel__label">{r.label || r.name}</span>
                <span className="satchel__count">×{r.amount}</span>
              </button>
            ))}
          </div>
        )}

        {isGunStore && (
          <>
            <div className="picker__section">County weapon catalog — sold new, serial-stamped</div>
            {!hasCode && (
              <div className="toast toast--bad" style={{ margin: '8px 0 0' }}>
                The Bureau must stamp a store code before guns can be sold — every piece
                carries a serial with your mark.
              </div>
            )}
            <div className="satchel">
              {catalog.map((w) => (
                <button key={w.name} disabled={!hasCode}
                  className={'satchel__slot' + (picked?.kind === 'weapon' && picked.name === w.name ? ' on' : '')}
                  onClick={() => pickWeapon(w)}>
                  <span className="satchel__label">{w.label}</span>
                  <span className="satchel__count">{'$' + Number(w.base).toFixed(2)}</span>
                </button>
              ))}
            </div>
          </>
        )}

        {picked && (
          <div className="satchel__confirm">
            <span>List <b>{picked.label}</b></span>
            <span className="stepper">
              <button onClick={() => setQty(Math.max(1, cappedQty - 1))}>−</button>
              <b>{cappedQty}</b>
              <button onClick={() => setQty(Math.min(picked.max, cappedQty + 1))}>+</button>
            </span>
            <input className="search" style={{ width: 90 }} value={price}
              onChange={(e) => setPrice(e.target.value)} placeholder="$ each" />
            <button className="primary" onClick={go}>List {cappedQty}</button>
          </div>
        )}
        <div className="modal__foot">
          <button onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  )
}

/* Visual satchel picker (ledger II K1): pick goods by sight, never by
   typing database names. */
function SatchelPicker({ satchel, onClose, onDeposit }) {
  const [picked, setPicked] = useState(null)   // { name, label, count }
  const [qty, setQty] = useState(1)

  const pick = (s) => { setPicked(s); setQty(s.count) }

  return (
    <div className="modal__scrim" onClick={onClose}>
      <div className="modal modal--wide" onClick={(e) => e.stopPropagation()}>
        <div className="modal__eyebrow">Back Room · Deposit</div>
        <h2 className="modal__title">Your Satchel</h2>
        {satchel.length === 0 ? (
          <div className="empty">You aren't carrying anything that can be stored.</div>
        ) : (
          <div className="satchel">
            {satchel.map((s) => (
              <button key={s.name}
                className={'satchel__slot' + (picked?.name === s.name ? ' on' : '')}
                onClick={() => pick(s)}>
                <ItemArt item={s.name} label={s.label} size="sm" />
                <span className="satchel__label">{s.label}</span>
                <span className="satchel__count">×{s.count}</span>
              </button>
            ))}
          </div>
        )}
        {picked && (
          <div className="satchel__confirm">
            <span>Deposit <b>{picked.label}</b></span>
            <span className="stepper">
              <button onClick={() => setQty(Math.max(1, qty - 1))}>−</button>
              <b>{Math.min(qty, picked.count)}</b>
              <button onClick={() => setQty(Math.min(picked.count, qty + 1))}>+</button>
            </span>
            <button className="primary" onClick={() => onDeposit(picked.name, Math.min(qty, picked.count))}>
              Deposit {Math.min(qty, picked.count)}
            </button>
          </div>
        )}
        <div className="modal__foot">
          <button onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  )
}

/* ── Employees ────────────────────────────────────────────────────── */

function StaffView({ data, act, me }) {
  const [hiring, setHiring] = useState(null)   // { charid, name } being configured
  const [mask, setMask] = useState(1)
  const [payModel, setPayModel] = useState('hourly')
  const [rate, setRate] = useState('0.50')

  return (
    <div className="sheetcard">
      <div className="sheetcard__bar">
        <div><span className="sheetcard__eyebrow">Roster</span><h2 className="sheetcard__title">Employees</h2></div>
        <FindInline label="+ Hire" postName="mgmtFind" onPick={(c) => setHiring(c)} />
      </div>

      {hiring && (
        <div className="hirecard">
          <b>Hiring {hiring.name}</b>
          <div className="hirecard__perms">
            {PERM_FLAGS.map((f) => (
              <label key={f.bit} className="permcheck">
                <input type="checkbox" checked={hasPerm(mask, f.bit)}
                  onChange={(e) => setMask((m) => e.target.checked ? (m | f.bit) : (m & ~f.bit))} />
                {f.label}
              </label>
            ))}
          </div>
          <div className="hirecard__pay">
            <select value={payModel} onChange={(e) => setPayModel(e.target.value)}>
              <option value="hourly">Hourly</option>
              <option value="daily">Daily</option>
            </select>
            <input value={rate} onChange={(e) => setRate(e.target.value)} placeholder="rate $" />
            <button className="primary" onClick={async () => {
              const ok = await act('hire', { charid: hiring.charid, permissions: mask, payModel, payRate: rate }, 'Hired.')
              if (ok) setHiring(null)
            }}>Hire</button>
            <button onClick={() => setHiring(null)}>Cancel</button>
          </div>
        </div>
      )}

      {data.staff.length === 0 ? <div className="empty">Just you behind the counter.</div> : (
        <table className="dtable">
          <thead><tr><th>Name</th><th>Role</th><th>Permissions</th><th>Pay</th><th /></tr></thead>
          <tbody>
            {data.staff.map((e) => (
              <tr key={e.charid} className="norow">
                <td><b>{e.name}</b></td>
                <td className="dim">{e.role === 'coowner' ? 'Co-Owner' : 'Employee'}</td>
                <td>
                  {e.role === 'coowner' ? <span className="dim">all</span> : (
                    <div className="permrow">
                      {PERM_FLAGS.map((f) => (
                        <label key={f.bit} className="permcheck permcheck--sm">
                          <input type="checkbox" checked={hasPerm(e.permissions, f.bit)}
                            onChange={(ev) => {
                              const next = ev.target.checked ? (e.permissions | f.bit) : (e.permissions & ~f.bit)
                              act('set_employee', { charid: e.charid, permissions: next, payModel: e.payModel, payRate: e.payRate }, 'Permissions updated.')
                            }} />
                          {f.label}
                        </label>
                      ))}
                    </div>
                  )}
                </td>
                <td className="dim">{e.role === 'coowner' ? '—' : `${fmtMoney(e.payRate)} ${e.payModel}`}</td>
                <td>
                  <div className="actions actions--tight">
                    {me.role === 'owner' && e.role === 'employee' && (
                      <button onClick={() => act('set_coowner', { charid: e.charid }, 'Promoted to co-owner.')}>Promote</button>
                    )}
                    <button className="danger" onClick={() => act('fire', { charid: e.charid }, 'Removed from the roster.')}>Fire</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

/* ── Ledgers ──────────────────────────────────────────────────────── */

function LedgersView({ data, act, me, isBoss }) {
  const canDeposit = isBoss || hasPerm(me.permissions, 2)
  const canWithdraw = isBoss || hasPerm(me.permissions, 4)
  return (
    <div className="cols2">
      <div className="sheetcard">
        <div className="sheetcard__bar">
          <div><span className="sheetcard__eyebrow">{fmtMoney(data.store.balances.operating)}</span>
            <h2 className="sheetcard__title">Operating Ledger</h2></div>
          <div className="actions actions--tight">
            {canDeposit && <AskInline label="Deposit" placeholder="$"
              onSubmit={(v) => act('deposit', { account: 'operating', amount: v }, 'Deposited.')} />}
            {canWithdraw && <AskInline label="Withdraw" placeholder="$"
              onSubmit={(v) => act('withdraw', { amount: v }, 'Withdrawn — cash in hand.')} />}
          </div>
        </div>
        <LedgerRows rows={data.ledger} />
      </div>

      <div className="sheetcard">
        <div className="sheetcard__bar">
          <div><span className="sheetcard__eyebrow">{fmtMoney(data.store.balances.tax)} · deposit-only</span>
            <h2 className="sheetcard__title">Tax Reserve</h2></div>
          {canDeposit && <AskInline label="Deposit" placeholder="$"
            onSubmit={(v) => act('deposit', { account: 'tax', amount: v }, 'Set aside for the county.')} />}
        </div>
        <LedgerRows rows={data.taxLedger} />
      </div>
    </div>
  )
}

function LedgerRows({ rows }) {
  if (!rows || rows.length === 0) return <div className="empty">No transactions yet.</div>
  return (
    <table className="dtable"><tbody>
      {rows.map((h, i) => (
        <tr key={i} className="norow">
          <td><b>{h.type}</b></td>
          <td className={h.amount >= 0 ? 'pos' : 'neg'}>{(h.amount >= 0 ? '+' : '') + fmtMoney(h.amount)}</td>
          <td className="dim">{fmtMoney(h.balance_after)}</td>
          <td className="dim">{fmtAgo(h.created_at)}</td>
        </tr>
      ))}
    </tbody></table>
  )
}

/* ── Storefront settings ──────────────────────────────────────────── */

function StorefrontView({ data, act }) {
  const s = data.store
  const b = s.branding || {}
  return (
    <div className="sheetcard">
      <div className="sheetcard__bar"><div><span className="sheetcard__eyebrow">Identity & signage</span>
        <h2 className="sheetcard__title">Storefront</h2></div></div>
      <div className="actions">
        <AskInline label={'Rename (' + s.name + ')'} placeholder="store name"
          onSubmit={(v) => act('rename', { name: v }, 'Renamed — the blip follows.')} />
        <AskInline label={'Tagline' + (b.tagline ? ' (' + b.tagline + ')' : '')} placeholder="under the store name"
          onSubmit={(v) => act('branding', { ...b, tagline: v }, 'Tagline set.')} />
        <AskInline label="Closed message" placeholder="shown while closed"
          onSubmit={(v) => act('branding', { ...b, closed_message: v }, 'Closed notice set.')} />
      </div>
      <p className="mgmt__hint">
        The map blip shows only while the store is open. Buyers see the tagline under your store
        name; the closed message greets anyone who visits outside hours.
      </p>

      <div className="sheetcard__bar" style={{ marginTop: 18 }}>
        <div><span className="sheetcard__eyebrow">Who minds the counter</span>
          <h2 className="sheetcard__title">Cashier</h2></div>
      </div>
      {(data.cashierPeds || []).map((group) => (
        <div key={group.key} className="pedgroup">
          <div className="pedgroup__label">{group.label}</div>
          <div className="pedgroup__row">
            {group.peds.map((ped) => (
              <button key={ped.model}
                className={'pedpick' + (s.npcModel?.toLowerCase() === ped.model.toLowerCase() ? ' on' : '')}
                onClick={() => act('set_cashier', { model: ped.model }, 'The new cashier takes the counter.')}>
                {ped.label}
              </button>
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}

/* ── Inline editors (shared pattern; CEF has no window.prompt) ────── */

function AskInline({ label, placeholder, onSubmit }) {
  const [open, setOpen] = useState(false)
  const [value, setValue] = useState('')
  if (!open) return <button onClick={() => { setValue(''); setOpen(true) }}>{label}…</button>
  const go = () => { setOpen(false); if (value.trim() !== '') onSubmit(value.trim()) }
  return (
    <span className="finder finder--inline">
      <input autoFocus className="search" placeholder={placeholder || ''} value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Enter') go() }} />
      <button className="finder__hit" onClick={go}>Apply</button>
      <button className="finder__cancel" onClick={() => setOpen(false)}>✕</button>
    </span>
  )
}

function FindInline({ label, onPick }) {
  const [open, setOpen] = useState(false)
  const [q, setQ] = useState('')
  const [results, setResults] = useState([])
  const timer = useRef(null)

  const search = (value) => {
    setQ(value)
    clearTimeout(timer.current)
    timer.current = setTimeout(async () => {
      const res = await post('mgmtFind', { query: value })
      setResults(res?.ok ? res.results : [])
    }, 250)
  }

  if (!open) return <button className="primary" onClick={() => setOpen(true)}>{label}</button>
  return (
    <span className="finder finder--inline">
      <input autoFocus className="search" placeholder="Character name…" value={q} onChange={(e) => search(e.target.value)} />
      {results.map((r) => (
        <button key={r.charid} className="finder__hit"
          onClick={() => { setOpen(false); setQ(''); setResults([]); onPick(r) }}>{r.name}</button>
      ))}
      <button className="finder__cancel" onClick={() => { setOpen(false); setQ(''); setResults([]) }}>✕</button>
    </span>
  )
}
