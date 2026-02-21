import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:runanywhere/runanywhere.dart';

import '../models/chat_models.dart';

/// Types of meditation and mindfulness practices
enum MeditationType {
  guidedMeditation,
  breathingExercise,
  bodyscan,
  lovingKindness,
  mindfulnessBreak,
  sleepMeditation,
  anxietyRelief,
  stressRelease,
  focusBoost,
  gratitudePractice
}

/// Meditation session lengths
enum SessionDuration {
  quick,     // 2-3 minutes
  short,     // 5-7 minutes  
  medium,    // 10-15 minutes
  long,      // 20-30 minutes
  custom     // User defined
}

/// Meditation difficulty levels
enum MeditationLevel {
  beginner,     // Simple instructions, more guidance
  intermediate, // Moderate guidance, some silence
  advanced      // Minimal guidance, longer silence periods
}

/// A completed meditation session
class MeditationSession {
  final String id;
  final MeditationType type;
  final SessionDuration duration;
  final int actualMinutes;
  final DateTime startTime;
  final DateTime endTime;
  final bool completed;
  final int? rating; // 1-5 how beneficial it felt
  final String? notes;
  final MoodType? moodBefore;
  final MoodType? moodAfter;
  final Map<String, dynamic>? metadata;

  MeditationSession({
    required this.id,
    required this.type,
    required this.duration,
    required this.actualMinutes,
    required this.startTime,
    required this.endTime,
    required this.completed,
    this.rating,
    this.notes,
    this.moodBefore,
    this.moodAfter,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'duration': duration.name,
    'actualMinutes': actualMinutes,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'completed': completed,
    'rating': rating,
    'notes': notes,
    'moodBefore': moodBefore?.name,
    'moodAfter': moodAfter?.name,
    'metadata': metadata,
  };

  factory MeditationSession.fromJson(Map<String, dynamic> json) => MeditationSession(
    id: json['id'],
    type: MeditationType.values.byName(json['type']),
    duration: SessionDuration.values.byName(json['duration']),
    actualMinutes: json['actualMinutes'],
    startTime: DateTime.parse(json['startTime']),
    endTime: DateTime.parse(json['endTime']),
    completed: json['completed'],
    rating: json['rating'],
    notes: json['notes'],
    moodBefore: json['moodBefore'] != null ? MoodType.values.byName(json['moodBefore']) : null,
    moodAfter: json['moodAfter'] != null ? MoodType.values.byName(json['moodAfter']) : null,
    metadata: json['metadata'],
  );
}

/// A guided meditation script segment
class MeditationSegment {
  final String instruction;
  final int durationSeconds;
  final bool isSilence;
  final String? backgroundSound;

  MeditationSegment({
    required this.instruction,
    required this.durationSeconds,
    this.isSilence = false,
    this.backgroundSound,
  });
}

/// Service for managing mindfulness and meditation experiences
class MindfulnessService extends ChangeNotifier {
  static const String _sessionsFileName = 'meditation_sessions.json';
  
  List<MeditationSession> _sessions = [];
  MeditationSession? _currentSession;
  bool _isInSession = false;
  bool _isInitialized = false;
  
  // Current session state
  Timer? _sessionTimer;
  int _currentSegmentIndex = 0;
  List<MeditationSegment> _currentScript = [];
  DateTime? _sessionStartTime;
  StreamController<String>? _instructionController;
  
  List<MeditationSession> get sessions => List.unmodifiable(_sessions);
  MeditationSession? get currentSession => _currentSession;
  bool get isInSession => _isInSession;
  bool get isInitialized => _isInitialized;
  
  Stream<String>? get instructionStream => _instructionController?.stream;

  /// Initialize the mindfulness service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadSessions();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing mindfulness service: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Start a meditation session
  Future<void> startMeditation({
    required MeditationType type,
    required SessionDuration duration,
    MeditationLevel level = MeditationLevel.beginner,
    int? customMinutes,
    MoodType? currentMood,
  }) async {
    if (_isInSession) {
      await stopMeditation();
    }

    _sessionStartTime = DateTime.now();
    _currentSegmentIndex = 0;
    _isInSession = true;
    
    // Generate meditation script
    _currentScript = _generateMeditationScript(type, duration, level, customMinutes);
    
    // Create session record
    _currentSession = MeditationSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      duration: duration,
      actualMinutes: customMinutes ?? _getDurationMinutes(duration),
      startTime: _sessionStartTime!,
      endTime: _sessionStartTime!.add(Duration(minutes: customMinutes ?? _getDurationMinutes(duration))),
      completed: false,
      moodBefore: currentMood,
    );
    
