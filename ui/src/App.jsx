/* =====================================================================
   SOVEREIGN STORES · APP ROUTER
   One NUI, several panels: the buyer storefront and the Commerce
   Bureau (admin). The Management workspace joins later in Phase 2.
   Lua decides what opens; this file only routes messages.
   ===================================================================== */

import { useEffect, useState } from 'react'
import { post, onMessage } from './nui.js'
import Storefront from './components/Storefront.jsx'
import Bureau from './components/Bureau.jsx'

export default function App() {
  const [storeView, setStoreView] = useState(null)   // { store, money }
  const [adminView, setAdminView] = useState(null)   // overview payload

  useEffect(() => onMessage((msg) => {
    if (msg.action === 'store:open') setStoreView({ store: msg.payload.store, money: msg.payload.money })
    if (msg.action === 'store:close') setStoreView(null)
    if (msg.action === 'admin:open') setAdminView(msg.payload)
    if (msg.action === 'admin:close') setAdminView(null)
  }), [])

  useEffect(() => {
    const onKey = (e) => {
      if (e.key !== 'Escape') return
      if (adminView) post('adminClose')
      else if (storeView) post('close')
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [adminView, storeView])

  if (adminView) return <div className="scrim"><Bureau initial={adminView} /></div>
  if (storeView) return <div className="scrim"><Storefront view={storeView} setView={setStoreView} /></div>
  return null
}
