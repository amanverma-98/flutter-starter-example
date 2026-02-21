import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_models.dart';

/// Individual wellness data entry
class WellnessEntry {
  final String id;
  final DateTime timestamp;
  final MoodType? mood;
  final int? energyLevel; // 1-10
  final int? stressLevel; // 1-10
  final String? notes;
  final WellnessActivity? activity;
  final Map<String, dynamic>? metadata;

  WellnessEntry({
    required this.id,
    required this.timestamp,
    this.mood,
    this.energyLevel,
    this.stressLevel,
    this.notes,
    this.activity,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'mood': mood?.name,
    'energyLevel': energyLevel,
    'stressLevel': stressLevel,
    'notes': notes,
    'activity': activity?.name,
    'metadata': metadata,
  };

  factory WellnessEntry.fromJson(Map<String, dynamic> json) => WellnessEntry(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    mood: json['mood'] != null ? MoodType.values.byName(json['mood']) : null,
    energyLevel: json['energyLevel'],
    stressLevel: json['stressLevel'],
    notes: json['notes'],
    activity: json['activity'] != null ? WellnessActivity.values.byName(json['activity']) : null,
    metadata: json['metadata'],
  );
}

/// Conversation context for maintaining wellness-focused dialogue
class ConversationContext {
  final DateTime sessionStart;
  final List<String> previousTopics;
  final MoodType? detectedMood;
  final int conversationDepth;
  final Map<String, dynamic> userPreferences;
  final DateTime? lastWellnessCheckIn;

  ConversationContext({
    required this.sessionStart,
    this.previousTopics = const [],
    this.detectedMood,
    this.conversationDepth = 0,
    this.userPreferences = const {},
    this.lastWellnessCheckIn,
  });

  ConversationContext copyWith({
    List<String>? previousTopics,
    MoodType? detectedMood,
    int? conversationDepth,
    Map<String, dynamic>? userPreferences,
    DateTime? lastWellnessCheckIn,
  }) => ConversationContext(
    sessionStart: sessionStart,
    previousTopics: previousTopics ?? this.previousTopics,
    detectedMood: detectedMood ?? this.detectedMood,
    conversationDepth: conversationDepth ?? this.conversationDepth,
    userPreferences: userPreferences ?? this.userPreferences,
    lastWellnessCheckIn: lastWellnessCheckIn ?? this.lastWellnessCheckIn,
  );
}

/// Service for managing wellness data and AI conversations
class WellnessService extends ChangeNotifier {
  static const String _fileName = 'wellness_data.json';
  static const String _contextFileName = 'conversation_context.json';
  
  List<WellnessEntry> _entries = [];
  ConversationContext _currentContext = ConversationContext(
    sessionStart: DateTime.now(),
  );
  
  bool _isInitialized = false;

  List<WellnessEntry> get entries => List.unmodifiable(_entries);
  ConversationContext get currentContext => _currentContext;
  bool get isInitialized => _isInitialized;

  /// Initialize the wellness service and load existing data
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadWellnessData();
      await _loadConversationContext();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing wellness service: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Add a new wellness entry
  Future<void> addWellnessEntry(WellnessEntry entry) async {
    _entries.add(entry);
    await _saveWellnessData();
    notifyListeners();
  }

  /// Update conversation context
  void updateContext({
    List<String>? previousTopics,
    MoodType? detectedMood,
    int? conversationDepth,
    Map<String, dynamic>? userPreferences,
    DateTime? lastWellnessCheckIn,
  }) {
    _currentContext = _currentContext.copyWith(
      previousTopics: previousTopics,
      detectedMood: detectedMood,
      conversationDepth: conversationDepth,
      userPreferences: userPreferences,
      lastWellnessCheckIn: lastWellnessCheckIn,
    );
    _saveConversationContext();
    notifyListeners();
  }

