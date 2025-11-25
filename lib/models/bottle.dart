class Bottle {
  final String id;
  final String contentType;
  final String? message;
  final String? audioUrl;
  final String? photoUrl;
  final String? caption;
  final String? mood;
  final DateTime createdAt;
  final DateTime updatedAt;

  Bottle({
    required this.id,
    required this.contentType,
    this.message,
    this.audioUrl,
    this.photoUrl,
    this.caption,
    this.mood,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Bottle.fromJson(Map<String, dynamic> json) {
    return Bottle(
      id: json['id'] as String,
      contentType: json['content_type'] as String,
      message: json['message'] as String?,
      audioUrl: json['audio_url'] as String?,
      photoUrl: json['photo_url'] as String?,
      caption: json['caption'] as String?,
      mood: json['mood'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_type': contentType,
      'message': message,
      'audio_url': audioUrl,
      'photo_url': photoUrl,
      'caption': caption,
      'mood': mood,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ReceivedBottle extends Bottle {
  final String receiverId;
  final String? senderId;
  final bool isRead;
  final bool isReplied;
  final int matchScore; // Compatibility score from matching algorithm
  final DateTime? matchedAt; // When the match was made

  ReceivedBottle({
    required super.id,
    required super.contentType,
    super.message,
    super.audioUrl,
    super.photoUrl,
    super.caption,
    super.mood,
    required super.createdAt,
    required super.updatedAt,
    required this.receiverId,
    this.senderId,
    required this.isRead,
    required this.isReplied,
    this.matchScore = 0,
    this.matchedAt,
  });

  factory ReceivedBottle.fromJson(Map<String, dynamic> json) {
    return ReceivedBottle(
      id: json['id'] as String,
      contentType: json['content_type'] as String,
      message: json['message'] as String?,
      audioUrl: json['audio_url'] as String?,
      photoUrl: json['photo_url'] as String?,
      caption: json['caption'] as String?,
      mood: json['mood'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      receiverId: json['receiver_id'] as String,
      senderId: json['sender_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      isReplied: json['is_replied'] as bool? ?? false,
      matchScore: json['match_score'] as int? ?? 0,
      matchedAt: json['matched_at'] != null
          ? DateTime.parse(json['matched_at'] as String)
          : null,
    );
  }

  ReceivedBottle copyWith({
    String? id,
    String? contentType,
    String? message,
    String? audioUrl,
    String? photoUrl,
    String? caption,
    String? mood,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? receiverId,
    String? senderId,
    bool? isRead,
    bool? isReplied,
    int? matchScore,
    DateTime? matchedAt,
  }) {
    return ReceivedBottle(
      id: id ?? this.id,
      contentType: contentType ?? this.contentType,
      message: message ?? this.message,
      audioUrl: audioUrl ?? this.audioUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      caption: caption ?? this.caption,
      mood: mood ?? this.mood,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      receiverId: receiverId ?? this.receiverId,
      senderId: senderId ?? this.senderId,
      isRead: isRead ?? this.isRead,
      isReplied: isReplied ?? this.isReplied,
      matchScore: matchScore ?? this.matchScore,
      matchedAt: matchedAt ?? this.matchedAt,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'receiver_id': receiverId,
      'sender_id': senderId,
      'is_read': isRead,
      'is_replied': isReplied,
      'match_score': matchScore,
      'matched_at': matchedAt?.toIso8601String(),
    });
    return json;
  }
}

class SentBottle extends Bottle {
  final String senderId;
  final String? receiverId; // matched_recipient_id
  final bool isDelivered;
  final bool hasReply;
  final int matchScore; // Compatibility score
  final String status; // 'floating', 'matched', 'delivered', 'read'
  final DateTime? deliveredAt;
  final DateTime? readAt;

  SentBottle({
    required super.id,
    required super.contentType,
    super.message,
    super.audioUrl,
    super.photoUrl,
    super.caption,
    super.mood,
    required super.createdAt,
    required super.updatedAt,
    required this.senderId,
    this.receiverId,
    required this.isDelivered,
    required this.hasReply,
    this.matchScore = 0,
    this.status = 'floating',
    this.deliveredAt,
    this.readAt,
  });

  /// Check if bottle is currently floating in the sea
  bool get isFloating => status == 'floating';
  
  /// Check if bottle has been matched with a recipient
  bool get isMatched => status == 'matched' || status == 'delivered' || status == 'read';
  
  /// Check if bottle has been read by recipient
  bool get isRead => status == 'read';

  factory SentBottle.fromJson(Map<String, dynamic> json) {
    return SentBottle(
      id: json['id'] as String,
      contentType: json['content_type'] as String,
      message: json['message'] as String?,
      audioUrl: json['audio_url'] as String?,
      photoUrl: json['photo_url'] as String?,
      caption: json['caption'] as String?,
      mood: json['mood'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      senderId: json['sender_id'] as String,
      receiverId: json['matched_recipient_id'] as String?,
      isDelivered: json['is_delivered'] as bool? ?? false,
      hasReply: json['has_reply'] as bool? ?? false,
      matchScore: json['match_score'] as int? ?? 0,
      status: json['status'] as String? ?? 'floating',
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'sender_id': senderId,
      'matched_recipient_id': receiverId,
      'is_delivered': isDelivered,
      'has_reply': hasReply,
      'match_score': matchScore,
      'status': status,
      'delivered_at': deliveredAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    });
    return json;
  }
}
