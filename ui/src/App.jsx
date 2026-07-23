/* =====================================================================
   SOVEREIGN STORES · STOREFRONT (concept build — docs/04-UI-DESIGN.md)
   One storefront for every store in the county. Everything shown is
   server-supplied; the UI never invents a price. Type scaled for
   readability (rule zero) — the concept's look, not its font size.
   ===================================================================== */

import { useEffect, useMemo, useRef, useState } from 'react'
import { post, onMessage, itemImage } from './nui.js'
import { CategoryIcon, IconBasket } from './components/Icons.jsx'

const money = (n) => '$' + (Math.round((Number(n) || 0) * 100) / 100).toFixed(2)

const ERRORS = {
  cant_afford: "You can't cover that total.",
  cant_carry: "You can't carry that much",
  bad_line: 'The clerk squints at your order — try again.',
  empty_cart: 'Your basket is empty.',
  too_far: 'Step up to the counter first.',
  job_locked: "This store doesn't serve your line of work.",
  stack_gone: 'Those goods are no longer in your satchel.',
  too_worn: 'The clerk turns that up — too far gone.',
  no_response: 'The clerk seems distracted — try again.',
}
const errText = (res) => {
  const base = ERRORS[res?.error] || ERRORS.no_response
  return res?.item ? `${base} (${res.item}).` : base
}

function ItemArt({ item, label, size }) {
  const [gone, setGone] = useState(false)
  if (gone) return <div className={'art art--empty' + (size ? ' art--' + size : '')}>{(label || '?').slice(0, 1)}</div>
  return <img className={'art' + (size ? ' art--' + size : '')} src={itemImage(item)} alt="" onError={() => setGone(true)} />
}

const salePrice = (e) => e.salePercent ? e.price * (1 - e.salePercent / 100) : e.price

