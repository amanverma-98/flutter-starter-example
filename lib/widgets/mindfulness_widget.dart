import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../services/mindfulness_service.dart';
import '../services/mood_analysis_service.dart';
import '../models/chat_models.dart';
import '../theme/app_theme.dart';

class MindfulnessWidget extends StatefulWidget {
  final Function(String)? onMindfulnessMessage;
  
  const MindfulnessWidget({
    super.key,
    this.onMindfulnessMessage,
  });

  @override
  State<MindfulnessWidget> createState() => _MindfulnessWidgetState();
}

class _MindfulnessWidgetState extends State<MindfulnessWidget> 
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _pulseController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _pulseAnimation;
  
  MindfulnessService? _mindfulnessService;
  bool _isExpanded = false;
  String _selectedView = 'practice'; // 'practice', 'sessions', 'stats'

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeMindfulnessService();
  }

  void _initializeAnimations() {
    _breathingController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _breathingAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _pulseController.repeat(reverse: true);
  }

  void _initializeMindfulnessService() async {
    _mindfulnessService = MindfulnessService();
    await _mindfulnessService!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mindfulnessService == null) {
      return const SizedBox.shrink();
    }

    return ChangeNotifierProvider.value(
      value: _mindfulnessService,
      child: Consumer<MindfulnessService>(
        builder: (context, mindfulnessService, child) {
          return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentViolet.withOpacity(0.1),
                  AppColors.accentPink.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accentViolet.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(mindfulnessService),
                  if (_isExpanded) ...[
                    const SizedBox(height: 16),
                    if (mindfulnessService.isInSession)
                      _buildActiveSession(mindfulnessService)
                    else ...[
                      _buildViewSelector(),
                      const SizedBox(height: 16),
                      _buildSelectedView(mindfulnessService),
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

  Widget _buildHeader(MindfulnessService mindfulnessService) {
    final stats = mindfulnessService.getMeditationStats(days: 7);
    final totalSessions = stats['totalSessions'] as int;
    final totalMinutes = stats['totalMinutes'] as int;

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: mindfulnessService.isInSession 
                ? _breathingAnimation 
                : _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: mindfulnessService.isInSession 
                    ? _breathingAnimation.value 
                    : _pulseAnimation.value,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: mindfulnessService.isInSession
                          ? [AppColors.accentViolet, AppColors.accentPink]
                          : [AppColors.accentViolet.withOpacity(0.7), AppColors.accentViolet],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentViolet.withOpacity(0.4),
                        blurRadius: mindfulnessService.isInSession ? 15 : 10,
                        spreadRadius: mindfulnessService.isInSession ? 3 : 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    mindfulnessService.isInSession 
                        ? Icons.self_improvement_rounded 
                        : Icons.spa_rounded,
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
                  'Mindfulness',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.accentViolet,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getStatusText(mindfulnessService, totalSessions, totalMinutes),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (mindfulnessService.isInSession) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentViolet.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'In Session',
                style: TextStyle(
                  color: AppColors.accentViolet,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: AppColors.accentViolet,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSession(MindfulnessService mindfulnessService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentViolet.withOpacity(0.2),
            AppColors.accentPink.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentViolet.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Breathing Animation Circle
          AnimatedBuilder(
            animation: _breathingAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _breathingAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accentViolet.withOpacity(0.3),
                        AppColors.accentPink.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.accentViolet, AppColors.accentPink],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.self_improvement_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            _getMeditationTypeLabel(mindfulnessService.currentSession?.type),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.accentViolet,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getBreathingInstruction(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pauseResumeMeditation(mindfulnessService),
                icon: Icon(Icons.pause_rounded, size: 18),
                label: const Text('Pause'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentViolet.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _stopMeditation(mindfulnessService),
                icon: Icon(Icons.stop_rounded, size: 18),
                label: const Text('End'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewSelector() {
    return Row(
      children: [
        _buildViewTab('practice', 'Practice', Icons.self_improvement_rounded),
        _buildViewTab('sessions', 'History', Icons.history_rounded),
        _buildViewTab('stats', 'Insights', Icons.analytics_rounded),
      ],
    );
  }

  Widget _buildViewTab(String view, String label, IconData icon) {
    final isSelected = _selectedView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedView = view),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.accentViolet.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? AppColors.accentViolet 
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.accentViolet : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected ? AppColors.accentViolet : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedView(MindfulnessService mindfulnessService) {
    switch (_selectedView) {
      case 'practice':
        return _buildPracticeView(mindfulnessService);
      case 'sessions':
        return _buildSessionsView(mindfulnessService);
      case 'stats':
        return _buildStatsView(mindfulnessService);
      default:
        return _buildPracticeView(mindfulnessService);
    }
  }

  Widget _buildPracticeView(MindfulnessService mindfulnessService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Practice',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Quick actions
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickPracticeChip('3-min Breathing', MeditationType.breathingExercise, SessionDuration.quick),
            _buildQuickPracticeChip('5-min Mindfulness', MeditationType.mindfulnessBreak, SessionDuration.short),
            _buildQuickPracticeChip('Stress Relief', MeditationType.stressRelease, SessionDuration.short),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Personalized recommendation
        Builder(
          builder: (context) {
            // Try to get mood service from provider, but handle if not available
            try {
              final moodService = Provider.of<MoodAnalysisService>(context, listen: false);
              final recommendedType = mindfulnessService.getRecommendedMeditation(moodService.currentMood);
              return _buildRecommendationTile(recommendedType, moodService.currentMood, mindfulnessService);
            } catch (e) {
              // Fallback if mood service not available
              final recommendedType = mindfulnessService.getRecommendedMeditation(null);
              return _buildRecommendationTile(recommendedType, null, mindfulnessService);
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // All meditation types
        Text(
          'All Practices',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...MeditationType.values.take(6).map((type) => _buildMeditationTile(type, mindfulnessService)).toList(),
      ],
    );
  }

  Widget _buildQuickPracticeChip(String label, MeditationType type, SessionDuration duration) {
    return ActionChip(
      avatar: Icon(
        _getMeditationIcon(type),
        size: 16,
        color: AppColors.accentViolet,
      ),
      label: Text(label),
      backgroundColor: AppColors.primaryMid,
      side: BorderSide(color: AppColors.accentViolet.withOpacity(0.3)),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textPrimary,
      ),
      onPressed: () => _startQuickMeditation(type, duration),
    );
  }

  Widget _buildRecommendationTile(MeditationType type, MoodType? currentMood, MindfulnessService mindfulnessService) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentViolet.withOpacity(0.2),
            AppColors.accentPink.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentViolet.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentViolet.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.recommend_rounded,
              color: AppColors.accentViolet,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommended for you',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.accentViolet,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_getMeditationTypeLabel(type)}${currentMood != null ? ' - Perfect for when you\'re ${_getMoodLabel(currentMood)}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showMeditationOptions(type, mindfulnessService),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentViolet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text('Start', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildMeditationTile(MeditationType type, MindfulnessService mindfulnessService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _getMeditationColor(type).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getMeditationIcon(type),
            color: _getMeditationColor(type),
            size: 18,
          ),
        ),
        title: Text(
          _getMeditationTypeLabel(type),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          _getMeditationDescription(type),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.play_arrow_rounded,
          color: AppColors.accentViolet,
        ),
        onTap: () => _showMeditationOptions(type, mindfulnessService),
      ),
    );
  }

  Widget _buildSessionsView(MindfulnessService mindfulnessService) {
    final recentSessions = mindfulnessService.sessions.take(10).toList();
    
    if (recentSessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              color: AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No sessions yet',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start your first meditation to see your practice history here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Sessions',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...recentSessions.map((session) => _buildSessionTile(session)).toList(),
      ],
    );
  }

  Widget _buildSessionTile(MeditationSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: session.completed 
                  ? AppColors.accentGreen.withOpacity(0.2)
                  : AppColors.textSecondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              session.completed 
                  ? Icons.check_rounded 
                  : Icons.pause_rounded,
              color: session.completed 
                  ? AppColors.accentGreen 
                  : AppColors.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getMeditationTypeLabel(session.type),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${session.actualMinutes} min • ${_formatDate(session.startTime)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (session.rating != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) => Icon(
                index < session.rating! 
                    ? Icons.star_rounded 
                    : Icons.star_border_rounded,
                color: AppColors.accentOrange,
                size: 14,
              )),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsView(MindfulnessService mindfulnessService) {
    final stats = mindfulnessService.getMeditationStats(days: 30);
    final totalSessions = stats['totalSessions'] as int;
    final totalMinutes = stats['totalMinutes'] as int;
    final streak = stats['streak'] as int;
    final averageRating = stats['averageRating'] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '30-Day Summary',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        // Stats grid
        Row(
          children: [
            Expanded(child: _buildStatCard('Sessions', '$totalSessions', Icons.self_improvement_rounded, AppColors.accentViolet)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Minutes', '$totalMinutes', Icons.timer_rounded, AppColors.accentCyan)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('Streak', '${streak}d', Icons.local_fire_department_rounded, AppColors.accentOrange)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Rating', averageRating != null ? '$averageRating★' : 'N/A', Icons.star_rounded, AppColors.accentGreen)),
          ],
        ),
        
        if (totalSessions >= 3) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress Insights',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _generateInsightMessage(totalSessions, totalMinutes, streak),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Actions
  void _startQuickMeditation(MeditationType type, SessionDuration duration) async {
    if (_mindfulnessService == null) return;
    
    _breathingController.repeat(reverse: true);
    
    await _mindfulnessService!.startMeditation(
      type: type,
      duration: duration,
    );
    
    if (widget.onMindfulnessMessage != null) {
      widget.onMindfulnessMessage!('I just started a ${_getMeditationTypeLabel(type)} session. This always helps me feel more centered and calm.');
    }
  }

  void _showMeditationOptions(MeditationType type, MindfulnessService mindfulnessService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primaryDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildMeditationOptionsSheet(type, mindfulnessService),
    );
  }

  Widget _buildMeditationOptionsSheet(MeditationType type, MindfulnessService mindfulnessService) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getMeditationIcon(type),
                color: _getMeditationColor(type),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _getMeditationTypeLabel(type),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getMeditationDescription(type),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Choose Duration',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildDurationChip('3 min', SessionDuration.quick, type, mindfulnessService),
              _buildDurationChip('7 min', SessionDuration.short, type, mindfulnessService),
              _buildDurationChip('12 min', SessionDuration.medium, type, mindfulnessService),
              _buildDurationChip('25 min', SessionDuration.long, type, mindfulnessService),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDurationChip(String label, SessionDuration duration, MeditationType type, MindfulnessService mindfulnessService) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.primaryMid,
      side: BorderSide(color: AppColors.accentViolet.withOpacity(0.3)),
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
      ),
      onPressed: () {
        Navigator.pop(context);
        _startMeditation(type, duration, mindfulnessService);
      },
    );
  }

  void _startMeditation(MeditationType type, SessionDuration duration, MindfulnessService mindfulnessService) async {
    _breathingController.repeat(reverse: true);
    
    await mindfulnessService.startMeditation(
      type: type,
      duration: duration,
    );
    
    if (widget.onMindfulnessMessage != null) {
      widget.onMindfulnessMessage!('I\'m starting a ${_getMeditationTypeLabel(type)} meditation session. Taking this time to nurture my wellbeing feels so important.');
    }
  }

  void _pauseResumeMeditation(MindfulnessService mindfulnessService) {
    mindfulnessService.pauseResumeMeditation();
    
    if (mindfulnessService.isInSession) {
      _breathingController.repeat(reverse: true);
    } else {
      _breathingController.stop();
    }
  }

  void _stopMeditation(MindfulnessService mindfulnessService) async {
    _breathingController.stop();
    
    await mindfulnessService.stopMeditation(
      completed: false,
      notes: 'Session ended early',
    );
    
    if (widget.onMindfulnessMessage != null) {
      widget.onMindfulnessMessage!('I ended my meditation session early, but even a few mindful moments make a difference. Every bit of self-care counts.');
    }
  }

  // Helper methods
  String _getStatusText(MindfulnessService mindfulnessService, int totalSessions, int totalMinutes) {
    if (mindfulnessService.isInSession) {
      return 'Currently meditating...';
    } else if (totalSessions == 0) {
      return 'Ready for your first session';
    } else {
      return '$totalSessions sessions this week • $totalMinutes minutes';
    }
  }

  String _getBreathingInstruction() {
    final instructions = [
      'Breathe in slowly... breathe out gently',
      'Follow your natural rhythm',
      'Let each breath bring calm',
      'Notice the pause between breaths',
      'Feel your body settling with each exhale',
    ];
    return instructions[DateTime.now().second % instructions.length];
  }

  IconData _getMeditationIcon(MeditationType type) {
    switch (type) {
      case MeditationType.guidedMeditation:
        return Icons.self_improvement_rounded;
      case MeditationType.breathingExercise:
        return Icons.air_rounded;
      case MeditationType.bodyscan:
        return Icons.accessibility_new_rounded;
      case MeditationType.lovingKindness:
        return Icons.favorite_rounded;
      case MeditationType.mindfulnessBreak:
        return Icons.pause_circle_rounded;
      case MeditationType.sleepMeditation:
        return Icons.bedtime_rounded;
      case MeditationType.anxietyRelief:
        return Icons.healing_rounded;
      case MeditationType.stressRelease:
        return Icons.spa_rounded;
      case MeditationType.focusBoost:
        return Icons.center_focus_strong_rounded;
      case MeditationType.gratitudePractice:
        return Icons.wb_sunny_rounded;
    }
  }

  Color _getMeditationColor(MeditationType type) {
    switch (type) {
      case MeditationType.guidedMeditation:
        return AppColors.accentViolet;
      case MeditationType.breathingExercise:
        return AppColors.accentCyan;
      case MeditationType.bodyscan:
        return AppColors.accentGreen;
      case MeditationType.lovingKindness:
        return AppColors.accentPink;
      case MeditationType.mindfulnessBreak:
        return AppColors.accentViolet;
      case MeditationType.sleepMeditation:
        return Colors.indigo;
      case MeditationType.anxietyRelief:
        return AppColors.accentCyan;
      case MeditationType.stressRelease:
        return AppColors.accentGreen;
      case MeditationType.focusBoost:
        return AppColors.accentOrange;
      case MeditationType.gratitudePractice:
        return Colors.amber;
    }
  }

  String _getMeditationTypeLabel(MeditationType? type) {
    if (type == null) return 'Meditation';
    
    switch (type) {
      case MeditationType.guidedMeditation:
        return 'Guided Meditation';
      case MeditationType.breathingExercise:
        return 'Breathing Exercise';
      case MeditationType.bodyscan:
        return 'Body Scan';
      case MeditationType.lovingKindness:
        return 'Loving Kindness';
      case MeditationType.mindfulnessBreak:
        return 'Mindful Pause';
      case MeditationType.sleepMeditation:
        return 'Sleep Meditation';
      case MeditationType.anxietyRelief:
        return 'Anxiety Relief';
      case MeditationType.stressRelease:
        return 'Stress Release';
      case MeditationType.focusBoost:
        return 'Focus Boost';
      case MeditationType.gratitudePractice:
        return 'Gratitude Practice';
    }
  }

  String _getMeditationDescription(MeditationType type) {
    switch (type) {
      case MeditationType.guidedMeditation:
        return 'Gentle guidance for mindful awareness';
      case MeditationType.breathingExercise:
        return 'Focus on breath to calm the mind';
      case MeditationType.bodyscan:
        return 'Progressive relaxation through body awareness';
      case MeditationType.lovingKindness:
        return 'Cultivate compassion for self and others';
      case MeditationType.mindfulnessBreak:
        return 'Quick pause for present moment awareness';
      case MeditationType.sleepMeditation:
        return 'Prepare your mind and body for rest';
      case MeditationType.anxietyRelief:
        return 'Techniques to ease anxious thoughts';
      case MeditationType.stressRelease:
        return 'Let go of tension and worries';
      case MeditationType.focusBoost:
        return 'Enhance concentration and mental clarity';
      case MeditationType.gratitudePractice:
        return 'Appreciate the good in your life';
    }
  }

  String _getMoodLabel(MoodType mood) {
    switch (mood) {
      case MoodType.stressed:
        return 'stressed';
      case MoodType.anxious:
        return 'anxious';
      case MoodType.tired:
        return 'tired';
      case MoodType.overwhelmed:
        return 'overwhelmed';
      case MoodType.happy:
        return 'happy';
      case MoodType.energetic:
        return 'energetic';
      case MoodType.calm:
        return 'calm';
      case MoodType.focused:
        return 'focused';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  String _generateInsightMessage(int sessions, int minutes, int streak) {
    if (streak >= 7) {
      return 'Amazing! You\'ve meditated for $streak days straight. This consistency is building real neural pathways for calm.';
    } else if (sessions >= 10) {
      return 'You\'ve completed $sessions meditation sessions! Your practice is developing beautifully.';
    } else if (minutes >= 60) {
      return 'You\'ve spent $minutes minutes in mindfulness this month. Each moment contributes to your wellbeing.';
    } else {
      return 'You\'re building a wonderful foundation for mindfulness. Every session makes a difference.';
    }
  }
}