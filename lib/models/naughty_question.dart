class NaughtyQuestion {
  final int id;
  final String questionText;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;

  NaughtyQuestion({
    required this.id,
    required this.questionText,
    required this.displayOrder,
    this.isActive = true,
    required this.createdAt,
  });

  factory NaughtyQuestion.fromJson(Map<String, dynamic> json) {
    return NaughtyQuestion(
      id: json['id'] as int,
      questionText: json['question_text'] as String,
      displayOrder: json['display_order'] as int,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_text': questionText,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
