import { useState, useEffect, useRef, memo, useCallback } from 'react';
import {
  collection, onSnapshot, doc,
  updateDoc, deleteDoc, arrayUnion, serverTimestamp,
  query, where,
} from 'firebase/firestore';
import { db } from '../firebase';

import { STATUS, PRIORITY, DEPTS, STEPS, ESCALATION_HOURS } from '../constants';
import { Ic, ICONS, SBadge, PBadge } from '../components/SharedUI';
import ViewComplaint from '../components/ViewComplaint';

export { STATUS, PRIORITY, DEPTS, STEPS };

// ─── Complaints page ───────────────────────────────────────────────────────────
export default function Complaints({ user }) {
  const [issues, setIssues] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [sortBy, setSortBy] = useState('newest');
  const [selectedId, setSelectedId] = useState(null);
  const [selectedIds, setSelectedIds] = useState([]);
  const [deletingId, setDeletingId] = useState(null);
  const [bulkDeleting, setBulkDeleting] = useState(false);

  const isHOD = user.role === 'hod';

  useEffect(() => {
    const baseRef = collection(db, 'issues');
    const q = (isHOD && user.department)
      ? query(baseRef, where('assignedTo', '==', user.department))
      : baseRef;

    const unsub = onSnapshot(q, snap => {
      setIssues(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    }, (err) => {
      console.warn("Complaints Fetch Error:", err);
      setIssues([]);
      setLoading(false);
    });
    return unsub;
  }, [isHOD, user.department]);

  const fmtDate = useCallback(ts => {
    if (!ts) return '—';
    const d = ts.toDate ? ts.toDate() : new Date(ts);
    return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`;
  }, []);

  const sorted = [...issues].sort((a, b) => {
    const ta = a.createdAt?.toDate ? a.createdAt.toDate() : new Date(0);
    const tb = b.createdAt?.toDate ? b.createdAt.toDate() : new Date(0);
    return sortBy === 'oldest' ? ta - tb : tb - ta;
  });

  const filtered = sorted.filter(i => {
    const q = search.toLowerCase();
    const ms = !q
      || (i.title || '').toLowerCase().includes(q)
      || (i.trackId || '').toLowerCase().includes(q)
      || (i.userName || '').toLowerCase().includes(q)
      || (i.category || '').toLowerCase().includes(q)
      || String(i.wardNo || '').includes(q);
    const mf =
      filter === 'all' ? true :
        filter === 'open' ? (i.status === 'open' || i.status === 'assigned') :
          i.status === filter;
    
    // Escalation filter
    const isEscalated = (['open', 'assigned'].includes(i.status)) && (
      ((new Date() - (i.createdAt?.toDate ? i.createdAt.toDate() : new Date(i.createdAt))) / 3600000) > ESCALATION_HOURS
    );

    if (filter === 'escalated') return isEscalated && ms;

    return ms && mf;
  });

  const counts = {
    all: issues.length,
    open: issues.filter(i => i.status === 'open' || i.status === 'assigned').length,
    in_progress: issues.filter(i => i.status === 'in_progress').length,
    resolved: issues.filter(i => i.status === 'resolved').length,
    rejected: issues.filter(i => i.status === 'rejected').length,
    escalated: issues.filter(i => {
      if (!['open', 'assigned'].includes(i.status)) return false;
      const created = i.createdAt?.toDate ? i.createdAt.toDate() : new Date(i.createdAt);
      return ((new Date() - created) / 3600000) > ESCALATION_HOURS;
    }).length,
  };

  const FILTERS = [
    { id: 'all', label: 'All' },
    { id: 'open', label: 'Open' },
    { id: 'escalated', label: 'Escalated' },
    { id: 'in_progress', label: 'In Progress' },
    { id: 'resolved', label: 'Resolved' },
    { id: 'rejected', label: 'Rejected' },
  ];

  const handleOpen = useCallback(issue => setSelectedId(issue.id), []);
  const handleClose = useCallback(() => setSelectedId(null), []);

  const handleDelete = useCallback(async (issueId, issueTitle, e) => {
    if (e) e.stopPropagation();
    if (!window.confirm(`Are you sure you want to delete complaint "${issueTitle || issueId}"?\n\nThis cannot be undone.`)) {
      return;
    }
    setDeletingId(issueId);
    try {
      await deleteDoc(doc(db, 'issues', issueId));
      setSelectedIds(prev => prev.filter(id => id !== issueId));
      if (selectedId === issueId) setSelectedId(null);
    } catch (err) {
      console.error("Error deleting complaint:", err);
      alert(`Failed to delete complaint: ${err.message}`);
    } finally {
      setDeletingId(null);
    }
  }, [selectedId]);

  const handleBulkDelete = useCallback(async () => {
    if (selectedIds.length === 0) return;
    if (!window.confirm(`Are you sure you want to permanently delete all ${selectedIds.length} selected complaints?\n\nThis action cannot be undone.`)) {
      return;
    }
    setBulkDeleting(true);
    try {
      await Promise.all(selectedIds.map(id => deleteDoc(doc(db, 'issues', id))));
      if (selectedIds.includes(selectedId)) setSelectedId(null);
      setSelectedIds([]);
    } catch (err) {
      console.error("Error bulk deleting complaints:", err);
      alert(`Failed to delete selected complaints: ${err.message}`);
    } finally {
      setBulkDeleting(false);
    }
  }, [selectedIds, selectedId]);

  const toggleSelect = useCallback((id, e) => {
    if (e) e.stopPropagation();
    setSelectedIds(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]);
  }, []);

  const toggleSelectAll = useCallback((e) => {
    if (e.target.checked) {
      setSelectedIds(filtered.map(i => i.id));
    } else {
      setSelectedIds([]);
    }
  }, [filtered]);

  const liveIssue = issues.find(i => i.id === selectedId);

  if (liveIssue) {
    return <ViewComplaint issue={liveIssue} user={user} onClose={handleClose} onDelete={handleDelete} />;
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>

      {/* Header */}
      <div style={{
        display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between',
        animation: 'fadeUp .4s cubic-bezier(.16,1,.3,1) both',
      }}>
        <div>
          <h1 style={{
            fontFamily: 'var(--font-display)', fontSize: 28, fontWeight: 700,
            color: 'var(--text)', margin: 0, letterSpacing: -0.5
          }}>{isHOD ? `${user.department} Complaints` : 'Complaints'}</h1>
          <p style={{ color: 'var(--text2)', fontSize: 14, marginTop: 5 }}>
            {isHOD ? 'Department Queue' : 'Real-time'} · {issues.length} total
          </p>
        </div>
        {counts.open > 0 ? (
          <div style={{
            padding: '8px 16px', borderRadius: 10,
            background: 'var(--orangeBg)', border: '1px solid var(--orangeBd)',
            fontSize: 13, fontWeight: 700, color: 'var(--orange)',
            display: 'flex', alignItems: 'center', gap: 7,
          }}>
            <div style={{ width: 7, height: 7, borderRadius: '50%', background: 'var(--orange)', animation: 'pulse 1.8s ease infinite' }} />
            {counts.open} Open
          </div>
        ) : (
          <div style={{
            padding: '8px 16px', borderRadius: 10,
            background: 'var(--greenBg)', border: '1px solid var(--greenBd)',
            fontSize: 13, fontWeight: 700, color: 'var(--green)',
            display: 'flex', alignItems: 'center', gap: 7,
          }}>
            <Ic d={ICONS.check} size={14} sw={2.5} />
            All Clear
          </div>
        )}
      </div>

      {/* Controls */}
      <div style={{
        background: 'var(--surface)', borderRadius: 16,
        border: '1.5px solid var(--border)',
        padding: '12px 16px',
        boxShadow: 'var(--sh)',
        display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'center',
        animation: 'fadeUp .4s .05s cubic-bezier(.16,1,.3,1) both',
      }}>
        {/* Tabs */}
        <div style={{ display: 'flex', background: 'var(--bg)', borderRadius: 11, padding: 3, gap: 2 }}>
          {FILTERS.map(f => (
            <button key={f.id} onClick={() => setFilter(f.id)} style={{
              padding: '6px 13px', borderRadius: 9, border: 'none',
              cursor: 'pointer', fontSize: 12, fontWeight: 600,
              background: filter === f.id ? 'var(--surface)' : 'transparent',
              color: filter === f.id ? (f.id === 'escalated' ? 'var(--red)' : 'var(--accent)') : 'var(--text2)',
              boxShadow: filter === f.id ? 'var(--sh)' : 'none',
              transition: 'all .15s', outline: 'none',
            }}>
              {f.label}
              <span style={{
                marginLeft: 5, fontSize: 10, fontWeight: 800,
                color: filter === f.id ? (f.id === 'escalated' ? 'var(--red)' : 'var(--accent)') : 'var(--text3)',
              }}>({counts[f.id]})</span>
            </button>
          ))}
        </div>

        {/* Search */}
        <div style={{ flex: 1, minWidth: 200, position: 'relative' }}>
          <span style={{ position: 'absolute', left: 11, top: '50%', transform: 'translateY(-50%)', color: 'var(--text3)' }}>
            <Ic d={ICONS.search} size={14} />
          </span>
          <input
            value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search title, ID, user, ward..."
            style={{
              width: '100%', padding: '9px 12px 9px 33px',
              background: 'var(--surface2)', border: '1.5px solid var(--border)',
              borderRadius: 10, color: 'var(--text)', fontSize: 13, outline: 'none',
              transition: 'border .2s',
            }}
            onFocus={e => e.target.style.borderColor = 'var(--accent)'}
            onBlur={e => e.target.style.borderColor = 'var(--border)'}
          />
        </div>

        {/* Sort */}
        <div style={{ position: 'relative' }}>
          <span style={{
            position: 'absolute', left: 10, top: '50%',
            transform: 'translateY(-50%)', color: 'var(--text3)', pointerEvents: 'none',
          }}>
            <Ic d={ICONS.sort} size={13} />
          </span>
          <select
            value={sortBy} onChange={e => setSortBy(e.target.value)}
            style={{
              padding: '9px 12px 9px 30px',
              background: 'var(--surface2)', border: '1.5px solid var(--border)',
              borderRadius: 10, color: 'var(--text)', fontSize: 12,
              cursor: 'pointer', outline: 'none',
            }}
          >
            <option value="newest">Newest first</option>
            <option value="oldest">Oldest first</option>
          </select>
        </div>
      </div>

      {/* Table */}
      {loading ? (
        <div style={{
          display: 'flex', justifyContent: 'center', alignItems: 'center',
          padding: 80, background: 'var(--surface)', borderRadius: 18,
          border: '1.5px solid var(--border)',
        }}>
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
            width: 52, height: 52, borderRadius: '50%',
            background: 'var(--surface2)', border: '1.5px solid var(--border)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            margin: '0 auto 14px', color: 'var(--text3)',
          }}>
            <Ic d={ICONS.file} size={22} />
          </div>
          <p style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 700, color: 'var(--text)', margin: 0 }}>
            No complaints found
          </p>
          <p style={{ fontSize: 13, color: 'var(--text3)', marginTop: 5 }}>
            Try adjusting your search or filter
          </p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {/* Bulk actions banner */}
          {selectedIds.length > 0 && !isHOD && (
            <div style={{
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              padding: '10px 16px', background: 'var(--redBg)', border: '1.5px solid var(--redBd)',
              borderRadius: 14, animation: 'fadeUp .2s ease both',
            }}>
              <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--red)' }}>
                {selectedIds.length} complaint{selectedIds.length > 1 ? 's' : ''} selected
              </span>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <button
                  onClick={() => setSelectedIds([])}
                  style={{
                    padding: '6px 12px', borderRadius: 8, background: 'var(--surface)',
                    border: '1px solid var(--border)', color: 'var(--text2)',
                    fontSize: 12, fontWeight: 600, cursor: 'pointer', outline: 'none',
                  }}
                >
                  Clear Selection
                </button>
                <button
                  disabled={bulkDeleting}
                  onClick={handleBulkDelete}
                  style={{
                    padding: '6px 14px', borderRadius: 8, background: 'var(--red)',
                    border: 'none', color: '#fff', fontSize: 12, fontWeight: 700,
                    cursor: bulkDeleting ? 'not-allowed' : 'pointer', outline: 'none',
                    display: 'flex', alignItems: 'center', gap: 6,
                    boxShadow: '0 2px 8px rgba(220,38,38,0.25)',
                  }}
                >
                  <Ic d={ICONS.trash} size={13} />
                  {bulkDeleting ? 'Deleting...' : `Delete Selected (${selectedIds.length})`}
                </button>
              </div>
            </div>
          )}

          <div style={{
            background: 'var(--surface)', borderRadius: 18,
            border: '1.5px solid var(--border)', overflow: 'hidden',
            boxShadow: 'var(--sh)',
            animation: 'fadeUp .4s .1s cubic-bezier(.16,1,.3,1) both',
          }}>
            {/* Head */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: !isHOD ? '36px 2.3fr 1fr 0.65fr 1fr 0.75fr 0.65fr 108px' : '2.4fr 1fr 0.65fr 1fr 0.75fr 0.65fr 72px',
              padding: '10px 20px',
              background: 'var(--surface2)',
              borderBottom: '1.5px solid var(--border)',
              fontSize: 9, fontWeight: 900, color: 'var(--text3)',
              letterSpacing: 1.4, textTransform: 'uppercase',
              alignItems: 'center',
            }}>
              {!isHOD && (
                <div style={{ display: 'flex', alignItems: 'center' }}>
                  <input
                    type="checkbox"
                    checked={filtered.length > 0 && selectedIds.length === filtered.length}
                    onChange={toggleSelectAll}
                    style={{ cursor: 'pointer', accentColor: 'var(--accent)', width: 14, height: 14 }}
                    title="Select all complaints"
                  />
                </div>
              )}
              {['Complaint', 'Category', 'Ward', 'Status', 'Priority', 'Date', ''].map((h, i) => (
                <span key={i} style={i === 6 ? { textAlign: 'right' } : {}}>{h}</span>
              ))}
            </div>

            {/* Rows — virtualise by only re-rendering changes */}
            {filtered.map((issue, idx) => (
              <div
                key={issue.id}
                onClick={() => handleOpen(issue)}
                style={{
                  display: 'grid',
                  gridTemplateColumns: !isHOD ? '36px 2.3fr 1fr 0.65fr 1fr 0.75fr 0.65fr 108px' : '2.4fr 1fr 0.65fr 1fr 0.75fr 0.65fr 72px',
                  padding: '12px 20px', alignItems: 'center',
                  borderBottom: idx < filtered.length - 1 ? '1px solid var(--border)' : 'none',
                  borderLeft: (['open', 'assigned'].includes(issue.status) && ((new Date() - (issue.createdAt?.toDate ? issue.createdAt.toDate() : new Date(issue.createdAt))) / 3600000) > ESCALATION_HOURS) ? '3px solid var(--red)' : '3px solid transparent',
                  cursor: 'pointer', transition: 'background .1s',
                }}
                onMouseEnter={e => e.currentTarget.style.background = 'var(--surface2)'}
                onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
              >
                {!isHOD && (
                  <div style={{ display: 'flex', alignItems: 'center' }} onClick={e => e.stopPropagation()}>
                    <input
                      type="checkbox"
                      checked={selectedIds.includes(issue.id)}
                      onChange={e => toggleSelect(issue.id, e)}
                      style={{ cursor: 'pointer', accentColor: 'var(--accent)', width: 14, height: 14 }}
                    />
                  </div>
                )}
                <div style={{ minWidth: 0 }}>
                  <p style={{
                    fontSize: 13, fontWeight: 600, color: 'var(--text)',
                    overflow: 'hidden', textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap', margin: 0,
                  }}>{issue.title || 'Untitled'}</p>
                  <p style={{ fontSize: 11, color: 'var(--text3)', margin: '3px 0 0' }}>
                    #{issue.trackId || issue.id?.slice(0, 8)} · {issue.userName || '—'}
                  </p>
                </div>
                <span style={{ fontSize: 12, color: 'var(--text2)' }}>{issue.category || '—'}</span>
                <span style={{ fontSize: 12, color: 'var(--text2)' }}>{issue.wardNo ? `W${issue.wardNo}` : '—'}</span>
                <SBadge status={issue.status || 'open'} />
                <PBadge priority={issue.priority} />
                <span style={{ fontSize: 11, color: 'var(--text3)' }}>{fmtDate(issue.createdAt)}</span>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 6 }}>
                  <button
                    onClick={e => { e.stopPropagation(); handleOpen(issue); }}
                    style={{
                      padding: '5px 10px', borderRadius: 8,
                      background: 'var(--accentBg)', border: '1.5px solid var(--accentBd)',
                      color: 'var(--accent)', fontSize: 11, fontWeight: 700,
                      cursor: 'pointer', outline: 'none',
                      display: 'flex', alignItems: 'center', gap: 4,
                      transition: 'all .15s', whiteSpace: 'nowrap',
                    }}
                    onMouseEnter={e => e.currentTarget.style.opacity = 0.8}
                    onMouseLeave={e => e.currentTarget.style.opacity = 1}
                  >
                    <Ic d={ICONS.view} size={12} />
                    View
                  </button>
                  {!isHOD && (
                    <button
                      disabled={deletingId === issue.id}
                      onClick={e => handleDelete(issue.id, issue.title, e)}
                      title="Delete Complaint"
                      style={{
                        padding: '5px 8px', borderRadius: 8,
                        background: 'var(--redBg)', border: '1.5px solid var(--redBd)',
                        color: 'var(--red)', fontSize: 11, fontWeight: 700,
                        cursor: deletingId === issue.id ? 'not-allowed' : 'pointer', outline: 'none',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        transition: 'all .15s',
                      }}
                      onMouseEnter={e => {
                        if (deletingId !== issue.id) {
                          e.currentTarget.style.background = 'var(--red)';
                          e.currentTarget.style.color = '#fff';
                        }
                      }}
                      onMouseLeave={e => {
                        if (deletingId !== issue.id) {
                          e.currentTarget.style.background = 'var(--redBg)';
                          e.currentTarget.style.color = 'var(--red)';
                        }
                      }}
                    >
                      <Ic d={ICONS.trash} size={12} />
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <style>{`
        @keyframes fadeUp  { from{opacity:0;transform:translateY(14px)} to{opacity:1;transform:translateY(0)} }
        @keyframes scaleUp { from{opacity:0;transform:scale(0.97) translateY(8px)} to{opacity:1;transform:scale(1) translateY(0)} }
        @keyframes spin    { to{transform:rotate(360deg)} }
        @keyframes pulse   { 0%,100%{opacity:1} 50%{opacity:.4} }
      `}</style>
    </div>
  );
}
