
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String type; // 'text', 'image', 'voice'
  final String? text;
  final String? mediaUrl;
  final String? voicePath; // Local path for recording
  final int? duration; // Duration in seconds for voice
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isRead;
  final bool isMe; // Helper for UI
  final String? mood; // Mood associated with the message
  final String? replyToId;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaUrl,
    this.voicePath,
    this.duration,
    required this.createdAt,
    this.updatedAt,
    this.isRead = false,
    this.isMe = false,
    this.mood,
    this.replyToId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      mediaUrl: json['media_url'] as String?,
      voicePath: json['voice_path'] as String?,
      duration: json['duration'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String).toUtc() : null,
      isRead: json['is_read'] as bool? ?? false,
      isMe: currentUserId != null && json['sender_id'] == currentUserId,
      mood: json['mood'] as String?,
      replyToId: json['reply_to_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'type': type,
      'text': text,
      'media_url': mediaUrl,
      'voice_path': voicePath,
      'duration': duration,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_read': isRead,
      'mood': mood,
      'reply_to_id': replyToId,
    };
  }
}
