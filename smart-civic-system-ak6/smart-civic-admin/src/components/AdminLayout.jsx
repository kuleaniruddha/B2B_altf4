import { useState, useEffect } from 'react';
import { signOut } from 'firebase/auth';
import { collection, onSnapshot, query, where } from 'firebase/firestore';
import { auth, db } from '../firebase';
import Dashboard from '../pages/Dashboard';
import Complaints from '../pages/Complaints';
import Users from '../pages/Users';
import Analytics from '../pages/Analytics';

// ─── SVG Icon Set ─────────────────────────────────────────────────────────────
const Icon = ({ d, size = 18, stroke = 'currentColor', strokeWidth = 1.8, fill = 'none', viewBox = '0 0 24 24' }) => (
  <svg width={size} height={size} viewBox={viewBox} fill={fill} stroke={stroke}
    strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round"
    style={{ flexShrink: 0, display: 'block' }}>
    {Array.isArray(d) ? d.map((path, i) => <path key={i} d={path} />) : <path d={d} />}
  </svg>
);

const Icons = {
  dashboard: ['M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z', 'M9 22V12h6v10'],
  complaints: ['M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z', 'M14 2v6h6', 'M16 13H8', 'M16 17H8', 'M10 9H8'],
  users: ['M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2', 'M9 7a4 4 0 1 0 8 0 4 4 0 0 0-8 0'],
  analytics: ['M18 20V10', 'M12 20V4', 'M6 20v-6'],
  chevronL: 'M15 18l-6-6 6-6',
  chevronR: 'M9 18l6-6-6-6',
  logout: ['M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4', 'M16 17l5-5-5-5', 'M21 12H9'],
  user: ['M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2', 'M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8'],
  calendar: ['M8 2v4', 'M16 2v4', 'M3 8h18', 'M4 6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2H4z'],
  shield: 'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z',
  bell: ['M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9', 'M13.73 21a2 2 0 0 1-3.46 0'],
  sun: ['M12 2v2', 'M12 20v2', 'M4.93 4.93l1.41 1.41', 'M17.66 17.66l1.41 1.41', 'M2 12h2', 'M20 12h2', 'M4.93 19.07l1.41-1.41', 'M17.66 6.34l1.41-1.41', 'M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8z'],
  moon: 'M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z',
};

// Renders a multi-path icon cleanly
const NavIcon = ({ id, size = 16 }) => {
  const paths = Icons[id];
  if (!paths) return null;
  if (Array.isArray(paths)) {
    return (
      <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
        stroke="currentColor" strokeWidth="2" strokeLinecap="round"
        strokeLinejoin="round" style={{ flexShrink: 0 }}>
        {paths.map((p, i) => <path key={i} d={p} />)}
      </svg>
    );
  }
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
      stroke="currentColor" strokeWidth="2" strokeLinecap="round"
      strokeLinejoin="round" style={{ flexShrink: 0 }}>
      <path d={paths} />
    </svg>
  );
};

