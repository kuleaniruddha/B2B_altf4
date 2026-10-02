import { useState, useEffect } from 'react';
import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc, setDoc, collection, query, where, getDocs, deleteDoc } from 'firebase/firestore';
import { auth, db } from './firebase';
import LoginPage   from './pages/LoginPage';
import AdminLayout from './components/AdminLayout';

const ADMIN_EMAIL = 'admin@smartcivic.com';

// ─── Full-screen loader ───────────────────────────────────────────────────────
function Loader() {
  return (
    <div style={{
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      height: '100vh', background: 'var(--bg)', gap: 16,
    }}>
      {/* Logo */}
      <div style={{
        width: 52, height: 52, borderRadius: 16,
        background: 'linear-gradient(135deg, var(--accent), var(--accentL))',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: 'var(--shAccent)',
        marginBottom: 4,
      }}>
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none"
          stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
          <polyline points="9 22 9 12 15 12 15 22"/>
        </svg>
      </div>

      {/* Spinner */}
      <div style={{
        width: 28, height: 28, borderRadius: '50%',
        border: '2.5px solid var(--border)',
        borderTopColor: 'var(--accent)',
        animation: 'spin .8s linear infinite',
      }}/>

      <p style={{
        fontFamily: 'var(--font-display)',
        fontSize: 13, fontWeight: 600,
        color: 'var(--text3)', letterSpacing: 0.3,
      }}>Authenticating…</p>

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

// ─── App ──────────────────────────────────────────────────────────────────────
export default function App() {
  const [user,    setUser]    = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);
  const [debug,   setDebug]   = useState('');

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      if (!u) {
        setUser(null); setIsAdmin(false); setLoading(false); return;
      }

      try {
        const snap = await getDoc(doc(db, 'users', u.uid));
        
        let userData = snap.exists() ? snap.data() : { role: 'citizen' };

        // Fallback for Seeded HODs: If role is still citizen, check by email
        if (userData.role === 'citizen' && u.email) {
          const q = query(collection(db, 'users'), where('email', '==', u.email.toLowerCase().trim()));
          const qSnap = await getDocs(q);
          
          const emailDoc = qSnap.docs.find(d => d.id !== u.uid); // find the seed doc
          if (emailDoc) {
             const seedData = emailDoc.data();
             if (seedData.role === 'hod' || seedData.role === 'admin' || seedData.role === 'super_admin') {
               // Claim this role!
               userData = { ...userData, ...seedData };
               await setDoc(doc(db, 'users', u.uid), userData, { merge: true });
               
               // Optionally cleanup the old seed doc if it has a random ID
               try {
                 if (emailDoc.id.length > 20) { // Firebase auto IDs are long
                   await deleteDoc(doc(db, 'users', emailDoc.id));
                 }
               } catch (deleteError) {
                 console.warn("Cleanup of seed doc failed, but ignoring to allow login:", deleteError);
               }
             }
          }
        }

        // If it's the master admin email, force super_admin
        if (u.email?.toLowerCase().trim() === ADMIN_EMAIL.toLowerCase().trim()) {
           userData.role = 'super_admin';
           userData.name = userData.name || 'Master Admin';
           await setDoc(doc(db, 'users', u.uid), userData, { merge: true });
        }

        const role = userData.role?.trim();
        if (role === 'super_admin' || role === 'hod' || role === 'admin') {
          // Found an authorized admin/hod
          setUser({ ...u, ...userData });
          setIsAdmin(true); 
          setDebug('');
        } else {
          setDebug(`Access denied for ${u.email}. Found role: "${role || 'none'}". Authorized personnel only.`);
          setUser(null); 
          setIsAdmin(false);
          await auth.signOut();
        }
      } catch (e) {
        setDebug(`Auth Error: ${e.message}`);
        setUser(null); 
        setIsAdmin(false);
        await auth.signOut();
      }

      setLoading(false);
    });

    return unsub;
  }, []);

  if (loading)              return <Loader />;
  if (!user || !isAdmin)    return <LoginPage debugMsg={debug} />;
  return                           <AdminLayout user={user} />;
}
