import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:stacked/stacked.dart';

import '../firebase_options.dart';

class AuthService with ListenableServiceMixin {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
    scopes: ['email', 'profile'],
  );

  fb.User? _user;
  fb.User? get user => _user ?? _auth.currentUser;

  bool get isAuthenticated => user != null;

  AuthService() {
    _auth.authStateChanges().listen((fb.User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<fb.UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred;
  }

  Future<fb.UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<fb.UserCredential?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In process...');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign-In was cancelled by user');
        return null;
      }

      print('Google user obtained: ${googleUser.email}');
      
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      
      print('Google authentication completed');

      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Firebase credential created, signing in...');
      
      final userCredential = await _auth.signInWithCredential(credential);
      print('Firebase sign-in successful: ${userCredential.user?.email}');
      
      return userCredential;
    } catch (e) {
      print('Google Sign-In error: $e');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('network')) {
        print('Network-related error detected');
      }
      if (e.toString().contains('cancelled')) {
        print('User cancelled the sign-in');
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<bool> isGoogleSignInAvailable() async {
    try {
      final isAvailable = await _googleSignIn.isSignedIn();
      print('Google Sign-In availability check: $isAvailable');
      return true;
    } catch (e) {
      print('Google Sign-In not available: $e');
      return false;
    }
  }
}
