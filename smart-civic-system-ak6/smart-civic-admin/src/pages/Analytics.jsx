import { useState, useEffect } from 'react';
import { collection, onSnapshot } from 'firebase/firestore';
import { db } from '../firebase';
import {
  AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
} from 'recharts';

import { Ic, ICONS } from '../components/SharedUI';

// ─── Palette ──────────────────────────────────────────────────────────────────
const C = {
  orange: 'var(--accent)', blue: 'var(--blue)', green: 'var(--green)',
  purple: 'var(--purple)', teal: 'var(--teal)', amber: 'var(--yellow)',
  red: 'var(--red)', pink: 'var(--pink)',
};
const CAT_COLORS = Object.values(C);

// ─── KPI Card ─────────────────────────────────────────────────────────────────
function KPI({ iconKey, label, value, color, bg, bd, sub, delay = 0 }) {
  return (
    <div style={{
      background: 'var(--surface)',
      border: `1.5px solid ${bd || 'var(--border)'}`,
      borderRadius: 18,
      padding: '22px 24px',
      boxShadow: 'var(--shMd)',
      position: 'relative',
      overflow: 'hidden',
      animation: `fadeUp .45s ${delay}s cubic-bezier(.16,1,.3,1) both`,
      transition: 'transform .2s, box-shadow .2s, border-color .2s',
      cursor: 'default',
    }}
      onMouseEnter={e => {
        e.currentTarget.style.transform = 'translateY(-2px)';
        e.currentTarget.style.boxShadow = 'var(--shHover)';
        e.currentTarget.style.borderColor = 'var(--border2)';
      }}
      onMouseLeave={e => {
        e.currentTarget.style.transform = 'translateY(0)';
        e.currentTarget.style.boxShadow = 'var(--shMd)';
        e.currentTarget.style.borderColor = `${bd || 'var(--border)'}`;
      }}>
      {/* BG shape */}
      <div style={{
        position: 'absolute', top: -22, right: -22,
        width: 80, height: 80, borderRadius: '50%',
        background: bg || 'var(--surface2)', opacity: 1,
      }} />

      {/* Icon box */}
      <div style={{
        width: 46, height: 46, borderRadius: 13,
        background: bg || 'var(--surface2)',
        border: `1.5px solid ${bd || 'var(--border)'}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: color || 'var(--text2)', marginBottom: 16,
        position: 'relative', zIndex: 2
      }}>
        <Ic d={ICONS[iconKey]} size={20} />
      </div>

      <p style={{
        fontFamily: 'var(--font-display)', fontSize: 32, fontWeight: 700,
        color: color || 'var(--text)', lineHeight: 1, margin: 0,
        position: 'relative', zIndex: 2
      }}>{value}</p>
      <p style={{ fontSize: 13, color: 'var(--text2)', marginTop: 6, fontWeight: 500, position: 'relative', zIndex: 2 }}>
        {label}
      </p>
      {sub && (
        <p style={{
          fontSize: 11, color: color || 'var(--text3)',
          marginTop: 4, fontWeight: 700, position: 'relative', zIndex: 2
        }}>{sub}</p>
      )}
    </div>
  );
}

// ─── Chart Card ───────────────────────────────────────────────────────────────
function Card({ iconKey, title, subtitle, children, badge }) {
  return (
    <div style={{
      background: 'var(--surface)',
      border: '1.5px solid var(--border)',
      borderRadius: 18,
      padding: '22px 24px',
      boxShadow: 'var(--shMd)',
    }}>
      <div style={{
        display: 'flex', alignItems: 'flex-start',
        justifyContent: 'space-between', marginBottom: 20,
      }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
          <div style={{
            width: 36, height: 36, borderRadius: 10, flexShrink: 0,
            background: 'var(--bg)', border: '1px solid var(--borderHl)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: 'var(--text2)',
          }}>
            <Ic d={ICONS[iconKey]} size={16} />
          </div>
          <div>
            <h3 style={{
              fontFamily: 'var(--font-display)', fontSize: 15, fontWeight: 700,
              color: 'var(--text)', margin: 0, letterSpacing: -0.2,
            }}>{title}</h3>
            {subtitle && (
              <p style={{ fontSize: 12, color: 'var(--text3)', marginTop: 3 }}>
                {subtitle}
              </p>
            )}
          </div>
        </div>
        {badge}
      </div>
      {children}
    </div>
  );
}

// ─── Empty State ──────────────────────────────────────────────────────────────
function Empty({ message }) {
  return (
    <div style={{
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      padding: '40px 20px', gap: 10,
    }}>
      <div style={{
        width: 44, height: 44, borderRadius: '50%',
        background: 'var(--bg)', border: '1px solid var(--borderHl)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: 'var(--textMuted)',
      }}>
        <Ic d={ICONS.bar} size={20} />
      </div>
      <p style={{ fontSize: 13, color: 'var(--text3)', margin: 0, textAlign: 'center' }}>
        {message}
      </p>
    </div>
  );
}

// ─── Custom Recharts Tooltip ──────────────────────────────────────────────────
const CustomTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div style={{
      background: 'var(--surface)', border: '1px solid var(--border)',
      borderRadius: 12, padding: '10px 14px',
      boxShadow: 'var(--shHover)',
      fontSize: 12,
    }}>
      <p style={{ color: 'var(--text2)', fontWeight: 700, margin: '0 0 6px' }}>{label}</p>
      {payload.map((p, i) => (
        <div key={i} style={{
          display: 'flex', alignItems: 'center',
          gap: 8, marginBottom: 3,
        }}>
          <div style={{
            width: 8, height: 8, borderRadius: '50%',
            background: p.color || p.fill, flexShrink: 0,
          }} />
          <span style={{ color: 'var(--text2)' }}>{p.name || p.dataKey}</span>
          <span style={{ fontWeight: 800, color: 'var(--text)', marginLeft: 'auto', paddingLeft: 16 }}>
            {p.value}
          </span>
        </div>
      ))}
    </div>
  );
};

// ─── Analytics ────────────────────────────────────────────────────────────────
export default function Analytics() {
  const [issues, setIssues] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'issues'), snap => {
      setIssues(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    }, () => setLoading(false));
    return unsub;
  }, []);

  // ── Derived data ──────────────────────────────────────────────
  const total = issues.length;
  const open = issues.filter(i => i.status === 'open').length;
  const inProg = issues.filter(i => i.status === 'in_progress').length;
  const resolved = issues.filter(i => i.status === 'resolved').length;
  const rejected = issues.filter(i => i.status === 'rejected').length;
  const resRate = total > 0 ? Math.round((resolved / total) * 100) : 0;

  const resTimes = issues
    .filter(i => i.status === 'resolved' && i.createdAt && i.updatedAt)
    .map(i => {
      const c = i.createdAt.toDate ? i.createdAt.toDate() : new Date(i.createdAt);
      const u = i.updatedAt.toDate ? i.updatedAt.toDate() : new Date(i.updatedAt);
      return (u - c) / 86400000;
    });
  const avgDays = resTimes.length > 0
    ? Math.round(resTimes.reduce((a, b) => a + b, 0) / resTimes.length)
    : 0;

  // Category
  const catMap = {};
  issues.forEach(i => { const c = i.category || 'Other'; catMap[c] = (catMap[c] || 0) + 1; });
  const catData = Object.entries(catMap).sort((a, b) => b[1] - a[1])
    .map(([name, value]) => ({ name, value }));

  // Status pie
  const statusPie = [
    { name: 'Open', value: open, color: C.blue },
    { name: 'In Progress', value: inProg, color: C.orange },
    { name: 'Resolved', value: resolved, color: C.green },
    { name: 'Rejected', value: rejected, color: C.red },
  ].filter(d => d.value > 0);

  // Wards
  const wardMap = {};
  issues.forEach(i => { const w = i.wardNo ? `W${i.wardNo}` : '?'; wardMap[w] = (wardMap[w] || 0) + 1; });
  const wardData = Object.entries(wardMap).sort((a, b) => b[1] - a[1]).slice(0, 10)
    .map(([name, value]) => ({ name, value }));

  // Monthly trend
  const monthMap = {};
  issues.forEach(i => {
    if (!i.createdAt) return;
    const d = i.createdAt.toDate ? i.createdAt.toDate() : new Date(i.createdAt);
    const k = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    if (!monthMap[k]) monthMap[k] = { total: 0, resolved: 0 };
    monthMap[k].total++;
    if (i.status === 'resolved') monthMap[k].resolved++;
  });
  const trendData = Object.entries(monthMap)
    .sort((a, b) => a[0].localeCompare(b[0])).slice(-8)
    .map(([m, v]) => ({
      month: m.slice(5) + '/' + m.slice(2, 4),
      Total: v.total, Resolved: v.resolved,
    }));

  // Priority
  const prioMap = { urgent: 0, high: 0, normal: 0 };
  issues.forEach(i => { if (i.priority) prioMap[i.priority] = (prioMap[i.priority] || 0) + 1; });
  const prioData = [
    { name: 'Urgent', value: prioMap.urgent, color: C.red },
    { name: 'High', value: prioMap.high, color: C.orange },
    { name: 'Normal', value: prioMap.normal, color: C.green },
  ].filter(d => d.value > 0);

  if (loading) return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: 340 }}>
      <div style={{
        width: 38, height: 38, borderRadius: '50%',
        border: '3px solid var(--border)', borderTopColor: 'var(--accent)',
        animation: 'spin .8s linear infinite',
      }} />
    </div>
  );

  // ── Summary badge helper ──────────────────────────────────────
  const badge = (label, color, bg, bd) => (
    <div style={{
      padding: '5px 12px', borderRadius: 99,
      background: bg, border: `1px solid ${bd}`,
      fontSize: 11, fontWeight: 700, color,
    }}>{label}</div>
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>

      {/* ── Page Header ── */}
      <div style={{
        display: 'flex', alignItems: 'flex-start',
        justifyContent: 'space-between',
        animation: 'fadeUp .4s cubic-bezier(.16,1,.3,1) both',
      }}>
        <div>
          <h1 style={{
            fontFamily: 'var(--font-display)', fontSize: 28, fontWeight: 700,
            color: 'var(--text)', margin: 0, letterSpacing: -0.5,
          }}>Analytics</h1>
          <p style={{ color: 'var(--text2)', fontSize: 14, marginTop: 5, fontWeight: 400 }}>
            Live performance metrics & civic insights
          </p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          {badge(`${resRate}% Resolved`,
            resRate >= 60 ? 'var(--green)' : 'var(--orange)',
            resRate >= 60 ? 'var(--greenBg)' : 'var(--orangeBg)',
            resRate >= 60 ? 'var(--greenBd)' : 'var(--orangeBd)'
          )}
          {badge(`${total} Total`, 'var(--blue)', 'var(--blueBg)', 'var(--blueBd)')}
        </div>
      </div>

      {/* ── KPI Row ── */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(165px, 1fr))',
        gap: 14,
      }}>
        <KPI delay={0} iconKey="total" label="Total Complaints" value={total} />
        <KPI delay={0.05} iconKey="resolved" label="Resolution Rate"
          value={`${resRate}%`} color={C.green} bg="var(--greenBg)" bd="var(--greenBd)"
          sub={`${resolved} resolved`} />
        <KPI delay={0.10} iconKey="time" label="Avg Resolution"
          value={`${avgDays}d`} color={C.blue} bg="var(--blueBg)" bd="var(--blueBd)" />
        <KPI delay={0.15} iconKey="open" label="Open Cases"
          value={open} color={C.orange} bg="var(--orangeBg)" bd="var(--orangeBd)" />
        <KPI delay={0.20} iconKey="category" label="Top Category"
          value={catData[0]?.name?.split(' ')[0] || '—'}
          color={C.orange} bg="var(--accentBg)" bd="var(--accentBd)" />
      </div>

      {/* ── Row 1: Trend + Pie ── */}
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 14 }}>

        {/* Trend */}
        <Card iconKey="trend" title="Monthly Complaint Trend"
          subtitle="Total submitted vs resolved over the past 8 months"
          badge={
            <div style={{ display: 'flex', gap: 16 }}>
              {[['var(--accent)', 'Total'], ['var(--green)', 'Resolved']].map(([color, label]) => (
                <div key={label} style={{
                  display: 'flex', alignItems: 'center', gap: 6,
                  fontSize: 11, color: 'var(--text2)', fontWeight: 500,
                }}>
                  <div style={{ width: 22, height: 3, borderRadius: 2, background: color }} />
                  {label}
                </div>
              ))}
            </div>
          }
        >
          <ResponsiveContainer width="100%" height={210}>
            <AreaChart data={trendData} margin={{ top: 4, right: 4, bottom: 0, left: -18 }}>
              <defs>
                <linearGradient id="gT" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="var(--accent)" stopOpacity={0.13} />
                  <stop offset="95%" stopColor="var(--accent)" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="gR" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="var(--green)" stopOpacity={0.13} />
                  <stop offset="95%" stopColor="var(--green)" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
              <XAxis dataKey="month"
                tick={{ fill: 'var(--text3)', fontSize: 11 }}
                axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: 'var(--text3)', fontSize: 11 }} axisLine={false} tickLine={false} />
              <Tooltip content={<CustomTooltip />} />
              <Area type="monotone" dataKey="Total"
                stroke="var(--accent)" fill="url(#gT)" strokeWidth={2.5}
                dot={false} activeDot={{ r: 5, fill: 'var(--accent)', strokeWidth: 0 }} />
              <Area type="monotone" dataKey="Resolved"
                stroke="var(--green)" fill="url(#gR)" strokeWidth={2.5}
                dot={false} activeDot={{ r: 5, fill: 'var(--green)', strokeWidth: 0 }} />
            </AreaChart>
          </ResponsiveContainer>
        </Card>

        {/* Status Pie */}
        <Card iconKey="pie" title="Status Distribution" subtitle="Current breakdown">
          {statusPie.length === 0 ? <Empty message="No complaints yet" /> : (
            <>
              <ResponsiveContainer width="100%" height={155}>
                <PieChart>
                  <Pie data={statusPie} cx="50%" cy="50%"
                    innerRadius={46} outerRadius={70}
                    paddingAngle={3} dataKey="value" stroke="none">
                    {statusPie.map((e, i) => <Cell key={i} fill={e.color} />)}
                  </Pie>
                  <Tooltip content={<CustomTooltip />} />
                </PieChart>
              </ResponsiveContainer>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 7, marginTop: 10 }}>
                {statusPie.map(d => {
                  const pct = total > 0 ? Math.round((d.value / total) * 100) : 0;
                  return (
                    <div key={d.name} style={{
                      display: 'flex', alignItems: 'center',
                      justifyContent: 'space-between',
                    }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div style={{
                          width: 8, height: 8, borderRadius: '50%',
                          background: d.color, flexShrink: 0,
                        }} />
                        <span style={{ fontSize: 12, color: 'var(--text2)' }}>{d.name}</span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div style={{
                          width: 60, height: 4, borderRadius: 99,
                          background: 'var(--surface2)', overflow: 'hidden',
                        }}>
                          <div style={{
                            width: `${pct}%`, height: '100%',
                            background: d.color, borderRadius: 99,
                            transition: 'width .6s ease',
                          }} />
                        </div>
                        <span style={{
                          fontWeight: 800, color: 'var(--text)',
                          fontSize: 13, minWidth: 20, textAlign: 'right',
                        }}>{d.value}</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </>
          )}
        </Card>
      </div>

      {/* ── Row 2: Category + Ward ── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>

        {/* Category */}
        <Card iconKey="bar" title="Issues by Category" subtitle="Most reported civic issue types">
          {catData.length === 0 ? <Empty message="No data yet" /> : (
            <ResponsiveContainer width="100%" height={230}>
              <BarChart data={catData} layout="vertical"
                margin={{ top: 0, right: 8, bottom: 0, left: -8 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" horizontal={false} />
                <XAxis type="number"
                  tick={{ fill: 'var(--text3)', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis type="category" dataKey="name" width={118}
                  tick={{ fill: 'var(--text2)', fontSize: 11 }} axisLine={false} tickLine={false} />
                <Tooltip content={<CustomTooltip />} />
                <Bar dataKey="value" radius={[0, 7, 7, 0]}>
                  {catData.map((_, i) => <Cell key={i} fill={CAT_COLORS[i % CAT_COLORS.length]} />)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          )}
        </Card>

        {/* Ward */}
        <Card iconKey="ward" title="Top Problem Wards" subtitle="Wards with the most reported issues">
          {wardData.length === 0 ? <Empty message="No ward data yet" /> : (
            <ResponsiveContainer width="100%" height={230}>
              <BarChart data={wardData} margin={{ top: 0, right: 8, bottom: 0, left: -18 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
                <XAxis dataKey="name"
                  tick={{ fill: 'var(--text3)', fontSize: 10 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: 'var(--text3)', fontSize: 11 }} axisLine={false} tickLine={false} />
                <Tooltip content={<CustomTooltip />} />
                <Bar dataKey="value" radius={[5, 5, 0, 0]}>
                  {wardData.map((_, i) => (
                    // We can reuse the palette array to colour these individually.
                    <Cell key={i} fill={CAT_COLORS[i % CAT_COLORS.length]} opacity={0.8} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          )}
        </Card>
      </div>

      {/* ── Row 3: Priority ── */}
      <Card iconKey="priority" title="Priority Distribution"
        subtitle="Complaints categorised by urgency level"
        badge={prioData.length > 0 && (
          <div style={{ display: 'flex', gap: 6 }}>
            {prioData.map(d => (
              <div key={d.name} style={{
                padding: '3px 10px', borderRadius: 99,
                fontSize: 10, fontWeight: 700,
                background: 'var(--surface2)', // Simple neutral badge background
                color: d.color, border: `1px solid var(--border)`,
              }}>{d.name}: {d.value}</div>
            ))}
          </div>
        )}
      >
        {prioData.length === 0 ? (
          <Empty message="No priorities set yet — open a complaint and assign a priority level" />
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: 28, alignItems: 'center' }}>

            {/* Progress bars */}
            <div>
              {prioData.map(d => {
                const pct = total > 0 ? Math.round((d.value / total) * 100) : 0;
                return (
                  <div key={d.name} style={{ marginBottom: 16 }}>
                    <div style={{
                      display: 'flex', justifyContent: 'space-between',
                      alignItems: 'center', marginBottom: 7,
                    }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div style={{
                          width: 8, height: 8, borderRadius: 3,
                          background: d.color,
                        }} />
                        <span style={{ fontSize: 13, color: 'var(--text)', fontWeight: 600 }}>
                          {d.name}
                        </span>
                      </div>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                        <span style={{ fontSize: 11, color: 'var(--text3)' }}>{pct}%</span>
                        <span style={{
                          fontSize: 14, fontWeight: 800, color: 'var(--text)',
                          minWidth: 20, textAlign: 'right',
                        }}>{d.value}</span>
                      </div>
                    </div>
                    <div style={{
                      height: 6, borderRadius: 99,
                      background: 'var(--surface2)', overflow: 'hidden',
                    }}>
                      <div style={{
                        height: '100%', borderRadius: 99,
                        background: `linear-gradient(90deg, ${d.color}, ${d.color})`, // Simple solid color that works
                        width: `${pct}%`,
                        transition: 'width .7s cubic-bezier(.4,0,.2,1)',
                      }} />
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Priority bar chart */}
            <ResponsiveContainer width="100%" height={160}>
              <BarChart data={prioData} margin={{ top: 4, right: 8, bottom: 0, left: -18 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
                <XAxis dataKey="name"
                  tick={{ fill: 'var(--text3)', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: 'var(--text3)', fontSize: 11 }} axisLine={false} tickLine={false} />
                <Tooltip content={<CustomTooltip />} />
                <Bar dataKey="value" radius={[6, 6, 0, 0]}>
                  {prioData.map((e, i) => <Cell key={i} fill={e.color} />)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </Card>

    </div>
  );
}
