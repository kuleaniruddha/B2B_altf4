# Smart Civic Mumbai - Admin Panel
## Setup Instructions

---

## STEP 1 - File Structure
Verify the folder structure:

```
smart-civic-admin/
├── index.html
├── package.json
├── vite.config.js
└── src/
    ├── main.jsx
    ├── App.jsx
    ├── index.css
    ├── firebase.js          (Firebase config location)
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

## STEP 2 - Add Your Firebase Config

Open `src/firebase.js` and configure your credentials:
```js
const firebaseConfig = {
  apiKey: "...",           // From Firebase Console
  authDomain: "...",
  projectId: "smartcivic-996df",
  storageBucket: "...",
  messagingSenderId: "...",
  appId: "...",
};
```

Reference: Firebase Console -> Project Settings -> Your Apps -> SDK setup & config

---

## STEP 3 - Create Admin User in Firestore

In Firebase Console -> Firestore -> users collection, find your user document and set the role field:

```json
{
  "name": "Admin",
  "email": "your@email.com",
  "role": "admin"
}
```

Note: Without `role: "admin"` or `role: "hod"`, login will be rejected.

---

## STEP 4 - Firestore Rules

In Firebase Console -> Firestore -> Rules:

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

## STEP 5 - Install & Run

Open terminal in the `smart-civic-admin` folder:

```bash
npm install
npm run dev
```

Open browser at: http://localhost:5173

---

## STEP 6 - Build for Production

```bash
npm run build
```

---

## Features
- Admin-only authentication with role validation from Firestore
- Dashboard with live statistics and summary widgets
- Complaints table with search, sorting, and status filter tabs
- Complaint detail modal with workflow timeline and AI verification
- Department assignment, status transitions, and resolution remarks
- User directory management
- Analytics views with department-wise performance metrics
- Real-time updates via Firebase onSnapshot
- Responsive collapsible sidebar navigation
- Modern theme design