// ─── AdminLayout ───────────────────────────────────────────────────────────────
export default function AdminLayout({ user }) {
  const isHOD = user.role === 'hod';
  
  const NAV = [
    { id: 'dashboard', label: 'Dashboard' },
    { id: 'complaints', label: 'Complaints', live: true },
    ...(!isHOD ? [
      { id: 'users', label: 'Users' },
      { id: 'analytics', label: 'Analytics' },
    ] : []),
  ];

  const [page, setPage] = useState('dashboard');
  const [collapsed, setCollapsed] = useState(false);
  const [counts, setCounts] = useState({ open: 0, total: 0 });
  const [theme, setTheme] = useState(() => localStorage.getItem('theme') || 'light');

  // Sync theme
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
  }, [theme]);

  const toggleTheme = () => setTheme(t => t === 'light' ? 'dark' : 'light');

  // Sync complaints count for sidebar badge
  useEffect(() => {
    const baseRef = collection(db, 'issues');
    const q = (user.role === 'hod' && user.department)
      ? query(baseRef, where('assignedTo', '==', user.department))
      : baseRef;

    const unsub = onSnapshot(q, snap => {
      const issues = snap.docs.map(d => d.data());
      setCounts({
        open: issues.filter(i => i.status === 'open' || i.status === 'assigned').length,
        total: issues.length,
      });
    }, (err) => {
      console.warn("Sidebar count error:", err);
      setCounts({ open: 0, total: 0 });
    });
    return unsub;
  }, [user.role, user.department]);

  const logout = async () => {
    if (window.confirm('Sign out of admin panel?')) await signOut(auth);
  };

  const W = collapsed ? 64 : 234;

  const renderPage = () => {
    switch (page) {
      case 'dashboard': return <Dashboard user={user} />;
      case 'complaints': return <Complaints user={user} />;
      case 'users': return <Users user={user} />;
      case 'analytics': return <Analytics user={user} />;
      default: return <Dashboard user={user} />;
    }
  };

  // ── Sidebar ──────────────────────────────────────────────────────────────────
  const Sidebar = () => (
    <aside style={{
      width: W, flexShrink: 0,
      background: 'linear-gradient(180deg, rgba(255,255,255,0.88) 0%, rgba(255,255,255,0.72) 100%)',
      borderRight: '1px solid var(--border)',
      display: 'flex', flexDirection: 'column',
      transition: 'width .22s cubic-bezier(.4,0,.2,1), background-color 0.3s',
      overflow: 'hidden',
      boxShadow: 'var(--shMd)',
      zIndex: 20, position: 'relative',
      backdropFilter: 'blur(22px)',
      WebkitBackdropFilter: 'blur(22px)',
    }}>

      {/* Accent stripe */}
      <div style={{
        height: 3, flexShrink: 0,
        background: 'linear-gradient(90deg, var(--accent) 0%, var(--accentL) 60%, var(--yellow) 100%)',
      }} />

      {/* Logo */}
      <div style={{
        height: 58, flexShrink: 0,
        display: 'flex', alignItems: 'center',
        padding: collapsed ? '0' : '0 16px',
        justifyContent: collapsed ? 'center' : 'flex-start',
        gap: 11, borderBottom: '1px solid var(--border)',
      }}>
        <div style={{
          width: 34, height: 34, borderRadius: 10, flexShrink: 0,
          background: 'linear-gradient(135deg, var(--accent), var(--accentL))',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: 'var(--shAccent)',
        }}>
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none"
            stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
            <polyline points="9 22 9 12 15 12 15 22" />
          </svg>
        </div>
        {!collapsed && (
          <div style={{ overflow: 'hidden', minWidth: 0 }}>
            <div style={{
              fontFamily: 'var(--font-display)', fontSize: 13, fontWeight: 700,
              color: 'var(--text)', whiteSpace: 'nowrap', letterSpacing: -0.2,
            }}>Civic Admin</div>
            <div style={{
              fontSize: 10, color: 'var(--text3)', whiteSpace: 'nowrap', marginTop: 1,
            }}>Mumbai BMC Portal</div>
          </div>
        )}
      </div>

      {/* Nav */}
      <nav style={{ flex: 1, padding: '14px 8px', overflowY: 'auto' }}>
        {!collapsed && (
          <p style={{
            fontSize: 9, fontWeight: 800, letterSpacing: 1.6,
            color: 'var(--textMuted)', padding: '0 8px 10px',
            textTransform: 'uppercase', margin: 0,
          }}>Main Menu</p>
        )}
        {NAV.map(item => {
          const active = page === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setPage(item.id)}
              title={collapsed ? item.label : undefined}
              style={{
                display: 'flex', alignItems: 'center',
                gap: 10, width: '100%',
                padding: collapsed ? '11px 0' : '10px 12px',
                justifyContent: collapsed ? 'center' : 'flex-start',
                background: active ? 'linear-gradient(180deg, rgba(255,255,255,0.88) 0%, var(--accentBg) 100%)' : 'transparent',
                border: active ? '1px solid var(--accentBd)' : '1px solid transparent',
                borderRadius: 14, cursor: 'pointer',
                color: active ? 'var(--accent)' : 'var(--text2)',
                fontSize: 13, fontWeight: active ? 700 : 500,
                transition: 'all .15s', marginBottom: 3,
                position: 'relative', outline: 'none',
                boxShadow: active ? '0 10px 24px rgba(240, 100, 30, 0.10)' : 'none',
              }}
              onMouseEnter={e => { if (!active) e.currentTarget.style.background = 'var(--surface2)'; }}
              onMouseLeave={e => { if (!active) e.currentTarget.style.background = 'transparent'; }}
            >
              <NavIcon id={item.id} size={16} />

              {!collapsed && (
                <span style={{ flex: 1, textAlign: 'left' }}>{item.label}</span>
              )}

              {/* Live badge */}
              {!collapsed && item.live && counts.open > 0 && (
                <span style={{
                  fontSize: 10, fontWeight: 800,
                  padding: '1px 7px', borderRadius: 99,
                  background: 'var(--redBg)', color: 'var(--red)',
                  border: '1px solid var(--redBd)',
                  animation: 'pulse 1.8s ease infinite',
                  lineHeight: 1.6,
                }}>{counts.open}</span>
              )}

              {/* Active bar */}
              {active && (
                <div style={{
                  position: 'absolute', right: 0, top: '50%',
                  transform: 'translateY(-50%)',
                  width: 3, height: 18, background: 'var(--accent)',
                  borderRadius: '2px 0 0 2px',
                }} />
              )}
            </button>
          );
        })}
      </nav>

      {/* Bottom */}
      <div style={{
        padding: '10px 8px 12px',
        borderTop: '1px solid var(--border)',
        flexShrink: 0,
      }}>
        {/* User info */}
        {!collapsed && (
          <div style={{
            display: 'flex', alignItems: 'center', gap: 10,
            padding: '10px 12px', borderRadius: 16,
            background: 'linear-gradient(180deg, rgba(255,255,255,0.9) 0%, rgba(255,255,255,0.62) 100%)', border: '1px solid var(--border)',
            marginBottom: 8,
            boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.6)',
          }}>
            <div style={{
              width: 32, height: 32, borderRadius: '50%', flexShrink: 0,
              background: 'linear-gradient(135deg, var(--accent), var(--accentL))',
              display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff'
            }}>
              <NavIcon id="user" size={14} />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{
                fontSize: 12, fontWeight: 700, color: 'var(--text)',
                overflow: 'hidden', textOverflow: 'ellipsis',
                whiteSpace: 'nowrap', margin: 0,
              }}>{user.name || user.email?.split('@')[0]}</p>
              <p style={{
                fontSize: 10, color: 'var(--accent)', fontWeight: 600,
                margin: '2px 0 0',
              }}>
                {user.role === 'hod' ? `HOD · ${user.department}` : 'Master Admin'}
              </p>
            </div>
          </div>
        )}

        {/* Collapse button */}
        <button
          onClick={() => setCollapsed(c => !c)}
          style={{
            display: 'flex', alignItems: 'center', gap: 8,
            width: '100%', padding: '9px 12px',
            justifyContent: collapsed ? 'center' : 'flex-start',
            background: 'transparent', border: '1px solid transparent',
            borderRadius: 9, color: 'var(--text3)', fontSize: 12,
            marginBottom: 4, cursor: 'pointer', outline: 'none',
            transition: 'all .15s',
          }}
          onMouseEnter={e => {
            e.currentTarget.style.background = 'var(--surface2)';
            e.currentTarget.style.borderColor = 'var(--border)';
          }}
          onMouseLeave={e => {
            e.currentTarget.style.background = 'transparent';
            e.currentTarget.style.borderColor = 'transparent';
          }}
        >
          {collapsed
            ? <NavIcon id="chevronR" size={15} />
            : <NavIcon id="chevronL" size={15} />
          }
          {!collapsed && (
            <span style={{ fontSize: 12, fontWeight: 500 }}>Collapse</span>
          )}
        </button>

        {/* Logout */}
        <button
          onClick={logout}
          style={{
            display: 'flex', alignItems: 'center', gap: 8,
            width: '100%', padding: '9px 12px',
            justifyContent: collapsed ? 'center' : 'flex-start',
            background: 'var(--redBg)', border: '1px solid var(--redBd)',
            borderRadius: 9, color: 'var(--red)', fontSize: 12,
            fontWeight: 600, cursor: 'pointer', outline: 'none',
            transition: 'all .15s',
          }}
          onMouseEnter={e => e.currentTarget.style.opacity = '0.8'}
          onMouseLeave={e => e.currentTarget.style.opacity = '1'}
        >
          <NavIcon id="logout" size={15} />
          {!collapsed && <span>Sign Out</span>}
        </button>
      </div>
    </aside>
  );

  // ── Main ─────────────────────────────────────────────────────────────────────
  return (
    <div style={{
      display: 'flex', height: '100vh',
      overflow: 'hidden',
      background: 'transparent',
    }}>
      <Sidebar />

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>

        {/* ── Topbar ── */}
        <header style={{
          height: 58, flexShrink: 0,
          background: 'linear-gradient(180deg, rgba(255,255,255,0.76) 0%, rgba(255,255,255,0.58) 100%)',
          borderBottom: '1px solid var(--border)',
          display: 'flex', alignItems: 'center',
          padding: '0 24px', gap: 12,
          boxShadow: 'var(--sh)',
          backdropFilter: 'blur(24px)',
          WebkitBackdropFilter: 'blur(24px)',
        }}>

          {/* Page title */}
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ color: 'var(--textMuted)' }}>
              <NavIcon id={page} size={16} />
            </div>
            <h2 style={{
              fontFamily: 'var(--font-display)', fontSize: 15, fontWeight: 700,
              color: 'var(--text)', textTransform: 'capitalize', margin: 0,
            }}>{page}</h2>
          </div>

          {/* Open complaints badge */}
          {counts.open > 0 && (
            <div style={{
              display: 'flex', alignItems: 'center', gap: 6,
              padding: '5px 13px', borderRadius: 99,
              background: 'var(--orangeBg)', border: '1px solid var(--orangeBd)',
            }}>
              <div style={{
                width: 6, height: 6, borderRadius: '50%',
                background: 'var(--orange)',
                animation: 'pulse 1.8s ease infinite',
              }} />
              <span style={{
                fontSize: 11, fontWeight: 700, color: 'var(--orange)',
              }}>{counts.open} Open</span>
            </div>
          )}

          {/* Live dot */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            padding: '5px 13px', borderRadius: 99,
            background: 'var(--greenBg)', border: '1px solid var(--greenBd)',
          }}>
            <div style={{
              width: 6, height: 6, borderRadius: '50%',
              background: 'var(--green)',
              animation: 'pulse 1.8s ease infinite',
            }} />
            <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--green)' }}>
              Live
            </span>
          </div>

          {/* Date */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 7,
            padding: '5px 13px', borderRadius: 99,
            background: 'var(--surface2)', border: '1px solid var(--border)',
            fontSize: 12, color: 'var(--text2)', fontWeight: 500,
          }}>
            <NavIcon id="calendar" size={13} />
            <span>{new Date().toLocaleDateString('en-IN', {
              day: '2-digit', month: 'short', year: 'numeric',
            })}</span>
          </div>

          {/* Admin badge */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            padding: '6px 14px', borderRadius: 99,
            background: 'var(--accentBg)', border: '1px solid var(--accentBd)',
          }}>
            <div style={{
              width: 24, height: 24, borderRadius: '50%', flexShrink: 0,
              background: 'linear-gradient(135deg, var(--accent), var(--accentL))',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: '#fff',
            }}>
              <NavIcon id="user" size={12} />
            </div>
            <span style={{
              fontSize: 12, fontWeight: 600, color: 'var(--accent)',
              maxWidth: 140, overflow: 'hidden',
              textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            }}>{user.email}</span>
          </div>

          {/* Theme Toggle */}
          <button style={{
            width: 36, height: 36, borderRadius: 10, flexShrink: 0,
            background: 'var(--surface2)', border: '1px solid var(--border)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', color: 'var(--text2)', transition: 'all .15s',
          }}
            onClick={toggleTheme}
            onMouseEnter={e => {
              e.currentTarget.style.background = 'var(--accentBg)';
              e.currentTarget.style.borderColor = 'var(--accentBd)';
              e.currentTarget.style.color = 'var(--accent)';
            }}
            onMouseLeave={e => {
              e.currentTarget.style.background = 'var(--surface2)';
              e.currentTarget.style.borderColor = 'var(--border)';
              e.currentTarget.style.color = 'var(--text2)';
            }}>
            <NavIcon id={theme === 'dark' ? 'sun' : 'moon'} size={16} />
          </button>

          {/* Notification bell */}
          <button style={{
            width: 36, height: 36, borderRadius: 10, flexShrink: 0,
            background: 'var(--surface2)', border: '1px solid var(--border)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', color: 'var(--text2)', position: 'relative',
            transition: 'all .15s',
          }}
            onMouseEnter={e => {
              e.currentTarget.style.background = 'var(--accentBg)';
              e.currentTarget.style.borderColor = 'var(--accentBd)';
              e.currentTarget.style.color = 'var(--accent)';
            }}
            onMouseLeave={e => {
              e.currentTarget.style.background = 'var(--surface2)';
              e.currentTarget.style.borderColor = 'var(--border)';
              e.currentTarget.style.color = 'var(--text2)';
            }}>
            <NavIcon id="bell" size={16} />
            {counts.open > 0 && (
              <div style={{
                position: 'absolute', top: 7, right: 7,
                width: 7, height: 7, borderRadius: '50%',
                background: 'var(--red)',
                border: '1.5px solid var(--surface)',
              }} />
            )}
          </button>
        </header>

        {/* ── Page content ── */}
        <main style={{
          flex: 1, overflowY: 'auto', overflowX: 'hidden',
          padding: 24,
          background: 'transparent',
        }}>
          <div key={page} style={{
            animation: 'fadeUp .38s cubic-bezier(.16,1,.3,1) both',
          }}>
            {renderPage()}
          </div>
        </main>
      </div>

    </div>
  );
}
