import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================= REGISTER =================
  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String email,
    required String wardNo,
    required String password,
  }) async {
    try {
      // Step 1: Create Firebase Auth user
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Step 2: Send verification email
      try {
        await userCred.user!.sendEmailVerification();
      } catch (e) {
        print("Verification email failed (non-fatal): $e");
      }

      // Step 3: Save to Firestore (non-fatal if it fails)
      try {
        await _db.collection("users").doc(userCred.user!.uid).set({
          "name": name,
          "phone": phone,
          "email": email,
          "wardNo": wardNo,
          "createdAt": FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("Firestore write failed (non-fatal): $e");
      }

      // Step 4: Save locally
      await saveUserName(name);
      await saveUserPhone(phone);
      await saveWard(wardNo);

      // Step 5: CRITICAL — sign out so Firebase session doesn't
      // auto-redirect to /home, bypassing email verification + MPIN setup
      await _auth.signOut();

      return {'success': true, 'message': 'Account created successfully'};

    } on FirebaseAuthException catch (e) {
      print("Register Error: ${e.code} - ${e.message}");
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered. Try logging in.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password sign-up is not enabled.';
          break;
        case 'network-request-failed':
          message = 'No internet connection. Please try again.';
          break;
        default:
          message = e.message ?? 'Registration failed. Please try again.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      print("Register unknown error: $e");
      return {'success': false, 'message': 'Something went wrong. Please try again.'};
    }
  }

  // ================= LOGIN =================
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!userCred.user!.emailVerified) {
        await _auth.signOut();
        return {
          'success': false,
          'message': 'Email not verified. Please check your inbox.',
          'unverified': true,
        };
      }

      try {
        final doc = await _db.collection("users").doc(userCred.user!.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            await saveUserName(data["name"] ?? "");
            await saveUserPhone(data["phone"] ?? "");
            await saveWard(data["wardNo"] ?? "");
          }
        }
      } catch (e) {
        print("Firestore read failed (non-fatal): $e");
      }

      await setLoggedIn(true);
      return {'success': true, 'message': 'Login successful'};

    } on FirebaseAuthException catch (e) {
      print("Login Error: ${e.code} - ${e.message}");
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'No internet connection. Please try again.';
          break;
        default:
          message = e.message ?? 'Login failed. Please try again.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      print("Login unknown error: $e");
      return {'success': false, 'message': 'Something went wrong. Please try again.'};
    }
  }

  // ================= RESEND VERIFICATION EMAIL =================
  Future<bool> resendVerificationEmail(String email, String password) async {
    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!userCred.user!.emailVerified) {
        await userCred.user!.sendEmailVerification();
        await _auth.signOut();
        return true;
      }
      await _auth.signOut();
      return false;
    } catch (e) {
      print("Resend Error: $e");
      return false;
    }
  }

  // ================= FORGOT PASSWORD =================
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      print("Reset Error: ${e.message}");
      return false;
    }
  }

  // ================= SESSION CHECK =================
  Future<bool> isLoggedIn() async {
    final localLoggedIn  = await isLoggedInLocal();
    final firebaseLoggedIn = isLoggedInFirebase();
    return localLoggedIn && firebaseLoggedIn;
  }

  bool isLoggedInFirebase() => _auth.currentUser != null;

  Future<bool> isLoggedInLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', value);
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ================= MPIN =================
  Future<void> saveMPIN(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mpin', pin);
  }

  Future<String?> getMPIN() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('mpin');
  }

  Future<bool> verifyMPIN(String enteredPin) async {
    final savedPin = await getMPIN();
    return savedPin == enteredPin;
  }

  Future<bool> hasMPIN() async {
    final pin = await getMPIN();
    return pin != null && pin.isNotEmpty;
  }

  // ================= LOCAL STORAGE =================
  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
  }

  Future<String?> getSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  Future<void> saveUserPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', phone);
  }

  Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('phone');
  }

  Future<void> saveWard(String ward) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ward', ward);
  }

  Future<String?> getSavedWard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ward');
  }
}