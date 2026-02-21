import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Types of wellness habits that can be tracked
enum HabitType {
  exercise,
  meditation,
  sleep,
  hydration,
  nutrition,
  socializing,
  learning,
  creativity,
  outdoors,
  gratitude,
  breathingExercise,
  stretching,
  reading,
  journaling,
  selfCare
}

/// Frequency patterns for habits
enum HabitFrequency {
  daily,
  weekdays,
  weekends,
  weekly,
  biweekly,
  custom
}

/// Difficulty levels for habits
enum HabitDifficulty {
  easy,      // 1-2 minutes, very simple
  moderate,  // 5-15 minutes, some effort
  challenging // 20+ minutes, significant commitment
}

/// A specific habit instance/completion
class HabitCompletion {
  final String id;
  final String habitId;
  final DateTime completedAt;
  final String? notes;
  final int? rating; // 1-5 how it felt
  final Map<String, dynamic>? metadata;

  HabitCompletion({
    required this.id,
    required this.habitId,
    required this.completedAt,
    this.notes,
    this.rating,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'habitId': habitId,
    'completedAt': completedAt.toIso8601String(),
    'notes': notes,
    'rating': rating,
    'metadata': metadata,
  };

  factory HabitCompletion.fromJson(Map<String, dynamic> json) => HabitCompletion(
    id: json['id'],
    habitId: json['habitId'],
    completedAt: DateTime.parse(json['completedAt']),
    notes: json['notes'],
    rating: json['rating'],
    metadata: json['metadata'],
  );
}

/// A wellness habit definition
class WellnessHabit {
  final String id;
  final String name;
  final String description;
  final HabitType type;
  final HabitFrequency frequency;
  final HabitDifficulty difficulty;
  final int targetDuration; // minutes
  final DateTime createdAt;
  final DateTime? archivedAt;
  final bool isActive;
  final String? customFrequency; // for custom frequency patterns
  final Map<String, dynamic>? settings;

  WellnessHabit({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.frequency,
    required this.difficulty,
    required this.targetDuration,
    required this.createdAt,
    this.archivedAt,
    this.isActive = true,
    this.customFrequency,
    this.settings,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.name,
    'frequency': frequency.name,
    'difficulty': difficulty.name,
    'targetDuration': targetDuration,
    'createdAt': createdAt.toIso8601String(),
    'archivedAt': archivedAt?.toIso8601String(),
    'isActive': isActive,
    'customFrequency': customFrequency,
    'settings': settings,
  };

  factory WellnessHabit.fromJson(Map<String, dynamic> json) => WellnessHabit(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    type: HabitType.values.byName(json['type']),
    frequency: HabitFrequency.values.byName(json['frequency']),
    difficulty: HabitDifficulty.values.byName(json['difficulty']),
    targetDuration: json['targetDuration'],
    createdAt: DateTime.parse(json['createdAt']),
    archivedAt: json['archivedAt'] != null ? DateTime.parse(json['archivedAt']) : null,
    isActive: json['isActive'] ?? true,
    customFrequency: json['customFrequency'],
    settings: json['settings'],
  );
}

/// Coaching insight based on habit patterns
class CoachingInsight {
  final String id;
  final DateTime timestamp;
  final String title;
  final String message;
  final String type; // 'encouragement', 'suggestion', 'celebration', 'concern'
  final String? habitId; // Related to specific habit
  final bool isRead;
  final Map<String, dynamic>? data;

  CoachingInsight({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.message,
    required this.type,
    this.habitId,
    this.isRead = false,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'title': title,
    'message': message,
    'type': type,
    'habitId': habitId,
    'isRead': isRead,
    'data': data,
  };

  factory CoachingInsight.fromJson(Map<String, dynamic> json) => CoachingInsight(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    title: json['title'],
    message: json['message'],
    type: json['type'],
    habitId: json['habitId'],
    isRead: json['isRead'] ?? false,
    data: json['data'],
  );
}

/// Service for tracking habits and providing coaching insights
class HabitTrackingService extends ChangeNotifier {
  static const String _habitsFileName = 'wellness_habits.json';
  static const String _completionsFileName = 'habit_completions.json';
  static const String _insightsFileName = 'coaching_insights.json';

  List<WellnessHabit> _habits = [];
  List<HabitCompletion> _completions = [];
  List<CoachingInsight> _insights = [];
  
  bool _isInitialized = false;

