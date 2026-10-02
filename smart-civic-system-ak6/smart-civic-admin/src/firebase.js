// src/firebase.js

import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";
// Optional (only if you need analytics)
import { getAnalytics } from "firebase/analytics";

// ✅ Your Firebase Web Config
const firebaseConfig = {
  apiKey: "AIzaSyBN1oxt48PaeKy1d1EDHTFXo5INJlKZYbM",
  authDomain: "smartcivic-996df.firebaseapp.com",
  projectId: "smartcivic-996df",
  storageBucket: "smartcivic-996df.appspot.com",
  messagingSenderId: "374041201622",
  appId: "1:374041201622:web:353a8d23c94b4806067277",
  measurementId: "G-2VPC21J7X3"
};

// ✅ Initialize Firebase
const app = initializeApp(firebaseConfig);

// ✅ Services
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// ✅ Analytics (optional, works only in browser)
export const analytics =
  typeof window !== "undefined" ? getAnalytics(app) : null;

export default app;