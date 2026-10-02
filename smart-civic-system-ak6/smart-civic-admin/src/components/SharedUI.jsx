import { memo } from 'react';
import { STATUS, PRIORITY } from '../constants';

// ─── Tiny SVG icon ─────────────────────────────────────────────────────────────
export const Ic = memo(({ d, size = 14, sw = 1.8, style = {}, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
    stroke="currentColor" strokeWidth={sw} strokeLinecap="round"
    strokeLinejoin="round" style={{ display: 'block', flexShrink: 0, ...style }}
    className={className}
  >
    {[].concat(d).map((p, i) => <path key={i} d={p} />)}
  </svg>
));

// ─── Global Icons ──────────────────────────────────────────────────────────────
export const ICONS = {
  search: 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16zm10 2-4.35-4.35',
  close: 'M18 6 6 18M6 6l12 12',
  sort: ['M3 6h18', 'M7 12h10', 'M11 18h2'],
  view: ['M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z', 'M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6'],
  check: 'M20 6 9 17l-5-5',
  tag: ['M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z', 'M7 7h.01'],
  file: ['M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z', 'M14 2v6h6'],
  loc: ['M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z', 'M12 10a3 3 0 1 0 0-6 3 3 0 0 0 0 6'],
  user: ['M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2', 'M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8'],
  cal: ['M8 2v4', 'M16 2v4', 'M3 8h18', 'M4 4h16a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z'],
  note: ['M12 20h9', 'M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4z'],
  map: ['M1 6v16l7-4 8 4 7-4V2l-7 4-8-4-7 4', 'M8 2v16', 'M16 6v16'],
  img: ['M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z', 'M12 9a4 4 0 1 0 0 8 4 4 0 0 0 0-8'],
  assign: ['M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2', 'M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8', 'M20 8v6', 'M23 11h-6'],
  chevR: 'M9 18l6-6-6-6',
  info: ['M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z', 'M12 8v4', 'M12 16h.01'],
  flag: ['M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z', 'M4 22v-7'],
  warn: ['M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z', 'M12 9v4', 'M12 17h.01'],
  time: ['M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z', 'M12 6v6l4 2'],
  trend: ['M3 3v18h18', 'M18.7 8l-5.1 5.2-2.8-2.7L7 14.3'],
  pie: ['M21.21 15.89A10 10 0 1 1 8 2.83', 'M22 12A10 10 0 0 0 12 2v10z'],
  category: ['M4 6h16', 'M4 10h16', 'M4 14h16', 'M4 18h16'],
  bar: ['M12 20V10', 'M18 20V4', 'M6 20v-4'],
  ward: ['M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z', 'M9 22V12h6v10'],
  priority: ['M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z'],
  arrow: 'M5 12h14M12 5l7 7-7 7',
  trash: ['M3 6h18', 'M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2', 'M10 11v6', 'M14 11v6'],
  block: ['M18.36 6.64a9 9 0 1 1-12.72 0 9 9 0 0 1 12.72 0z', 'M4.93 4.93l14.14 14.14'],
  unlock: ['M7 11V7a5 5 0 0 1 9.9-1', 'M21 11H3a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h18a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2z'],
};

// ─── Badges ────────────────────────────────────────────────────────────────────
export const SBadge = memo(({ status }) => {
  const s = STATUS[status] || STATUS.open;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '3px 10px', borderRadius: 99, fontSize: 11, fontWeight: 700,
      color: s.color, background: s.bg, border: `1px solid ${s.bd}`,
      whiteSpace: 'nowrap',
    }}>
      <span style={{ width: 5, height: 5, borderRadius: '50%', background: s.color, flexShrink: 0 }} />
      {s.label}
    </span>
  );
});

export const PBadge = memo(({ priority }) => {
  if (!priority) return <span style={{ color: 'var(--text3)', fontSize: 11 }}>—</span>;
  const p = PRIORITY[priority] || PRIORITY.normal;
  return (
    <span style={{
      padding: '2px 8px', borderRadius: 99, fontSize: 10, fontWeight: 700,
      color: p.color, background: p.bg, border: `1px solid ${p.bd}`,
      textTransform: 'capitalize',
    }}>{p.label}</span>
  );
});
