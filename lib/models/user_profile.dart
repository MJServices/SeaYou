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
  String? secretDesire;
  String? secretAudioUrl;
  bool isPremium;
  
  // Usage tracking
  int bottlesSentToday;
  DateTime? lastBottleSentDate;
  int messagesSentWeek;
  DateTime? lastMessageSentWeekStart;

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
    this.secretDesire,
    this.secretAudioUrl,
    this.isPremium = false,
    this.bottlesSentToday = 0,
    this.lastBottleSentDate,
    this.messagesSentWeek = 0,
    this.lastMessageSentWeekStart,
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
      'secret_desire': secretDesire,
      'secret_audio_url': secretAudioUrl,
      'is_premium': isPremium,
      'bottles_sent_today': bottlesSentToday,
      'last_bottle_sent_date': lastBottleSentDate?.toIso8601String(),
      'messages_sent_week': messagesSentWeek,
      'last_message_sent_week_start': lastMessageSentWeekStart?.toIso8601String(),
    };
  }
}
