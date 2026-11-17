export default function BrandMark({size=26}:{size?:number}) {
  return <svg width={size} height={size} viewBox="0 0 32 32" fill="none" aria-hidden="true"><rect x="2" y="2" width="28" height="28" rx="8" fill="currentColor"/><path d="M10 10H22L10 22H22" stroke="var(--bg, #fafaf7)" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"/></svg>;
}
