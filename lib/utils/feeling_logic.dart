class FeelingComputer {
  int exchanges = 0;
  String? lastSender;
  bool exchangeOpen = false;

  int apply(String sender) {
    if (lastSender == null) {
      lastSender = sender;
      exchangeOpen = true;
    } else if (lastSender != sender && exchangeOpen) {
      exchanges += 1;
      exchangeOpen = false;
      lastSender = sender;
    } else {
      exchangeOpen = true;
      lastSender = sender;
    }
    return (exchanges * 10).clamp(0, 100);
  }
}
