import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:runanywhere/runanywhere.dart';

import '../models/chat_models.dart';
import '../services/wellness_service.dart';

/// Voice analysis metrics for mood detection
class VoiceMetrics {
  final double averageAmplitude;
  final double speechRate; // words per minute
  final double pauseFrequency; // pauses per minute
  final double averagePauseDuration; // seconds
  final double energyLevel; // 0.0 to 1.0
  final DateTime timestamp;
  
  VoiceMetrics({
    required this.averageAmplitude,
    required this.speechRate,
    required this.pauseFrequency,
    required this.averagePauseDuration,
    required this.energyLevel,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'averageAmplitude': averageAmplitude,
    'speechRate': speechRate,
    'pauseFrequency': pauseFrequency,
    'averagePauseDuration': averagePauseDuration,
    'energyLevel': energyLevel,
    'timestamp': timestamp.toIso8601String(),
  };

  factory VoiceMetrics.fromJson(Map<String, dynamic> json) => VoiceMetrics(
    averageAmplitude: json['averageAmplitude']?.toDouble() ?? 0.0,
    speechRate: json['speechRate']?.toDouble() ?? 0.0,
    pauseFrequency: json['pauseFrequency']?.toDouble() ?? 0.0,
    averagePauseDuration: json['averagePauseDuration']?.toDouble() ?? 0.0,
    energyLevel: json['energyLevel']?.toDouble() ?? 0.0,
    timestamp: DateTime.parse(json['timestamp']),
  );
}

/// Mood detection result combining voice and text analysis
class MoodAnalysisResult {
  final MoodType detectedMood;
  final double confidence; // 0.0 to 1.0
  final int energyLevel; // 1-10
  final int stressLevel; // 1-10
  final List<String> indicators; // What led to this assessment
  final VoiceMetrics? voiceMetrics;
  final DateTime timestamp;

