/* =====================================================================
   SOVEREIGN STORES · STOREFRONT
   One storefront for every store in the county — NPC or player-owned.
   Everything shown here is server-supplied; the UI never invents a
   price. UI copy is English for v1 (full locale pass lands in Phase 5).
   ===================================================================== */

import { useEffect, useMemo, useRef, useState } from 'react'
import { post, onMessage, itemImage } from './nui.js'

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

function ItemArt({ item, label }) {
  const [gone, setGone] = useState(false)
  if (gone) return <div className="art art--empty">{(label || '?').slice(0, 1)}</div>
  return <img className="art" src={itemImage(item)} alt="" onError={() => setGone(true)} />
}

export default function App() {
  const [view, setView] = useState(null)      // { store, money }
  const [tab, setTab] = useState('buy')
  const [cat, setCat] = useState('all')
  const [q, setQ] = useState('')
  const [cart, setCart] = useState({})        // item -> qty
  const [busy, setBusy] = useState(false)
  const [toast, setToast] = useState(null)    // { kind: 'good'|'bad', text }
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
        return entry ? { ...entry, qty, cost: entry.price * qty } : null
      })
      .filter(Boolean)
  }, [store, cart])
  const cartTotal = cartLines.reduce((s, l) => s + l.cost, 0)

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
  const canSell = store.sell.length > 0

  return (
    <div className="scrim">
      <div className="counter">
        <header className="head">
          <div className="head__eyebrow">~ Sovereign County Mercantile ~</div>
          <h1 className="head__name">{store.label}</h1>
          <div className="head__wallet">{money(view.money)} <span>on hand</span></div>
          <button className="head__close" onClick={() => post('close')} aria-label="Close">✕</button>
        </header>

        {toast && <div className={`toast toast--${toast.kind}`}>{toast.text}</div>}

        <nav className="tabs">
          <button className={tab === 'buy' ? 'on' : ''} onClick={() => setTab('buy')}>Buy</button>
          {canSell && (
            <button className={tab === 'sell' ? 'on' : ''} onClick={() => setTab('sell')}>Sell</button>
          )}
        </nav>

        {tab === 'buy' && (
          <div className="trade">
            <div className="goods">
              <div className="filters">
                <div className="chips">
                  {cats.map((c) => (
                    <button key={c.key} className={cat === c.key ? 'on' : ''} onClick={() => setCat(c.key)}>
                      {c.label}
                    </button>
                  ))}
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
                    <button key={e.item} className="card" onClick={() => addToCart(e.item)}>
                      <ItemArt item={e.item} label={e.label} />
                      <span className="card__label">{e.label}</span>
                      <span className="card__price">{money(e.price)}</span>
                      {cart[e.item] ? <span className="card__inCart">×{cart[e.item]}</span> : null}
                    </button>
                  ))}
                </div>
              )}
            </div>

            <aside className="basket">
              <div className="basket__title">Basket</div>
              {cartLines.length === 0 ? (
                <div className="basket__empty">Tap goods to add them.</div>
              ) : (
                <div className="basket__lines">
                  {cartLines.map((l) => (
                    <div className="line" key={l.item}>
                      <span className="line__label">{l.label}</span>
                      <span className="line__qty">
                        <button onClick={() => setQty(l.item, l.qty - 1)}>−</button>
                        <b>{l.qty}</b>
                        <button onClick={() => setQty(l.item, l.qty + 1)}>+</button>
                      </span>
                      <span className="line__cost">{money(l.cost)}</span>
                    </div>
                  ))}
                </div>
              )}
              <div className="basket__foot">
                <div className="basket__total">
                  <span>Total</span><b>{money(cartTotal)}</b>
                </div>
                <button
                  className="basket__go"
                  disabled={busy || cartLines.length === 0 || cartTotal > view.money}
                  onClick={checkout}
                >
                  {busy ? 'Ringing up…' : cartTotal > view.money ? 'Not enough cash' : 'Pay the clerk'}
                </button>
              </div>
            </aside>
          </div>
        )}

        {tab === 'sell' && (
          <div className="selling">
            {store.sell.length === 0 ? (
              <div className="empty">The clerk isn't buying anything you carry.</div>
            ) : (
              store.sell.map((entry) =>
                entry.stacks.map((stack, i) => (
                  <SellRow key={entry.item + ':' + i} entry={entry} stack={stack} busy={busy} onSell={sellStack} />
                ))
              )
            )}
          </div>
        )}

        <footer className="foot">
          <span>SOVEREIGN MERCANTILE AUTHORITY — ALL SALES FINAL</span>
          <span className="foot__hint">ESC to leave the counter</span>
        </footer>
      </div>
    </div>
  )
}

function SellRow({ entry, stack, busy, onSell }) {
  const [qty, setQty] = useState(1)
  const max = stack.qty || 1
  const unit = stack.percentage != null && entry.scaleByCondition
    ? entry.price * (stack.percentage / 100)
    : entry.price

  return (
    <div className="sellrow">
      <ItemArt item={entry.item} label={entry.label} />
      <div className="sellrow__info">
        <span className="sellrow__label">{entry.label}</span>
        <span className="sellrow__meta">
          {stack.percentage != null && (
            <i className={'cond' + (stack.percentage < 40 ? ' cond--low' : '')}>{Math.floor(stack.percentage)}%</i>
          )}
          <span>{money(unit)} each · {max} carried</span>
        </span>
      </div>
      <span className="line__qty">
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