  List<WellnessHabit> get habits => List.unmodifiable(_habits.where((h) => h.isActive));
  List<WellnessHabit> get allHabits => List.unmodifiable(_habits);
  List<HabitCompletion> get completions => List.unmodifiable(_completions);
  List<CoachingInsight> get insights => List.unmodifiable(_insights);
  List<CoachingInsight> get unreadInsights => List.unmodifiable(_insights.where((i) => !i.isRead));
  bool get isInitialized => _isInitialized;

  /// Initialize the habit tracking service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadHabits();
      await _loadCompletions();
      await _loadInsights();
      
      // Create default habits if none exist
      if (_habits.isEmpty) {
        await _createDefaultHabits();
      }
      
      // Generate coaching insights based on recent patterns
      await _generateCoachingInsights();
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing habit tracking service: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Add a new habit
  Future<WellnessHabit> createHabit({
    required String name,
    required String description,
    required HabitType type,
    required HabitFrequency frequency,
    required HabitDifficulty difficulty,
    required int targetDuration,
    String? customFrequency,
    Map<String, dynamic>? settings,
  }) async {
    final habit = WellnessHabit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      type: type,
      frequency: frequency,
      difficulty: difficulty,
      targetDuration: targetDuration,
      createdAt: DateTime.now(),
      customFrequency: customFrequency,
      settings: settings,
    );

    _habits.add(habit);
    await _saveHabits();
    
    // Generate welcome coaching insight
    await _generateHabitCreationInsight(habit);
    
    notifyListeners();
    return habit;
  }

  /// Complete a habit
  Future<HabitCompletion> completeHabit({
    required String habitId,
    String? notes,
    int? rating,
    Map<String, dynamic>? metadata,
  }) async {
    final completion = HabitCompletion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      habitId: habitId,
      completedAt: DateTime.now(),
      notes: notes,
      rating: rating,
      metadata: metadata,
    );

    _completions.add(completion);
    await _saveCompletions();
    
    // Check for streak achievements and generate insights
    await _checkForStreakAchievements(habitId);
    await _generateCompletionInsight(habitId, completion);
    
    notifyListeners();
    return completion;
  }

  /// Get habit statistics
  Map<String, dynamic> getHabitStats(String habitId, {int days = 30}) {
    final habit = _habits.firstWhere((h) => h.id == habitId);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recentCompletions = _completions
        .where((c) => c.habitId == habitId && c.completedAt.isAfter(cutoff))
        .toList();

    // Calculate streak
    int currentStreak = 0;
    final today = DateTime.now();
    for (int i = 0; i < days; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final hasCompletion = recentCompletions.any((c) => 
        _isSameDay(c.completedAt, checkDate));
      
      if (hasCompletion) {
        currentStreak++;
      } else {
        break;
      }
    }

    // Calculate completion rate
    final expectedCompletions = _calculateExpectedCompletions(habit, days);
    final actualCompletions = recentCompletions.length;
    final completionRate = expectedCompletions > 0 
        ? (actualCompletions / expectedCompletions).clamp(0.0, 1.0)
        : 0.0;

    // Calculate average rating
    final ratingsWithRating = recentCompletions.where((c) => c.rating != null);
    final averageRating = ratingsWithRating.isNotEmpty
        ? ratingsWithRating.map((c) => c.rating!).reduce((a, b) => a + b) / ratingsWithRating.length
        : null;

    return {
      'habitId': habitId,
      'habitName': habit.name,
      'currentStreak': currentStreak,
      'completionRate': completionRate,
      'totalCompletions': actualCompletions,
      'expectedCompletions': expectedCompletions,
      'averageRating': averageRating,
      'lastCompleted': recentCompletions.isNotEmpty 
          ? recentCompletions.map((c) => c.completedAt).reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    };
  }

  /// Get overall wellness progress
  Map<String, dynamic> getOverallProgress({int days = 7}) {
    if (_habits.isEmpty) {
      return {'totalHabits': 0, 'completionRate': 0.0};
    }

    final activeHabits = _habits.where((h) => h.isActive).toList();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    
    int totalExpected = 0;
    int totalCompleted = 0;
    
    for (final habit in activeHabits) {
      final expected = _calculateExpectedCompletions(habit, days);
      final completed = _completions
          .where((c) => c.habitId == habit.id && c.completedAt.isAfter(cutoff))
          .length;
      
      totalExpected += expected;
      totalCompleted += completed;
    }

    final overallRate = totalExpected > 0 ? totalCompleted / totalExpected : 0.0;

    // Find habit types being worked on
    final habitTypes = activeHabits.map((h) => h.type.name).toSet().toList();

    return {
      'totalHabits': activeHabits.length,
      'completionRate': overallRate,
      'totalCompleted': totalCompleted,
      'totalExpected': totalExpected,
      'habitTypes': habitTypes,
      'daysAnalyzed': days,
    };
  }

