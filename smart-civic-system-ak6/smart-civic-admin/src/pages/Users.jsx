import { useState, useEffect } from 'react';
import { collection, onSnapshot, doc, updateDoc, deleteDoc, setDoc, serverTimestamp as firestoreTimestamp } from 'firebase/firestore';
import { db } from '../firebase';

import { STATUS, PRIORITY, DEPTS, STEPS } from '../constants';
import { Ic, ICONS, SBadge, PBadge } from '../components/SharedUI';

// ─── Role badge config ────────────────────────────────────────────────────────
const roleOf = u => {
  if (u.role === 'super_admin' || u.role === 'admin') return { label: 'Admin', icon: 'crown', color: 'var(--purple)', bg: 'var(--purpleBg)', bd: 'var(--purpleBd)' };
  if (u.role === 'hod') return { label: 'HOD', icon: 'shield', color: 'var(--blue)', bg: 'var(--blueBg)', bd: 'var(--blueBd)' };
  if (u.blocked) return { label: 'Blocked', icon: 'block', color: 'var(--red)', bg: 'var(--redBg)', bd: 'var(--redBd)' };
  return { label: 'Active', icon: 'check', color: 'var(--green)', bg: 'var(--greenBg)', bd: 'var(--greenBd)' };
};

// ─── Avatar initials ──────────────────────────────────────────────────────────
const Avatar = ({ name, size = 48 }) => {
  const initials = (name || '?').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();
  const hue = [...(name || 'A')].reduce((a, c) => a + c.charCodeAt(0), 0) % 360;
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%', flexShrink: 0,
      background: `hsl(${hue},60%,46%)`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: size * 0.35,
      color: '#fff', letterSpacing: 0.5,
      boxShadow: `0 3px 10px hsla(${hue},60%,40%,0.3)`,
    }}>{initials}</div>
  );
};