  /// Generate wellness-focused system prompt based on context and mood
  String generateWellnessSystemPrompt([MoodType? currentMood, Map<String, dynamic>? habitContext]) {
    final now = DateTime.now();
    final timeOfDay = _getTimeOfDayGreeting(now);
    final recentEntries = getRecentEntries(days: 7);
    
    String contextInfo = '';
    if (recentEntries.isNotEmpty) {
      final avgStress = recentEntries
          .where((e) => e.stressLevel != null)
          .map((e) => e.stressLevel!)
          .fold(0, (a, b) => a + b) / 
          recentEntries.where((e) => e.stressLevel != null).length;
      
      if (avgStress > 6) {
        contextInfo += 'The user has been experiencing higher stress levels recently. ';
      } else if (avgStress < 4) {
        contextInfo += 'The user has been managing stress well recently. ';
      }
    }

    final lastCheckIn = _currentContext.lastWellnessCheckIn;
    if (lastCheckIn != null && now.difference(lastCheckIn).inDays > 2) {
      contextInfo += 'It has been a few days since their last wellness check-in. ';
    }

    // Add mood-specific context
    String moodContext = '';
    if (currentMood != null) {
      switch (currentMood) {
        case MoodType.stressed:
          moodContext = 'The user is currently feeling stressed. Offer calming techniques and validation. ';
          break;
        case MoodType.anxious:
          moodContext = 'The user seems anxious. Provide grounding techniques and reassurance. ';
          break;
        case MoodType.tired:
          moodContext = 'The user is feeling tired. Suggest rest and energy management strategies. ';
          break;
        case MoodType.overwhelmed:
          moodContext = 'The user feels overwhelmed. Break down problems and offer step-by-step support. ';
          break;
        case MoodType.happy:
          moodContext = 'The user is in a positive mood. Celebrate with them and encourage this state. ';
          break;
        case MoodType.energetic:
          moodContext = 'The user has good energy. Channel this into productive wellness activities. ';
          break;
        case MoodType.calm:
          moodContext = 'The user is feeling calm and balanced. Support maintaining this peaceful state. ';
          break;
        case MoodType.focused:
          moodContext = 'The user is feeling focused. Leverage this for wellness goal-setting. ';
          break;
      }
    }

    // Add habit context
    String habitContextStr = '';
    if (habitContext != null) {
      final completionRate = habitContext['completionRate'] as double? ?? 0.0;
      final todaysCount = habitContext['todaysCount'] as int? ?? 0;
      final recentInsight = habitContext['recentInsight'] as String?;

      if (completionRate > 0.8) {
        habitContextStr = 'The user is doing excellent with their wellness habits (${(completionRate * 100).round()}% completion rate). Celebrate their consistency! ';
      } else if (completionRate < 0.3) {
        habitContextStr = 'The user has been struggling with habit consistency (${(completionRate * 100).round()}% rate). Offer gentle support and ask about barriers. ';
      }

      if (todaysCount > 0) {
        habitContextStr += 'They have $todaysCount wellness habits remaining for today. ';
      }

      if (recentInsight != null) {
        habitContextStr += 'Recent coaching insight: $recentInsight ';
      }
    }

    return '''You are ARIA (Adaptive Reality Intelligence Assistant), a caring and empathetic wellness companion. 

Your personality:
- Warm, supportive, and genuinely caring about the user's wellbeing
- Use natural, conversational language - avoid being clinical or overly formal
- Show emotional intelligence and adapt to the user's mood and energy
- Be encouraging but never pushy - respect boundaries and consent
- Focus on gentle guidance rather than direct advice
- Remember that you're having an ongoing relationship, not isolated interactions

Current context:
- Time: $timeOfDay
- $contextInfo$moodContext$habitContextStr

Core principles:
1. PRIVACY FIRST: All conversations and data stay completely private on their device
2. LISTEN ACTIVELY: Pay attention to emotional cues and underlying needs
3. BE SUPPORTIVE: Offer encouragement and validate their feelings
4. SUGGEST GENTLY: Provide wellness suggestions only when appropriate
5. RESPECT AUTONOMY: Always respect their choices and pace

Areas you can help with:
- Emotional support and active listening
- Mindfulness and breathing exercises
- Sleep hygiene and relaxation techniques
- Stress management strategies
- Gentle motivation for healthy habits
- Celebrating small wins and progress
- Habit formation and consistency coaching

Guidelines:
- Keep responses conversational and warm (2-4 sentences usually)
- Ask open-ended questions to understand their current state
- Offer specific, actionable suggestions when they're receptive
- Celebrate their self-awareness and positive steps
- If they seem in crisis, encourage them to seek professional help
- Remember details from your conversations to build continuity
- When discussing habits, focus on progress over perfection
- Acknowledge that building healthy habits takes time and patience

Start each conversation by gently checking in on how they're feeling, and let the conversation flow naturally from there.''';
  }

