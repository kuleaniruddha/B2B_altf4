import { useState, useEffect } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../firebase';

export default function LoginPage({ debugMsg }) {
  const [loginMode, setLoginMode] = useState('admin'); // 'admin' or 'hod'
  const [email, setEmail] = useState('');
  const [pass, setPass] = useState('');
  const [err, setErr] = useState('');
  const [loading, setLoading] = useState(false);
  const [showP, setShowP] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    // Force Light theme on Login page to keep brand consistency,
    // or we can allow dark mode if system prefers it.
    // For now we will allow global theme to take over.
    const t = setTimeout(() => setMounted(true), 60);
    return () => clearTimeout(t);
  }, []);

  const login = async (e) => {
    e.preventDefault();
    if (!email || !pass) { setErr('Please fill in all fields.'); return; }
    setLoading(true); setErr('');
    try {
      await signInWithEmailAndPassword(auth, email.trim(), pass);
    } catch (ex) {
      setErr(
        ex.code === 'auth/invalid-credential' || ex.code === 'auth/wrong-password'
          ? 'Invalid email or password.' :
          ex.code === 'auth/user-not-found' ? 'No account found with this email.' :
            ex.code === 'auth/too-many-requests' ? 'Too many attempts. Try later.' :
              ex.code === 'auth/invalid-email' ? 'Invalid email format.' :
                `Error: ${ex.code}`
      );
    }
    setLoading(false);
  };

  const inputStyle = {
    width: '100%',
    padding: '13px 16px',
    background: 'var(--surface2)',
    border: '1.5px solid var(--border)',
    borderRadius: 12,
    fontSize: 14,
    color: 'var(--text)',
    transition: 'border-color .2s, box-shadow .2s, background .2s',
    display: 'block',
  };

  const transition = (ms = 0) => ({
    opacity: mounted ? 1 : 0,
    transform: mounted ? 'translateY(0)' : 'translateY(20px)',
    transition: `opacity .6s ease ${ms}ms, transform .6s cubic-bezier(.16,1,.3,1) ${ms}ms`,
  });

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      overflow: 'hidden',
      fontFamily: 'var(--font-sans)',
      background: 'var(--bg)'
    }}>

      {/* ════════════════════════════════════════
          LEFT — Form
      ════════════════════════════════════════ */}
      <div style={{
        width: 500,
        flexShrink: 0,
        background: 'var(--surface)',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        padding: '52px 56px',
        position: 'relative',
        zIndex: 2,
        boxShadow: 'var(--shMd)',
      }}>

        {/* Top accent line */}
        <div style={{
          position: 'absolute', top: 0, left: 0, right: 0, height: 4,
          background: 'linear-gradient(90deg, var(--accent) 0%, var(--accentL) 50%, var(--accent) 100%)',
          backgroundSize: '200% 100%',
          animation: 'shimmerBar 3s ease infinite',
        }} />

        {/* ── Logo ── */}
        <div style={{ ...transition(0), display: 'flex', alignItems: 'center', gap: 14, marginBottom: 56 }}>
          <div style={{
            width: 44, height: 44, borderRadius: 12, flexShrink: 0,
            background: 'linear-gradient(135deg, var(--accent), var(--accentL))',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: 'var(--shAccent)',
          }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
              <polyline points="9 22 9 12 15 12 15 22" />
            </svg>
          </div>
          <div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 17, fontWeight: 700, color: 'var(--text)', letterSpacing: -0.3 }}>
              Smart Civic Mumbai
            </div>
            <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 1, letterSpacing: 0.3 }}>
              Admin Control Panel
            </div>
          </div>
        </div>

        {/* ── Mode Switcher ── */}
        <div style={{
          ...transition(50),
          display: 'flex', background: 'var(--surface2)', borderRadius: 12, padding: 4, marginBottom: 32, gap: 4,
          border: '1px solid var(--border)'
        }}>
          <button 
            type="button"
            onClick={() => setLoginMode('admin')}
            style={{
              flex: 1, padding: '10px', borderRadius: 9, border: 'none', cursor: 'pointer',
              fontSize: 12, fontWeight: 700, transition: 'all .25s',
              background: loginMode === 'admin' ? 'var(--surface)' : 'transparent',
              color: loginMode === 'admin' ? 'var(--accent)' : 'var(--text2)',
              boxShadow: loginMode === 'admin' ? 'var(--shMd)' : 'none',
              outline: 'none',
            }}>Main Admin</button>
          <button 
            type="button"
            onClick={() => setLoginMode('hod')}
            style={{
              flex: 1, padding: '10px', borderRadius: 9, border: 'none', cursor: 'pointer',
              fontSize: 12, fontWeight: 700, transition: 'all .25s',
              background: loginMode === 'hod' ? 'var(--surface)' : 'transparent',
              color: loginMode === 'hod' ? 'var(--accent)' : 'var(--text2)',
              boxShadow: loginMode === 'hod' ? 'var(--shMd)' : 'none',
              outline: 'none',
            }}>Department HOD</button>
        </div>

        {/* ── Heading ── */}
        <div key={loginMode} style={{ ...transition(100), animation: 'fadeUp .4s cubic-bezier(.16,1,.3,1) both' }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 7,
            background: 'var(--accentBg)', border: '1px solid var(--accentBd)',
            borderRadius: 99, padding: '5px 13px',
            fontSize: 11, fontWeight: 700, color: 'var(--accent)',
            marginBottom: 20, letterSpacing: 0.3, textTransform: 'uppercase'
          }}>
            <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--accent)', animation: 'pulse 1.8s ease infinite' }} />
            {loginMode === 'admin' ? 'Super User' : 'Departmental Head'}
          </div>

          <h1 style={{
            fontFamily: 'var(--font-display)', fontSize: 30, fontWeight: 700,
            color: 'var(--text)', lineHeight: 1.15, margin: '0 0 10px',
            letterSpacing: -0.5,
          }}>
            {loginMode === 'admin' ? 'Admin Login' : 'HOD Login'}
          </h1>
          <p style={{ fontSize: 14, color: 'var(--text2)', lineHeight: 1.7, margin: '0 0 30px' }}>
            {loginMode === 'admin' 
              ? 'Complete city-wide access for senior administrators.' 
              : 'Sign in to manage your department-specific workspace.'}
          </p>
        </div>

        {/* ── Error ── */}
        {(err || debugMsg) && (
          <div style={{
            background: 'var(--redBg)', border: '1px solid var(--redBd)',
            borderRadius: 12, padding: '12px 16px', marginBottom: 20,
            fontSize: 13, color: 'var(--red)', lineHeight: 1.5,
            display: 'flex', gap: 10, alignItems: 'center',
            animation: 'fadeIn .3s ease both',
          }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
              <circle cx="12" cy="12" r="10" /><line x1="12" y1="8" x2="12" y2="12" /><line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
            {err || debugMsg}
          </div>
        )}

        {/* ── Form ── */}
        <form onSubmit={login} style={transition(160)}>
          {/* Email */}
          <div style={{ marginBottom: 18 }}>
            <label style={{
              fontSize: 11, fontWeight: 700, color: 'var(--text3)',
              letterSpacing: 1.3, textTransform: 'uppercase',
              display: 'block', marginBottom: 8,
            }}>Email Address</label>
            <div style={{ position: 'relative' }}>
              <div style={{
                position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)',
                color: 'var(--text3)', pointerEvents: 'none',
              }}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
                  <polyline points="22,6 12,13 2,6" />
                </svg>
              </div>
              <input
                type="email" value={email}
                placeholder="admin@smartcivic.com"
                onChange={e => setEmail(e.target.value)}
                style={{ ...inputStyle, paddingLeft: 42 }}
                onFocus={e => {
                  e.target.style.borderColor = 'var(--accent)';
                  e.target.style.boxShadow = 'var(--shAccent)';
                  e.target.style.background = 'var(--surface)';
                }}
                onBlur={e => {
                  e.target.style.borderColor = 'var(--border)';
                  e.target.style.boxShadow = 'none';
                  e.target.style.background = 'var(--surface2)';
                }}
              />
            </div>
          </div>

          {/* Password */}
          <div style={{ marginBottom: 30 }}>
            <label style={{
              fontSize: 11, fontWeight: 700, color: 'var(--text3)',
              letterSpacing: 1.3, textTransform: 'uppercase',
              display: 'block', marginBottom: 8,
            }}>Password</label>
            <div style={{ position: 'relative' }}>
              <div style={{
                position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)',
                color: 'var(--text3)', pointerEvents: 'none',
              }}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                  <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                </svg>
              </div>
              <input
                type={showP ? 'text' : 'password'} value={pass}
                placeholder="Enter your password"
                onChange={e => setPass(e.target.value)}
                style={{ ...inputStyle, paddingLeft: 42, paddingRight: 48 }}
                onFocus={e => {
                  e.target.style.borderColor = 'var(--accent)';
                  e.target.style.boxShadow = 'var(--shAccent)';
                  e.target.style.background = 'var(--surface)';
                }}
                onBlur={e => {
                  e.target.style.borderColor = 'var(--border)';
                  e.target.style.boxShadow = 'none';
                  e.target.style.background = 'var(--surface2)';
                }}
              />
              <button
                type="button" onClick={() => setShowP(p => !p)}
                style={{
                  position: 'absolute', right: 14, top: '50%', transform: 'translateY(-50%)',
                  background: 'none', border: 'none', cursor: 'pointer',
                  color: 'var(--text3)', padding: 0, lineHeight: 0,
                  transition: 'color .15s',
                }}
                onMouseEnter={e => e.currentTarget.style.color = 'var(--accent)'}
                onMouseLeave={e => e.currentTarget.style.color = 'var(--text3)'}
              >
                {showP
                  ? <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" /><line x1="1" y1="1" x2="23" y2="23" /></svg>
                  : <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" /><circle cx="12" cy="12" r="3" /></svg>
                }
              </button>
            </div>
          </div>

          {/* Submit */}
          <button
            type="submit" disabled={loading}
            style={{
              width: '100%', padding: '15px',
              background: loading
                ? 'var(--surface2)'
                : 'linear-gradient(135deg, var(--accent) 0%, var(--accentL) 100%)',
              border: 'none', borderRadius: 13,
              color: loading ? 'var(--text3)' : '#fff',
              fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 15,
              cursor: loading ? 'not-allowed' : 'pointer',
              boxShadow: loading ? 'none' : 'var(--shAccent)',
              transition: 'all .2s', letterSpacing: 0.2,
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
            }}
            onMouseEnter={e => {
              if (!loading) {
                e.currentTarget.style.transform = 'translateY(-1px)';
                e.currentTarget.style.boxShadow = '0 10px 30px rgba(230,81,0,0.4)';
              }
            }}
            onMouseLeave={e => {
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = loading ? 'none' : 'var(--shAccent)';
            }}
          >
            {loading ? (
              <>
                <div style={{
                  width: 18, height: 18, borderRadius: '50%',
                  border: '2.5px solid var(--border)',
                  borderTopColor: 'var(--text2)',
                  animation: 'spin .7s linear infinite',
                }} />
                Signing in...
              </>
            ) : (
              <>
                Sign In
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <line x1="5" y1="12" x2="19" y2="12" /><polyline points="12 5 19 12 12 19" />
                </svg>
              </>
            )}
          </button>
        </form>

        {/* Footer note */}
        <div style={{
          ...transition(240),
          marginTop: 32, paddingTop: 24,
          borderTop: '1px solid var(--border)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="var(--textMuted)" strokeWidth="2.5" strokeLinecap="round">
            <rect x="3" y="11" width="18" height="11" rx="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" />
          </svg>
          <span style={{ fontSize: 11, color: 'var(--text3)', letterSpacing: 0.3 }}>
            Secured with Firebase · BMC Official Portal
          </span>
        </div>
      </div>

      {/* ════════════════════════════════════════
          RIGHT — Visual Panel
      ════════════════════════════════════════ */}
      <div style={{
        flex: 1,
        background: 'var(--surface2)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: 52, position: 'relative', overflow: 'hidden',
      }}>
        {/* Decorative orbs */}
        <div style={{
          position: 'absolute', top: '-8%', right: '-4%',
          width: 420, height: 420, borderRadius: '50%',
          background: 'radial-gradient(circle, var(--accentGl) 0%, transparent 70%)',
        }} />
        <div style={{
          position: 'absolute', bottom: '8%', left: '-6%',
          width: 320, height: 320, borderRadius: '50%',
          background: 'radial-gradient(circle, var(--blueBg) 0%, transparent 70%)',
        }} />
        <div style={{
          position: 'absolute', top: '45%', left: '35%',
          width: 180, height: 180, borderRadius: '50%',
          background: 'radial-gradient(circle, var(--greenBg) 0%, transparent 70%)',
        }} />

        {/* Grid pattern */}
        <div style={{
          position: 'absolute', inset: 0,
          backgroundImage: 'radial-gradient(circle, var(--border) 1px, transparent 1px)',
          backgroundSize: '28px 28px',
          opacity: 0.6,
        }} />

        <div style={{ position: 'relative', maxWidth: 440, textAlign: 'center', ...transition(100) }}>
          {/* Icon block */}
          <div style={{
            width: 88, height: 88, borderRadius: 24, margin: '0 auto 28px',
            background: 'linear-gradient(135deg, var(--accent), var(--accentL))',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: 'var(--shAccent)',
          }}>
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
              <polyline points="9 22 9 12 15 12 15 22" />
            </svg>
          </div>

          <h2 style={{
            fontFamily: 'var(--font-display)', fontSize: 28, fontWeight: 700,
            color: 'var(--text)', marginBottom: 14, lineHeight: 1.25, letterSpacing: -0.4,
          }}>
            Mumbai Civic<br />Admin Portal
          </h2>
          <p style={{
            fontSize: 14, color: 'var(--text2)', lineHeight: 1.75, marginBottom: 40,
          }}>
            Centralized management for civic complaints, user oversight, and real-time analytics across all Mumbai wards.
          </p>

          {/* Feature list */}
          <div style={{
            display: 'flex', flexDirection: 'column', gap: 10,
            textAlign: 'left', marginBottom: 40,
          }}>
            {[
              { icon: '⬡', label: 'Real-time complaint tracking across 24 wards' },
              { icon: '⬡', label: 'Role-based admin access & user management' },
              { icon: '⬡', label: 'Live analytics, trends & hotspot maps' },
              { icon: '⬡', label: 'Step-by-step complaint workflow & assignments' },
            ].map((f, i) => (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', gap: 12,
                background: 'var(--surface)', border: '1px solid var(--border)',
                borderRadius: 12, padding: '12px 16px',
                boxShadow: 'var(--sh)',
                ...transition(200 + i * 60),
              }}>
                <div style={{
                  width: 28, height: 28, borderRadius: 8, flexShrink: 0,
                  background: 'var(--accentBg)', border: '1px solid var(--accentBd)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <div style={{ width: 8, height: 8, borderRadius: 2, background: 'var(--accent)' }} />
                </div>
                <span style={{ fontSize: 13, color: 'var(--text2)', fontWeight: 500 }}>
                  {f.label}
                </span>
              </div>
            ))}
          </div>

          {/* Stat row */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
            {[
              { val: '24', label: 'Wards' },
              { val: 'Live', label: 'Updates' },
              { val: 'BMC', label: 'Official' },
            ].map((s, i) => (
              <div key={s.label} style={{
                background: 'var(--surface)', border: '1px solid var(--border)',
                borderRadius: 14, padding: '16px 10px',
                boxShadow: 'var(--sh)',
                ...transition(340 + i * 60),
              }}>
                <div style={{
                  fontFamily: 'var(--font-display)', fontWeight: 700,
                  fontSize: 22, color: 'var(--accent)', marginBottom: 4,
                }}>{s.val}</div>
                <div style={{ fontSize: 11, color: 'var(--text3)', fontWeight: 500 }}>
                  {s.label}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Inline keyframes */}
      <style>{`
        @keyframes shimmerBar {
          0%   { background-position: -200% 0; }
          100% { background-position: 200%  0; }
        }
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50%       { opacity: 0.4; }
        }
        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(6px); }
          to   { opacity: 1; transform: translateY(0);    }
        }
      `}</style>
    </div>
  );
}
