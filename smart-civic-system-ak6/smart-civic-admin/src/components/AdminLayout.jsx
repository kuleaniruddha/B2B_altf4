import { useState, useEffect, useRef } from 'react';
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
  close: 'M18 6L6 18M6 6l12 12',
  check: 'M20 6L9 17l-5-5',
  alert: ['M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z', 'M12 9v4', 'M12 17h.01'],
  sparkle: ['M12 2v4', 'M12 18v4', 'M4.93 4.93l2.83 2.83', 'M16.24 16.24l2.83 2.83', 'M2 12h4', 'M18 12h4', 'M4.93 19.07l2.83-2.83', 'M16.24 7.76l2.83-2.83'],
};

// Friendly time string calculation
const formatTimeAgo = (date) => {
  if (!date) return 'Recently';
  const now = new Date();
  const past = date.toDate ? date.toDate() : new Date(date);
  const diffSec = Math.floor((now - past) / 1000);
  if (diffSec < 45) return 'Just now';
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h ago`;
  const diffDays = Math.floor(diffHr / 24);
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) return `${diffDays}d ago`;
  return past.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' });
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
  const [theme, setTheme] = useState(() => localStorage.getItem('civic_theme') || localStorage.getItem('theme') || 'dark');
  const [selectedComplaintId, setSelectedComplaintId] = useState(null);
  const [isCrisisMode, setIsCrisisMode] = useState(false);

  // Notification states
  const [notifications, setNotifications] = useState([]);
  const [readIds, setReadIds] = useState(() => {
    try {
      const stored = localStorage.getItem('civic_read_notifications');
      return new Set(stored ? JSON.parse(stored) : []);
    } catch {
      return new Set();
    }
  });
  const [notifOpen, setNotifOpen] = useState(false);
  const [notifTab, setNotifTab] = useState('all'); // 'all' | 'unread'
  const [activeToast, setActiveToast] = useState(null);
  const isInitialSnap = useRef(true);
  const notifRef = useRef(null);

  // Sync theme
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('civic_theme', theme);
    localStorage.setItem('theme', theme);
  }, [theme]);

  const toggleTheme = () => setTheme(t => t === 'light' ? 'dark' : 'light');

  // Sync complaints and notifications
  useEffect(() => {
    const baseRef = collection(db, 'issues');
    const q = (user.role === 'hod' && user.department)
      ? query(baseRef, where('assignedTo', '==', user.department))
      : baseRef;

    const unsub = onSnapshot(q, snap => {
      const rawIssues = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      
      // Sort issues newest first
      const sorted = [...rawIssues].sort((a, b) => {
        const ta = a.createdAt?.toDate ? a.createdAt.toDate() : new Date(a.createdAt || 0);
        const tb = b.createdAt?.toDate ? b.createdAt.toDate() : new Date(b.createdAt || 0);
        return tb - ta;
      });

      setNotifications(sorted);
      setCounts({
        open: sorted.filter(i => i.status === 'open' || i.status === 'assigned').length,
        total: sorted.length,
      });

      // Detect newly added complaints in real-time
      if (!isInitialSnap.current) {
        snap.docChanges().forEach(change => {
          if (change.type === 'added') {
            const d = change.doc.data();
            setActiveToast({
              id: change.doc.id,
              title: d.title || 'New Complaint Received',
              wardNo: d.wardNo,
              category: d.category,
              department: d.assignedTo,
              priority: d.priority || 'normal',
            });
          }
        });
      } else {
        isInitialSnap.current = false;
      }
    }, (err) => {
      console.warn("Sidebar & Notification count error:", err);
      setCounts({ open: 0, total: 0 });
    });
    return unsub;
  }, [user.role, user.department]);

  // Click outside to close notifications dropdown
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (notifRef.current && !notifRef.current.contains(e.target)) {
        setNotifOpen(false);
      }
    };
    if (notifOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [notifOpen]);

  // Auto-dismiss floating toast
  useEffect(() => {
    if (activeToast) {
      const timer = setTimeout(() => setActiveToast(null), 7000);
      return () => clearTimeout(timer);
    }
  }, [activeToast]);

  const markAsRead = (id) => {
    setReadIds(prev => {
      const next = new Set(prev);
      next.add(id);
      try {
        localStorage.setItem('civic_read_notifications', JSON.stringify([...next]));
      } catch (e) {
        console.warn('Storage error:', e);
      }
      return next;
    });
  };

  const markAllAsRead = () => {
    setReadIds(prev => {
      const next = new Set(prev);
      notifications.forEach(n => next.add(n.id));
      try {
        localStorage.setItem('civic_read_notifications', JSON.stringify([...next]));
      } catch (e) {
        console.warn('Storage error:', e);
      }
      return next;
    });
  };

  const handleNotificationClick = (id) => {
    markAsRead(id);
    setSelectedComplaintId(id);
    setPage('complaints');
    setNotifOpen(false);
  };

  const unreadCount = notifications.filter(n => !readIds.has(n.id)).length;
  const displayedNotifications = notifTab === 'unread' 
    ? notifications.filter(n => !readIds.has(n.id))
    : notifications;

  const logout = async () => {
    if (window.confirm('Sign out of admin panel?')) await signOut(auth);
  };

  const W = collapsed ? 64 : 234;

  const renderPage = () => {
    switch (page) {
      case 'dashboard': return <Dashboard user={user} isCrisisMode={isCrisisMode} />;
      case 'complaints': return (
        <Complaints
          user={user}
          initialSelectedId={selectedComplaintId}
          onClearSelectedId={() => setSelectedComplaintId(null)}
          isCrisisMode={isCrisisMode}
        />
      );
      case 'users': return <Users user={user} />;
      case 'analytics': return <Analytics user={user} />;
      default: return <Dashboard user={user} isCrisisMode={isCrisisMode} />;
    }
  };

  // ── Sidebar ──────────────────────────────────────────────────────────────────
  const Sidebar = () => (
    <aside style={{
      width: W, flexShrink: 0,
      background: 'var(--glass)',
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
                background: active ? 'linear-gradient(180deg, var(--surface) 0%, var(--accentBg) 100%)' : 'transparent',
                border: active ? '1px solid var(--accentBd)' : '1px solid transparent',
                borderRadius: 14, cursor: 'pointer',
                color: active ? 'var(--accent)' : 'var(--text2)',
                fontSize: 13, fontWeight: active ? 700 : 500,
                transition: 'all .15s', marginBottom: 3,
                position: 'relative', outline: 'none',
                boxShadow: active ? '0 10px 24px var(--accentGl)' : 'none',
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
            background: 'var(--surface2)', border: '1px solid var(--border)',
            marginBottom: 8,
            boxShadow: 'inset 0 1px 0 var(--borderHl)',
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
          background: 'var(--glass)',
          borderBottom: '1px solid var(--border)',
          display: 'flex', alignItems: 'center',
          padding: '0 24px', gap: 12,
          boxShadow: 'var(--sh)',
          backdropFilter: 'blur(24px)',
          WebkitBackdropFilter: 'blur(24px)',
          position: 'relative',
          zIndex: 100,
        }}>

          {/* Page title */}
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ color: isCrisisMode ? 'var(--red)' : 'var(--textMuted)' }}>
              <NavIcon id={isCrisisMode ? 'alert' : page} size={16} />
            </div>
            <h2 style={{
              fontFamily: 'var(--font-display)', fontSize: 15, fontWeight: 700,
              color: isCrisisMode ? 'var(--red)' : 'var(--text)', 
              textTransform: isCrisisMode ? 'uppercase' : 'capitalize', margin: 0,
              letterSpacing: isCrisisMode ? 0.5 : 0,
            }}>
              {isCrisisMode ? "EMERGENCY OPERATIONAL STATUS: SYSTEM STRESSED" : page}
            </h2>
          </div>

          {/* Crisis Mode Toggle */}
          <button
            onClick={() => setIsCrisisMode(!isCrisisMode)}
            style={{
              padding: '6px 14px', borderRadius: 99,
              background: isCrisisMode ? 'var(--red)' : 'var(--surface2)',
              border: `1px solid ${isCrisisMode ? 'var(--redBd)' : 'var(--redBd)'}`,
              color: isCrisisMode ? '#fff' : 'var(--red)',
              fontSize: 11.5, fontWeight: 800, cursor: 'pointer',
              display: 'flex', alignItems: 'center', gap: 6,
              transition: 'all .2s',
              animation: isCrisisMode ? 'pulse 2s infinite' : 'none',
              boxShadow: isCrisisMode ? '0 0 15px rgba(255, 60, 60, 0.4)' : 'none',
            }}
          >
            <NavIcon id="alert" size={13} />
            {isCrisisMode ? 'SYSTEM STRESSED' : 'Simulate System Stress / Crisis Mode'}
          </button>

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

          {/* Notification bell container with dropdown */}
          <div style={{ position: 'relative', zIndex: 110 }}>
            <button
              onClick={() => setNotifOpen(prev => !prev)}
              title="Notifications"
              style={{
                width: 36, height: 36, borderRadius: 10, flexShrink: 0,
                background: notifOpen ? 'var(--accentBg)' : 'var(--surface2)',
                border: `1px solid ${notifOpen ? 'var(--accentBd)' : 'var(--border)'}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                cursor: 'pointer', color: notifOpen ? 'var(--accent)' : 'var(--text2)',
                position: 'relative', transition: 'all .15s',
              }}
              onMouseEnter={e => {
                e.currentTarget.style.background = 'var(--accentBg)';
                e.currentTarget.style.borderColor = 'var(--accentBd)';
                e.currentTarget.style.color = 'var(--accent)';
              }}
              onMouseLeave={e => {
                if (!notifOpen) {
                  e.currentTarget.style.background = 'var(--surface2)';
                  e.currentTarget.style.borderColor = 'var(--border)';
                  e.currentTarget.style.color = 'var(--text2)';
                }
              }}
            >
              <NavIcon id="bell" size={16} />
              {unreadCount > 0 && (
                <div style={{
                  position: 'absolute', top: -4, right: -4,
                  minWidth: 17, height: 17, borderRadius: 99,
                  background: 'var(--red)', color: '#fff',
                  border: '2px solid var(--surface)',
                  fontSize: 9.5, fontWeight: 800,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  padding: '0 3px',
                  boxShadow: '0 2px 8px rgba(220,38,38,0.35)',
                  animation: 'pulse 1.8s ease infinite',
                  lineHeight: 1,
                }}>
                  {unreadCount > 99 ? '99+' : unreadCount}
                </div>
              )}
            </button>

            {/* Notification Dropdown Panel */}
            {notifOpen && (
              <div
                ref={notifRef}
                style={{
                  position: 'absolute', top: 48, right: 0,
                  width: 390, maxHeight: 530,
                  background: 'var(--popoverBg)',
                  border: '1.5px solid var(--border2)',
                  borderRadius: 20,
                  boxShadow: '0 30px 70px rgba(0, 0, 0, 0.55), 0 0 0 1px var(--border)',
                  display: 'flex', flexDirection: 'column',
                  zIndex: 99999,
                  animation: 'scaleIn .2s cubic-bezier(.16,1,.3,1) both',
                  overflow: 'hidden',
                }}
              >
                {/* Panel Header */}
                <div style={{
                  padding: '14px 18px',
                  borderBottom: '1px solid var(--border)',
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                  background: 'var(--popoverHeader)',
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{
                      width: 28, height: 28, borderRadius: 8,
                      background: 'var(--accentBg)', border: '1px solid var(--accentBd)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      color: 'var(--accent)',
                    }}>
                      <NavIcon id="bell" size={14} />
                    </div>
                    <div>
                      <h4 style={{
                        fontFamily: 'var(--font-display)', fontSize: 14, fontWeight: 700,
                        color: 'var(--text)', margin: 0, lineHeight: 1.2,
                      }}>Notifications</h4>
                      <p style={{ fontSize: 10.5, color: 'var(--text3)', margin: '2px 0 0', fontWeight: 600 }}>
                        {unreadCount > 0 ? `${unreadCount} unread complaint${unreadCount > 1 ? 's' : ''}` : 'All caught up'}
                      </p>
                    </div>
                  </div>

                  {unreadCount > 0 && (
                    <button
                      onClick={markAllAsRead}
                      style={{
                        background: 'var(--accentBg)', border: '1px solid var(--accentBd)',
                        color: 'var(--accent)', fontSize: 11, fontWeight: 700,
                        cursor: 'pointer', padding: '5px 10px', borderRadius: 8,
                        display: 'flex', alignItems: 'center', gap: 4,
                        transition: 'all .15s',
                      }}
                      onMouseEnter={e => e.currentTarget.style.opacity = '0.8'}
                      onMouseLeave={e => e.currentTarget.style.opacity = '1'}
                    >
                      <NavIcon id="check" size={12} />
                      Mark all read
                    </button>
                  )}
                </div>

                {/* Tab Filter */}
                <div style={{
                  display: 'flex', padding: '8px 12px', gap: 6,
                  borderBottom: '1px solid var(--border)',
                  background: 'var(--popoverBg)',
                }}>
                  <button
                    onClick={() => setNotifTab('all')}
                    style={{
                      flex: 1, padding: '7px 10px', borderRadius: 8,
                      border: notifTab === 'all' ? '1px solid var(--accentBd)' : '1px solid transparent',
                      cursor: 'pointer', fontSize: 11.5, fontWeight: 700,
                      background: notifTab === 'all' ? 'var(--accentBg)' : 'var(--surface2)',
                      color: notifTab === 'all' ? 'var(--accent)' : 'var(--text2)',
                      transition: 'all .15s',
                    }}
                  >
                    All ({notifications.length})
                  </button>
                  <button
                    onClick={() => setNotifTab('unread')}
                    style={{
                      flex: 1, padding: '7px 10px', borderRadius: 8,
                      border: notifTab === 'unread' ? '1px solid var(--accentBd)' : '1px solid transparent',
                      cursor: 'pointer', fontSize: 11.5, fontWeight: 700,
                      background: notifTab === 'unread' ? 'var(--accentBg)' : 'var(--surface2)',
                      color: notifTab === 'unread' ? 'var(--accent)' : 'var(--text2)',
                      transition: 'all .15s',
                    }}
                  >
                    Unread ({unreadCount})
                  </button>
                </div>

                {/* Notifications List */}
                <div style={{
                  flex: 1, overflowY: 'auto', maxHeight: 350, padding: '10px 12px',
                  background: 'var(--popoverBg)',
                }}>
                  {displayedNotifications.length === 0 ? (
                    <div style={{ textAlign: 'center', padding: '40px 20px', color: 'var(--text3)' }}>
                      <div style={{
                        width: 44, height: 44, borderRadius: '50%',
                        background: 'var(--surface2)', margin: '0 auto 10px',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        color: 'var(--text3)', border: '1px solid var(--border)',
                      }}>
                        <NavIcon id="sparkle" size={20} />
                      </div>
                      <p style={{ fontSize: 13, fontWeight: 700, color: 'var(--text)', margin: 0 }}>
                        {notifTab === 'unread' ? 'No unread notifications' : 'No notifications yet'}
                      </p>
                      <p style={{ fontSize: 11, color: 'var(--text3)', marginTop: 4 }}>
                        New incoming complaints from citizens will appear here in real time.
                      </p>
                    </div>
                  ) : (
                    displayedNotifications.map(item => {
                      const isUnread = !readIds.has(item.id);
                      const isUrgent = item.priority === 'urgent';
                      const isHigh = item.priority === 'high';
                      const color = isUrgent ? 'var(--red)' : isHigh ? 'var(--orange)' : 'var(--blue)';
                      const bg = isUrgent ? 'var(--redBg)' : isHigh ? 'var(--orangeBg)' : 'var(--blueBg)';
                      const bd = isUrgent ? 'var(--redBd)' : isHigh ? 'var(--orangeBd)' : 'var(--blueBd)';

                      return (
                        <div
                          key={item.id}
                          onClick={() => handleNotificationClick(item.id)}
                          style={{
                            padding: '12px 14px',
                            borderRadius: 14,
                            background: isUnread ? 'var(--surface2)' : 'var(--surfaceCard)',
                            border: `1.5px solid ${isUnread ? 'var(--border2)' : 'var(--border)'}`,
                            marginBottom: 8,
                            cursor: 'pointer',
                            display: 'flex', alignItems: 'flex-start', gap: 12,
                            transition: 'all .15s',
                            boxShadow: '0 2px 6px rgba(0, 0, 0, 0.08)',
                          }}
                          onMouseEnter={e => {
                            e.currentTarget.style.background = 'var(--surfaceHover)';
                            e.currentTarget.style.borderColor = 'var(--accentBd)';
                          }}
                          onMouseLeave={e => {
                            e.currentTarget.style.background = isUnread ? 'var(--surface2)' : 'var(--surfaceCard)';
                            e.currentTarget.style.borderColor = isUnread ? 'var(--border2)' : 'var(--border)';
                          }}
                        >
                          {/* Priority dot / Icon */}
                          <div style={{
                            width: 34, height: 34, borderRadius: 10, flexShrink: 0,
                            background: bg, border: `1.5px solid ${bd}`,
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            color: color, marginTop: 2,
                          }}>
                            <NavIcon id={isUrgent ? 'alert' : 'complaints'} size={15} />
                          </div>

                          {/* Details */}
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 6 }}>
                              <p style={{
                                fontSize: 13, fontWeight: isUnread ? 700 : 600,
                                color: 'var(--text)', margin: 0,
                                overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                              }}>
                                {item.title || 'Untitled Complaint'}
                              </p>
                              {isUnread && (
                                <div style={{
                                  width: 8, height: 8, borderRadius: '50%',
                                  background: 'var(--accent)', flexShrink: 0,
                                  boxShadow: '0 0 6px var(--accent)',
                                }} />
                              )}
                            </div>

                            <div style={{
                              display: 'flex', alignItems: 'center', gap: 6,
                              marginTop: 6, flexWrap: 'wrap',
                            }}>
                              <span style={{
                                fontSize: 10, fontWeight: 700,
                                padding: '2px 7px', borderRadius: 6,
                                background: 'var(--surface2)', border: '1px solid var(--border)',
                                color: 'var(--text)',
                              }}>
                                Ward {item.wardNo || 'N/A'}
                              </span>
                              <span style={{
                                fontSize: 11, fontWeight: 500, color: 'var(--text2)',
                                maxWidth: 130, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                              }}>
                                {item.category || item.assignedTo || 'General'}
                              </span>
                              <span style={{ fontSize: 10.5, fontWeight: 600, color: 'var(--text3)', marginLeft: 'auto' }}>
                                {formatTimeAgo(item.createdAt)}
                              </span>
                            </div>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>

                {/* Panel Footer */}
                <div style={{
                  padding: '12px 16px',
                  borderTop: '1px solid var(--border)',
                  background: 'var(--popoverHeader)',
                  textAlign: 'center',
                }}>
                  <button
                    onClick={() => {
                      setPage('complaints');
                      setNotifOpen(false);
                    }}
                    style={{
                      width: '100%', padding: '9px',
                      background: 'var(--surface2)', border: '1px solid var(--border)',
                      borderRadius: 10, color: 'var(--accent)',
                      fontSize: 12, fontWeight: 700, cursor: 'pointer',
                      transition: 'all .15s',
                    }}
                    onMouseEnter={e => {
                      e.currentTarget.style.background = 'var(--accentBg)';
                      e.currentTarget.style.borderColor = 'var(--accentBd)';
                    }}
                    onMouseLeave={e => {
                      e.currentTarget.style.background = 'var(--surface2)';
                      e.currentTarget.style.borderColor = 'var(--border)';
                    }}
                  >
                    View All Complaints in Queue →
                  </button>
                </div>
              </div>
            )}
          </div>
        </header>

        {/* Floating Real-time Toast Alert */}
        {activeToast && (
          <div
            style={{
              position: 'fixed', top: 68, right: 24, zIndex: 999999,
              width: 360, background: 'var(--popoverBg)',
              border: '1.5px solid var(--accentBd)', borderRadius: 16,
              padding: '14px 16px',
              boxShadow: '0 25px 60px rgba(0, 0, 0, 0.55)',
              display: 'flex', alignItems: 'flex-start', gap: 12,
              animation: 'slideInRight .35s cubic-bezier(.16,1,.3,1) both',
            }}
          >
            <div style={{
              width: 36, height: 36, borderRadius: 10,
              background: 'var(--accentBg)', border: '1px solid var(--accentBd)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: 'var(--accent)', flexShrink: 0,
            }}>
              <NavIcon id="bell" size={18} />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 2 }}>
                <span style={{ fontSize: 11, fontWeight: 800, color: 'var(--accent)', textTransform: 'uppercase', letterSpacing: 0.5 }}>
                  New Complaint Received
                </span>
                <button
                  onClick={() => setActiveToast(null)}
                  style={{ background: 'none', border: 'none', color: 'var(--text3)', cursor: 'pointer', padding: 2 }}
                >
                  <NavIcon id="close" size={13} />
                </button>
              </div>
              <p style={{
                fontSize: 13, fontWeight: 700, color: 'var(--text)', margin: 0,
                overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
              }}>
                {activeToast.title}
              </p>
              <p style={{ fontSize: 11, color: 'var(--text2)', margin: '2px 0 8px' }}>
                Ward {activeToast.wardNo || 'N/A'} · {activeToast.department || activeToast.category || 'General'}
              </p>
              <button
                onClick={() => {
                  handleNotificationClick(activeToast.id);
                  setActiveToast(null);
                }}
                style={{
                  padding: '6px 14px', borderRadius: 8,
                  background: 'var(--accent)', border: 'none',
                  color: '#fff', fontSize: 11.5, fontWeight: 700,
                  cursor: 'pointer', outline: 'none',
                  display: 'inline-flex', alignItems: 'center', gap: 5,
                  boxShadow: '0 2px 8px rgba(240, 100, 30, 0.4)',
                }}
              >
                View Complaint →
              </button>
            </div>
          </div>
        )}

        {/* ── Page content ── */}
        <main style={{
          flex: 1, overflowY: 'auto', overflowX: 'hidden',
          padding: 24,
          background: isCrisisMode ? 'rgba(220, 20, 20, 0.05)' : 'transparent',
          position: 'relative',
          zIndex: 1,
          animation: isCrisisMode ? 'crisisPulse 2.5s ease-in-out infinite alternate' : 'none',
        }}>
          <div key={page} style={{
            animation: 'fadeUp .38s cubic-bezier(.16,1,.3,1) both',
          }}>
            {renderPage()}
          </div>
        </main>
      </div>

      <style>{`
        @keyframes scaleIn {
          from { opacity: 0; transform: scale(0.95) translateY(-6px); }
          to { opacity: 1; transform: scale(1) translateY(0); }
        }
        @keyframes slideInRight {
          from { opacity: 0; transform: translateX(40px); }
          to { opacity: 1; transform: translateX(0); }
        }
        @keyframes crisisPulse {
          0% { box-shadow: inset 0 0 0 rgba(255, 0, 0, 0); }
          100% { box-shadow: inset 0 0 120px rgba(255, 0, 0, 0.15); }
        }
      `}</style>
    </div>
  );
}