    // Initialize instruction stream
    _instructionController = StreamController<String>.broadcast();
    
    notifyListeners();
    
    // Start the meditation sequence
    await _runMeditationSequence();
  }

  /// Stop the current meditation session
  Future<void> stopMeditation({bool completed = false, int? rating, String? notes, MoodType? moodAfter}) async {
    if (!_isInSession) return;
    
    _sessionTimer?.cancel();
    _isInSession = false;
    
    if (_currentSession != null) {
      // Update session with completion data
      final endTime = DateTime.now();
      final actualMinutes = endTime.difference(_sessionStartTime!).inMinutes;
      
      final completedSession = MeditationSession(
        id: _currentSession!.id,
        type: _currentSession!.type,
        duration: _currentSession!.duration,
        actualMinutes: actualMinutes,
        startTime: _currentSession!.startTime,
        endTime: endTime,
        completed: completed,
        rating: rating,
        notes: notes,
        moodBefore: _currentSession!.moodBefore,
        moodAfter: moodAfter,
        metadata: _currentSession!.metadata,
      );
      
      _sessions.add(completedSession);
      await _saveSessions();
    }
    
    _currentSession = null;
    _currentScript.clear();
    _currentSegmentIndex = 0;
    _sessionStartTime = null;
    
    await _instructionController?.close();
    _instructionController = null;
    
    notifyListeners();
  }

  /// Pause/resume meditation (for intermediate users)
  void pauseResumeMeditation() {
    if (_sessionTimer?.isActive == true) {
      _sessionTimer?.cancel();
    } else if (_isInSession) {
      _continueFromCurrentSegment();
    }
    notifyListeners();
  }

  /// Get meditation statistics
  Map<String, dynamic> getMeditationStats({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recentSessions = _sessions.where((s) => s.startTime.isAfter(cutoff)).toList();
    
    if (recentSessions.isEmpty) {
      return {'totalSessions': 0, 'totalMinutes': 0, 'averageRating': null};
    }
    
    final completedSessions = recentSessions.where((s) => s.completed).toList();
    final totalMinutes = completedSessions.fold(0, (sum, session) => sum + session.actualMinutes);
    
    final ratingsWithValue = completedSessions.where((s) => s.rating != null);
    final averageRating = ratingsWithValue.isNotEmpty
        ? ratingsWithValue.map((s) => s.rating!).reduce((a, b) => a + b) / ratingsWithValue.length
        : null;
    
    // Calculate streak
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < days; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final hasSession = recentSessions.any((s) => 
        _isSameDay(s.startTime, checkDate) && s.completed);
      
      if (hasSession) {
        streak++;
      } else {
        break;
      }
    }
    
    // Most practiced type
    final typeCounts = <MeditationType, int>{};
    for (final session in completedSessions) {
      typeCounts[session.type] = (typeCounts[session.type] ?? 0) + 1;
    }
    
    final favoriteType = typeCounts.isNotEmpty 
        ? typeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : null;
    
    return {
      'totalSessions': completedSessions.length,
      'totalMinutes': totalMinutes,
      'averageRating': averageRating?.round(),
      'streak': streak,
      'favoriteType': favoriteType?.name,
      'daysAnalyzed': days,
    };
  }

  /// Generate personalized meditation recommendation
  MeditationType getRecommendedMeditation(MoodType? currentMood) {
    if (currentMood == null) return MeditationType.mindfulnessBreak;
    
    switch (currentMood) {
      case MoodType.stressed:
        return MeditationType.stressRelease;
      case MoodType.anxious:
        return MeditationType.anxietyRelief;
      case MoodType.tired:
        return MeditationType.sleepMeditation;
      case MoodType.overwhelmed:
        return MeditationType.breathingExercise;
      case MoodType.happy:
        return MeditationType.gratitudePractice;
      case MoodType.energetic:
        return MeditationType.focusBoost;
      case MoodType.calm:
        return MeditationType.mindfulnessBreak;
      case MoodType.focused:
        return MeditationType.guidedMeditation;
    }
  }

  /// Generate ARIA-compatible meditation message
  String generateMeditationMessage() {
    final stats = getMeditationStats(days: 7);
    final totalSessions = stats['totalSessions'] as int;
    final totalMinutes = stats['totalMinutes'] as int;
    
    if (totalSessions == 0) {
      return 'I\'m interested in trying some meditation or mindfulness practice. Can you guide me through something calming?';
    } else if (totalSessions >= 5) {
      return 'I\'ve been keeping up with my meditation practice - $totalSessions sessions this week for $totalMinutes minutes total. It\'s really helping my wellbeing.';
    } else {
      return 'I did some meditation this week but would love to be more consistent. What would you recommend for building a regular practice?';
    }
  }