  /// Get today's habits that need attention
  List<WellnessHabit> getTodaysHabits() {
    final today = DateTime.now();
    return _habits.where((habit) {
      if (!habit.isActive) return false;
      
      // Check if already completed today
      final completedToday = _completions.any((c) => 
        c.habitId == habit.id && _isSameDay(c.completedAt, today));
      
      if (completedToday) return false;
      
      // Check if habit should be done today based on frequency
      return _shouldDoHabitToday(habit, today);
    }).toList();
  }

  /// Mark insight as read
  Future<void> markInsightAsRead(String insightId) async {
    final insightIndex = _insights.indexWhere((i) => i.id == insightId);
    if (insightIndex != -1) {
      _insights[insightIndex] = CoachingInsight(
        id: _insights[insightIndex].id,
        timestamp: _insights[insightIndex].timestamp,
        title: _insights[insightIndex].title,
        message: _insights[insightIndex].message,
        type: _insights[insightIndex].type,
        habitId: _insights[insightIndex].habitId,
        isRead: true,
        data: _insights[insightIndex].data,
      );
      await _saveInsights();
      notifyListeners();
    }
  }

  /// Generate coaching message for ARIA based on current state
  String generateCoachingMessage() {
    final todaysHabits = getTodaysHabits();
    final overallProgress = getOverallProgress(days: 7);
    final unread = unreadInsights;

    if (unread.isNotEmpty) {
      final insight = unread.first;
      return insight.message;
    }

    if (todaysHabits.isNotEmpty) {
      final habit = todaysHabits.first;
      return 'I noticed you haven\'t done your ${habit.name} today yet. Would you like some gentle encouragement or shall we adjust the timing?';
    }

    final completionRate = overallProgress['completionRate'] as double;
    if (completionRate > 0.8) {
      return 'You\'re doing amazingly well with your wellness habits! Your consistency rate is ${(completionRate * 100).round()}%. How are you feeling about your progress?';
    } else if (completionRate < 0.3) {
      return 'I\'ve noticed your wellness routine has been a bit inconsistent lately. That\'s totally normal! Would you like to talk about what\'s been challenging or maybe adjust your goals?';
    }

    return 'How are your wellness habits going? I\'m here to support you in whatever way feels right for you.';
  }

  /// Private helper methods

  Future<void> _createDefaultHabits() async {
    final defaultHabits = [
      {
        'name': 'Morning Mindfulness',
        'description': '5 minutes of breathing or meditation to start the day',
        'type': HabitType.meditation,
        'frequency': HabitFrequency.daily,
        'difficulty': HabitDifficulty.easy,
        'duration': 5,
      },
      {
        'name': 'Gratitude Practice',
        'description': 'Think of 3 things you\'re grateful for',
        'type': HabitType.gratitude,
        'frequency': HabitFrequency.daily,
        'difficulty': HabitDifficulty.easy,
        'duration': 2,
      },
      {
        'name': 'Movement Break',
        'description': 'Stretch, walk, or do light exercise',
        'type': HabitType.exercise,
        'frequency': HabitFrequency.daily,
        'difficulty': HabitDifficulty.moderate,
        'duration': 15,
      },
    ];

    for (final habitData in defaultHabits) {
      await createHabit(
        name: habitData['name'] as String,
        description: habitData['description'] as String,
        type: habitData['type'] as HabitType,
        frequency: habitData['frequency'] as HabitFrequency,
        difficulty: habitData['difficulty'] as HabitDifficulty,
        targetDuration: habitData['duration'] as int,
      );
    }
  }

  Future<void> _generateCoachingInsights() async {
    // Generate insights based on patterns - run this periodically
    final now = DateTime.now();
    
    // Don't generate insights more than once per day
    final todayInsights = _insights.where((i) => _isSameDay(i.timestamp, now)).toList();
    if (todayInsights.isNotEmpty) return;

    final progress = getOverallProgress(days: 7);
    final completionRate = progress['completionRate'] as double;

    if (completionRate > 0.9) {
      await _addInsight(
        'Amazing Consistency!',
        'You\'re absolutely crushing your wellness goals with ${(completionRate * 100).round()}% completion rate this week! Your dedication is inspiring.',
        'celebration',
      );
    } else if (completionRate < 0.3) {
      await _addInsight(
        'Gentle Reminder',
        'Life gets busy, and that\'s okay! Your wellness habits are here to support you, not stress you out. What feels manageable for you right now?',
        'encouragement',
      );
    }
  }

