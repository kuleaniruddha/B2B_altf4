import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ApiService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── CREATE ISSUE ─────────────────────────────────────────────
  static Future<Map<String, dynamic>?> createIssue({
    required String title,
    required String description,
    required String category,
    required String wardNo,
    double? latitude,
    double? longitude,
    File? image,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      String? imageUrl;

      // ── Upload Image ─────────────────────────────
      if (image != null) {
        final ref = _storage
            .ref()
            .child("issues/${DateTime.now().millisecondsSinceEpoch}.jpg");

        await ref.putFile(image);
        imageUrl = await ref.getDownloadURL();
      }

      // ── Save Issue to Firestore ──────────────────
      final doc = await _db.collection("issues").add({
        "userId": user.uid,
        "title": title,
        "description": description,
        "category": category,
        "wardNo": wardNo,
        "latitude": latitude,
        "longitude": longitude,
        "imageUrl": imageUrl,
        "status": "Pending",
        "createdAt": FieldValue.serverTimestamp(),
      });

      return {"trackId": doc.id};
    } catch (e) {
      print("Create Issue Error: $e");
      return null;
    }
  }

  // ── GET ALL ISSUES ─────────────────────────────
  static Future<List<dynamic>> getIssues() async {
    try {
      final snapshot = await _db.collection("issues").get();
      return snapshot.docs.map((doc) => {...doc.data(), "id": doc.id}).toList();
    } catch (e) {
      print("Get Issues Error: $e");
      return [];
    }
  }

  // ── GET MY ISSUES ─────────────────────────────
  static Future<List<dynamic>> getMyIssues() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _db
          .collection("issues")
          .where("userId", isEqualTo: user.uid)
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), "id": doc.id}).toList();
    } catch (e) {
      print("My Issues Error: $e");
      return [];
    }
  }

  // ── TRACK ISSUE ─────────────────────────────
  static Future<Map<String, dynamic>?> trackIssue(String trackId) async {
    try {
      final doc = await _db.collection("issues").doc(trackId).get();

      if (doc.exists) {
        return {...doc.data()!, "id": doc.id};
      }
    } catch (e) {
      print("Track Issue Error: $e");
    }
    return null;
  }

  // ── GET HOTSPOTS ─────────────────────────────
  static Future<List<dynamic>> getHotspots() async {
    try {
      final snapshot = await _db.collection("issues").get();

      return snapshot.docs
          .map((doc) => {
                "lat": doc["latitude"],
                "lng": doc["longitude"],
              })
          .where((e) => e["lat"] != null && e["lng"] != null)
          .toList();
    } catch (e) {
      print("Hotspots Error: $e");
      return [];
    }
  }

  // ── GET ISSUE BY ID ─────────────────────────
  static Future<Map<String, dynamic>?> getIssueById(String id) async {
    try {
      final doc = await _db.collection("issues").doc(id).get();

      if (doc.exists) {
        return {...doc.data()!, "id": doc.id};
      }
    } catch (e) {
      print("Get Issue Error: $e");
    }
    return null;
  }
}