  /// Private helper methods

  Future<void> _runMeditationSequence() async {
    for (int i = 0; i < _currentScript.length; i++) {
      if (!_isInSession) break; // Session was stopped
      
      _currentSegmentIndex = i;
      final segment = _currentScript[i];
      
      if (!segment.isSilence && segment.instruction.isNotEmpty) {
        // Speak the instruction using TTS
        try {
          await RunAnywhere.synthesize(segment.instruction);
          _instructionController?.add(segment.instruction);
        } catch (e) {
          debugPrint('TTS Error: $e');
          _instructionController?.add(segment.instruction);
        }
      }
      
      // Wait for the segment duration
      _sessionTimer = Timer(Duration(seconds: segment.durationSeconds), () {
        // Timer completes, continue to next segment
      });
      
      await Future.delayed(Duration(seconds: segment.durationSeconds));
    }
    
    if (_isInSession) {
      // Session completed naturally
      await _completeMeditation();
    }
  }

  void _continueFromCurrentSegment() async {
    for (int i = _currentSegmentIndex; i < _currentScript.length; i++) {
      if (!_isInSession) break;
      
      final segment = _currentScript[i];
      
      if (!segment.isSilence && segment.instruction.isNotEmpty) {
        try {
          await RunAnywhere.synthesize(segment.instruction);
          _instructionController?.add(segment.instruction);
        } catch (e) {
          _instructionController?.add(segment.instruction);
        }
      }
      
      await Future.delayed(Duration(seconds: segment.durationSeconds));
    }
    
    if (_isInSession) {
      await _completeMeditation();
    }
  }

