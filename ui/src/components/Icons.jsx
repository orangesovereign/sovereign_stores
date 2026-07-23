/* Minimal geometric icon set (docs/04): 16px, 1.5 stroke, brass by default.
   Simple shapes only — no long hand-authored paths. */

const base = {
  width: 16, height: 16, viewBox: '0 0 16 16',
  fill: 'none', stroke: 'currentColor', strokeWidth: 1.5,
  strokeLinecap: 'round', strokeLinejoin: 'round',
}

export const IconBox = () => (
  <svg {...base}><rect x="2.5" y="4.5" width="11" height="9" /><path d="M2.5 7.5h11M8 4.5v3" /></svg>
)
export const IconBowl = () => (
  <svg {...base}><path d="M2.5 8h11" /><path d="M3.5 8a4.5 4.5 0 0 0 9 0" /><path d="M5 5.5c0-1 1-1 1-2M9 5.5c0-1 1-1 1-2" /></svg>
)
export const IconWrench = () => (
  <svg {...base}><circle cx="5" cy="5" r="2.5" /><path d="M7 7l6 6" /><path d="M11.5 13.5l2-2" /></svg>
)
export const IconArrow = () => (
  <svg {...base}><path d="M13.5 2.5L4 12" /><path d="M13.5 2.5l-4 .8M13.5 2.5l-.8 4" /><path d="M4.8 9.2L2.5 13.5l4.3-2.3" /></svg>
)
export const IconHorseshoe = () => (
  <svg {...base}><path d="M3.5 13.5V8a4.5 4.5 0 0 1 9 0v5.5" /><path d="M3.5 10.5h2M10.5 10.5h2" /></svg>
)
export const IconCoin = () => (
  <svg {...base}><circle cx="8" cy="8" r="5.5" /><path d="M8 5.2v5.6M6.2 6.5h2.7a1.4 1.4 0 1 1 0 2.8H6.5" /></svg>
)
export const IconBottle = () => (
  <svg {...base}><path d="M6.5 2.5h3M7 2.5v3l-2 2v6h6v-6l-2-2v-3" /></svg>
)
export const IconBasket = () => (
  <svg {...base}><path d="M2.5 6.5h11l-1.4 7h-8.2z" /><path d="M5.5 6.5L8 2.5l2.5 4" /></svg>
)
export const IconTag = () => (
  <svg {...base}><path d="M2.5 2.5h5l6 6-5 5-6-6z" /><circle cx="5.5" cy="5.5" r="1" fill="currentColor" stroke="none" /></svg>
)
export const IconDot = () => (
  <svg {...base}><circle cx="8" cy="8" r="2.5" /></svg>
)

const MAP = {
  all: IconBox, general: IconBox, goods: IconBox,
  provisions: IconBowl, food: IconBowl,
  supplies: IconWrench, tools: IconWrench,
  hunting: IconArrow,
  horse: IconHorseshoe, horsecare: IconHorseshoe,
  sundries: IconCoin, valuables: IconCoin,
  drinks: IconBottle,
  sale: IconTag,
}

export function CategoryIcon({ id }) {
  const C = MAP[id] || IconDot
  return <C />
}
