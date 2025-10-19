import 'package:hive/hive.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 0)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String text;

  @HiveField(2)
  final bool isUser;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final MessageStatus status;

  @HiveField(5)
  final bool isSynced;

  @HiveField(6)
  final String? originalQuery;

  @HiveField(7)
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.status,
    this.isSynced = false,
    this.originalQuery,
    this.metadata,
  });

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isSynced,
    String? originalQuery,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isSynced: isSynced ?? this.isSynced,
      originalQuery: originalQuery ?? this.originalQuery,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString(),
      'isSynced': isSynced,
      'originalQuery': originalQuery,
      'metadata': metadata,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      isUser: map['isUser'] as bool,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => MessageStatus.sent,
      ),
      isSynced: map['isSynced'] as bool? ?? false,
      originalQuery: map['originalQuery'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

@HiveType(typeId: 1)
enum MessageStatus {
  @HiveField(0)
  sent,
  @HiveField(1)
  error,
  @HiveField(2)
  pending,
}
