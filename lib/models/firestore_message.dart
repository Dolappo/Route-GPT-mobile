/// Model for chat messages stored in Firestore for short-term memory
class FirestoreMessage {
  final String role; // 'user' or 'assistant'
  final String text;
  final DateTime timestamp;

  FirestoreMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  /// Convert to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from Firestore document
  factory FirestoreMessage.fromMap(Map<String, dynamic> map) {
    return FirestoreMessage(
      role: map['role'] as String,
      text: map['text'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  /// Create from existing ChatMessage
  factory FirestoreMessage.fromChatMessage(dynamic chatMessage) {
    return FirestoreMessage(
      role: chatMessage.isUser ? 'user' : 'assistant',
      text: chatMessage.text,
      timestamp: chatMessage.timestamp,
    );
  }

  @override
  String toString() {
    return 'FirestoreMessage(role: $role, text: $text, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FirestoreMessage &&
        other.role == role &&
        other.text == text &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return role.hashCode ^ text.hashCode ^ timestamp.hashCode;
  }
}
