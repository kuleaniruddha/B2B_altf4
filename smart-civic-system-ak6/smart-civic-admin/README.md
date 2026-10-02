# Smart Civic Mumbai — Admin Panel
## Setup Instructions (Follow exactly)

---

## STEP 1 — File Structure
Create this folder structure on your computer:

```
smart-civic-admin/
├── index.html
├── package.json
├── vite.config.js
└── src/
    ├── main.jsx
    ├── App.jsx
    ├── index.css
    ├── firebase.js          ← PUT YOUR FIREBASE CONFIG HERE
    ├── pages/
    │   ├── LoginPage.jsx
    │   ├── Dashboard.jsx
    │   ├── Complaints.jsx
    │   ├── Users.jsx
    │   └── Analytics.jsx
    └── components/
        └── AdminLayout.jsx
```

---

## STEP 2 — Add Your Firebase Config

Open `src/firebase.js` and replace the placeholder values:
```js
const firebaseConfig = {
  apiKey: "...",           // From Firebase Console
  authDomain: "...",
  projectId: "smartcivic-996df",  // Your project ID
  storageBucket: "...",
  messagingSenderId: "...",
  appId: "...",
};
```

👉 Get these from: Firebase Console → Project Settings → Your Apps → SDK setup & config

---

## STEP 3 — Create Admin User in Firestore

In Firebase Console → Firestore → users collection,
find YOUR user document and add/update the `role` field:

```json
{
  "name": "Admin",
  "email": "your@email.com",
  "role": "admin"
}
```

⚠️ Without `role: "admin"`, login will be rejected even with correct credentials.

---

## STEP 4 — Firestore Rules

In Firebase Console → Firestore → Rules, paste:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null;
    }
    match /issues/{issueId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## STEP 5 — Install & Run

Open terminal in the `smart-civic-admin` folder:

```bash
npm install
npm run dev
```

Open browser at: http://localhost:5173

---

## STEP 6 — Build for Production

```bash
npm run build
```

Upload the `dist/` folder to any static host (Firebase Hosting, Netlify, Vercel).

---

## Features
- ✅ Admin-only login (role check from Firestore)
- ✅ Dashboard with live stats + 4 charts
- ✅ Complaints table with search + filter tabs
- ✅ Complaint detail modal with workflow timeline
- ✅ Assign to department, update status, add notes
- ✅ Users grid with block/delete
- ✅ Analytics page with 5 charts
- ✅ Real-time updates (Firebase onSnapshot)
- ✅ Collapsible sidebar
- ✅ Dark mode design