import { useState, useEffect, useRef, memo, useCallback } from 'react';
import { doc, updateDoc, deleteDoc, arrayUnion, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase';
import { STATUS, PRIORITY, DEPTS, STEPS, ESCALATION_HOURS, getDepartmentForCategory } from '../constants';
import { Ic, ICONS, SBadge, PBadge } from './SharedUI';

const AI_ANALYSIS_ENDPOINT = '/ai-api/analyze-image';

const formatModelLabel = value => {
  if (!value) return 'Unknown';
  return value
    .split('_')
    .map(part => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
};

const formatConfidence = value =>
  typeof value === 'number' ? `${Math.round(value * 100)}%` : '---';

const formatTrustStatus = value => {
  if (!value) return 'Unknown';
  return value
    .split('_')
    .map(part => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
};

// --- Lazy image with fallback ---
const LazyImage = memo(({ src }) => {
  const [state, setState] = useState('loading');

  useEffect(() => { setState('loading'); }, [src]);

  if (!src || typeof src !== 'string' || !src.startsWith('http')) return null;

  return (
    <div style={{
      borderRadius: 12, overflow: 'hidden',
      border: '1.5px solid var(--border)',
      background: 'var(--surface2)',
      position: 'relative', minHeight: state === 'error' ? 0 : 100,
      cursor: state === 'ok' ? 'zoom-in' : 'default',
    }}
      onClick={() => state === 'ok' && window.open(src, '_blank')}
    >
      {state === 'loading' && (
        <div style={{ height: 80, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{
            width: 22, height: 22, borderRadius: '50%',
            border: '2.5px solid var(--border)',
            borderTopColor: 'var(--accent)',
            animation: 'spin .7s linear infinite',
          }} />
        </div>
      )}
      {state === 'error' && (
        <div style={{
          padding: '18px 16px', display: 'flex', alignItems: 'center', gap: 10,
          background: 'var(--surface2)',
        }}>
          <div style={{
            width: 34, height: 34, borderRadius: 9,
            background: 'var(--yellowBg)', border: '1px solid var(--yellowBd)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            flexShrink: 0, color: 'var(--yellow)',
          }}>
            <Ic d={ICONS.img} size={16} />
          </div>
          <div>
            <p style={{ fontSize: 12, fontWeight: 600, color: 'var(--text)', margin: 0 }}>
              Image could not be loaded
            </p>
            <p style={{ fontSize: 11, color: 'var(--text3)', margin: '2px 0 0' }}>
              The file might be private, deleted, or the URL is invalid.
            </p>
          </div>
        </div>
      )}
      <img
        src={src} alt="complaint" loading="lazy"
        onLoad={() => setState('ok')}
        onError={() => setState('error')}
        style={{
          width: '100%', maxHeight: 400,
          objectFit: 'cover', display: 'block',
          opacity: state === 'ok' ? 1 : 0,
          transition: 'opacity .3s ease',
        }}
      />
      {state === 'ok' && (
        <div style={{
          position: 'absolute', bottom: 10, right: 10,
          background: 'rgba(0,0,0,0.6)', color: '#fff',
          padding: '4px 8px', borderRadius: 6, fontSize: 10,
          fontWeight: 700, pointerEvents: 'none',
          backdropFilter: 'blur(4px)', border: '1px solid rgba(255,255,255,0.2)',
        }}>
          Click to Enlarge
        </div>
      )}
    </div>
  );
});

// --- Map preview via OSM iframe ---
const MapPreview = memo(({ lat, lng }) => {
  const latN = Number(lat);
  const lngN = Number(lng);
  if (!lat || !lng || isNaN(latN) || isNaN(lngN)) return null;

  const bbox = `${lngN - 0.005},${latN - 0.005},${lngN + 0.005},${latN + 0.005}`;
  const osmUrl = `https://www.openstreetmap.org/export/embed.html?bbox=${bbox}&layer=mapnik&marker=${latN},${lngN}`;
  const fullUrl = `https://www.openstreetmap.org/?mlat=${latN}&mlon=${lngN}#map=17/${latN}/${lngN}`;

  return (
    <div style={{ borderRadius: 12, overflow: 'hidden', border: '1.5px solid var(--border)' }}>
      <div style={{
        padding: '8px 12px', background: 'var(--surface2)',
        borderBottom: '1px solid var(--border)',
        display: 'flex', alignItems: 'center', gap: 7,
        fontSize: 11, fontWeight: 700, color: 'var(--text2)',
      }}>
        <Ic d={ICONS.map} size={13} />
        Location Map
        <a href={fullUrl} target="_blank" rel="noopener noreferrer"
          style={{ marginLeft: 'auto', fontSize: 10, color: 'var(--accent)', fontWeight: 600, textDecoration: 'none' }}>
          Open full map {"->"}
        </a>
      </div>
      <iframe
        title="Issue location" src={osmUrl} width="100%" height="180"
        style={{ border: 'none', display: 'block' }}
        loading="lazy" sandbox="allow-scripts allow-same-origin"
      />
      <div style={{
        padding: '6px 12px', background: 'var(--surface2)',
        borderTop: '1px solid var(--border)',
        fontSize: 10, color: 'var(--text3)', fontFamily: 'monospace',
      }}>
        {latN.toFixed(6)}, {lngN.toFixed(6)}
      </div>
    </div>
  );
});

// --- Section card ---
const Section = memo(({ label, children }) => (
  <div style={{
    background: 'var(--surface2)',
    borderRadius: 14,
    border: '1px solid var(--border)',
    overflow: 'hidden',
    flexShrink: 0,
  }}>
    <div style={{ padding: '9px 14px 8px', borderBottom: '1px solid var(--border)' }}>
      <p style={{
        fontSize: 9, fontWeight: 900,
        letterSpacing: 1.6, color: 'var(--text3)',
        textTransform: 'uppercase', margin: 0,
      }}>{label}</p>
    </div>
    <div style={{ padding: '14px' }}>{children}</div>
  </div>
));

// --- Detail row ---
const DetailRow = memo(({ label, value }) => (
  <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
    <span style={{
      fontSize: 10, color: 'var(--text3)',
      minWidth: 82, flexShrink: 0, paddingTop: 1,
      letterSpacing: 0.2,
    }}>{label}</span>
    <span style={{
      fontSize: 12, color: 'var(--text)',
      fontWeight: 500, lineHeight: 1.55,
      wordBreak: 'break-word',
    }}>{value || '---'}</span>
  </div>
));

const AnalysisCard = memo(({ state, result, error }) => {
  const isLoading = state === 'loading';
  const hasError = state === 'error';
  const isIdle = state === 'idle';

  return (
    <Section label="AI Analysis">
      {isLoading && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, color: 'var(--text2)' }}>
          <div style={{
            width: 18, height: 18, borderRadius: '50%',
            border: '2.5px solid var(--border)',
            borderTopColor: 'var(--accent)',
            animation: 'spin .7s linear infinite',
            flexShrink: 0,
          }} />
          <p style={{ margin: 0, fontSize: 12, fontWeight: 600 }}>
            Running your civic AI model on this complaint image...
          </p>
        </div>
      )}

      {isIdle && (
        <p style={{ margin: 0, fontSize: 12, color: 'var(--text3)', lineHeight: 1.6 }}>
          Analysis will appear here when the image and complaint location are available.
        </p>
      )}

      {hasError && (
        <div style={{
          padding: '12px 14px',
          borderRadius: 12,
          background: 'var(--redBg)',
          border: '1px solid var(--redBd)',
          color: 'var(--red)',
        }}>
          <p style={{ margin: 0, fontSize: 12, fontWeight: 700 }}>Analysis could not be completed</p>
          <p style={{ margin: '4px 0 0', fontSize: 11, lineHeight: 1.5 }}>
            {error}
          </p>
        </div>
      )}

      {!isLoading && !hasError && result && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{
            padding: '12px 14px',
            borderRadius: 12,
            background: 'var(--accentBg)',
            border: '1px solid var(--accentBd)',
          }}>
            <p style={{ margin: 0, fontSize: 10, color: 'var(--text3)', fontWeight: 800, textTransform: 'uppercase', letterSpacing: 1 }}>
              Predicted Issue
            </p>
            <p style={{ margin: '4px 0 0', fontSize: 17, fontWeight: 800, color: 'var(--accent)' }}>
              {formatModelLabel(result.issueLabel)}
            </p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: 10 }}>
            <div style={{ padding: '11px 12px', borderRadius: 12, border: '1px solid var(--border)', background: 'var(--surface)' }}>
              <p style={{ margin: 0, fontSize: 10, color: 'var(--text3)', fontWeight: 800, textTransform: 'uppercase', letterSpacing: 1 }}>
                Confidence
              </p>
              <p style={{ margin: '4px 0 0', fontSize: 15, fontWeight: 800, color: 'var(--text)' }}>
                {formatConfidence(result.confidence)}
              </p>
            </div>
            <div style={{ padding: '11px 12px', borderRadius: 12, border: '1px solid var(--border)', background: 'var(--surface)' }}>
              <p style={{ margin: 0, fontSize: 10, color: 'var(--text3)', fontWeight: 800, textTransform: 'uppercase', letterSpacing: 1 }}>
                Severity
              </p>
              <p style={{ margin: '4px 0 0', fontSize: 15, fontWeight: 800, color: 'var(--text)' }}>
                {formatModelLabel(result.severity)}
              </p>
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <DetailRow label="Department" value={result.departmentId || '---'} />
            <DetailRow label="Trust" value={formatTrustStatus(result.trustStatus)} />
            <DetailRow label="Review" value={result.reviewRequired ? 'Required' : 'Not required'} />
            <DetailRow label="Latency" value={result.latencyMs?.total_ms ? `${Math.round(result.latencyMs.total_ms)} ms` : '---'} />
            {result.duplicateOf && <DetailRow label="Duplicate of" value={result.duplicateOf} />}
            {result.wastePredictions?.[0] && (
              <DetailRow
                label="Waste Type"
                value={`${formatModelLabel(result.wastePredictions[0].label)} (${formatConfidence(result.wastePredictions[0].confidence)})`}
              />
            )}
          </div>
        </div>
      )}
    </Section>
  );
});