  Future<void> _completeMeditation() async {
    _instructionController?.add('Your meditation is complete. Take a moment to notice how you feel.');
    
    try {
      await RunAnywhere.synthesize('Your meditation is complete. Take a moment to notice how you feel.');
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
    
    await stopMeditation(completed: true);
  }

  List<MeditationSegment> _generateMeditationScript(
    MeditationType type, 
    SessionDuration duration, 
    MeditationLevel level,
    int? customMinutes,
  ) {
    final minutes = customMinutes ?? _getDurationMinutes(duration);
    final segments = <MeditationSegment>[];
    
    // Opening (30-60 seconds)
    segments.add(MeditationSegment(
      instruction: _getOpeningInstruction(type),
      durationSeconds: level == MeditationLevel.beginner ? 60 : 45,
    ));
    
    // Settling in (1-2 minutes)
    segments.add(MeditationSegment(
      instruction: 'Close your eyes gently and take three deep breaths with me. Breathe in slowly... and breathe out completely.',
      durationSeconds: 30,
    ));
    
    segments.add(MeditationSegment(
      instruction: '',
      durationSeconds: 30,
      isSilence: true,
    ));
    
    // Main practice (majority of time)
    final mainPracticeMinutes = minutes - 2; // Reserve 2 minutes for opening and closing
    segments.addAll(_generateMainPractice(type, mainPracticeMinutes * 60, level));
    
    // Closing (30-60 seconds)
    segments.add(MeditationSegment(
      instruction: 'Begin to bring your attention back to the room. Wiggle your fingers and toes gently.',
      durationSeconds: 30,
    ));
    
    segments.add(MeditationSegment(
      instruction: 'When you\'re ready, slowly open your eyes. Notice how you feel in this moment.',
      durationSeconds: 30,
    ));
    
    return segments;
  }

  String _getOpeningInstruction(MeditationType type) {
    switch (type) {
      case MeditationType.guidedMeditation:
        return 'Welcome to your guided meditation. Find a comfortable seated position and allow your body to relax.';
      case MeditationType.breathingExercise:
        return 'Let\'s begin a calming breathing exercise. Sit comfortably and place one hand on your chest, one on your belly.';
      case MeditationType.bodyscan:
        return 'We\'ll practice a body scan meditation. Lie down comfortably or sit with your back straight and supported.';
      case MeditationType.lovingKindness:
        return 'This loving-kindness meditation will help cultivate compassion. Sit comfortably and bring a gentle smile to your face.';
      case MeditationType.mindfulnessBreak:
        return 'Time for a mindful pause. Simply sit or stand comfortably wherever you are.';
      case MeditationType.sleepMeditation:
        return 'This meditation will help prepare your body and mind for restful sleep. Make yourself comfortable in bed.';
      case MeditationType.anxietyRelief:
        return 'Let\'s work together to calm your anxious mind. Find a safe, comfortable place to sit.';
      case MeditationType.stressRelease:
        return 'We\'ll release tension and stress from your body and mind. Sit comfortably and let your shoulders drop.';
      case MeditationType.focusBoost:
        return 'This meditation will help sharpen your focus and clarity. Sit upright but relaxed.';
      case MeditationType.gratitudePractice:
        return 'Let\'s cultivate gratitude and appreciation. Sit comfortably and bring to mind something you\'re thankful for.';
    }
  }

  List<MeditationSegment> _generateMainPractice(MeditationType type, int totalSeconds, MeditationLevel level) {
    final segments = <MeditationSegment>[];
    
    switch (type) {
      case MeditationType.breathingExercise:
        segments.addAll(_generateBreathingPractice(totalSeconds, level));
        break;
      case MeditationType.bodyscan:
        segments.addAll(_generateBodyScanPractice(totalSeconds, level));
        break;
      case MeditationType.lovingKindness:
        segments.addAll(_generateLovingKindnessPractice(totalSeconds, level));
        break;
      case MeditationType.anxietyRelief:
        segments.addAll(_generateAnxietyReliefPractice(totalSeconds, level));
        break;
      case MeditationType.stressRelease:
        segments.addAll(_generateStressReleasePractice(totalSeconds, level));
        break;
      case MeditationType.gratitudePractice:
        segments.addAll(_generateGratitudePractice(totalSeconds, level));
        break;
      default:
        segments.addAll(_generateGeneralMindfulness(totalSeconds, level));
    }
    
    return segments;
  }

  List<MeditationSegment> _generateBreathingPractice(int totalSeconds, MeditationLevel level) {
    final segments = <MeditationSegment>[];
    final guidanceFrequency = level == MeditationLevel.beginner ? 60 : level == MeditationLevel.intermediate ? 120 : 180;
    
    final instructions = [
      'Now we\'ll focus on the natural rhythm of your breath. Simply notice each inhale and exhale.',
      'If your mind wanders, that\'s perfectly normal. Gently return your attention to your breath.',
      'Feel the cool air entering through your nose, and the warm air leaving your body.',
      'Let each exhale release any tension you\'re holding in your body.',
      'Continue following your breath, allowing it to be your anchor in this moment.',
    ];
    
    int timeUsed = 0;
    int instructionIndex = 0;
    
    while (timeUsed < totalSeconds) {
      // Add instruction
      segments.add(MeditationSegment(
        instruction: instructions[instructionIndex % instructions.length],
        durationSeconds: 15,
      ));
      timeUsed += 15;
      
      // Add silence period
      final silenceDuration = (guidanceFrequency - 15).clamp(30, totalSeconds - timeUsed);
      segments.add(MeditationSegment(
        instruction: '',
        durationSeconds: silenceDuration,
        isSilence: true,
      ));
      timeUsed += silenceDuration;
      instructionIndex++;
    }
    
    return segments;
  }

  List<MeditationSegment> _generateBodyScanPractice(int totalSeconds, MeditationLevel level) {
    final segments = <MeditationSegment>[];
    
    final bodyParts = [
      'Start by bringing attention to the top of your head. Notice any sensations there.',
      'Move your awareness to your forehead, allowing it to soften and relax.',
      'Notice your eyes, letting them rest gently in their sockets.',
      'Bring attention to your jaw. Let it drop slightly and release any tension.',
      'Feel your neck and shoulders. Let them drop and soften.',
      'Notice your arms, from shoulders down to fingertips.',
      'Bring awareness to your chest. Feel it rising and falling with each breath.',
      'Notice your stomach and lower back. Let them soften.',
      'Feel your hips and pelvis, letting them settle.',
      'Bring attention to your thighs and knees.',
      'Notice your calves and shins.',
      'Finally, feel your feet and toes. Let them completely relax.',
    ];
    
    final timePerPart = totalSeconds ~/ bodyParts.length;
    
    for (final instruction in bodyParts) {
      segments.add(MeditationSegment(
        instruction: instruction,
        durationSeconds: 10,
      ));
      
      segments.add(MeditationSegment(
        instruction: '',
        durationSeconds: timePerPart - 10,
        isSilence: true,
      ));
    }
    
    return segments;
  }

  List<MeditationSegment> _generateLovingKindnessPractice(int totalSeconds, MeditationLevel level) {
    final segments = <MeditationSegment>[];
    
    final phases = [
      'Begin by offering loving-kindness to yourself. Silently repeat: "May I be happy, may I be healthy, may I be at peace."',
      'Now bring to mind someone you love dearly. Send them loving-kindness: "May you be happy, may you be healthy, may you be at peace."',
      'Think of a neutral person - someone you neither love nor dislike. Offer them the same wishes.',
      'Now, if you feel ready, bring to mind someone difficult. Send them loving-kindness as well.',
      'Finally, extend these wishes to all beings everywhere: "May all beings be happy, may all beings be healthy, may all beings be at peace."',
    ];
    
    final timePerPhase = totalSeconds ~/ phases.length;
    
    for (final instruction in phases) {
      segments.add(MeditationSegment(
        instruction: instruction,
        durationSeconds: 20,
      ));
      
      segments.add(MeditationSegment(
        instruction: '',
        durationSeconds: timePerPhase - 20,
        isSilence: true,
      ));
    }
    
    return segments;
  }

  List<MeditationSegment> _generateAnxietyReliefPractice(int totalSeconds, MeditationLevel level) {
    final segments = <MeditationSegment>[];
    
    segments.add(MeditationSegment(
      instruction: 'Notice that you are safe in this moment. Feel your body supported by what you\'re sitting on.',
      durationSeconds: 30,
    ));
    
    segments.add(MeditationSegment(
      instruction: 'Take a deep breath in for 4 counts... hold for 4... and exhale for 6 counts. This longer exhale activates your calming response.',
      durationSeconds: 45,
    ));
    
    // Continue with more specific anxiety-relief techniques
    final remainingTime = totalSeconds - 75;
    segments.addAll(_generateBreathingPractice(remainingTime, level));
    
    return segments;
  }

  List<MeditationSegment> _generateStressReleasePractice(int totalSeconds, MeditationLevel level) {
    final segments = <MeditationSegment>[];
    
    segments.add(MeditationSegment(
      instruction: 'Imagine stress leaving your body with each exhale. See it as gray smoke flowing out and dissolving.',
      durationSeconds: 30,
    ));
    
    segments.add(MeditationSegment(
      instruction: 'Tense all the muscles in your body for 5 seconds... and now release completely. Feel the wave of relaxation.',
      durationSeconds: 30,
    ));
    
    final remainingTime = totalSeconds - 60;
    segments.addAll(_generateBodyScanPractice(remainingTime, level));
    
    return segments;
  }

  List<MeditationSegment> _generateGratitudePractice(int totalSeconds, MeditationLevel level) {
    final segments = <MeditationSegment>[];
    
    segments.add(MeditationSegment(
      instruction: 'Bring to mind three things you\'re grateful for today. They can be big or small.',
      durationSeconds: 30,
    ));
    
    segments.add(MeditationSegment(
      instruction: 'Feel the warmth of gratitude in your heart. Let it spread throughout your body.',
      durationSeconds: 30,
    ));
    
    segments.add(MeditationSegment(
      instruction: 'Think of someone who has helped or supported you. Send them silent thanks.',
      durationSeconds: 30,
    ));
    
    final remainingTime = totalSeconds - 90;
    segments.add(MeditationSegment(
      instruction: '',
      durationSeconds: remainingTime,
      isSilence: true,
    ));
    
    return segments;
  }

  List<MeditationSegment> _generateGeneralMindfulness(int totalSeconds, MeditationLevel level) {
    return _generateBreathingPractice(totalSeconds, level);
  }

  int _getDurationMinutes(SessionDuration duration) {
    switch (duration) {
      case SessionDuration.quick:
        return 3;
      case SessionDuration.short:
        return 7;
      case SessionDuration.medium:
        return 12;
      case SessionDuration.long:
        return 25;
      case SessionDuration.custom:
        return 10; // Default fallback
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // File operations
  Future<File> _getSessionsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_sessionsFileName');
  }

  Future<void> _loadSessions() async {
    try {
      final file = await _getSessionsFile();
      if (!await file.exists()) return;

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);
      _sessions = jsonList.map((json) => MeditationSession.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading meditation sessions: $e');
      _sessions = [];
    }
  }

  Future<void> _saveSessions() async {
    try {
      final file = await _getSessionsFile();
      final jsonString = json.encode(_sessions.map((s) => s.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error saving meditation sessions: $e');
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _instructionController?.close();
    super.dispose();
  }
}