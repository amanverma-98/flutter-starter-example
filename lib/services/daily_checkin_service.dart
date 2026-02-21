import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_models.dart';
import '../services/wellness_service.dart';
import '../services/habit_tracking_service.dart';
import '../services/mood_analysis_service.dart';
import '../services/mindfulness_service.dart';

/// Daily check-in response categories
enum CheckInCategory {
  mood,
  energy,
  stress,
  sleep,
  gratitude,
  challenges,
  goals,
  reflection
}

/// A daily wellness check-in entry
class DailyCheckIn {
  final String id;
  final DateTime date;
  final Map<CheckInCategory, dynamic> responses;
  final double completionScore; // 0.0 to 1.0 based on responses
  final DateTime createdAt;
  final String? notes;

  DailyCheckIn({
    required this.id,
    required this.date,
    required this.responses,
    required this.completionScore,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'responses': responses.map((key, value) => MapEntry(key.name, value)),
    'completionScore': completionScore,
    'createdAt': createdAt.toIso8601String(),
    'notes': notes,
  };

  factory DailyCheckIn.fromJson(Map<String, dynamic> json) {
    final responses = <CheckInCategory, dynamic>{};
    if (json['responses'] != null) {
      (json['responses'] as Map<String, dynamic>).forEach((key, value) {
        try {
          responses[CheckInCategory.values.byName(key)] = value;
        } catch (e) {
          // Skip invalid categories
        }
      });
    }
    
    return DailyCheckIn(
      id: json['id'],
      date: DateTime.parse(json['date']),
      responses: responses,
      completionScore: json['completionScore']?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt']),
      notes: json['notes'],
    );
  }
}

/// Personalized wellness insights
class WellnessInsight {
  final String id;
  final DateTime timestamp;
  final String title;
  final String message;
  final String category; // 'pattern', 'achievement', 'suggestion', 'concern'
  final double priority; // 0.0 to 1.0
  final Map<String, dynamic>? data;
  final bool isRead;

  WellnessInsight({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    this.data,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'title': title,
    'message': message,
    'category': category,
    'priority': priority,
    'data': data,
    'isRead': isRead,
  };

  factory WellnessInsight.fromJson(Map<String, dynamic> json) => WellnessInsight(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    title: json['title'],
    message: json['message'],
    category: json['category'],
    priority: json['priority']?.toDouble() ?? 0.5,
    data: json['data'],
    isRead: json['isRead'] ?? false,
  );
}

/// Service for managing daily check-ins and generating wellness insights
class DailyCheckInService extends ChangeNotifier {
  static const String _checkInsFileName = 'daily_checkins.json';
  static const String _insightsFileName = 'wellness_insights.json';

  final WellnessService _wellnessService;
  final HabitTrackingService? _habitService;
  final MoodAnalysisService? _moodService;
  final MindfulnessService? _mindfulnessService;

  List<DailyCheckIn> _checkIns = [];
  List<WellnessInsight> _insights = [];
  DailyCheckIn? _todaysCheckIn;
  bool _isInitialized = false;
  DateTime? _lastInsightGeneration;

  DailyCheckInService({
    required WellnessService wellnessService,
    HabitTrackingService? habitService,
    MoodAnalysisService? moodService,
    MindfulnessService? mindfulnessService,
  }) : _wellnessService = wellnessService,
       _habitService = habitService,
       _moodService = moodService,
       _mindfulnessService = mindfulnessService;

  List<DailyCheckIn> get checkIns => List.unmodifiable(_checkIns);
  List<WellnessInsight> get insights => List.unmodifiable(_insights);
  List<WellnessInsight> get unreadInsights => List.unmodifiable(_insights.where((i) => !i.isRead));
  DailyCheckIn? get todaysCheckIn => _todaysCheckIn;
  bool get isInitialized => _isInitialized;
  bool get hasCheckedInToday => _todaysCheckIn != null;

  /// Initialize the service and generate insights if needed
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadCheckIns();
      await _loadInsights();
      
      _checkForTodaysCheckIn();
      
