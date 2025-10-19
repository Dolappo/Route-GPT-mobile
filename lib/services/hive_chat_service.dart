import 'package:hive_flutter/hive_flutter.dart';
import 'package:stacked/stacked.dart';

import '../models/chat_message.dart';

class HiveChatService with ListenableServiceMixin {
  static const String _chatBoxName = 'chat_messages';
  static const String _userMemoryBoxName = 'user_memory';
  static const String _pendingSyncBoxName = 'pending_sync';

  late Box<ChatMessage> _chatBox;
  late Box<Map> _userMemoryBox;
  late Box<ChatMessage> _pendingSyncBox;

  final ReactiveValue<List<ChatMessage>> _messages = ReactiveValue<List<ChatMessage>>([]);
  final ReactiveValue<Map<String, dynamic>> _userMemory = ReactiveValue<Map<String, dynamic>>({});
  final ReactiveValue<List<ChatMessage>> _pendingSync = ReactiveValue<List<ChatMessage>>([]);

  List<ChatMessage> get messages => _messages.value;
  Map<String, dynamic> get userMemory => _userMemory.value;
  List<ChatMessage> get pendingSync => _pendingSync.value;

  HiveChatService() {
    listenToReactiveValues([_messages, _userMemory, _pendingSync]);
  }

  /// Initialize Hive and open boxes
  Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MessageStatusAdapter());
    }

    // Open boxes
    _chatBox = await Hive.openBox<ChatMessage>(_chatBoxName);
    _userMemoryBox = await Hive.openBox<Map>(_userMemoryBoxName);
    _pendingSyncBox = await Hive.openBox<ChatMessage>(_pendingSyncBoxName);

    // Load initial data
    await _loadMessages();
    await _loadUserMemory();
    await _loadPendingSync();

    // Listen to changes
    _chatBox.listenable().addListener(_onChatBoxChanged);
    _userMemoryBox.listenable().addListener(_onMemoryBoxChanged);
    _pendingSyncBox.listenable().addListener(_onPendingSyncChanged);
  }

  void _onChatBoxChanged() {
    _loadMessages();
  }

  void _onMemoryBoxChanged() {
    _loadUserMemory();
  }

  void _onPendingSyncChanged() {
    _loadPendingSync();
  }

  /// Load all messages from Hive
  Future<void> _loadMessages() async {
    final allMessages = _chatBox.values.toList();
    allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _messages.value = allMessages;
  }

  /// Load user memory from Hive
  Future<void> _loadUserMemory() async {
    final memory = _userMemoryBox.get('memory');
    if (memory != null) {
      _userMemory.value = Map<String, dynamic>.from(memory);
    } else {
      _userMemory.value = {};
    }
  }

  /// Load pending sync messages from Hive
  Future<void> _loadPendingSync() async {
    final pending = _pendingSyncBox.values.toList();
    _pendingSync.value = pending;
  }

  /// Add a new message to Hive (immediate write)
  Future<void> addMessage(ChatMessage message) async {
    await _chatBox.put(message.id, message);
    // Messages are automatically loaded via listener
  }

  /// Update a message (e.g., mark as synced)
  Future<void> updateMessage(ChatMessage message) async {
    await _chatBox.put(message.id, message);
  }

  /// Mark message as synced
  Future<void> markAsSynced(String messageId) async {
    final message = _chatBox.get(messageId);
    if (message != null) {
      final updatedMessage = message.copyWith(isSynced: true);
      await _chatBox.put(messageId, updatedMessage);
    }
  }

  /// Add message to pending sync queue
  Future<void> addToPendingSync(ChatMessage message) async {
    await _pendingSyncBox.put(message.id, message);
  }

  /// Remove message from pending sync queue
  Future<void> removeFromPendingSync(String messageId) async {
    await _pendingSyncBox.delete(messageId);
  }

  /// Get messages for a specific date
  List<ChatMessage> getMessagesForDate(DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _messages.value.where((msg) {
      final msgDate = '${msg.timestamp.year}-${msg.timestamp.month.toString().padLeft(2, '0')}-${msg.timestamp.day.toString().padLeft(2, '0')}';
      return msgDate == dateStr;
    }).toList();
  }

  /// Get today's messages
  List<ChatMessage> getTodayMessages() {
    final today = DateTime.now();
    return getMessagesForDate(today);
  }

  /// Update user memory
  Future<void> updateUserMemory(Map<String, dynamic> newMemory) async {
    final updatedMemory = Map<String, dynamic>.from(_userMemory.value);
    updatedMemory.addAll(newMemory);
    await _userMemoryBox.put('memory', updatedMemory);
  }

  /// Clear all messages
  Future<void> clearAllMessages() async {
    await _chatBox.clear();
    await _pendingSyncBox.clear();
  }

  /// Clear today's messages
  Future<void> clearTodayMessages() async {
    final today = DateTime.now();
    final todayMessages = getMessagesForDate(today);
    
    for (final message in todayMessages) {
      await _chatBox.delete(message.id);
      await _pendingSyncBox.delete(message.id);
    }
  }

  /// Get unsynced messages for authenticated users
  List<ChatMessage> getUnsyncedMessages() {
    return _messages.value.where((msg) => !msg.isSynced).toList();
  }

  /// Migrate local chats to user account (for unauthenticated users who sign up)
  Future<void> migrateToUser(String userId) async {
    // This will be called when an unauthenticated user signs up
    // The actual migration logic will be handled by the ChatHistoryService
    // This method just marks all messages as ready for migration
    final allMessages = _chatBox.values.toList();
    for (final message in allMessages) {
      final migratedMessage = message.copyWith(
        metadata: {
          ...?message.metadata,
          'migratedToUser': userId,
          'migrationTimestamp': DateTime.now().toIso8601String(),
        },
      );
      await _chatBox.put(message.id, migratedMessage);
    }
  }

  /// Check if there are messages to migrate
  bool hasMessagesToMigrate() {
    return _messages.value.isNotEmpty;
  }

  /// Get messages for migration
  List<ChatMessage> getMessagesForMigration() {
    return _messages.value.where((msg) => 
      msg.metadata?['migratedToUser'] == null
    ).toList();
  }

  /// Dispose resources
  Future<void> dispose() async {
    _chatBox.listenable().removeListener(_onChatBoxChanged);
    _userMemoryBox.listenable().removeListener(_onMemoryBoxChanged);
    _pendingSyncBox.listenable().removeListener(_onPendingSyncChanged);
    
    await _chatBox.close();
    await _userMemoryBox.close();
    await _pendingSyncBox.close();
  }
}
