import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';

class UsageService {
  static const String _deviceIdKey = 'device_id';
  static const String _hasShownCreateAccountDialog =
      'has_shown_create_account_dialog';
  static const int _initialFreePrompts = 3;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      deviceId = await _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  Future<String> _generateDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final data =
            '${androidInfo.brand}-${androidInfo.model}-${androidInfo.id}';
        return sha256.convert(utf8.encode(data)).toString();
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final data =
            '${iosInfo.name}-${iosInfo.model}-${iosInfo.identifierForVendor}';
        return sha256.convert(utf8.encode(data)).toString();
      }
    } catch (e) {}

    return sha256
        .convert(utf8.encode(DateTime.now().millisecondsSinceEpoch.toString()))
        .toString();
  }

  Future<bool> hasShownCreateAccountDialog() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasShownCreateAccountDialog) ?? false;
  }

  Future<void> markCreateAccountDialogShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasShownCreateAccountDialog, true);
  }

  Future<int> getRemainingFreePrompts() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _db.collection('user_usage').doc(user.uid).get();
        if (doc.exists) {
          return (doc.data()!['free_prompts_remaining'] as int?) ?? 0;
        } else {
          // initialize
          await _db.collection('user_usage').doc(user.uid).set({
            'free_prompts_remaining': _initialFreePrompts,
            'total_prompts_used': 0,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
          return _initialFreePrompts;
        }
      } else {
        final deviceId = await _getDeviceId();
        final doc = await _db.collection('device_usage').doc(deviceId).get();
        if (doc.exists) {
          return (doc.data()!['free_prompts_remaining'] as int?) ??
              _initialFreePrompts;
        } else {
          await _db.collection('device_usage').doc(deviceId).set({
            'free_prompts_remaining': _initialFreePrompts,
            'total_prompts_used': 0,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
          return _initialFreePrompts;
        }
      }
    } catch (e) {
      return _initialFreePrompts;
    }
  }

  Future<bool> canMakePrompt() async {
    final remaining = await getRemainingFreePrompts();
    return remaining > 0;
  }

  Future<bool> usePrompt() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final ref = _db.collection('user_usage').doc(user.uid);
        return await _db.runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          final data = snap.data();
          final remaining =
              (data?['free_prompts_remaining'] as int?) ?? _initialFreePrompts;
          final used = (data?['total_prompts_used'] as int?) ?? 0;
          if (remaining > 0) {
            tx.set(
                ref,
                {
                  'free_prompts_remaining': remaining - 1,
                  'total_prompts_used': used + 1,
                  'updated_at': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true));
            return true;
          }
          return false;
        });
      } else {
        final deviceId = await _getDeviceId();
        final ref = _db.collection('device_usage').doc(deviceId);
        return await _db.runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          final data = snap.data() as Map<String, dynamic>?;
          final remaining =
              (data?['free_prompts_remaining'] as int?) ?? _initialFreePrompts;
          final used = (data?['total_prompts_used'] as int?) ?? 0;
          if (remaining > 0) {
            tx.set(
                ref,
                {
                  'free_prompts_remaining': remaining - 1,
                  'total_prompts_used': used + 1,
                  'updated_at': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true));
            return true;
          }
          return false;
        });
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> migrateDeviceUsageToUser(String userId) async {
    try {
      final deviceId = await _getDeviceId();
      final deviceDoc =
          await _db.collection('device_usage').doc(deviceId).get();
      final deviceData = deviceDoc.data();
      if (deviceData != null) {
        await _db.collection('user_usage').doc(userId).set({
          'free_prompts_remaining':
              deviceData['free_prompts_remaining'] ?? _initialFreePrompts,
          'total_prompts_used': deviceData['total_prompts_used'] ?? 0,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _db.collection('device_usage').doc(deviceId).delete();
      }
    } catch (e) {}
  }
}
