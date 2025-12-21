class ProfilePhoto {
  final String id;
  final String userId;
  final String url;
  final bool isFace;
  final bool showInSecretSouls;

  ProfilePhoto({
    required this.id,
    required this.userId,
    required this.url,
    required this.isFace,
    required this.showInSecretSouls,
  });

  factory ProfilePhoto.fromJson(Map<String, dynamic> json) {
    return ProfilePhoto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      url: json['url'] as String,
      isFace: (json['is_face'] as bool?) ?? false,
      showInSecretSouls: (json['show_in_secret_souls'] as bool?) ?? false,
    );
  }
}

