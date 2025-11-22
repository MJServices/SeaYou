class UserProfile {
  String? email;
  String? fullName;
  int? age;
  String? city;
  String? about;
  List<String>? sexualOrientation;
  bool showOrientation;
  String? expectation;
  String? interestedIn;
  List<String>? interests;
  String? avatarUrl;
  String? language;

  UserProfile({
    this.email,
    this.fullName,
    this.age,
    this.city,
    this.about,
    this.sexualOrientation,
    this.showOrientation = false,
    this.expectation,
    this.interestedIn,
    this.interests,
    this.avatarUrl,
    this.language,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'full_name': fullName,
      'age': age,
      'city': city,
      'about': about,
      'sexual_orientation': sexualOrientation,
      'show_orientation': showOrientation,
      'expectation': expectation,
      'interested_in': interestedIn,
      'interests': interests,
      'avatar_url': avatarUrl,
      'language': language,
    };
  }
}
