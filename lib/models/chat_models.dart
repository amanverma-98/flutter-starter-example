/// Common interface for chat messages across different views
abstract class BaseChatMessage {
  String get text;
  bool get isUser;
  DateTime get timestamp;
  double? get tokensPerSecond;
  int? get totalTokens;
  bool get isError;
  bool get wasCancelled;
}

/// Standard chat message implementation
class ChatMessage implements BaseChatMessage {
  @override
  final String text;
  @override
  final bool isUser;
  @override
  final DateTime timestamp;
  @override
  final double? tokensPerSecond;
  @override
  final int? totalTokens;
  @override
  final bool isError;
  @override
  final bool wasCancelled;
  
  // Additional properties for ARIA
  final bool isAriaMessage;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.tokensPerSecond,
    this.totalTokens,
    this.isError = false,
    this.wasCancelled = false,
    this.isAriaMessage = false,
  });
}

/// Mood types for wellness tracking
enum MoodType {
  energetic,
  calm,
  stressed,
  tired,
  happy,
  anxious,
  focused,
  overwhelmed
}

/// Wellness activities
enum WellnessActivity {
  meditation,
  exercise,
  sleep,
  nutrition,
  socializing,
  work,
  relaxation,
  learning
}