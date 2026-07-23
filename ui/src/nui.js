/* =====================================================================
   SOVEREIGN STORES · NUI TRANSPORT
   ---------------------------------------------------------------------
   The only place that talks to Lua (postoffice pattern). Outside the
   game, post() logs and returns null so the shell stays developable
   with `npm run dev`.
   ===================================================================== */

const RESOURCE =
  typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function'
    ? window.GetParentResourceName()
    : 'sovereign_stores'

export const inGame =
  typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function'

/** Send a request to Lua. Returns the parsed reply, or null out of game. */
export async function post(name, data = {}) {
  if (!inGame) {
    console.info(`[stores] nui:${name}`, data)
    return null
  }
  try {
    const res = await fetch(`https://${RESOURCE}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    })
    return await res.json()
  } catch (err) {
    console.error(`[stores] nui:${name} failed`, err)
    return null
  }
}

/** Subscribe to messages from Lua. Returns an unsubscribe function. */
export function onMessage(handler) {
  const listener = (event) => {
    const data = event.data
    if (!data || typeof data.action !== 'string') return
    handler(data)
  }
  window.addEventListener('message', listener)
  return () => window.removeEventListener('message', listener)
}

/** Item art from the county's canonical image directory (Cas-inventory). */
export function itemImage(item) {
  return `nui://vorp_inventory/html/img/items/${item}.png`
}