// --- Action button ---
const ActBtn = memo(({ label, color, bg, bd, active, disabled, onClick }) => (
  <button
    disabled={disabled || active}
    onClick={onClick}
    style={{
      padding: '11px 14px', borderRadius: 10, width: '100%',
      background: active ? bg : 'var(--surface)',
      border: `1.5px solid ${active ? bd : 'var(--border)'}`,
      color: active ? color : 'var(--text2)',
      fontWeight: active ? 800 : 600,
      fontSize: 13,
      cursor: active ? 'default' : disabled ? 'not-allowed' : 'pointer',
      opacity: disabled && !active ? 0.5 : 1,
      transition: 'all .2s cubic-bezier(.4,0,.2,1)',
      outline: 'none', textAlign: 'left',
      display: 'flex', alignItems: 'center', gap: 8,
      boxShadow: active ? `0 4px 12px ${bg}44` : 'none',
      flexShrink: 0,
    }}
    onMouseEnter={e => {
      if (!active && !disabled) {
        e.currentTarget.style.borderColor = bd;
        e.currentTarget.style.color = color;
        e.currentTarget.style.background = bg;
        e.currentTarget.style.transform = 'translateY(-1px)';
        e.currentTarget.style.boxShadow = `0 4px 12px ${bg}44`;
      }
    }}
    onMouseLeave={e => {
      if (!active && !disabled) {
        e.currentTarget.style.borderColor = 'var(--border)';
        e.currentTarget.style.color = 'var(--text2)';
        e.currentTarget.style.background = 'var(--surface)';
        e.currentTarget.style.transform = 'translateY(0)';
        e.currentTarget.style.boxShadow = 'none';
      }
    }}
  >
    <span style={{
      width: 8, height: 8, borderRadius: '50%',
      background: color, flexShrink: 0, opacity: active ? 1 : 0.5,
      boxShadow: active ? `0 0 6px ${color}` : 'none',
    }} />
    {label}
    {active && (
      <span style={{
        marginLeft: 'auto', fontSize: 10,
        background: color, color: '#fff',
        padding: '2px 7px', borderRadius: 20, fontWeight: 700,
      }}>
        Active
      </span>
    )}
  </button>
));

