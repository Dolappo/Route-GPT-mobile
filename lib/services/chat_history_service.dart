import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';

import '../models/chat_message.dart';
import 'hive_chat_service.dart';

class ChatHistoryService with ListenableServiceMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HiveChatService _hiveService;

  // Reactive properties
  final ReactiveValue<List<ChatMessage>> _todayMessages = ReactiveValue<List<ChatMessage>>([]);
  final ReactiveValue<Map<String, dynamic>> _userMemory = ReactiveValue<Map<String, dynamic>>({});
  final ReactiveValue<bool> _isSyncing = ReactiveValue<bool>(false);
  final ReactiveValue<List<ChatMessage>> _pendingMessages = ReactiveValue<List<ChatMessage>>([]);
  final ReactiveValue<bool> _hasMigrationData = ReactiveValue<bool>(false);

  List<ChatMessage> get todayMessages => _todayMessages.value;
  Map<String, dynamic> get userMemory => _userMemory.value;
  bool get isSyncing => _isSyncing.value;
  List<ChatMessage> get pendingMessages => _pendingMessages.value;
  bool get hasMigrationData => _hasMigrationData.value;

  ChatHistoryService(this._hiveService) {
    listenToReactiveValues([_todayMessages, _userMemory, _isSyncing, _pendingMessages, _hasMigrationData]);
  }

  /// Initialize service for current user
  Future<void> initialize() async {
    // Initialize Hive first
    await _hiveService.initialize();
    
    // Load from Hive (offline-first)
    await _loadFromHive();
    
    // Check for migration data
    _hasMigrationData.value = _hiveService.hasMessagesToMigrate();
    
    // For authenticated users, try to sync with Firestore
    if (_auth.currentUser != null) {
      await _syncWithFirestore();
    }
  }

  /// Load data from Hive (offline-first)
  Future<void> _loadFromHive() async {
    // Load today's messages from Hive
    final todayMessages = _hiveService.getTodayMessages();
    _todayMessages.value = todayMessages;
    
    // Load user memory from Hive
    _userMemory.value = _hiveService.userMemory;
    
    // Load pending sync messages
    _pendingMessages.value = _hiveService.pendingSync;
  }

  /// Sync with Firestore for authenticated users
  Future<void> _syncWithFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _isSyncing.value = true;
      
      // Upload unsynced messages to Firestore
      final unsyncedMessages = _hiveService.getUnsyncedMessages();
      if (unsyncedMessages.isNotEmpty) {
        await _uploadMessagesToFirestore(unsyncedMessages);
      }
      
      // Download messages from Firestore
      await _downloadMessagesFromFirestore();
      
      // Sync user memory
      await _syncUserMemoryWithFirestore();
      
    } catch (e) {
      print('Error syncing with Firestore: $e');
    } finally {
      _isSyncing.value = false;
    }
  }

  /// Upload messages to Firestore
  Future<void> _uploadMessagesToFirestore(List<ChatMessage> messages) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('chat_history')
        .doc(today);

    // Get existing messages from Firestore
    final doc = await docRef.get();
    List<Map<String, dynamic>> existingMessages = [];
    if (doc.exists && doc.data() != null) {
      existingMessages = List<Map<String, dynamic>>.from(doc.data()!['messages'] ?? []);
    }

    // Add new messages
    for (final message in messages) {
      existingMessages.add(message.toMap());
      // Mark as synced in Hive
      await _hiveService.markAsSynced(message.id);
    }

    // Save to Firestore
    await docRef.set({
      'date': today,
      'messages': existingMessages,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Download messages from Firestore
  Future<void> _downloadMessagesFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('chat_history')
          .doc(today);

      final doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final messagesData = data['messages'] as List<dynamic>? ?? [];
        
        // Convert to ChatMessage objects and save to Hive
        for (final msgData in messagesData) {
          // Convert any Firestore timestamps to DateTime objects
          final convertedMsgData = convertTimestampsToDateTime(Map<String, dynamic>.from(msgData));
          final message = ChatMessage.fromMap(convertedMsgData);
          await _hiveService.addMessage(message.copyWith(isSynced: true));
        }
      }
    } catch (e) {
      print('Error downloading from Firestore: $e');
    }
  }

  /// Sync user memory with Firestore
  Future<void> _syncUserMemoryWithFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('memory')
          .doc('context');

      final doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final firestoreMemory = Map<String, dynamic>.from(doc.data()!);
        final hiveMemory = _hiveService.userMemory;
        
        // Convert Firestore timestamps to DateTime objects for Hive compatibility
        final convertedFirestoreMemory = convertTimestampsToDateTime(firestoreMemory);
        
        // Merge memories (Hive takes precedence for conflicts)
        final mergedMemory = Map<String, dynamic>.from(convertedFirestoreMemory);
        mergedMemory.addAll(hiveMemory);
        
        // Update both Hive and Firestore
        await _hiveService.updateUserMemory(mergedMemory);
        await docRef.set({
          ...mergedMemory,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error syncing user memory: $e');
    }
  }

  /// Convert Firestore Timestamp objects to DateTime objects for Hive compatibility
  Map<String, dynamic> convertTimestampsToDateTime(Map<String, dynamic> data) {
    final converted = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      try {
        if (value is Timestamp) {
          // Convert Firestore Timestamp to DateTime
          converted[key] = value.toDate();
        } else if (value is Map<String, dynamic>) {
          // Recursively convert nested maps
          converted[key] = convertTimestampsToDateTime(value);
        } else if (value is List) {
          // Convert lists that might contain timestamps
          converted[key] = value.map((item) {
            if (item is Timestamp) {
              return item.toDate();
            } else if (item is Map<String, dynamic>) {
              return convertTimestampsToDateTime(item);
            }
            return item;
          }).toList();
        } else {
          // Keep other values as-is
          converted[key] = value;
        }
      } catch (e) {
        // If conversion fails for any reason, skip this field
        print('Warning: Could not convert field $key: $e');
        converted[key] = value;
      }
    }
    
    return converted;
  }

  /// Save a message (offline-first with optional Firestore sync)
  Future<void> saveMessage(ChatMessage message) async {
    // Always save to Hive first (offline-first)
    await _hiveService.addMessage(message);
    
    // For authenticated users, try to sync to Firestore
    if (_auth.currentUser != null) {
      try {
        await _uploadMessagesToFirestore([message]);
      } catch (e) {
        print('Error syncing to Firestore, adding to pending: $e');
        await _hiveService.addToPendingSync(message);
      }
    }
  }

  /// Update user memory (offline-first with optional Firestore sync)
  Future<void> updateUserMemory(Map<String, dynamic> newContext) async {
    // Always save to Hive first
    await _hiveService.updateUserMemory(newContext);
    
    // For authenticated users, try to sync to Firestore
    if (_auth.currentUser != null) {
      try {
        await _saveUserMemoryToFirestore(newContext);
      } catch (e) {
        print('Error syncing user memory to Firestore: $e');
      }
    }
  }

  /// Save user memory to Firestore
  Future<void> _saveUserMemoryToFirestore(Map<String, dynamic> memory) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('memory')
          .doc('context');

      await docRef.set({
        ...memory,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving user memory to Firestore: $e');
    }
  }

  /// Get context for AI responses (from Hive)
  Map<String, dynamic> getContextForAI() {
    final context = <String, dynamic>{};

    // Add today's chat history (last 10 messages for context)
    final todayMessages = _hiveService.getTodayMessages();
    if (todayMessages.isNotEmpty) {
      final recentMessages = todayMessages
          .take(10)
          .map((msg) => {
                'role': msg.isUser ? 'user' : 'assistant',
                'content': msg.text,
                'timestamp': msg.timestamp.toIso8601String(),
              })
          .toList();
      context['todayChatHistory'] = recentMessages;
    }

    // Add user memory/context
    final memory = _hiveService.userMemory;
    if (memory.isNotEmpty) {
      context['userMemory'] = memory;
    }

    return context;
  }

  /// Clear today's chat history
  Future<void> clearTodayHistory() async {
    // Clear from Hive
    await _hiveService.clearTodayMessages();
    
    // Clear from Firestore if authenticated
    if (_auth.currentUser != null) {
      try {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('chat_history')
            .doc(today)
            .delete();
      } catch (e) {
        print('Error clearing from Firestore: $e');
      }
    }
    
    // Reload from Hive
    await _loadFromHive();
  }

  /// Migrate local chats to user account
  Future<void> migrateLocalChatsToUser(String userId) async {
    if (!_hiveService.hasMessagesToMigrate()) return;

    try {
      final messagesToMigrate = _hiveService.getMessagesForMigration();
      
      // Group messages by date
      final messagesByDate = <String, List<ChatMessage>>{};
      for (final message in messagesToMigrate) {
        final dateStr = DateFormat('yyyy-MM-dd').format(message.timestamp);
        messagesByDate.putIfAbsent(dateStr, () => []).add(message);
      }

      // Upload each date's messages to Firestore
      for (final entry in messagesByDate.entries) {
        final dateStr = entry.key;
        final messages = entry.value;
        
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('chat_history')
            .doc(dateStr);

        final messagesData = messages.map((msg) => msg.toMap()).toList();
        
        await docRef.set({
          'date': dateStr,
          'messages': messagesData,
          'lastUpdated': FieldValue.serverTimestamp(),
          'migratedFromLocal': true,
        }, SetOptions(merge: true));
      }

      // Mark messages as migrated in Hive
      await _hiveService.migrateToUser(userId);
      
      // Update migration status
      _hasMigrationData.value = false;
      
    } catch (e) {
      print('Error migrating local chats: $e');
      rethrow;
    }
  }

  /// Force sync with Firestore
  Future<void> forceSync() async {
    if (_auth.currentUser != null) {
      await _syncWithFirestore();
      await _loadFromHive(); // Reload after sync
    }
  }

  /// Handle user authentication state change
  Future<void> onAuthStateChanged() async {
    if (_auth.currentUser != null) {
      // User signed in - try to sync
      await _syncWithFirestore();
      
      // Check for migration data
      _hasMigrationData.value = _hiveService.hasMessagesToMigrate();
    } else {
      // User signed out - clear migration flag
      _hasMigrationData.value = false;
    }
  }

  /// Get chat history for a specific date
  Future<List<ChatMessage>> getChatHistoryForDate(DateTime date) async {
    return _hiveService.getMessagesForDate(date);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _hiveService.dispose();
  }
}
