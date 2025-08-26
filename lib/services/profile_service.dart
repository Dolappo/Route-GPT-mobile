import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data();
  }

  Future<void> updateColors({required Color primary, required Color secondary}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'theme': {
        'primary': primary.value,
        'secondary': secondary.value,
        'updated_at': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> updatePersonalInfo({
    String? homeAddress,
    List<Map<String, dynamic>>? favoriteLocations,
    String? commuteTimes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final data = <String, dynamic>{};
    if (homeAddress != null) data['homeAddress'] = homeAddress;
    if (favoriteLocations != null) data['favoriteLocations'] = favoriteLocations;
    if (commuteTimes != null) data['commuteTimes'] = commuteTimes;
    data['updated_at'] = FieldValue.serverTimestamp();
    await _db.collection('users').doc(user.uid).set({'profile': data}, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getMemory() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final snap = await _db
        .collection('users')
        .doc(user.uid)
        .collection('memory')
        .orderBy('updated_at', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<void> addMemoryItem({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('memory')
        .add({'type': type, 'data': data, 'updated_at': FieldValue.serverTimestamp()});
  }
}