// --- Premium Button ---
const PremiumBtn = memo(({ label, icon, onClick, disabled, loading, color = 'var(--accent)', bg = 'var(--accentBg)', bd = 'var(--accentBd)' }) => (
  <button
    disabled={disabled || loading}
    onClick={onClick}
    style={{
      width: '100%', padding: '13px 18px', borderRadius: 12,
      background: bg, border: `1.5px solid ${bd}`,
      color: color, fontWeight: 800, fontSize: 13,
      cursor: (disabled || loading) ? 'not-allowed' : 'pointer',
      opacity: (disabled && !loading) ? 0.5 : 1,
      transition: 'all .25s cubic-bezier(.16,1,.3,1)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
      boxShadow: `0 4px 14px ${bg}66`,
      outline: 'none', flexShrink: 0,
    }}
    onMouseEnter={e => {
      if (!disabled && !loading) {
        e.currentTarget.style.transform = 'translateY(-2px) scale(1.01)';
        e.currentTarget.style.filter = 'brightness(1.08)';
      }
    }}
    onMouseLeave={e => {
      if (!disabled && !loading) {
        e.currentTarget.style.transform = 'translateY(0) scale(1)';
        e.currentTarget.style.filter = 'none';
      }
    }}
    onMouseDown={e => { if (!disabled && !loading) e.currentTarget.style.transform = 'scale(0.98)'; }}
    onMouseUp={e => { if (!disabled && !loading) e.currentTarget.style.transform = 'translateY(-2px) scale(1.01)'; }}
  >
    <Ic d={loading ? ICONS.cal : icon} size={16} sw={2.5} className={loading ? 'spin' : ''} />
    {loading ? 'Processing...' : label}
  </button>
));

// --- Column scroll wrapper ---
const ColScroll = memo(({ children, style = {} }) => (
  <div style={{
    display: 'flex',
    flexDirection: 'column',
    gap: 14,
    overflowY: 'auto',
    minHeight: 0,
    padding: '20px',
    ...style,
  }}>
    {children}
  </div>
));

