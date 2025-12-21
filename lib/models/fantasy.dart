class Fantasy {
  final String id;
  final String userId;
  final String text;
  final bool isActive;
  final DateTime createdAt;

  Fantasy({
    required this.id,
    required this.userId,
    required this.text,
    required this.isActive,
    required this.createdAt,
  });

  factory Fantasy.fromJson(Map<String, dynamic> json) {
    return Fantasy(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      text: json['text'] as String,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

