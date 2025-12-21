
/// User block model - represents a user blocking another user
class UserBlock {
  final String id;
  final String blockerId;
  final String blockedId;
  final DateTime createdAt;

  UserBlock({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    required this.createdAt,
  });

  factory UserBlock.fromJson(Map<String, dynamic> json) {
    return UserBlock(
      id: json['id'] as String,
      blockerId: json['blocker_id'] as String,
      blockedId: json['blocked_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'blocker_id': blockerId,
      'blocked_id': blockedId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// User preferences model - stores user's bottle receiving preferences
class UserPreferences {
  final String id;
  final String userId;
  final String acceptFromGender; // 'men', 'women', 'everyone'
  final int acceptFromAgeMin;
  final int acceptFromAgeMax;
  final int maxBottlesPerDay;
  final bool notifyOnBottleReceived;
  final bool notifyOnBottleRead;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserPreferences({
    required this.id,
    required this.userId,
    this.acceptFromGender = 'everyone',
    this.acceptFromAgeMin = 18,
    this.acceptFromAgeMax = 100,
    this.maxBottlesPerDay = 5,
    this.notifyOnBottleReceived = true,
    this.notifyOnBottleRead = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      acceptFromGender: json['accept_from_gender'] as String? ?? 'everyone',
      acceptFromAgeMin: json['accept_from_age_min'] as int? ?? 18,
      acceptFromAgeMax: json['accept_from_age_max'] as int? ?? 100,
      maxBottlesPerDay: json['max_bottles_per_day'] as int? ?? 5,
      notifyOnBottleReceived: json['notify_on_bottle_received'] as bool? ?? true,
      notifyOnBottleRead: json['notify_on_bottle_read'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'accept_from_gender': acceptFromGender,
      'accept_from_age_min': acceptFromAgeMin,
      'accept_from_age_max': acceptFromAgeMax,
      'max_bottles_per_day': maxBottlesPerDay,
      'notify_on_bottle_received': notifyOnBottleReceived,
      'notify_on_bottle_read': notifyOnBottleRead,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserPreferences copyWith({
    String? id,
    String? userId,
    String? acceptFromGender,
    int? acceptFromAgeMin,
    int? acceptFromAgeMax,
    int? maxBottlesPerDay,
    bool? notifyOnBottleReceived,
    bool? notifyOnBottleRead,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      acceptFromGender: acceptFromGender ?? this.acceptFromGender,
      acceptFromAgeMin: acceptFromAgeMin ?? this.acceptFromAgeMin,
      acceptFromAgeMax: acceptFromAgeMax ?? this.acceptFromAgeMax,
      maxBottlesPerDay: maxBottlesPerDay ?? this.maxBottlesPerDay,
      notifyOnBottleReceived: notifyOnBottleReceived ?? this.notifyOnBottleReceived,
      notifyOnBottleRead: notifyOnBottleRead ?? this.notifyOnBottleRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Bottle delivery queue model - tracks bottles waiting to be delivered
class BottleDeliveryQueue {
  final String id;
  final String sentBottleId;
  final String senderId;
  final String recipientId;
  final DateTime scheduledDeliveryAt;
  final bool delivered;
  final DateTime? deliveredAt;
  final DateTime createdAt;

  BottleDeliveryQueue({
    required this.id,
    required this.sentBottleId,
    required this.senderId,
    required this.recipientId,
    required this.scheduledDeliveryAt,
    this.delivered = false,
    this.deliveredAt,
    required this.createdAt,
  });

  factory BottleDeliveryQueue.fromJson(Map<String, dynamic> json) {
    return BottleDeliveryQueue(
      id: json['id'] as String,
      sentBottleId: json['sent_bottle_id'] as String,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String,
      scheduledDeliveryAt: DateTime.parse(json['scheduled_delivery_at'] as String),
      delivered: json['delivered'] as bool? ?? false,
      deliveredAt: json['delivered_at'] != null 
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sent_bottle_id': sentBottleId,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'scheduled_delivery_at': scheduledDeliveryAt.toIso8601String(),
      'delivered': delivered,
      'delivered_at': deliveredAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if bottle is ready to be delivered
  bool get isReadyForDelivery {
    return !delivered && DateTime.now().isAfter(scheduledDeliveryAt);
  }
}