export default function App() {
  const [view, setView] = useState(null)
  const [tab, setTab] = useState('buy')
  const [cat, setCat] = useState('all')
  const [q, setQ] = useState('')
  const [cart, setCart] = useState({})
  const [busy, setBusy] = useState(false)
  const [toast, setToast] = useState(null)
  const toastTimer = useRef(null)

  const say = (kind, text) => {
    clearTimeout(toastTimer.current)
    setToast({ kind, text })
    toastTimer.current = setTimeout(() => setToast(null), 3200)
  }

  useEffect(() => onMessage((msg) => {
    if (msg.action === 'store:open') {
      setView({ store: msg.payload.store, money: msg.payload.money })
      setTab('buy'); setCat('all'); setQ(''); setCart({}); setToast(null)
    }
    if (msg.action === 'store:close') setView(null)
  }), [])

  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape') post('close') }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  const store = view?.store
  const buyList = useMemo(() => {
    if (!store) return []
    const needle = q.trim().toLowerCase()
    return store.buy.filter((e) =>
      (cat === 'all' || e.category === cat) &&
      (!needle || e.label.toLowerCase().includes(needle)))
  }, [store, cat, q])

  const cartLines = useMemo(() => {
    if (!store) return []
    return Object.entries(cart)
      .map(([item, qty]) => {
        const entry = store.buy.find((e) => e.item === item)
        return entry ? { ...entry, qty, unit: salePrice(entry), cost: salePrice(entry) * qty } : null
      })
      .filter(Boolean)
  }, [store, cart])
  const subtotal = cartLines.reduce((s, l) => s + l.cost, 0)
  const fee = 0 // county fee line: $0.00 until a levy ever exists (docs/04)
  const total = subtotal + fee

  if (!store) return null

  const addToCart = (item) =>
    setCart((c) => ({ ...c, [item]: Math.min((c[item] || 0) + 1, 99) }))
  const setQty = (item, qty) =>
    setCart((c) => {
      const next = { ...c }
      if (qty <= 0) delete next[item]
      else next[item] = Math.min(qty, 99)
      return next
    })

  const checkout = async () => {
    if (busy || cartLines.length === 0) return
    setBusy(true)
    const res = await post('checkout', {
      store: store.key,
      cart: cartLines.map((l) => ({ item: l.item, qty: l.qty })),
    })
    setBusy(false)
    if (res?.ok) {
      setCart({})
      setView((v) => ({ ...v, money: res.money }))
      say('good', `Purchase complete — ${money(res.total)}.`)
    } else {
      if (res?.money != null) setView((v) => ({ ...v, money: res.money }))
      say('bad', errText(res))
    }
  }

  const sellStack = async (entry, stack, qty) => {
    if (busy || qty < 1) return
    setBusy(true)
    const res = await post('sell', {
      store: store.key,
      entries: [{ item: entry.item, qty, percentage: stack.percentage ?? null }],
    })
    if (res?.ok) {
      say('good', `Sold — ${money(res.total)} received.`)
      const fresh = await post('refresh', { store: store.key })
      if (fresh?.ok) setView({ store: fresh.store, money: fresh.money })
      else setView((v) => ({ ...v, money: res.money }))
    } else {
      say('bad', errText(res))
    }
    setBusy(false)
  }

  const cats = [{ key: 'all', label: 'All Goods' }, ...store.categories]
  const sellCount = store.sell.length

  return (
    <div className="scrim">
      <div className="panel">

        <header className="masthead">
          <div className="masthead__id">
            <div className="monogram"><span>{(store.label || '?').slice(0, 1)}</span></div>
            <div className="masthead__names">
              <div className="masthead__est">{store.est || '~ SOVEREIGN COUNTY ~'}</div>
              <h1 className="masthead__name">{store.label}</h1>
              {store.tagline && <div className="masthead__tag">{store.tagline}</div>}
            </div>
          </div>
          <div className="masthead__side">
            <div className="status">
              <span className="status__label">Store Status</span>
              <span className="status__value"><i className="dot dot--open" />Open for Business</span>
            </div>
            <button className="closebtn" onClick={() => post('close')} aria-label="Close">✕</button>
          </div>
        </header>

        <nav className="tabs">
          <button className={tab === 'buy' ? 'on' : ''} onClick={() => setTab('buy')}>Shop Goods</button>
          {sellCount > 0 && (
            <button className={tab === 'sell' ? 'on' : ''} onClick={() => setTab('sell')}>
              Sell to Store <span className="tabs__badge">{sellCount} wanted</span>
            </button>
          )}
        </nav>

        {toast && <div className={`toast toast--${toast.kind}`}>{toast.text}</div>}

        {tab === 'buy' && (
          <div className="floor">
            <aside className="depts">
              <div className="depts__label">Departments</div>
              {cats.map((c) => (
                <button key={c.key} className={'dept' + (cat === c.key ? ' on' : '')} onClick={() => setCat(c.key)}>
                  <span className="dept__icon"><CategoryIcon id={c.icon || c.key} /></span>
                  <span className="dept__name">{c.label}</span>
                </button>
              ))}
              {store.notice && (
                <div className="notice">
                  <div className="notice__title">Today's notice</div>
                  <div className="notice__body">{store.notice}</div>
                </div>
              )}
            </aside>

            <section className="goods">
              <div className="goods__bar">
                <div className="goods__count">
                  <span className="goods__label">Available Goods</span>
                  <span className="goods__sub">{buyList.length} item{buyList.length === 1 ? '' : 's'} on the shelves</span>
                </div>
                <input
                  className="search" type="text" placeholder="Search the shelves…"
                  value={q} onChange={(e) => setQ(e.target.value)}
                />
              </div>

              {buyList.length === 0 ? (
                <div className="empty">Nothing on these shelves.</div>
              ) : (
                <div className="grid">
                  {buyList.map((e) => (
                    <div key={e.item} className="card">
                      <div className="card__well">
                        {e.salePercent ? <span className="card__sale">{e.salePercent}% OFF</span> : null}
                        {e.stock != null && (
                          <span className={'card__stock' + (e.stock <= 8 ? ' card__stock--low' : '')}>
                            {e.stock <= 8 ? `Only ${e.stock} left` : `${e.stock} in stock`}
                          </span>
                        )}
                        <ItemArt item={e.item} label={e.label} size="lg" />
                      </div>
                      <div className="card__cat">{catLabel(store, e.category)}</div>
                      <div className="card__name">{e.label}</div>
                      {e.desc && <div className="card__desc">{e.desc}</div>}
                      <div className="card__foot">
                        <span className="card__price">
                          {e.salePercent ? <s>{money(e.price)}</s> : null}
                          <b className={e.salePercent ? 'onsale' : ''}>{money(salePrice(e))}</b>
                        </span>
                        <button className="card__add" onClick={() => addToCart(e.item)} aria-label={'Add ' + e.label}>
                          <IconBasket />
                          {cart[e.item] ? <i className="card__count">{cart[e.item]}</i> : null}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </section>

            <aside className="order">
              <div className="order__head">
                <div>
                  <div className="order__label">Your Order</div>
                  <div className="order__sub">{cartLines.length} selection{cartLines.length === 1 ? '' : 's'}</div>
                </div>
                <span className="order__icon"><IconBasket /></span>
              </div>

              {cartLines.length === 0 ? (
                <div className="order__empty">Tap goods to add them.</div>
              ) : (
                <div className="order__lines">
                  {cartLines.map((l) => (
                    <div className="oline" key={l.item}>
                      <ItemArt item={l.item} label={l.label} size="sm" />
                      <div className="oline__info">
                        <span className="oline__name">{l.label}</span>
                        <span className="oline__unit">{money(l.unit)} each</span>
                      </div>
                      <span className="stepper">
                        <button onClick={() => setQty(l.item, l.qty - 1)}>−</button>
                        <b>{l.qty}</b>
                        <button onClick={() => setQty(l.item, l.qty + 1)}>+</button>
                      </span>
                    </div>
                  ))}
                </div>
              )}

              <div className="order__foot">
                <div className="tally"><span>Subtotal</span><span>{money(subtotal)}</span></div>
                <div className="tally"><span>County fee</span><span>{money(fee)}</span></div>
                <div className="tally tally--due"><span>Total due</span><b>{money(total)}</b></div>
                <button
                  className="paybtn"
                  disabled={busy || cartLines.length === 0 || total > view.money}
                  onClick={checkout}
                >
                  {busy ? 'Ringing up…' : total > view.money ? 'Not enough cash' : 'Complete Purchase'}
                </button>
                <div className="order__note">
                  Payment is taken from the cash carried on your person — {money(view.money)} on hand.
                </div>
              </div>
            </aside>
          </div>
        )}

        {tab === 'sell' && (
          <div className="selling">
            <div className="selling__note">The clerk buys the following — condition inspected at the counter.</div>
            {store.sell.map((entry) =>
              entry.stacks.length > 0 ? (
                entry.stacks.map((stack, i) => (
                  <SellRow key={entry.item + ':' + i} entry={entry} stack={stack} busy={busy} onSell={sellStack} />
                ))
              ) : (
                <SellRow key={entry.item + ':none'} entry={entry} stack={null} busy={busy} onSell={sellStack} />
              )
            )}
          </div>
        )}

        <footer className="foot">
          <span>{store.label}{store.code ? ` · Store Code ${store.code}` : ' · Sovereign County'}</span>
          <span className="foot__esc"><i>ESC</i> Close</span>
        </footer>
      </div>
    </div>
  )
}

function catLabel(store, key) {
  const c = store.categories.find((c) => c.key === key)
  return c ? c.label : key
}

function SellRow({ entry, stack, busy, onSell }) {
  const [qty, setQty] = useState(1)

  if (!stack) {
    return (
      <div className="sellrow sellrow--none">
        <ItemArt item={entry.item} label={entry.label} size="sm" />
        <div className="sellrow__info">
          <span className="sellrow__label">{entry.label}</span>
          <span className="sellrow__meta">
            {money(entry.price)} each{entry.minCondition ? ` · ${entry.minCondition}%+ condition` : ''}
          </span>
        </div>
        <span className="sellrow__nonetag">None carried</span>
      </div>
    )
  }

  const max = stack.qty || 1
  const unit = stack.percentage != null && entry.scaleByCondition
    ? entry.price * (stack.percentage / 100)
    : entry.price

  return (
    <div className="sellrow">
      <ItemArt item={entry.item} label={entry.label} size="sm" />
      <div className="sellrow__info">
        <span className="sellrow__label">{entry.label}</span>
        <span className="sellrow__meta">
          {stack.percentage != null && (
            <i className={'cond' + (stack.percentage < 40 ? ' cond--low' : '')}>{Math.floor(stack.percentage)}%</i>
          )}
          {money(unit)} each · {max} carried
        </span>
      </div>
      <span className="stepper">
        <button onClick={() => setQty(Math.max(1, qty - 1))}>−</button>
        <b>{Math.min(qty, max)}</b>
        <button onClick={() => setQty(Math.min(max, qty + 1))}>+</button>
      </span>
      <button className="sellrow__go" disabled={busy} onClick={() => onSell(entry, stack, Math.min(qty, max))}>
        Sell {money(unit * Math.min(qty, max))}
      </button>
    </div>
  )
}
