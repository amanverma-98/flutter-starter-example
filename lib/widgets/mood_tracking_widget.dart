import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/chat_models.dart';
import '../services/mood_analysis_service.dart';
import '../services/wellness_service.dart';
import '../theme/app_theme.dart';

class MoodTrackingWidget extends StatefulWidget {
  final Function(String)? onMoodMessage;
  
  const MoodTrackingWidget({
    super.key,
    this.onMoodMessage,
  });

  @override
  State<MoodTrackingWidget> createState() => _MoodTrackingWidgetState();
}

class _MoodTrackingWidgetState extends State<MoodTrackingWidget> 
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  MoodAnalysisService? _moodService;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeMoodService();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initializeMoodService() {
    final wellnessService = Provider.of<WellnessService>(context, listen: false);
    _moodService = MoodAnalysisService(wellnessService);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_moodService == null) {
      return const SizedBox.shrink();
    }

    return ChangeNotifierProvider.value(
      value: _moodService,
      child: Consumer<MoodAnalysisService>(
        builder: (context, moodService, child) {
          return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentPink.withOpacity(0.1),
                  AppColors.accentViolet.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accentPink.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(moodService),
                  if (_isExpanded) ...[
                    const SizedBox(height: 16),
                    _buildMoodOptions(),
                    const SizedBox(height: 16),
                    _buildVoiceAnalysisButton(moodService),
                    if (moodService.currentMood != null) ...[
                      const SizedBox(height: 16),
                      _buildCurrentMood(moodService),
                    ],
                    if (moodService.recentAnalyses.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMoodTrend(moodService),
                    ],
                  ],
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms);
        },
      ),
    );
  }

  Widget _buildHeader(MoodAnalysisService moodService) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentPink,
                        AppColors.accentViolet,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentPink.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getMoodIcon(moodService.currentMood),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mood Tracker',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.accentPink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getMoodStatusText(moodService),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: AppColors.accentPink,
          ),
        ],
      ),
    );
  }

  Widget _buildMoodOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How are you feeling?',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MoodType.values.map((mood) => _buildMoodChip(mood)).toList(),
        ),
      ],
    );
  }

  Widget _buildMoodChip(MoodType mood) {
    return ActionChip(
      avatar: Icon(
        _getMoodIcon(mood),
        size: 16,
        color: AppColors.accentPink,
      ),
      label: Text(_getMoodLabel(mood)),
      backgroundColor: AppColors.primaryMid,
      side: BorderSide(color: AppColors.accentPink.withOpacity(0.3)),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textPrimary,
      ),
      onPressed: () => _onMoodSelected(mood),
    );
  }

  Widget _buildVoiceAnalysisButton(MoodAnalysisService moodService) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: moodService.isAnalyzing ? null : _startVoiceAnalysis,
        icon: moodService.isAnalyzing
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.mic_rounded),
        label: Text(
          moodService.isAnalyzing 
              ? 'Analyzing your voice...' 
              : 'Voice Mood Check',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentMood(MoodAnalysisService moodService) {
    final latestAnalysis = moodService.recentAnalyses.isNotEmpty 
        ? moodService.recentAnalyses.first 
        : null;

    if (latestAnalysis == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentPink.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getMoodIcon(latestAnalysis.detectedMood),
                color: AppColors.accentPink,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Currently: ${_getMoodLabel(latestAnalysis.detectedMood)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentPink.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(latestAnalysis.confidence * 100).round()}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.accentPink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMoodMetric('Energy', latestAnalysis.energyLevel, Colors.green),
              const SizedBox(width: 16),
              _buildMoodMetric('Stress', latestAnalysis.stressLevel, Colors.orange),
            ],
          ),
          if (latestAnalysis.indicators.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Indicators: ${latestAnalysis.indicators.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodMetric(String label, int value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: $value/10',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value / 10.0,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodTrend(MoodAnalysisService moodService) {
    final trend = moodService.getMoodTrend(days: 7);
    
    if (trend['trend'] != 'available') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '7-Day Wellness Trend',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTrendStat('Avg Energy', '${trend['averageEnergy']}/10', Colors.green),
              _buildTrendStat('Avg Stress', '${trend['averageStress']}/10', Colors.orange),
              _buildTrendStat('Main Mood', _getMoodLabel(
                MoodType.values.byName(trend['dominantMood'])
              ), AppColors.accentPink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _onMoodSelected(MoodType mood) async {
    if (_moodService == null) return;

    // Create a mood analysis result from manual selection
    final moodResult = MoodAnalysisResult(
      detectedMood: mood,
      confidence: 1.0, // User selected, so confidence is 100%
      energyLevel: _getDefaultEnergyForMood(mood),
      stressLevel: _getDefaultStressForMood(mood),
      indicators: ['manually_selected'],
      timestamp: DateTime.now(),
    );

    // Add to recent analyses using public method
    _moodService!.addMoodAnalysis(moodResult);

    // Store in wellness service
    await _moodService!.wellnessService.addWellnessEntry(WellnessEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      mood: mood,
      energyLevel: _getDefaultEnergyForMood(mood),
      stressLevel: _getDefaultStressForMood(mood),
      notes: 'Mood manually selected: ${_getMoodLabel(mood)}',
      metadata: {
        'source': 'manual_selection',
        'confidence': 1.0,
      },
    ));

    // Send message to ARIA if callback provided
    if (widget.onMoodMessage != null) {
      final message = _generateMoodMessage(mood);
      widget.onMoodMessage!(message);
    }

    // Start pulse animation to show selection
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
  }

  void _startVoiceAnalysis() async {
    if (_moodService == null) return;

    final result = await _moodService!.analyzeVoiceInput();
    
    if (result != null && widget.onMoodMessage != null) {
      final message = 'I just analyzed my voice and I\'m feeling ${_getMoodLabel(result.detectedMood)}. ${result.indicators.join(', ')}.';
      widget.onMoodMessage!(message);
    }
  }

  // Helper methods
  IconData _getMoodIcon(MoodType? mood) {
    switch (mood) {
      case MoodType.happy:
        return Icons.sentiment_very_satisfied_rounded;
      case MoodType.energetic:
        return Icons.bolt_rounded;
      case MoodType.calm:
        return Icons.spa_rounded;
      case MoodType.stressed:
        return Icons.sentiment_dissatisfied_rounded;
      case MoodType.tired:
        return Icons.bedtime_rounded;
      case MoodType.anxious:
        return Icons.sentiment_neutral_rounded;
      case MoodType.focused:
        return Icons.center_focus_strong_rounded;
      case MoodType.overwhelmed:
        return Icons.sentiment_very_dissatisfied_rounded;
      default:
        return Icons.favorite_rounded;
    }
  }

  String _getMoodLabel(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 'Happy';
      case MoodType.energetic:
        return 'Energetic';
      case MoodType.calm:
        return 'Calm';
      case MoodType.stressed:
        return 'Stressed';
      case MoodType.tired:
        return 'Tired';
      case MoodType.anxious:
        return 'Anxious';
      case MoodType.focused:
        return 'Focused';
      case MoodType.overwhelmed:
        return 'Overwhelmed';
    }
  }

  String _getMoodStatusText(MoodAnalysisService moodService) {
    if (moodService.isAnalyzing) {
      return 'Analyzing voice patterns...';
    } else if (moodService.currentMood != null) {
      return 'Feeling ${_getMoodLabel(moodService.currentMood!)}';
    } else {
      return 'Tap to track your mood';
    }
  }

  int _getDefaultEnergyForMood(MoodType mood) {
    switch (mood) {
      case MoodType.energetic:
        return 9;
      case MoodType.happy:
        return 8;
      case MoodType.focused:
        return 7;
      case MoodType.calm:
        return 6;
      case MoodType.anxious:
        return 4;
      case MoodType.stressed:
        return 3;
      case MoodType.tired:
        return 2;
      case MoodType.overwhelmed:
        return 2;
    }
  }

  int _getDefaultStressForMood(MoodType mood) {
    switch (mood) {
      case MoodType.overwhelmed:
        return 9;
      case MoodType.stressed:
        return 8;
      case MoodType.anxious:
        return 7;
      case MoodType.tired:
        return 5;
      case MoodType.focused:
        return 4;
      case MoodType.calm:
        return 2;
      case MoodType.happy:
        return 2;
      case MoodType.energetic:
        return 3;
    }
  }

  String _generateMoodMessage(MoodType mood) {
    final messages = {
      MoodType.happy: [
        'I\'m feeling really happy right now!',
        'I\'m in a great mood today.',
        'I\'m feeling joyful and content.',
      ],
      MoodType.energetic: [
        'I\'m feeling really energetic and ready to take on the day!',
        'I have so much energy right now.',
        'I\'m feeling pumped and motivated.',
      ],
      MoodType.calm: [
        'I\'m feeling calm and peaceful.',
        'I\'m in a relaxed state of mind.',
        'I\'m feeling centered and balanced.',
      ],
      MoodType.stressed: [
        'I\'m feeling quite stressed right now.',
        'I have a lot on my mind and feeling overwhelmed.',
        'I\'m feeling the pressure and could use some support.',
      ],
      MoodType.tired: [
        'I\'m feeling really tired and drained.',
        'I need some rest, I\'m exhausted.',
        'I\'m feeling low energy and sluggish.',
      ],
      MoodType.anxious: [
        'I\'m feeling anxious and a bit worried.',
        'I have some anxiety and could use some calming techniques.',
        'I\'m feeling nervous and unsettled.',
      ],
      MoodType.focused: [
        'I\'m feeling focused and determined.',
        'I\'m in the zone and ready to be productive.',
        'I\'m feeling clear-minded and concentrated.',
      ],
      MoodType.overwhelmed: [
        'I\'m feeling completely overwhelmed right now.',
        'Everything feels like too much and I need help coping.',
        'I\'m struggling to handle everything on my plate.',
      ],
    };

    final moodMessages = messages[mood] ?? ['I\'m feeling ${_getMoodLabel(mood)}.'];
    return moodMessages[Random().nextInt(moodMessages.length)];
  }
}