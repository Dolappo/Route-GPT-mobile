import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/firestore_message.dart';

/// Service for managing short-term memory using Firestore
/// Stores the last 10 messages per user session for context
class FirestoreMemoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collectionName = 'sessions';
  static const int _maxMessages = 10;

  /// Get the current user's UID, returns null if not authenticated
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Check if user is authenticated
  bool get isAuthenticated => _currentUserId != null;

  /// Fetch the last N messages from Firestore for the current user
  /// Returns empty list if user is not authenticated or no messages exist
  Future<List<FirestoreMessage>> getLastMessages(
      {int limit = _maxMessages}) async {
    if (!isAuthenticated) {
      print('User not authenticated, returning empty messages list');
      return [];
    }

    try {
      final docRef = _firestore.collection(_collectionName).doc(_currentUserId);
      final doc = await docRef.get();

      if (!doc.exists) {
        print('No session document found for user: $_currentUserId');
        return [];
      }

      final data = doc.data();
      if (data == null || !data.containsKey('messages')) {
        print('No messages field found in session document');
        return [];
      }

      final messagesData = data['messages'] as List<dynamic>? ?? [];
      final messages = messagesData
          .map((msg) => FirestoreMessage.fromMap(msg as Map<String, dynamic>))
          .toList();

      // Sort by timestamp (oldest first) and take the last N messages
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final lastMessages = messages.length > limit
          ? messages.sublist(messages.length - limit)
          : messages;

      print('Retrieved ${lastMessages.length} messages from Firestore');
      return lastMessages;
    } catch (e) {
      print('Error fetching messages from Firestore: $e');
      return [];
    }
  }

  /// Add new messages to the user's session in Firestore
  /// Automatically maintains the message limit by removing oldest messages
  Future<void> addMessages(List<FirestoreMessage> newMessages) async {
    if (!isAuthenticated) {
      print('User not authenticated, cannot save messages');
      return;
    }

    if (newMessages.isEmpty) {
      print('No new messages to save');
      return;
    }

    try {
      final docRef = _firestore.collection(_collectionName).doc(_currentUserId);

      // Get existing messages
      final existingMessages = await getLastMessages(limit: _maxMessages);

      // Add new messages
      final allMessages = [...existingMessages, ...newMessages];

      // Sort by timestamp and keep only the last N messages
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final messagesToKeep = allMessages.length > _maxMessages
          ? allMessages.sublist(allMessages.length - _maxMessages)
          : allMessages;

      // Convert to Firestore format
      final messagesData = messagesToKeep.map((msg) => msg.toMap()).toList();

      // Update the document
      await docRef.set({
        'messages': messagesData,
        'last_updated': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      print(
          'Successfully saved ${newMessages.length} new messages to Firestore');
      print('Total messages in session: ${messagesToKeep.length}');
    } catch (e) {
      print('Error saving messages to Firestore: $e');
      rethrow;
    }
  }

  /// Add a single message to the user's session
  Future<void> addMessage(FirestoreMessage message) async {
    await addMessages([message]);
  }

  /// Clear all messages for the current user
  Future<void> clearSession() async {
    if (!isAuthenticated) {
      print('User not authenticated, cannot clear session');
      return;
    }

    try {
      final docRef = _firestore.collection(_collectionName).doc(_currentUserId);
      await docRef.delete();
      print('Successfully cleared session for user: $_currentUserId');
    } catch (e) {
      print('Error clearing session: $e');
      rethrow;
    }
  }

  /// Get session info (message count, last updated)
  Future<Map<String, dynamic>?> getSessionInfo() async {
    if (!isAuthenticated) {
      return null;
    }

    try {
      final docRef = _firestore.collection(_collectionName).doc(_currentUserId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      if (data == null) {
        return null;
      }

      final messagesData = data['messages'] as List<dynamic>? ?? [];
      final lastUpdated = data['last_updated'] as String?;

      return {
        'messageCount': messagesData.length,
        'lastUpdated': lastUpdated != null ? DateTime.parse(lastUpdated) : null,
        'maxMessages': _maxMessages,
      };
    } catch (e) {
      print('Error getting session info: $e');
      return null;
    }
  }

  /// Convert FirestoreMessage list to Gemini API format
  /// Returns list of maps with 'role' and 'parts' fields
  List<Map<String, dynamic>> toGeminiFormat(List<FirestoreMessage> messages) {
    return messages
        .map((msg) => {
              'role': msg.role,
              'parts': [
                {'text': msg.text}
              ],
            })
        .toList();
  }

  /// Get messages formatted for Gemini API context
  Future<List<Map<String, dynamic>>> getGeminiContext(
      {int limit = _maxMessages}) async {
    final messages = await getLastMessages(limit: limit);
    return toGeminiFormat(messages);
  }
}