      // Generate insights if it's been more than 6 hours since last generation
      if (_shouldGenerateInsights()) {
        await _generateDailyInsights();
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing daily check-in service: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Start or update today's check-in
  Future<void> updateCheckIn(CheckInCategory category, dynamic response) async {
    final today = DateTime.now();
    final todayKey = _getDateKey(today);

    if (_todaysCheckIn == null) {
      _todaysCheckIn = DailyCheckIn(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime(today.year, today.month, today.day),
        responses: {category: response},
        completionScore: 0.0,
        createdAt: DateTime.now(),
      );
    } else {
      // Update existing check-in
      _todaysCheckIn!.responses[category] = response;
    }

    // Recalculate completion score
    final completionScore = _calculateCompletionScore(_todaysCheckIn!.responses);
    _todaysCheckIn = DailyCheckIn(
      id: _todaysCheckIn!.id,
      date: _todaysCheckIn!.date,
      responses: _todaysCheckIn!.responses,
      completionScore: completionScore,
      createdAt: _todaysCheckIn!.createdAt,
      notes: _todaysCheckIn!.notes,
    );

    // Save or update in list
    final existingIndex = _checkIns.indexWhere((c) => _getDateKey(c.date) == todayKey);
    if (existingIndex != -1) {
      _checkIns[existingIndex] = _todaysCheckIn!;
    } else {
      _checkIns.add(_todaysCheckIn!);
    }

    await _saveCheckIns();
    notifyListeners();

    // Generate immediate insights if check-in is substantial
    if (completionScore >= 0.5) {
      await _generateCheckInInsights(_todaysCheckIn!);
    }
  }

  /// Complete today's check-in with notes
  Future<void> completeCheckIn({String? notes}) async {
    if (_todaysCheckIn == null) return;

    final updatedCheckIn = DailyCheckIn(
      id: _todaysCheckIn!.id,
      date: _todaysCheckIn!.date,
      responses: _todaysCheckIn!.responses,
      completionScore: _todaysCheckIn!.completionScore,
      createdAt: _todaysCheckIn!.createdAt,
      notes: notes,
    );

    final existingIndex = _checkIns.indexWhere((c) => 
      _getDateKey(c.date) == _getDateKey(_todaysCheckIn!.date));
    if (existingIndex != -1) {
      _checkIns[existingIndex] = updatedCheckIn;
    } else {
      _checkIns.add(updatedCheckIn);
    }

    _todaysCheckIn = updatedCheckIn;
    await _saveCheckIns();
    await _generateCheckInInsights(updatedCheckIn);
    notifyListeners();
  }

  /// Get check-in statistics
  Map<String, dynamic> getCheckInStats({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recentCheckIns = _checkIns.where((c) => c.date.isAfter(cutoff)).toList();

    if (recentCheckIns.isEmpty) {
      return {
        'totalCheckIns': 0,
        'averageCompletion': 0.0,
        'streak': 0,
        'moodTrend': 'neutral',
        'energyTrend': 'neutral',
      };
    }

    final avgCompletion = recentCheckIns
        .map((c) => c.completionScore)
        .reduce((a, b) => a + b) / recentCheckIns.length;

    // Calculate streak
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < days; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final hasCheckIn = recentCheckIns.any((c) => _isSameDay(c.date, checkDate));
      
      if (hasCheckIn) {
        streak++;
      } else {
        break;
      }
    }

    // Analyze trends
    final moodTrend = _analyzeTrend(recentCheckIns, CheckInCategory.mood);
    final energyTrend = _analyzeTrend(recentCheckIns, CheckInCategory.energy);
    final stressTrend = _analyzeTrend(recentCheckIns, CheckInCategory.stress);

    return {
      'totalCheckIns': recentCheckIns.length,
      'averageCompletion': avgCompletion,
      'streak': streak,
      'moodTrend': moodTrend,
      'energyTrend': energyTrend,
      'stressTrend': stressTrend,
      'daysAnalyzed': days,
    };
  }

  /// Get personalized check-in questions based on patterns
  List<String> getPersonalizedQuestions() {
    final stats = getCheckInStats(days: 7);
    final questions = <String>[];

    // Base questions everyone gets
    questions.addAll([
      'How are you feeling emotionally right now?',
      'What\'s your energy level like today (1-10)?',
      'How stressed do you feel (1-10)?',
    ]);

    // Add contextual questions based on patterns
    if (stats['stressTrend'] == 'increasing') {
      questions.add('What\'s been the biggest source of stress lately?');
    }

    if (stats['energyTrend'] == 'decreasing') {
      questions.add('How has your sleep been recently?');
    }

    if (_habitService != null) {
      final habitProgress = _habitService!.getOverallProgress(days: 3);
      if ((habitProgress['completionRate'] as double) < 0.5) {
        questions.add('What\'s making it challenging to keep up with your wellness habits?');
      }
    }

    // Add gratitude and reflection
    questions.addAll([
      'What\'s one thing you\'re grateful for today?',
      'What would make tomorrow feel successful for you?',
    ]);

    return questions;
  }

  /// Generate ARIA-compatible check-in message
  String generateCheckInMessage() {
    if (!hasCheckedInToday) {
      final hour = DateTime.now().hour;
      if (hour < 12) {
        return 'Good morning! I\'d love to do a quick wellness check-in with you. How are you feeling as you start your day?';
      } else if (hour < 17) {
        return 'How has your day been going? I\'d like to check in on your wellbeing - what\'s your energy and mood like right now?';
      } else {
        return 'As your day winds down, how are you feeling? I\'d love to do an evening wellness check-in with you.';
      }
    } else {
      final completion = _todaysCheckIn!.completionScore;
      if (completion >= 0.8) {
        return 'Thanks for being so thoughtful about your wellness check-in today! Your self-awareness really shows in how you\'re tracking your wellbeing.';
      } else {
        return 'I appreciate you starting your wellness check-in today. Would you like to share a bit more about how you\'re feeling?';
      }
    }
  }

  /// Mark insight as read
  Future<void> markInsightAsRead(String insightId) async {
    final index = _insights.indexWhere((i) => i.id == insightId);
    if (index != -1) {
      _insights[index] = WellnessInsight(
        id: _insights[index].id,
        timestamp: _insights[index].timestamp,
        title: _insights[index].title,
        message: _insights[index].message,
        category: _insights[index].category,
        priority: _insights[index].priority,
        data: _insights[index].data,
        isRead: true,
      );
      await _saveInsights();
      notifyListeners();
    }
  }

  /// Private helper methods

  void _checkForTodaysCheckIn() {
    final today = DateTime.now();
    final todayKey = _getDateKey(today);
    
    _todaysCheckIn = _checkIns.where((c) => _getDateKey(c.date) == todayKey).firstOrNull;
  }

  bool _shouldGenerateInsights() {
    if (_lastInsightGeneration == null) return true;
    
    final hoursSinceLastGeneration = DateTime.now()
        .difference(_lastInsightGeneration!)
        .inHours;
    
    return hoursSinceLastGeneration >= 6;
  }

  Future<void> _generateDailyInsights() async {
    _lastInsightGeneration = DateTime.now();
    
    // Analyze patterns from the last 14 days
    final recentCheckIns = _checkIns
        .where((c) => c.date.isAfter(DateTime.now().subtract(const Duration(days: 14))))
        .toList();

    if (recentCheckIns.length < 3) {
      // Not enough data for meaningful insights
      return;
    }

    // Analyze mood patterns
    await _analyzeMoodPatterns(recentCheckIns);
    
    // Analyze energy and stress correlations
    await _analyzeEnergyStressPatterns(recentCheckIns);
    
    // Cross-reference with habits and meditation
    await _analyzeWellnessHolistically();
    
    // Generate achievement insights
    await _generateAchievementInsights();
    
    notifyListeners();
  }

  Future<void> _generateCheckInInsights(DailyCheckIn checkIn) async {
    final responses = checkIn.responses;
    
    // Immediate stress response
    if (responses.containsKey(CheckInCategory.stress) && 
        responses[CheckInCategory.stress] >= 7) {
      await _addInsight(
        'High Stress Detected',
        'I noticed you\'re feeling quite stressed today (${responses[CheckInCategory.stress]}/10). Would you like to try a quick breathing exercise or talk about what\'s causing the stress?',
        'concern',
        0.9,
      );
    }
    
    // Energy patterns
    if (responses.containsKey(CheckInCategory.energy) && 
        responses[CheckInCategory.energy] <= 3) {
      await _addInsight(
        'Low Energy Alert',
        'Your energy seems quite low today. This could be related to sleep, nutrition, or stress. Would you like some gentle suggestions for an energy boost?',
        'suggestion',
        0.7,
      );
    }
    
    // Positive reinforcement
    if (responses.containsKey(CheckInCategory.gratitude)) {
      await _addInsight(
        'Gratitude Practice',
        'I love that you took time to reflect on gratitude: "${responses[CheckInCategory.gratitude]}". This mindful appreciation really contributes to wellbeing.',
        'achievement',
        0.6,
      );
    }
  }

  Future<void> _analyzeMoodPatterns(List<DailyCheckIn> checkIns) async {
    final moodResponses = checkIns
        .where((c) => c.responses.containsKey(CheckInCategory.mood))
        .map((c) => c.responses[CheckInCategory.mood])
        .toList();

    if (moodResponses.length < 5) return;

    // Look for mood consistency
    final recentMoods = moodResponses.take(7).toList();
    final isConsistentlyPositive = recentMoods.every((mood) => 
        mood is String && ['happy', 'energetic', 'calm', 'focused'].contains(mood));
    
    final isConsistentlyNegative = recentMoods.every((mood) => 
        mood is String && ['stressed', 'anxious', 'tired', 'overwhelmed'].contains(mood));

    if (isConsistentlyPositive) {
      await _addInsight(
        'Positive Mood Streak!',
        'You\'ve been maintaining a positive emotional state for the past week! Your consistent wellbeing practices are really paying off.',
        'achievement',
        0.8,
      );
    } else if (isConsistentlyNegative) {
      await _addInsight(
        'Emotional Support Available',
        'I\'ve noticed you\'ve been struggling emotionally lately. You\'re not alone in this. Would you like to explore some coping strategies together?',
        'concern',
        0.9,
      );
    }
  }

  Future<void> _analyzeEnergyStressPatterns(List<DailyCheckIn> checkIns) async {
    final energyData = <double>[];
    final stressData = <double>[];
    
    for (final checkIn in checkIns) {
      if (checkIn.responses.containsKey(CheckInCategory.energy)) {
        final energy = checkIn.responses[CheckInCategory.energy];
        if (energy is num) energyData.add(energy.toDouble());
      }
      
      if (checkIn.responses.containsKey(CheckInCategory.stress)) {
        final stress = checkIn.responses[CheckInCategory.stress];
        if (stress is num) stressData.add(stress.toDouble());
      }
    }

    if (energyData.length >= 5 && stressData.length >= 5) {
      final avgEnergy = energyData.reduce((a, b) => a + b) / energyData.length;
      final avgStress = stressData.reduce((a, b) => a + b) / stressData.length;
      
      // High stress, low energy pattern
      if (avgStress > 6 && avgEnergy < 5) {
        await _addInsight(
          'Energy-Stress Pattern',
          'I\'ve noticed a pattern of high stress (${avgStress.toStringAsFixed(1)}) and low energy (${avgEnergy.toStringAsFixed(1)}). This often indicates burnout. Let\'s work on some recovery strategies.',
          'pattern',
          0.8,
        );
      }
      
      // Improving trend
      if (energyData.length >= 7) {
        final recentEnergy = energyData.take(3).reduce((a, b) => a + b) / 3;
        final olderEnergy = energyData.skip(4).take(3).reduce((a, b) => a + b) / 3;
        
        if (recentEnergy > olderEnergy + 1) {
          await _addInsight(
            'Energy Trending Up!',
            'Great news! Your energy levels have been improving over the past few days. Your wellness efforts are working!',
            'achievement',
            0.7,
          );
        }
      }
    }
  }

  Future<void> _analyzeWellnessHolistically() async {
    if (_habitService == null) return;
    
    final habitStats = _habitService!.getOverallProgress(days: 7);
    final checkInStats = getCheckInStats(days: 7);
    
    final habitCompletion = habitStats['completionRate'] as double;
    final avgCheckInCompletion = checkInStats['averageCompletion'] as double;
    
    // High engagement insight
    if (habitCompletion > 0.8 && avgCheckInCompletion > 0.7) {
      await _addInsight(
        'Wellness Champion!',
        'You\'ve been incredibly consistent with both your wellness habits (${(habitCompletion * 100).round()}%) and daily check-ins. This level of self-care is inspiring!',
        'achievement',
        0.9,
      );
    }
    
    // Meditation correlation
    if (_mindfulnessService != null) {
      final meditationStats = _mindfulnessService!.getMeditationStats(days: 7);
      final meditationSessions = meditationStats['totalSessions'] as int;
      
      if (meditationSessions >= 3 && checkInStats['stressTrend'] == 'decreasing') {
        await _addInsight(
          'Meditation Impact',
          'Your regular meditation practice (${meditationSessions} sessions this week) seems to be helping with stress management. Keep up this wonderful practice!',
          'pattern',
          0.8,
        );
      }
    }
  }

  Future<void> _generateAchievementInsights() async {
    final stats = getCheckInStats(days: 30);
    final streak = stats['streak'] as int;
    
    // Streak achievements
    if (streak == 7) {
      await _addInsight(
        'One Week Streak!',
        'Amazing! You\'ve checked in on your wellbeing for 7 days straight. This consistent self-awareness is building a powerful habit.',
        'achievement',
        0.8,
      );
    } else if (streak == 21) {
      await _addInsight(
        'Three Week Milestone!',
        'Incredible dedication! 21 days of consistent wellness check-ins shows real commitment to your mental health and growth.',
        'achievement',
        0.9,
      );
    } else if (streak == 30) {
      await _addInsight(
        'Monthly Master!',
        'A full month of daily wellness check-ins! You\'ve built an extraordinary habit of self-reflection and awareness. Congratulations!',
        'achievement',
        1.0,
      );
    }
  }

  Future<void> _addInsight(String title, String message, String category, double priority) async {
    // Check for duplicate insights in the last 24 hours
    final recent = _insights.where((i) => 
        DateTime.now().difference(i.timestamp).inHours < 24 &&
        i.title == title).toList();
    
    if (recent.isNotEmpty) return; // Don't duplicate recent insights
    
    final insight = WellnessInsight(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      title: title,
      message: message,
      category: category,
      priority: priority,
    );
    
    _insights.insert(0, insight); // Add to beginning
    
    // Keep only the most recent 50 insights
    if (_insights.length > 50) {
      _insights = _insights.take(50).toList();
    }
    
    await _saveInsights();
  }

  String _analyzeTrend(List<DailyCheckIn> checkIns, CheckInCategory category) {
    final values = checkIns
        .where((c) => c.responses.containsKey(category))
        .map((c) => c.responses[category])
        .where((v) => v is num)
        .map((v) => (v as num).toDouble())
        .toList();

    if (values.length < 3) return 'neutral';

    final recent = values.take(3).toList();
    final older = values.length > 3 ? values.skip(values.length - 3).toList() : recent;

    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;

    final difference = recentAvg - olderAvg;
    
    if (difference > 0.5) return 'increasing';
    if (difference < -0.5) return 'decreasing';
    return 'stable';
  }

  double _calculateCompletionScore(Map<CheckInCategory, dynamic> responses) {
    final totalCategories = CheckInCategory.values.length;
    final completedCategories = responses.keys.length;
    return completedCategories / totalCategories;
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // File operations
  Future<File> _getCheckInsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_checkInsFileName');
  }

  Future<File> _getInsightsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_insightsFileName');
  }

  Future<void> _loadCheckIns() async {
    try {
      final file = await _getCheckInsFile();
      if (!await file.exists()) return;

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);
      _checkIns = jsonList.map((json) => DailyCheckIn.fromJson(json)).toList();
      
      // Sort by date, most recent first
      _checkIns.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      debugPrint('Error loading check-ins: $e');
      _checkIns = [];
    }
  }

  Future<void> _saveCheckIns() async {
    try {
      final file = await _getCheckInsFile();
      final jsonString = json.encode(_checkIns.map((c) => c.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error saving check-ins: $e');
    }
  }

  Future<void> _loadInsights() async {
    try {
      final file = await _getInsightsFile();
      if (!await file.exists()) return;

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);
      _insights = jsonList.map((json) => WellnessInsight.fromJson(json)).toList();
      
      // Sort by priority and timestamp
      _insights.sort((a, b) {
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return b.timestamp.compareTo(a.timestamp);
      });
    } catch (e) {
      debugPrint('Error loading insights: $e');
      _insights = [];
    }
  }

  Future<void> _saveInsights() async {
    try {
      final file = await _getInsightsFile();
      final jsonString = json.encode(_insights.map((i) => i.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error saving insights: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// Extension to handle potential null values
extension ListExtensions<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}