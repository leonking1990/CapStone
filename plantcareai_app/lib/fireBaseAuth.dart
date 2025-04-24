import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Modified to directly throw exceptions on failure
Future<UserCredential> signUpWithEmailAndPassword(
    String email, String password, String fName) async {
  // No try-catch here; let the caller handle FirebaseAuthException
  UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  if (kDebugMode) {
    print("User signed up: ${userCredential.user?.email}");
  }
  // Update display name after successful creation
  // Using 'await' ensures we wait for the update to attempt completion.
  // Add null check for safety.
  if (userCredential.user != null) {
    await userCredential.user!.updateDisplayName(fName);
  }
  return userCredential; // Return the credential on success
}

// Modified to return UserCredential on success and throw exceptions on failure
Future<UserCredential> signInWithEmailAndPassword(
    String email, String password) async {
  // No try-catch here; let the caller handle FirebaseAuthException
  UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email, // Use the passed string directly
    password: password, // Use the passed string directly
  );
  if (kDebugMode) {
    print("User signed in: ${userCredential.user?.email}");
  }
  return userCredential; // Return the credential on success
}

Future<void> signOut() async {
  await FirebaseAuth.instance.signOut();
  if (kDebugMode) {
    print("User signed out");
  }
}
