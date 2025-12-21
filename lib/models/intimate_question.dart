class IntimateQuestion {
  final String id;
  final String conversationId;
  final String userId;
  final String? question1;
  final String? question2;
  final String? question3;
  final DateTime createdAt;
  final DateTime updatedAt;

  IntimateQuestion({
    required this.id,
    required this.conversationId,
    required this.userId,
    this.question1,
    this.question2,
    this.question3,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IntimateQuestion.fromJson(Map<String, dynamic> json) {
    return IntimateQuestion(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String,
      question1: json['question_1'] as String?,
      question2: json['question_2'] as String?,
      question3: json['question_3'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'user_id': userId,
      'question_1': question1,
      'question_2': question2,
      'question_3': question3,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
