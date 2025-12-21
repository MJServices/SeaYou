
class Conversation {
  final String id;
  final String userAId;
  final String userBId;
  final String? title;
  final int feelingPercent;
  final int unlockState;  // Changed from Map to int to match DB schema
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.userAId,
    required this.userBId,
    this.title,
    this.feelingPercent = 0,
    this.unlockState = 0,  // Changed default value
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      userAId: json['user_a_id'] as String,
      userBId: json['user_b_id'] as String,
      title: json['title'] as String?,
      feelingPercent: json['feeling_percent'] as int? ?? 0,
      unlockState: json['unlock_state'] as int? ?? 0,  // Fixed: changed from Map to int
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_a_id': userAId,
      'user_b_id': userBId,
      'title': title,
      'feeling_percent': feelingPercent,
      'unlock_state': unlockState,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'unread_count': unreadCount,
    };
  }
  
  String getOtherUserId(String myUserId) {
    return myUserId == userAId ? userBId : userAId;
  }
}