function UserModal({ u, user, onClose, onBlock, onDelete, onUpdate }) {
  const rb = roleOf(u);
  const [editRole, setEditRole] = useState(u.role || 'citizen');
  const [editDept, setEditDept] = useState(u.department || '');
  const [saving, setSaving] = useState(false);

  const isSuper = user.role === 'super_admin' || user.role === 'admin';

  useEffect(() => {
    const h = e => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [onClose]);

  const handleUpdate = async () => {
    setSaving(true);
    await onUpdate(u.id, { role: editRole, department: editRole === 'hod' ? editDept : '' });
    setSaving(false);
    onClose();
  };

  const fmtDate = ts => {
    if (!ts) return '—';
    const d = ts.toDate ? ts.toDate() : new Date(ts);
    return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  };

  const Row = ({ iconKey, label, value }) => (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '11px 16px',
      borderBottom: '1px solid var(--border)',
    }}>
      <div style={{
        width: 30, height: 30, borderRadius: 8, flexShrink: 0,
        background: 'var(--bg)', border: '1px solid var(--border)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: 'var(--text2)',
      }}>
        <Ic d={ICONS[iconKey]} size={14} />
      </div>
      <span style={{ fontSize: 12, color: 'var(--text3)', flex: '0 0 64px' }}>{label}</span>
      <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text)', flex: 1 }}>{value}</span>
    </div>
  );

  return (
    <div onClick={e => e.target === e.currentTarget && onClose()} style={{
      position: 'fixed', inset: 0, zIndex: 1000,
      background: 'rgba(2,6,23,0.6)', backdropFilter: 'blur(8px)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20,
    }}>
      <div style={{
        background: 'var(--surface)', borderRadius: 22,
        width: '100%', maxWidth: 420,
        boxShadow: 'var(--shModal)',
        overflow: 'hidden',
        animation: 'scaleIn .26s cubic-bezier(.16,1,.3,1) both',
      }}>
        {/* Header */}
        <div style={{
          background: 'linear-gradient(135deg, #1e293b 0%, #334155 100%)',
          padding: '28px 24px 24px',
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          position: 'relative',
        }}>
          {/* Close */}
          <button onClick={onClose} style={{
            position: 'absolute', top: 14, right: 14,
            width: 30, height: 30, borderRadius: '50%',
            background: 'rgba(255,255,255,0.1)', border: '1px solid rgba(255,255,255,0.15)',
            color: 'rgba(255,255,255,0.7)', cursor: 'pointer', display: 'flex',
            alignItems: 'center', justifyContent: 'center', outline: 'none',
            transition: 'all .15s',
          }}
            onMouseEnter={e => { e.currentTarget.style.background = 'rgba(255,255,255,0.2)'; }}
            onMouseLeave={e => { e.currentTarget.style.background = 'rgba(255,255,255,0.1)'; }}>
            <Ic d={ICONS.close} size={13} sw={2.5} />
          </button>

          <div style={{ marginBottom: 14, position: 'relative' }}>
            <Avatar name={u.name} size={72} />
            {/* Role indicator ring */}
            <div style={{
              position: 'absolute', bottom: 0, right: 0,
              width: 22, height: 22, borderRadius: '50%',
              background: rb.bg, border: `2px solid #fff`, 
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: rb.color,
            }}>
              <Ic d={ICONS[rb.icon]} size={11} sw={2.2} />
            </div>
          </div>

          <h2 style={{
            fontFamily: 'var(--font-display)', fontSize: 18, fontWeight: 700,
            color: '#fff', margin: 0, letterSpacing: -0.3,
          }}>{u.name || 'Unknown User'}</h2>
          <p style={{ fontSize: 12, color: 'rgba(255,255,255,0.6)', marginTop: 4 }}>{u.email}</p>

          <span style={{
            marginTop: 12, padding: '4px 14px', borderRadius: 99,
            fontSize: 10, fontWeight: 800, letterSpacing: 0.5, textTransform: 'uppercase',
            background: rb.bg, color: rb.color, border: `1px solid ${rb.bd}`,
          }}>{rb.label} {u.department ? `· ${u.department}` : ''}</span>
        </div>

        {/* Details */}
        <div style={{ padding: '0 0 20px' }}>
          <div style={{ borderBottom: '1px solid var(--border)', maxHeight: '30vh', overflowY: 'auto' }}>
            <Row iconKey="phone" label="Phone" value={u.phone || '—'} />
            <Row iconKey="map" label="Ward" value={u.wardNo ? `Ward ${u.wardNo}` : '—'} />
            <Row iconKey="cal" label="Joined" value={fmtDate(u.createdAt)} />
            <Row iconKey="key" label="Current Role" value={u.role || 'citizen'} />
            
            {/* Super Admin Privileged Controls */}
            {isSuper && u.email !== user.email && (
              <div style={{ padding: '16px', background: 'var(--surface2)', borderTop: '1px solid var(--border)' }}>
                 <p style={{ fontSize: 9, fontWeight: 900, letterSpacing: 1, color: 'var(--text3)', textTransform: 'uppercase', marginBottom: 10 }}>Update Permissions</p>
                 <div style={{ display: 'flex', gap: 10, marginBottom: 10 }}>
                   <select value={editRole} onChange={e => setEditRole(e.target.value)} style={{
                     flex: 1, padding: '7px 10px', borderRadius: 8, border: '1.5px solid var(--border)', background: 'var(--surface)', fontSize: 12, color: 'var(--text)', outline: 'none'
                   }}>
                     <option value="citizen">Citizen</option>
                     <option value="hod">HOD (Dept Head)</option>
                     <option value="super_admin">Super Admin</option>
                   </select>
                   {editRole === 'hod' && (
                     <select value={editDept} onChange={e => setEditDept(e.target.value)} style={{
                       flex: 1.5, padding: '7px 10px', borderRadius: 8, border: '1.5px solid var(--border)', background: 'var(--surface)', fontSize: 12, color: 'var(--text)', outline: 'none'
                     }}>
                       <option value="">Select Dept...</option>
                       {DEPTS.map(d => <option key={d} value={d}>{d}</option>)}
                     </select>
                   )}
                 </div>
                 <button 
                  disabled={saving || (editRole === 'hod' && !editDept)}
                  onClick={handleUpdate} 
                  style={{
                    width: '100%', padding: '8px', borderRadius: 8, background: 'var(--accent)', color: '#fff', fontSize: 12, fontWeight: 700, border: 'none', cursor: 'pointer', opacity: (saving || (editRole === 'hod' && !editDept)) ? 0.6 : 1
                 }}>
                   {saving ? 'Saving...' : 'Save Changes'}
                 </button>
              </div>
            )}
          </div>

          <div style={{ padding: '16px 20px 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
            {u.role !== 'super_admin' && (
              <div style={{ display: 'flex', gap: 8 }}>
                <button onClick={() => { onBlock(u); onClose(); }} style={{
                  flex: 1, padding: '11px', borderRadius: 11, cursor: 'pointer',
                  background: u.blocked ? 'var(--greenBg)' : 'var(--yellowBg)',
                  border: `1.5px solid ${u.blocked ? 'var(--greenBd)' : 'var(--yellowBd)'}`,
                  color: u.blocked ? 'var(--green)' : 'var(--yellow)',
                  fontWeight: 700, fontSize: 13, outline: 'none',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7,
                  transition: 'all .15s',
                }}>
                  <Ic d={u.blocked ? ICONS.unlock : ICONS.block} size={14} />
                  {u.blocked ? 'Unblock' : 'Block'}
                </button>
                <button onClick={() => onDelete(u)} style={{
                  flex: 1, padding: '11px', borderRadius: 11, cursor: 'pointer',
                  background: 'var(--redBg)', border: '1.5px solid var(--redBd)',
                  color: 'var(--red)', fontWeight: 700, fontSize: 13, outline: 'none',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7,
                  transition: 'all .15s',
                }}>
                  <Ic d={ICONS.trash} size={14} />
                  Delete
                </button>
              </div>
            )}
            <button onClick={onClose} style={{
              width: '100%', padding: '11px', borderRadius: 11, cursor: 'pointer',
              background: 'var(--surface2)', border: '1px solid var(--border)',
              color: 'var(--text2)', fontWeight: 600, fontSize: 13, outline: 'none',
            }}>Close</button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Seed Data ──────────────────────────────────────────────────────────────
const HOD_SEED_DATA = [
  { email: 'hod.roads@mumbai.gov', name: 'HOD Roads', dept: 'Road Department' },
  { email: 'hod.electric@mumbai.gov', name: 'HOD Electric', dept: 'Electric Department' },
  { email: 'hod.water@mumbai.gov', name: 'HOD Water', dept: 'Water Supply' },
  { email: 'hod.sanit@mumbai.gov', name: 'HOD Sanitation', dept: 'Sanitation Department' },
  { email: 'hod.traffic@mumbai.gov', name: 'HOD Traffic', dept: 'Traffic Control' },
  { email: 'hod.trees@mumbai.gov', name: 'HOD Trees', dept: 'Tree Authority' },
  { email: 'hod.general@mumbai.gov', name: 'HOD Admin', dept: 'General Administration' },
];

// ─── Users Page ───────────────────────────────────────────────────────────────
export default function Users({ user }) {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all');
  const [sel, setSel] = useState(null);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'users'), snap => {
      setUsers(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    }, () => setLoading(false));
    return unsub;
  }, []);

  const filtered = users.filter(u => {
    const q = search.toLowerCase();
    const ms = !q
      || (u.name || '').toLowerCase().includes(q)
      || (u.email || '').toLowerCase().includes(q)
      || (u.phone || '').includes(q)
      || String(u.wardNo || '').includes(q);
    const mf =
      filter === 'all' ? true :
        filter === 'admin' ? (u.role === 'admin' || u.role === 'super_admin') :
          filter === 'hod' ? u.role === 'hod' :
            filter === 'blocked' ? u.blocked :
              filter === 'active' ? !u.blocked && u.role !== 'admin' && u.role !== 'super_admin' && u.role !== 'hod' : true;
    return ms && mf;
  });

  const onUpdate = async (id, data) => {
    await updateDoc(doc(db, 'users', id), data);
  };

  const toggleBlock = async u => {
    if (!window.confirm(`${u.blocked ? 'Unblock' : 'Block'} ${u.name || u.email}?`)) return;
    await updateDoc(doc(db, 'users', u.id), { blocked: !u.blocked });
  };

  const deleteUser = async u => {
    if (!window.confirm(`Delete ${u.name || u.email}? This cannot be undone.`)) return;
    await deleteDoc(doc(db, 'users', u.id));
    if (sel?.id === u.id) setSel(null);
  };

  const fmtDate = ts => {
    if (!ts) return '—';
    const d = ts.toDate ? ts.toDate() : new Date(ts);
    return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`;
  };

  const counts = {
    all: users.length,
    active: users.filter(u => !u.blocked && u.role !== 'admin' && u.role !== 'super_admin' && u.role !== 'hod').length,
    admin: users.filter(u => u.role === 'admin' || u.role === 'super_admin').length,
    hod: users.filter(u => u.role === 'hod').length,
    blocked: users.filter(u => u.blocked).length,
  };

  const seedHODs = async () => {
    if (!window.confirm("This will create/reset 7 official HOD accounts in Firestore. Proceed?")) return;
    setLoading(true);
    try {
      for (const h of HOD_SEED_DATA) {
        // Create a predictable ID from email or just use setDoc with email as ID if preferred
        // We'll use doc(collection(db, 'users')) but with a setDoc to ensure roles are correct
        const q = users.find(u => u.email === h.email);
        const ref = q ? doc(db, 'users', q.id) : doc(collection(db, 'users'));
        await setDoc(ref, {
          email: h.email,
          name: h.name,
          role: 'hod',
          department: h.dept,
          createdAt: firestoreTimestamp(),
          isPredefined: true
        }, { merge: true });
      }
      alert("HOD accounts seeded! Now please create these identical emails in Firebase Authentication console.");
    } catch (e) {
      alert("Error seeding: " + e.message);
    }
    setLoading(false);
  };

  const FILTERS = [
    { id: 'all', label: 'All' },
    { id: 'active', label: 'Citizens' },
    { id: 'admin', label: 'Admins' },
    { id: 'hod', label: 'HODs' },
    { id: 'blocked', label: 'Blocked' },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>

      {/* Header */}
      <div style={{
        display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between',
        animation: 'fadeUp .4s cubic-bezier(.16,1,.3,1) both',
      }}>
        <div>
          <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 28, fontWeight: 700, color: 'var(--text)', margin: 0, letterSpacing: -0.5 }}>
            Users
          </h1>
          <p style={{ color: 'var(--text2)', fontSize: 14, marginTop: 5 }}>
            {users.length} registered accounts · {counts.active} active citizens
          </p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          {[
            { label: `${counts.active} Active`, color: 'var(--green)', bg: 'var(--greenBg)', bd: 'var(--greenBd)' },
            { label: `${counts.blocked} Blocked`, color: 'var(--red)', bg: 'var(--redBg)', bd: 'var(--redBd)' },
          ].map(p => (
            <div key={p.label} style={{
              padding: '7px 14px', borderRadius: 10,
              background: p.bg, border: `1px solid ${p.bd}`,
              fontSize: 12, fontWeight: 700, color: p.color,
            }}>{p.label}</div>
          ))}
          {user.role === 'super_admin' && (
             <button 
               onClick={seedHODs}
               style={{
                marginLeft: 10, padding: '7px 16px', borderRadius: 10,
                background: 'var(--accent)', color: '#fff', border: 'none',
                fontSize: 12, fontWeight: 800, cursor: 'pointer',
                boxShadow: 'var(--shAccent)', transition: 'all .2s'
               }}
               onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.02)'}
               onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
             >
               Setup HOD Portal
             </button>
          )}
        </div>
      </div>

      {/* Controls */}
      <div style={{
        background: 'var(--surface)', border: '1.5px solid var(--border)', borderRadius: 16,
        padding: '12px 16px', boxShadow: 'var(--sh)',
        display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'center',
        animation: 'fadeUp .4s .05s cubic-bezier(.16,1,.3,1) both',
      }}>
        {/* Tabs */}
        <div style={{ display: 'flex', background: 'var(--bg)', borderRadius: 11, padding: 3, gap: 2 }}>
          {FILTERS.map(f => (
            <button key={f.id} onClick={() => setFilter(f.id)} style={{
              padding: '7px 14px', borderRadius: 9, border: 'none', cursor: 'pointer',
              fontSize: 12, fontWeight: 600,
              background: filter === f.id ? 'var(--surface)' : 'transparent',
              color: filter === f.id ? 'var(--accent)' : 'var(--text2)',
              boxShadow: filter === f.id ? 'var(--sh)' : 'none',
              transition: 'all .15s', outline: 'none',
            }}>
              {f.label}
              <span style={{
                marginLeft: 5, fontSize: 10, fontWeight: 800,
                color: filter === f.id ? 'var(--accent)' : 'var(--text3)',
              }}>({counts[f.id]})</span>
            </button>
          ))}
        </div>

        {/* Search */}
        <div style={{ flex: 1, minWidth: 200, position: 'relative' }}>
          <span style={{
            position: 'absolute', left: 11, top: '50%',
            transform: 'translateY(-50%)', color: 'var(--text3)',
          }}>
            <Ic d={ICONS.search} size={14} />
          </span>
          <input value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search name, email, phone, ward..."
            style={{
              width: '100%', padding: '9px 12px 9px 33px',
              background: 'var(--surface2)', border: '1.5px solid var(--border)',
              borderRadius: 10, color: 'var(--text)', fontSize: 13, outline: 'none',
              transition: 'border .2s',
            }}
            onFocus={e => {
              e.target.style.borderColor = 'var(--accent)';
              e.target.style.background = 'var(--surface)';
            }}
            onBlur={e => {
              e.target.style.borderColor = 'var(--border)';
              e.target.style.background = 'var(--surface2)';
            }} />
        </div>
      </div>

      {/* Grid */}
      {loading ? (
        <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', padding: 80 }}>
          <div style={{
            width: 36, height: 36, borderRadius: '50%',
            border: '3px solid var(--border)', borderTopColor: 'var(--accent)',
            animation: 'spin .8s linear infinite',
          }} />
        </div>
      ) : filtered.length === 0 ? (
        <div style={{
          textAlign: 'center', padding: '70px 20px',
          background: 'var(--surface)', borderRadius: 18, border: '1.5px solid var(--border)',
        }}>
          <div style={{
            width: 56, height: 56, borderRadius: '50%',
            background: 'var(--bg)', border: '1.5px solid var(--border)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            margin: '0 auto 14px', color: 'var(--text3)',
          }}>
            <Ic d={ICONS.users} size={24} />
          </div>
          <p style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 700, color: 'var(--text)', margin: 0 }}>
            No users found
          </p>
          <p style={{ fontSize: 13, color: 'var(--text3)', marginTop: 5 }}>
            Try adjusting your search or filter
          </p>
        </div>
      ) : (
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(295px, 1fr))',
          gap: 14,
          animation: 'fadeUp .4s .1s cubic-bezier(.16,1,.3,1) both',
        }}>
          {filtered.map(u => {
            const rb = roleOf(u);
            return (
              <div key={u.id} onClick={() => setSel(u)} style={{
                background: 'var(--surface)', border: '1.5px solid var(--border)',
                borderRadius: 18, padding: 20, cursor: 'pointer',
                boxShadow: 'var(--shMd)',
                transition: 'all .18s',
              }}
                onMouseEnter={e => {
                  e.currentTarget.style.borderColor = 'var(--accent)';
                  e.currentTarget.style.boxShadow = 'var(--shAccent)';
                  e.currentTarget.style.transform = 'translateY(-2px)';
                }}
                onMouseLeave={e => {
                  e.currentTarget.style.borderColor = 'var(--border)';
                  e.currentTarget.style.boxShadow = 'var(--shMd)';
                  e.currentTarget.style.transform = 'translateY(0)';
                }}>
                {/* Top row */}
                <div style={{ display: 'flex', alignItems: 'center', gap: 13, marginBottom: 14 }}>
                  <Avatar name={u.name} size={46} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{
                      fontWeight: 700, fontSize: 14, color: 'var(--text)',
                      overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', margin: 0,
                    }}>{u.name || 'Unknown'}</p>
                    <p style={{
                      fontSize: 12, color: 'var(--text2)',
                      overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', margin: '2px 0 0',
                    }}>{u.email}</p>
                  </div>
                  <span style={{
                    padding: '3px 9px', borderRadius: 99, fontSize: 10, fontWeight: 800,
                    background: rb.bg, color: rb.color, border: `1px solid ${rb.bd}`,
                    flexShrink: 0, textTransform: 'uppercase', letterSpacing: 0.3,
                    display: 'flex', alignItems: 'center', gap: 4,
                  }}>
                    <Ic d={ICONS[rb.icon]} size={9} sw={2.5} color={rb.color} />
                    {rb.label}
                  </span>
                </div>

                {/* Bottom meta */}
                <div style={{
                  borderTop: '1px solid var(--border)', paddingTop: 12,
                  display: 'flex', gap: 12, flexWrap: 'wrap',
                }}>
                  {[
                    [ICONS.phone, u.phone || '—'],
                    [ICONS.map, u.wardNo ? `Ward ${u.wardNo}` : '—'],
                    [ICONS.cal, fmtDate(u.createdAt)],
                  ].map(([ic, val], i) => (
                    <span key={i} style={{
                      display: 'flex', alignItems: 'center', gap: 5,
                      fontSize: 11, color: 'var(--text3)',
                    }}>
                      <span style={{ color: 'var(--textMuted)' }}><Ic d={ic} size={12} /></span>
                      {val}
                    </span>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {sel && (
        <UserModal
          u={sel}
          user={user}
          onClose={() => setSel(null)}
          onBlock={toggleBlock}
          onDelete={deleteUser}
          onUpdate={onUpdate}
        />
      )}
    </div>
  );
}