  Future<void> _generateHabitCreationInsight(WellnessHabit habit) async {
    await _addInsight(
      'New Habit Added',
      'Great job setting up "${habit.name}"! Starting small and being consistent is the key to lasting change. I\'m here to cheer you on.',
      'encouragement',
      habitId: habit.id,
    );
  }

  Future<void> _generateCompletionInsight(String habitId, HabitCompletion completion) async {
    final stats = getHabitStats(habitId, days: 30);
    final streak = stats['currentStreak'] as int;

    if (streak == 3) {
      await _addInsight(
        '3-Day Streak!',
        'You\'re building momentum with ${stats['habitName']}! Three days in a row shows real commitment.',
        'celebration',
        habitId: habitId,
      );
    } else if (streak == 7) {
      await _addInsight(
        'One Week Strong!',
        'A full week of ${stats['habitName']} - you\'re creating a real habit! The neural pathways are forming.',
        'celebration',
        habitId: habitId,
      );
    } else if (streak == 21) {
      await _addInsight(
        'Habit Mastery!',
        'Three weeks of consistent ${stats['habitName']}! You\'ve officially built this into your routine. Incredible work!',
        'celebration',
        habitId: habitId,
      );
    }
  }

  Future<void> _checkForStreakAchievements(String habitId) async {
    // This is handled in _generateCompletionInsight
  }

  Future<void> _addInsight(String title, String message, String type, {String? habitId}) async {
    final insight = CoachingInsight(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      title: title,
      message: message,
      type: type,
      habitId: habitId,
    );

    _insights.add(insight);
    await _saveInsights();
    notifyListeners();
  }

  bool _shouldDoHabitToday(WellnessHabit habit, DateTime date) {
    switch (habit.frequency) {
      case HabitFrequency.daily:
        return true;
      case HabitFrequency.weekdays:
        return date.weekday <= 5; // Monday = 1, Sunday = 7
      case HabitFrequency.weekends:
        return date.weekday > 5;
      case HabitFrequency.weekly:
        // Once per week - check if done this week
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        return !_completions.any((c) => 
          c.habitId == habit.id && 
          c.completedAt.isAfter(weekStart) &&
          c.completedAt.isBefore(date.add(const Duration(days: 1))));
      case HabitFrequency.biweekly:
        // Every other week
        final daysSinceEpoch = date.difference(DateTime(1970)).inDays;
        return (daysSinceEpoch ~/ 14) % 2 == 0;
      case HabitFrequency.custom:
        // Handle custom frequency patterns
        return true; // For now, default to true
    }
  }

  int _calculateExpectedCompletions(WellnessHabit habit, int days) {
    switch (habit.frequency) {
      case HabitFrequency.daily:
        return days;
      case HabitFrequency.weekdays:
        return (days / 7 * 5).round();
      case HabitFrequency.weekends:
        return (days / 7 * 2).round();
      case HabitFrequency.weekly:
        return (days / 7).round();
      case HabitFrequency.biweekly:
        return (days / 14).round();
      case HabitFrequency.custom:
        return days; // Default assumption
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // File operations
  Future<File> _getHabitsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_habitsFileName');
  }

  Future<File> _getCompletionsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_completionsFileName');
  }

  Future<File> _getInsightsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_insightsFileName');
  }

  Future<void> _loadHabits() async {
    try {
      final file = await _getHabitsFile();
      if (!await file.exists()) return;

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);
      _habits = jsonList.map((json) => WellnessHabit.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading habits: $e');
      _habits = [];
    }
  }

  Future<void> _saveHabits() async {
    try {
      final file = await _getHabitsFile();
      final jsonString = json.encode(_habits.map((h) => h.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error saving habits: $e');
    }
  }

  Future<void> _loadCompletions() async {
    try {
      final file = await _getCompletionsFile();
      if (!await file.exists()) return;

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);
      _completions = jsonList.map((json) => HabitCompletion.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading completions: $e');
      _completions = [];
    }
  }

  Future<void> _saveCompletions() async {
    try {
      final file = await _getCompletionsFile();
      final jsonString = json.encode(_completions.map((c) => c.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error saving completions: $e');
    }
  }

  Future<void> _loadInsights() async {
    try {
      final file = await _getInsightsFile();
      if (!await file.exists()) return;

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);
      _insights = jsonList.map((json) => CoachingInsight.fromJson(json)).toList();
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
}