  MoodAnalysisResult({
    required this.detectedMood,
    required this.confidence,
    required this.energyLevel,
    required this.stressLevel,
    required this.indicators,
    this.voiceMetrics,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'detectedMood': detectedMood.name,
    'confidence': confidence,
    'energyLevel': energyLevel,
    'stressLevel': stressLevel,
    'indicators': indicators,
    'voiceMetrics': voiceMetrics?.toJson(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory MoodAnalysisResult.fromJson(Map<String, dynamic> json) => MoodAnalysisResult(
    detectedMood: MoodType.values.byName(json['detectedMood']),
    confidence: json['confidence']?.toDouble() ?? 0.0,
    energyLevel: json['energyLevel'] ?? 5,
    stressLevel: json['stressLevel'] ?? 5,
    indicators: List<String>.from(json['indicators'] ?? []),
    voiceMetrics: json['voiceMetrics'] != null 
        ? VoiceMetrics.fromJson(json['voiceMetrics']) 
        : null,
    timestamp: DateTime.parse(json['timestamp']),
  );
}

/// Service for analyzing mood from voice and text inputs
class MoodAnalysisService extends ChangeNotifier {
  final WellnessService _wellnessService;
  
  List<MoodAnalysisResult> _recentAnalyses = [];
  bool _isAnalyzing = false;
  MoodType? _currentMood;
  
  MoodAnalysisService(this._wellnessService);

  List<MoodAnalysisResult> get recentAnalyses => List.unmodifiable(_recentAnalyses);
  bool get isAnalyzing => _isAnalyzing;
  MoodType? get currentMood => _currentMood;

  /// Add a mood analysis result (for manual entries)
  void addMoodAnalysis(MoodAnalysisResult result) {
    _recentAnalyses.insert(0, result);
    if (_recentAnalyses.length > 50) {
      _recentAnalyses.removeLast();
    }
    _currentMood = result.detectedMood;
    notifyListeners();
  }

  /// Get the wellness service for external operations
  WellnessService get wellnessService => _wellnessService;

  /// Analyze mood from voice input using voice session + voice metrics
  Future<MoodAnalysisResult?> analyzeVoiceInput() async {
    if (_isAnalyzing) return null;

    _isAnalyzing = true;
    notifyListeners();

    try {
      // Start voice session with VAD for mood analysis
      final session = await RunAnywhere.startVoiceSession(
        config: const VoiceSessionConfig(
          speechThreshold: 0.02, // More sensitive for mood detection
          silenceDuration: 2.0,  // Allow natural pauses
          autoPlayTTS: false,    // We just want to analyze, not respond
          continuousMode: false, // Single interaction for analysis
        ),
      );

      final List<double> audioLevels = [];
      String transcribedText = '';
      DateTime? speechStartTime;
      DateTime? speechEndTime;
      bool speechDetected = false;

      // Listen for voice session events
      final subscription = session.events.listen((event) {
        switch (event) {
          case VoiceSessionListening(:final audioLevel):
            audioLevels.add(audioLevel);
            break;
          case VoiceSessionSpeechStarted():
            speechStartTime = DateTime.now();
            speechDetected = true;
            break;
          case VoiceSessionTranscribed(:final text):
            transcribedText = text;
            speechEndTime = DateTime.now();
            break;
          case VoiceSessionStopped():
          case VoiceSessionTurnCompleted():
            // Analysis complete
            break;
          default:
            // Handle other events
            break;
        }
      });

      // Wait for speech or timeout after 15 seconds
      await Future.delayed(const Duration(seconds: 15));
      
      // Stop the session
      session.stop();
      subscription.cancel();

      // If no speech was detected, return null
      if (!speechDetected || transcribedText.isEmpty) {
        return null;
      }

      // Calculate voice metrics from collected data
      final voiceMetrics = _calculateVoiceMetricsFromSession(
        audioLevels,
        speechStartTime!,
        speechEndTime ?? DateTime.now(),
        transcribedText,
      );

      // Analyze mood from voice + text
      final moodResult = await _analyzeMoodFromData(transcribedText, voiceMetrics);
      
      if (moodResult != null) {
        _recentAnalyses.insert(0, moodResult);
        if (_recentAnalyses.length > 50) {
          _recentAnalyses.removeLast();
        }
        
        _currentMood = moodResult.detectedMood;
        
        // Store in wellness service
        await _wellnessService.addWellnessEntry(WellnessEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          mood: moodResult.detectedMood,
          energyLevel: moodResult.energyLevel,
          stressLevel: moodResult.stressLevel,
          notes: transcribedText,
          metadata: {
            'source': 'voice_analysis',
            'confidence': moodResult.confidence,
            'indicators': moodResult.indicators,
          },
        ));
      }

      return moodResult;
      
    } catch (e) {
      debugPrint('Error analyzing voice input: $e');
      return null;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// Analyze mood from text input (conversation messages)
  Future<MoodAnalysisResult?> analyzeTextInput(String text) async {
    if (text.trim().isEmpty) return null;

    try {
      final moodResult = await _analyzeMoodFromData(text, null);
      
      if (moodResult != null) {
        _recentAnalyses.insert(0, moodResult);
        if (_recentAnalyses.length > 50) {
          _recentAnalyses.removeLast();
        }
        
        _currentMood = moodResult.detectedMood;
        notifyListeners();
        
        // Store in wellness service
        await _wellnessService.addWellnessEntry(WellnessEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          mood: moodResult.detectedMood,
          energyLevel: moodResult.energyLevel,
          stressLevel: moodResult.stressLevel,
          notes: text,
          metadata: {
            'source': 'text_analysis',
            'confidence': moodResult.confidence,
            'indicators': moodResult.indicators,
          },
        ));
      }

      return moodResult;
      
    } catch (e) {
      debugPrint('Error analyzing text input: $e');
      return null;
    }
  }

  /// Get mood trend over specified days
  Map<String, dynamic> getMoodTrend({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recentAnalyses = _recentAnalyses
        .where((analysis) => analysis.timestamp.isAfter(cutoff))
        .toList();

    if (recentAnalyses.isEmpty) {
      return {'trend': 'no_data'};
    }

    // Calculate average energy and stress levels
    final avgEnergy = recentAnalyses
        .map((a) => a.energyLevel)
        .reduce((a, b) => a + b) / recentAnalyses.length;
    
    final avgStress = recentAnalyses
        .map((a) => a.stressLevel)
        .reduce((a, b) => a + b) / recentAnalyses.length;

    // Find most common mood
    final moodCounts = <MoodType, int>{};
    for (final analysis in recentAnalyses) {
      moodCounts[analysis.detectedMood] = 
          (moodCounts[analysis.detectedMood] ?? 0) + 1;
    }

    final dominantMood = moodCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return {
      'trend': 'available',
      'averageEnergy': avgEnergy.round(),
      'averageStress': avgStress.round(),
      'dominantMood': dominantMood.name,
      'totalAnalyses': recentAnalyses.length,
      'moodDistribution': moodCounts.map(
        (mood, count) => MapEntry(mood.name, count),
      ),
    };
  }

  /// Private helper methods
  
  VoiceMetrics _calculateVoiceMetricsFromSession(
    List<double> audioLevels,
    DateTime speechStartTime,
    DateTime speechEndTime,
    String transcribedText,
  ) {
    final avgAmplitude = audioLevels.isNotEmpty
        ? audioLevels.reduce((a, b) => a + b) / audioLevels.length
        : 0.0;

    final speechDurationMinutes = speechEndTime.difference(speechStartTime).inSeconds / 60.0;
    final wordCount = transcribedText.split(' ').where((w) => w.isNotEmpty).length;
    final speechRate = speechDurationMinutes > 0 ? wordCount / speechDurationMinutes : 0.0;

    // Estimate pause frequency from audio level variations
    int pauseCount = 0;
    double totalPauseDuration = 0.0;
    bool inPause = false;
    DateTime? pauseStart;
    
    for (int i = 1; i < audioLevels.length; i++) {
      final prevLevel = audioLevels[i - 1];
      final currentLevel = audioLevels[i];
      
      // Detect pause start (audio level drops significantly)
      if (!inPause && prevLevel > 0.02 && currentLevel < 0.01) {
        inPause = true;
        pauseStart = speechStartTime.add(Duration(milliseconds: i * 100)); // Assuming 10Hz sampling
        pauseCount++;
      }
      
      // Detect pause end
      if (inPause && currentLevel > 0.02) {
        inPause = false;
        if (pauseStart != null) {
          final pauseEnd = speechStartTime.add(Duration(milliseconds: i * 100));
          totalPauseDuration += pauseEnd.difference(pauseStart).inMilliseconds / 1000.0;
        }
      }
    }

    final pauseFreq = speechDurationMinutes > 0 ? pauseCount / speechDurationMinutes : 0.0;
    final avgPauseDuration = pauseCount > 0 ? totalPauseDuration / pauseCount : 0.0;

    // Energy level based on average amplitude and speech consistency
    final energyLevel = (avgAmplitude * 0.7 + (speechRate / 120.0).clamp(0.0, 1.0) * 0.3)
        .clamp(0.0, 1.0);

    return VoiceMetrics(
      averageAmplitude: avgAmplitude,
      speechRate: speechRate,
      pauseFrequency: pauseFreq,
      averagePauseDuration: avgPauseDuration,
      energyLevel: energyLevel,
      timestamp: DateTime.now(),
    );
  }

  Future<MoodAnalysisResult?> _analyzeMoodFromData(
    String text, 
    VoiceMetrics? voiceMetrics,
  ) async {
    final indicators = <String>[];
    
    // Analyze text content for emotional indicators
    final textLower = text.toLowerCase();
    
    // Stress indicators
    final stressWords = [
      'stressed', 'anxious', 'worried', 'overwhelmed', 'panic', 'pressure',
      'deadline', 'exhausted', 'burned out', 'cant cope', 'too much'
    ];
    
    // Mood indicators
    final positiveWords = [
      'happy', 'great', 'amazing', 'wonderful', 'excited', 'grateful',
      'love', 'joy', 'fantastic', 'awesome', 'good'
    ];
    
    final negativeWords = [
      'sad', 'depressed', 'angry', 'frustrated', 'upset', 'terrible',
      'awful', 'hate', 'horrible', 'bad', 'miserable'
    ];

    // Count word indicators
    int stressScore = stressWords.where((word) => textLower.contains(word)).length;
    int positiveScore = positiveWords.where((word) => textLower.contains(word)).length;
    int negativeScore = negativeWords.where((word) => textLower.contains(word)).length;
    
    // Check for energy-related words to improve mood detection
    final lowEnergyWords = ['tired', 'exhausted', 'sleepy', 'drained'];
    final highEnergyWords = ['energetic', 'pumped', 'motivated', 'excited', 'alert'];
    
    int lowEnergyScore = lowEnergyWords.where((word) => textLower.contains(word)).length;
    int highEnergyScore = highEnergyWords.where((word) => textLower.contains(word)).length;
    
    // Voice analysis adjustments
    double voiceStressMultiplier = 1.0;
    double voiceEnergyMultiplier = 1.0;
    
    if (voiceMetrics != null) {
      // High pause frequency might indicate hesitation/anxiety
      if (voiceMetrics.pauseFrequency > 3.0) {
        stressScore += 2;
        indicators.add('hesitant speech pattern');
        voiceStressMultiplier = 1.3;
      }
      
      // Very fast or very slow speech can indicate stress
      if (voiceMetrics.speechRate > 180 || voiceMetrics.speechRate < 80) {
        stressScore += 1;
        indicators.add('unusual speech rate');
      }
      
      // Energy level from voice
      voiceEnergyMultiplier = voiceMetrics.energyLevel;
      if (voiceMetrics.energyLevel < 0.3) {
        indicators.add('low voice energy');
      } else if (voiceMetrics.energyLevel > 0.7) {
        indicators.add('high voice energy');
      }
    }

    // Determine mood based on analysis
    MoodType detectedMood;
    double confidence = 0.5;
    
    if (stressScore > 2) {
      detectedMood = MoodType.stressed;
      confidence = (stressScore * 0.2).clamp(0.5, 0.9);
      indicators.add('stress indicators in text');
    } else if (negativeScore > positiveScore && negativeScore > 1) {
      detectedMood = MoodType.anxious;
      confidence = 0.7;
      indicators.add('negative emotional language');
    } else if (positiveScore > negativeScore && positiveScore > 1) {
      detectedMood = MoodType.happy;
      confidence = 0.8;
      indicators.add('positive emotional language');
    } else if (lowEnergyScore > 0 || voiceEnergyMultiplier < 0.4) {
      detectedMood = MoodType.tired;
      confidence = 0.6;
      indicators.add('low energy detected');
    } else if (highEnergyScore > 0 || voiceEnergyMultiplier > 0.8) {
      detectedMood = MoodType.energetic;
      confidence = 0.7;
      indicators.add('high energy detected');
    } else {
      detectedMood = MoodType.calm;
      confidence = 0.5;
      indicators.add('neutral emotional state');
    }

    // Calculate energy and stress levels (1-10)
    int energyLevel = (5 + (voiceEnergyMultiplier - 0.5) * 4 + 
                      (positiveScore - negativeScore) * 0.5).round().clamp(1, 10);
    
    int stressLevel = (5 + stressScore * voiceStressMultiplier + 
                      negativeScore * 0.5).round().clamp(1, 10);

    return MoodAnalysisResult(
      detectedMood: detectedMood,
      confidence: confidence,
      energyLevel: energyLevel,
      stressLevel: stressLevel,
      indicators: indicators,
      voiceMetrics: voiceMetrics,
      timestamp: DateTime.now(),
    );
  }
}