// --- ViewComplaint ---
export default memo(function ViewComplaint({ issue, user, onClose, onDelete }) {
  const [note, setNote] = useState('');
  const [dept, setDept] = useState(issue.assignedTo || '');
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [toast, setToast] = useState({ msg: '', type: 'ok' });
  const [analysisState, setAnalysisState] = useState('idle');
  const [analysisResult, setAnalysisResult] = useState(null);
  const [analysisError, setAnalysisError] = useState('');
  const timer = useRef(null);

  const isHOD = user.role === 'hod';
  const isSuper = user.role === 'super_admin' || user.role === 'admin';

  const showToast = useCallback((msg, type = 'ok') => {
    setToast({ msg, type });
    clearTimeout(timer.current);
    timer.current = setTimeout(() => setToast({ msg: '', type: 'ok' }), 2800);
  }, []);

  const handleDeleteComplaint = useCallback(async () => {
    if (!window.confirm(`Are you sure you want to delete complaint "${issue.title || issue.id}"?\n\nThis cannot be undone.`)) {
      return;
    }
    setDeleting(true);
    try {
      if (onDelete) {
        await onDelete(issue.id, issue.title);
      } else {
        await deleteDoc(doc(db, 'issues', issue.id));
      }
      onClose();
    } catch (err) {
      console.error("Failed to delete complaint:", err);
      showToast('Delete failed: ' + err.message, 'error');
      setDeleting(false);
    }
  }, [issue.id, issue.title, onDelete, onClose, showToast]);

  useEffect(() => {
    const h = e => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', h);
    return () => { window.removeEventListener('keydown', h); clearTimeout(timer.current); };
  }, [onClose]);

  useEffect(() => {
    if (issue.assignedTo) {
      setDept(issue.assignedTo);
    } else if (issue.category) {
      const autoDept = getDepartmentForCategory(issue.category);
      if (autoDept) {
        setDept(autoDept);
        // Persist auto-assignment to Firestore if not assigned yet
        updateDoc(doc(db, 'issues', issue.id), {
          assignedTo: autoDept,
          status: issue.status === 'open' ? 'assigned' : issue.status,
          timeline: arrayUnion({
            step: 'Forwarded to Department',
            time: new Date().toISOString(),
            by: 'System (Auto-Router)',
          }),
          updatedAt: serverTimestamp(),
        }).catch(err => console.warn("Auto-assignment on load failed:", err));
      }
    }
  }, [issue.id, issue.assignedTo, issue.category, issue.status]);

  useEffect(() => {
    let cancelled = false;

    const lat = Number(issue.latitude);
    const lon = Number(issue.longitude);

    if (!issue.imageUrl) {
      setAnalysisState('idle');
      setAnalysisResult(null);
      setAnalysisError('');
      return undefined;
    }

    if (Number.isNaN(lat) || Number.isNaN(lon)) {
      setAnalysisState('error');
      setAnalysisResult(null);
      setAnalysisError('Complaint location is missing, so the image could not be sent to the AI pipeline.');
      return undefined;
    }

    const analyzeImage = async () => {
      setAnalysisState('loading');
      setAnalysisResult(null);
      setAnalysisError('');

      try {
        const imageResponse = await fetch(issue.imageUrl);
        if (!imageResponse.ok) {
          throw new Error(`Image fetch failed with status ${imageResponse.status}.`);
        }

        const imageBlob = await imageResponse.blob();
        const fileExt = imageBlob.type?.split('/')[1] || 'jpg';
        const formData = new FormData();
        formData.append('image', imageBlob, `complaint-${issue.id}.${fileExt}`);
        formData.append('lat', String(lat));
        formData.append('lon', String(lon));

        const response = await fetch(AI_ANALYSIS_ENDPOINT, {
          method: 'POST',
          body: formData,
        });

        if (!response.ok) {
          throw new Error(`AI API returned ${response.status}.`);
        }

        const payload = await response.json();
        if (!cancelled) {
          setAnalysisResult(payload);
          setAnalysisState('done');

          // Auto-assign to concerned department based on AI classification
          const detectedLabel = payload.issueLabel || issue.category;
          const targetDept = (payload.departmentId && DEPTS.includes(payload.departmentId))
            ? payload.departmentId
            : getDepartmentForCategory(detectedLabel);

          if (targetDept && (!issue.assignedTo || issue.status === 'open')) {
            try {
              await updateDoc(doc(db, 'issues', issue.id), {
                assignedTo: targetDept,
                status: 'assigned',
                timeline: arrayUnion({
                  step: 'Forwarded to Department',
                  time: new Date().toISOString(),
                  by: `AI Classification (${formatModelLabel(payload.issueLabel)})`,
                }),
                updatedAt: serverTimestamp(),
              });
              setDept(targetDept);
              showToast(`Auto-assigned to ${targetDept}`);
            } catch (err) {
              console.warn("Auto-assignment update failed:", err);
            }
          }
        }
      } catch (error) {
        if (!cancelled) {
          setAnalysisState('error');
          setAnalysisError(error.message || 'Unexpected error while analyzing the image.');
        }
      }
    };

    analyzeImage();

    return () => {
      cancelled = true;
    };
  }, [issue.id, issue.imageUrl, issue.latitude, issue.longitude]);

  const fmt = useCallback(ts => {
    if (!ts) return '---';
    const d = ts.toDate ? ts.toDate() : new Date(ts);
    return d.toLocaleString('en-IN', {
      day: '2-digit', month: 'short', year: 'numeric',
      hour: '2-digit', minute: '2-digit',
    });
  }, []);

  const run = useCallback(async fn => {
    setSaving(true);
    try { await fn(); }
    catch (e) { showToast('Error: ' + e.message, 'error'); }
    setSaving(false);
  }, [showToast]);

  const updateStatus = useCallback((s, extra = {}, timelineStep = null) => run(async () => {
    const payload = {
      status: s, updatedAt: serverTimestamp(),
      timeline: arrayUnion({
        step: timelineStep || STATUS[s]?.label || s,
        time: new Date().toISOString(),
        by: user.name || user.role,
      }),
      ...extra,
    };
    await updateDoc(doc(db, 'issues', issue.id), payload);
    showToast(`Status -> "${STATUS[s]?.label || s}"`);
  }), [issue.id, run, showToast, user.name, user.role]);

  const setPrio = useCallback(p => run(async () => {
    await updateDoc(doc(db, 'issues', issue.id), { priority: p, updatedAt: serverTimestamp() });
    showToast(`Priority -> "${p}"`);
  }), [issue.id, run, showToast]);

  const saveNote = useCallback(() => run(async () => {
    if (!note.trim()) return;
    await updateDoc(doc(db, 'issues', issue.id), {
      comments: arrayUnion({ text: note.trim(), by: 'admin', time: new Date().toISOString() }),
      updatedAt: serverTimestamp(),
    });
    setNote('');
    showToast('Note saved');
  }), [issue.id, note, run, showToast]);

  const sc = STATUS[issue.status] || STATUS.open;
  const tl = issue.timeline || [];
  const cm = issue.comments || [];

  const stepDone = useCallback(key => {
    if (key === 'Reported') return true;
    if (key === 'Forwarded') return !!issue.assignedTo;
    if (key === 'Assigned') return !!tl.find(t => t.step === 'Assigned') || ['in_progress', 'assigned', 'resolved', 'rejected'].includes(issue.status);
    if (key === 'In Progress') return ['resolved', 'rejected'].includes(issue.status);
    if (key === 'Resolved') return issue.status === 'resolved';
    return false;
  }, [issue.status, issue.assignedTo, tl]);

  const stepActive = useCallback(key =>
    (key === 'Reported' && issue.status === 'open') ||
    ((key === 'Assigned' || key === 'In Progress') && issue.status === 'in_progress') ||
    (key === 'Resolved' && issue.status === 'resolved'),
    [issue.status]);

  const isEscalated = ['open', 'assigned'].includes(issue.status) &&
    ((new Date() - (issue.createdAt?.toDate ? issue.createdAt.toDate() : new Date(issue.createdAt))) / 3600000) > ESCALATION_HOURS;

  return (
    <div style={{
      display: 'flex', flexDirection: 'column', gap: 16,
      animation: 'fadeUp .3s cubic-bezier(.16,1,.3,1) both',
      height: '100%',
    }}>

      {/* Back button + breadcrumb */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0 }}>
        <button onClick={onClose} style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '8px 14px', borderRadius: 10,
          border: '1.5px solid var(--border)',
          background: 'var(--surface2)',
          color: 'var(--text2)', fontSize: 13,
          fontWeight: 700, cursor: 'pointer', outline: 'none',
          transition: 'all .15s', flexShrink: 0,
        }}
          onMouseEnter={e => { e.currentTarget.style.background = 'var(--surface)'; e.currentTarget.style.color = 'var(--text)'; }}
          onMouseLeave={e => { e.currentTarget.style.background = 'var(--surface2)'; e.currentTarget.style.color = 'var(--text2)'; }}>
          <Ic d="M15 18l-6-6 6-6" size={14} sw={2.5} />
          Back
        </button>
        <span style={{ fontSize: 12, color: 'var(--text3)', minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          Complaints {"->"} {issue.title || 'Untitled'}
        </span>
      </div>

      {/* Main card */}
      <div style={{
        background: 'var(--surface)',
        borderRadius: 22,
        border: '1.5px solid var(--border)',
        overflow: 'hidden',
        boxShadow: 'var(--sh)',
        display: 'flex',
        flexDirection: 'column',
        flex: 1,
        minHeight: 0,
      }}>
        {/* Status stripe */}
        <div style={{
          height: 5, flexShrink: 0,
          background: `linear-gradient(90deg, ${sc.color}, ${sc.color}44)`,
        }} />

        {/* Header */}
        <div style={{
          padding: '18px 24px 16px',
          borderBottom: '1.5px solid var(--border)',
          flexShrink: 0,
        }}>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            gap: 10, flexWrap: 'wrap', marginBottom: 8,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', minWidth: 0 }}>
              <h2 style={{
                fontFamily: 'var(--font-display)', fontSize: 19, fontWeight: 700,
                color: 'var(--text)', margin: 0, letterSpacing: -0.3,
                minWidth: 0,
              }}>{issue.title || 'Untitled Complaint'}</h2>
              <SBadge status={issue.status} />
              {issue.priority && <PBadge priority={issue.priority} />}
            </div>

            {!isHOD && (
              <button
                disabled={deleting || saving}
                onClick={handleDeleteComplaint}
                style={{
                  padding: '7px 14px', borderRadius: 9,
                  background: 'var(--redBg)', border: '1.5px solid var(--redBd)',
                  color: 'var(--red)', fontSize: 12, fontWeight: 700,
                  cursor: (deleting || saving) ? 'not-allowed' : 'pointer', outline: 'none',
                  display: 'inline-flex', alignItems: 'center', gap: 6,
                  transition: 'all .15s',
                }}
                onMouseEnter={e => !deleting && (e.currentTarget.style.opacity = '0.85')}
                onMouseLeave={e => !deleting && (e.currentTarget.style.opacity = '1')}
                title="Permanently delete this complaint"
              >
                <Ic d={ICONS.trash} size={13} />
                {deleting ? 'Deleting...' : 'Delete Complaint'}
              </button>
            )}
          </div>

          {/* Meta row */}
          <div style={{
            display: 'flex', gap: 16, flexWrap: 'wrap',
            fontSize: 12, color: 'var(--text2)',
          }}>
            {[
              [ICONS.tag, issue.trackId || issue.id?.slice(0, 10)],
              [ICONS.file, issue.category || '---'],
              [ICONS.loc, `Ward ${issue.wardNo || '---'}`],
              [ICONS.user, issue.userName || '---'],
              [ICONS.cal, fmt(issue.createdAt)],
            ].map(([ic, val], i) => (
              <span key={i} style={{ display: 'flex', alignItems: 'center', gap: 5, whiteSpace: 'nowrap' }}>
                <span style={{ color: 'var(--text3)' }}><Ic d={ic} size={13} /></span>
                {val}
              </span>
            ))}
          </div>
        </div>

        {/* Toast */}
        {toast.msg && (
          <div style={{
            margin: '10px 24px 0', flexShrink: 0,
            padding: '10px 14px',
            background: toast.type === 'error' ? 'var(--redBg)' : 'var(--greenBg)',
            border: `1px solid ${toast.type === 'error' ? 'var(--redBd)' : 'var(--greenBd)'}`,
            borderRadius: 10, fontSize: 12,
            color: toast.type === 'error' ? 'var(--red)' : 'var(--green)',
            fontWeight: 700,
            display: 'flex', alignItems: 'center', gap: 8,
            animation: 'fadeIn .3s ease both',
          }}>
            <Ic d={toast.type === 'error' ? ICONS.info : ICONS.check} size={14} sw={2.5} />
            {toast.msg}
          </div>
        )}

        {/* 3-column body */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr 260px',
          flex: 1,
          minHeight: 0,
          overflow: 'hidden',
        }}>

          {/* Column 1: Image + Map + Details */}
          <ColScroll style={{ borderRight: '1.5px solid var(--border)', padding: '20px 20px' }}>
            <LazyImage src={issue.imageUrl} />
            <AnalysisCard state={analysisState} result={analysisResult} error={analysisError} />
            <MapPreview lat={issue.latitude} lng={issue.longitude} />

            <Section label="Complaint Details">
              <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
                <DetailRow label="Description" value={issue.description} />
                <DetailRow label="Reported by" value={issue.userName} />
                <DetailRow label="Email" value={issue.userEmail} />
                <DetailRow label="Ward" value={issue.wardNo ? `Ward ${issue.wardNo}` : '---'} />
                <DetailRow label="Assigned to" value={issue.assignedTo || 'Not assigned'} />
                {issue.latitude && (
                  <DetailRow label="GPS"
                    value={`${Number(issue.latitude).toFixed(6)}, ${Number(issue.longitude).toFixed(6)}`} />
                )}
              </div>
            </Section>
          </ColScroll>

          {/* Column 2: Timeline + Assign + Notes */}
          <ColScroll style={{ borderRight: '1.5px solid var(--border)', padding: '20px 20px' }}>

            {/* Timeline */}
            <Section label="Workflow Timeline">
              <div style={{ display: 'flex', flexDirection: 'column' }}>
                {STEPS.map((step, i) => {
                  const done = stepDone(step.key);
                  const active = stepActive(step.key);
                  const tItem = tl.find(t => t.step === step.key);
                  return (
                    <div key={step.key} style={{ display: 'flex', gap: 12 }}>
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flexShrink: 0 }}>
                        <div style={{
                          width: 30, height: 30, borderRadius: '50%',
                          background: done ? 'var(--green)' : active ? 'var(--orange)' : 'var(--surface)',
                          border: `2px solid ${done ? 'var(--green)' : active ? 'var(--orange)' : 'var(--border2)'}`,
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          color: done || active ? '#fff' : 'var(--text3)',
                          fontWeight: 800, fontSize: 11,
                          boxShadow: done ? '0 2px 8px rgba(34,197,94,0.25)' : active ? '0 2px 8px rgba(249,115,22,0.25)' : 'none',
                          flexShrink: 0,
                        }}>
                          {done
                            ? <Ic d={ICONS.check} size={12} sw={2.8} />
                            : active
                              ? <Ic d={ICONS.chevR} size={12} sw={2.5} />
                              : <span>{i + 1}</span>
                          }
                        </div>
                        {i < STEPS.length - 1 && (
                          <div style={{
                            width: 2, flexGrow: 1, minHeight: 18,
                            background: done ? 'var(--green)' : 'var(--border2)',
                            opacity: done ? 0.4 : 0.6, margin: '3px 0',
                          }} />
                        )}
                      </div>

                      <div style={{ paddingTop: 5, paddingBottom: i < STEPS.length - 1 ? 14 : 0, minWidth: 0 }}>
                        <p style={{
                          fontSize: 13, fontWeight: 700, margin: 0,
                          color: done ? 'var(--green)' : active ? 'var(--orange)' : 'var(--text3)',
                          lineHeight: 1.4,
                        }}>{step.label}</p>
                        {tItem && (
                          <p style={{ fontSize: 10, color: 'var(--text3)', margin: '2px 0 0' }}>
                            {new Date(tItem.time).toLocaleString('en-IN')}
                            {tItem.by && <span style={{ opacity: 0.7 }}> · {tItem.by}</span>}
                          </p>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </Section>

            {/* Assign / Forward to Department */}
            <Section label={isHOD ? 'Assigned Department' : 'Forward to Department'}>
              {isHOD ? (
                <div style={{
                  display: 'flex', alignItems: 'center', gap: 12,
                  padding: '14px 16px',
                  background: 'var(--accentBg)',
                  border: '1.5px solid var(--accentBd)',
                  borderRadius: 12,
                }}>
                  <div style={{
                    width: 36, height: 36, borderRadius: 10,
                    background: 'var(--accent)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    flexShrink: 0,
                  }}>
                    <Ic d={ICONS.check} size={16} sw={3} style={{ color: '#fff' }} />
                  </div>
                  <div style={{ minWidth: 0 }}>
                    <p style={{ fontSize: 10, color: 'var(--text3)', margin: '0 0 2px', fontWeight: 600, textTransform: 'uppercase', letterSpacing: 0.8 }}>
                      Assigned to
                    </p>
                    <p style={{
                      fontSize: 15, fontWeight: 800,
                      color: 'var(--accent)',
                      margin: 0, wordBreak: 'break-word',
                    }}>
                      {issue.assignedTo || 'Unassigned'}
                    </p>
                  </div>
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {isEscalated && (
                    <div style={{
                      background: 'var(--redBg)', border: '1.5px solid var(--redBd)',
                      borderRadius: 12, padding: '12px 14px',
                      display: 'flex', alignItems: 'flex-start', gap: 10,
                    }}>
                      <div style={{
                        width: 30, height: 30, borderRadius: 8, background: 'var(--red)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        color: '#fff', flexShrink: 0, marginTop: 1,
                      }}>
                        <Ic d={ICONS.warn} size={15} sw={2.5} />
                      </div>
                      <div>
                        <p style={{ margin: 0, fontWeight: 800, fontSize: 12, color: 'var(--red)' }}>
                          Escalated Complaint
                        </p>
                        <p style={{ margin: '3px 0 0', fontSize: 11, color: 'var(--red)', opacity: 0.8, lineHeight: 1.45 }}>
                          Unattended for over {ESCALATION_HOURS} hours. Immediate action required.
                        </p>
                      </div>
                    </div>
                  )}

                  <select
                    value={dept}
                    onChange={e => setDept(e.target.value)}
                    style={{
                      width: '100%', padding: '11px 13px',
                      background: 'var(--surface)',
                      border: '2px solid var(--border)',
                      borderRadius: 10, color: 'var(--text)', fontSize: 13,
                      fontWeight: 600, outline: 'none', cursor: 'pointer',
                      transition: 'border-color .2s',
                    }}
                  >
                    <option value="">Choose department...</option>
                    {DEPTS.map(d => <option key={d} value={d}>{d}</option>)}
                  </select>

                  <PremiumBtn
                    label="Assign to Department"
                    icon={ICONS.assign}
                    disabled={!dept}
                    loading={saving}
                    bg="var(--blue)"
                    bd="var(--blueBd)"
                    color="#fff"
                    onClick={() => { if (dept) updateStatus('assigned', { assignedTo: dept }, 'Sent to Department'); }}
                  />

                  {issue.assignedTo && (
                    <div style={{
                      display: 'flex', alignItems: 'center', gap: 8,
                      padding: '9px 12px',
                      background: 'var(--surface)',
                      border: '1px solid var(--border)',
                      borderRadius: 9, fontSize: 12,
                    }}>
                      <span style={{ color: 'var(--text3)', fontSize: 11 }}>Currently:</span>
                      <span style={{ fontWeight: 700, color: 'var(--text)' }}>{issue.assignedTo}</span>
                    </div>
                  )}
                </div>
              )}
            </Section>

            {isHOD && issue.assignedTo === user.department && !tl.find(t => t.step === 'Assigned') && (
              <Section label="Immediate Actions">
                <PremiumBtn
                  label="Acknowledge & Accept"
                  icon={ICONS.check}
                  loading={saving}
                  bg="var(--green)"
                  bd="var(--greenBd)"
                  color="#fff"
                  onClick={() => updateStatus('in_progress', {}, 'Assigned')}
                />
              </Section>
            )}

            {/* Admin Notes */}
            <Section label={`Admin Notes${cm.length ? ` (${cm.length})` : ''}`}>
              {cm.length > 0 && (
                <div style={{
                  maxHeight: 150, overflowY: 'auto',
                  display: 'flex', flexDirection: 'column', gap: 6,
                  marginBottom: 10,
                  paddingRight: 2,
                }}>
                  {cm.map((c, i) => (
                    <div key={i} style={{
                      background: 'var(--surface)', borderRadius: 9,
                      padding: '9px 11px',
                      border: '1px solid var(--border)',
                    }}>
                      <p style={{ fontSize: 12, color: 'var(--text)', margin: 0, lineHeight: 1.5 }}>
                        {c.text}
                      </p>
                      <p style={{ fontSize: 10, color: 'var(--text3)', margin: '3px 0 0' }}>
                        {c.by} · {c.time ? new Date(c.time).toLocaleDateString('en-IN') : ''}
                      </p>
                    </div>
                  ))}
                </div>
              )}
              <textarea
                value={note}
                onChange={e => setNote(e.target.value)}
                placeholder="Write a note..."
                rows={3}
                style={{
                  width: '100%', padding: '9px 12px',
                  background: 'var(--surface)',
                  border: '1.5px solid var(--border)',
                  borderRadius: 9, color: 'var(--text)',
                  fontSize: 12, resize: 'vertical',
                  marginBottom: 8, outline: 'none',
                  lineHeight: 1.5, boxSizing: 'border-box',
                  fontFamily: 'inherit',
                }}
              />
              <button
                disabled={!note.trim() || saving}
                onClick={saveNote}
                style={{
                  width: '100%', padding: '9px', borderRadius: 9,
                  background: note.trim() ? 'var(--accentBg)' : 'var(--surface)',
                  border: `1.5px solid ${note.trim() ? 'var(--orangeBd)' : 'var(--border)'}`,
                  color: note.trim() ? 'var(--accent)' : 'var(--text3)',
                  fontWeight: 600, fontSize: 12,
                  cursor: note.trim() && !saving ? 'pointer' : 'not-allowed',
                  outline: 'none',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7,
                  transition: 'all .2s',
                }}
              >
                <Ic d={ICONS.note} size={13} />
                Save Note
              </button>
            </Section>
          </ColScroll>

          {/* Column 3: Status + Priority Actions */}
          <ColScroll style={{ background: 'var(--surface2)', padding: '20px 16px' }}>
            <Section label="Update Status">
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {[
                  { s: 'in_progress', label: 'In Progress', ...STATUS.in_progress },
                  { s: 'resolved', label: 'Resolved', ...STATUS.resolved },
                  { s: 'rejected', label: 'Reject', ...STATUS.rejected },
                  { s: 'open', label: 'Reopen', ...STATUS.open },
                ].map(a => (
                  <ActBtn
                    key={a.s}
                    label={a.label}
                    color={a.color} bg={a.bg} bd={a.bd}
                    active={issue.status === a.s}
                    disabled={saving}
                    onClick={() => updateStatus(a.s)}
                  />
                ))}
              </div>
            </Section>

            <Section label="Priority Level">
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {Object.entries(PRIORITY).map(([key, p]) => (
                  <ActBtn
                    key={key}
                    label={p.label}
                    color={p.color} bg={p.bg} bd={p.bd}
                    active={issue.priority === key}
                    disabled={saving}
                    onClick={() => setPrio(key)}
                  />
                ))}
              </div>
            </Section>

            {/* Quick summary card */}
            <div style={{
              padding: '12px 14px',
              background: 'var(--surface)',
              border: '1px solid var(--border)',
              borderRadius: 12,
              display: 'flex', flexDirection: 'column', gap: 8,
            }}>
              <p style={{ fontSize: 9, fontWeight: 900, letterSpacing: 1.6, color: 'var(--text3)', textTransform: 'uppercase', margin: 0 }}>
                Current State
              </p>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span style={{ fontSize: 11, color: 'var(--text3)' }}>Status</span>
                <SBadge status={issue.status} />
              </div>
              {issue.priority && (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <span style={{ fontSize: 11, color: 'var(--text3)' }}>Priority</span>
                  <PBadge priority={issue.priority} />
                </div>
              )}
              {issue.assignedTo && (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                  <span style={{ fontSize: 11, color: 'var(--text3)', flexShrink: 0 }}>Dept.</span>
                  <span style={{
                    fontSize: 11, fontWeight: 700, color: 'var(--text)',
                    textAlign: 'right', wordBreak: 'break-word',
                  }}>{issue.assignedTo}</span>
                </div>
              )}
            </div>

            {!isHOD && (
              <Section label="Danger Zone">
                <button
                  disabled={deleting || saving}
                  onClick={handleDeleteComplaint}
                  style={{
                    width: '100%', padding: '11px 14px', borderRadius: 10,
                    background: 'var(--redBg)', border: '1.5px solid var(--redBd)',
                    color: 'var(--red)', fontWeight: 700, fontSize: 12,
                    cursor: (deleting || saving) ? 'not-allowed' : 'pointer', outline: 'none',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7,
                    transition: 'all .15s',
                  }}
                  onMouseEnter={e => !deleting && (e.currentTarget.style.opacity = '0.85')}
                  onMouseLeave={e => !deleting && (e.currentTarget.style.opacity = '1')}
                >
                  <Ic d={ICONS.trash} size={14} />
                  {deleting ? 'Deleting Complaint...' : 'Delete Complaint'}
                </button>
                <p style={{ fontSize: 10, color: 'var(--text3)', margin: '6px 0 0', textAlign: 'center' }}>
                  Permanently deletes this complaint from the system.
                </p>
              </Section>
            )}
          </ColScroll>
        </div>
      </div>
    </div>
  );
});