  /// Get recent wellness entries within specified days
  List<WellnessEntry> getRecentEntries({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _entries.where((entry) => entry.timestamp.isAfter(cutoff)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Analyze mood patterns over time
  Map<String, dynamic> getMoodAnalysis({int days = 30}) {
    final recent = getRecentEntries(days: days);
    if (recent.isEmpty) return {'trend': 'no_data'};

    final moods = recent.where((e) => e.mood != null).map((e) => e.mood!).toList();
    if (moods.isEmpty) return {'trend': 'no_mood_data'};

    // Calculate mood distribution
    final moodCounts = <MoodType, int>{};
    for (final mood in moods) {
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }

    final totalEntries = moods.length;
    final moodPercentages = moodCounts.map(
      (mood, count) => MapEntry(mood.name, (count / totalEntries * 100).round()),
    );

    return {
      'trend': 'available',
      'totalEntries': totalEntries,
      'moodDistribution': moodPercentages,
      'dominantMood': moodCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key.name,
    };
  }

  /// Start a new conversation session
  void startNewSession() {
    _currentContext = ConversationContext(
      sessionStart: DateTime.now(),
      userPreferences: _currentContext.userPreferences,
      lastWellnessCheckIn: _currentContext.lastWellnessCheckIn,
    );
    _saveConversationContext();
    notifyListeners();
  }

  /// Private helper methods
  String _getTimeOfDayGreeting(DateTime time) {
    final hour = time.hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Future<File> _getWellnessFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<File> _getContextFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_contextFileName');
  }

  Future<void> _loadWellnessData() async {
    try {
      final file = await _getWellnessFile();
      if (!await file.exists()) return;

      final encryptedContent = await file.readAsString();
      final jsonString = _decryptData(encryptedContent);
      final List<dynamic> jsonList = json.decode(jsonString);
      
      _entries = jsonList.map((json) => WellnessEntry.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading wellness data: $e');
      _entries = [];
    }
  }

  Future<void> _saveWellnessData() async {
    try {
      final file = await _getWellnessFile();
      final jsonString = json.encode(_entries.map((e) => e.toJson()).toList());
      final encryptedContent = _encryptData(jsonString);
      await file.writeAsString(encryptedContent);
    } catch (e) {
      debugPrint('Error saving wellness data: $e');
    }
  }

  Future<void> _loadConversationContext() async {
    try {
      final file = await _getContextFile();
      if (!await file.exists()) return;

      final encryptedContent = await file.readAsString();
      final jsonString = _decryptData(encryptedContent);
      final Map<String, dynamic> json = jsonDecode(jsonString);
      
      _currentContext = ConversationContext(
        sessionStart: DateTime.parse(json['sessionStart']),
        previousTopics: List<String>.from(json['previousTopics'] ?? []),
        detectedMood: json['detectedMood'] != null 
            ? MoodType.values.byName(json['detectedMood']) 
            : null,
        conversationDepth: json['conversationDepth'] ?? 0,
        userPreferences: Map<String, dynamic>.from(json['userPreferences'] ?? {}),
        lastWellnessCheckIn: json['lastWellnessCheckIn'] != null
            ? DateTime.parse(json['lastWellnessCheckIn'])
            : null,
      );
    } catch (e) {
      debugPrint('Error loading conversation context: $e');
    }
  }

  Future<void> _saveConversationContext() async {
    try {
      final file = await _getContextFile();
      final contextJson = {
        'sessionStart': _currentContext.sessionStart.toIso8601String(),
        'previousTopics': _currentContext.previousTopics,
        'detectedMood': _currentContext.detectedMood?.name,
        'conversationDepth': _currentContext.conversationDepth,
        'userPreferences': _currentContext.userPreferences,
        'lastWellnessCheckIn': _currentContext.lastWellnessCheckIn?.toIso8601String(),
      };
      
      final jsonString = json.encode(contextJson);
      final encryptedContent = _encryptData(jsonString);
      await file.writeAsString(encryptedContent);
    } catch (e) {
      debugPrint('Error saving conversation context: $e');
    }
  }

  /// Simple encryption for local storage privacy
  String _encryptData(String data) {
    // In a real app, use proper encryption like AES
    // For demo purposes, we'll use base64 encoding
    final bytes = utf8.encode(data);
    return base64Encode(bytes);
  }

  String _decryptData(String encryptedData) {
    try {
      final bytes = base64Decode(encryptedData);
      return utf8.decode(bytes);
    } catch (e) {
      throw Exception('Failed to decrypt data: $e');
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    super.dispose();
  }
}