import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../services/habit_tracking_service.dart';
import '../theme/app_theme.dart';

class HabitTrackingWidget extends StatefulWidget {
  final Function(String)? onHabitMessage;
  
  const HabitTrackingWidget({
    super.key,
    this.onHabitMessage,
  });

  @override
  State<HabitTrackingWidget> createState() => _HabitTrackingWidgetState();
}

class _HabitTrackingWidgetState extends State<HabitTrackingWidget> 
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  HabitTrackingService? _habitService;
  bool _isExpanded = false;
  String _selectedView = 'today'; // 'today', 'progress', 'insights'

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeHabitService();
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
  }

  void _initializeHabitService() async {
    _habitService = HabitTrackingService();
    await _habitService!.initialize();
    if (mounted) {
      setState(() {});
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_habitService == null) {
      return const SizedBox.shrink();
    }

    return ChangeNotifierProvider.value(
      value: _habitService,
      child: Consumer<HabitTrackingService>(
        builder: (context, habitService, child) {
          return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentGreen.withOpacity(0.1),
                  AppColors.accentCyan.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accentGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(habitService),
                  if (_isExpanded) ...[
                    const SizedBox(height: 16),
                    _buildViewSelector(),
                    const SizedBox(height: 16),
                    _buildSelectedView(habitService),
                  ],
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms);
        },
      ),
    );
  }

  Widget _buildHeader(HabitTrackingService habitService) {
    final progress = habitService.getOverallProgress(days: 7);
    final completionRate = progress['completionRate'] as double;
    final todaysHabits = habitService.getTodaysHabits();

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CircularProgressIndicator(
                      value: completionRate * _progressAnimation.value,
                      backgroundColor: AppColors.accentGreen.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(AppColors.accentGreen),
                      strokeWidth: 4,
                    );
                  },
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentGreen,
                      AppColors.accentCyan,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getProgressIcon(completionRate),
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wellness Habits',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getStatusText(habitService, completionRate, todaysHabits.length),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (habitService.unreadInsights.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentOrange,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${habitService.unreadInsights.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: AppColors.accentGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildViewSelector() {
    return Row(
      children: [
        _buildViewTab('today', 'Today', Icons.today_rounded),
        _buildViewTab('progress', 'Progress', Icons.trending_up_rounded),
        _buildViewTab('insights', 'Insights', Icons.lightbulb_rounded),
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
                ? AppColors.accentGreen.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? AppColors.accentGreen 
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
                color: isSelected ? AppColors.accentGreen : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected ? AppColors.accentGreen : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedView(HabitTrackingService habitService) {
    switch (_selectedView) {
      case 'today':
        return _buildTodayView(habitService);
      case 'progress':
        return _buildProgressView(habitService);
      case 'insights':
        return _buildInsightsView(habitService);
      default:
        return _buildTodayView(habitService);
    }
  }

  Widget _buildTodayView(HabitTrackingService habitService) {
    final todaysHabits = habitService.getTodaysHabits();
    
    if (todaysHabits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.accentGreen,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'All caught up for today!',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.accentGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Great job staying on track with your wellness routine.',
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
          'Today\'s Habits (${todaysHabits.length})',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...todaysHabits.map((habit) => _buildHabitTile(habit, habitService)).toList(),
      ],
    );
  }

  Widget _buildHabitTile(WellnessHabit habit, HabitTrackingService habitService) {
    final stats = habitService.getHabitStats(habit.id, days: 7);
    final streak = stats['currentStreak'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentGreen.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getHabitTypeColor(habit.type).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getHabitTypeIcon(habit.type),
              color: _getHabitTypeColor(habit.type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${habit.targetDuration} min • ${_getDifficultyLabel(habit.difficulty)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (streak > 0)
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: AppColors.accentOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak day streak',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.accentOrange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _completeHabit(habit, habitService),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Done', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressView(HabitTrackingService habitService) {
    final progress = habitService.getOverallProgress(days: 7);
    final habits = habitService.habits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOverallProgress(progress),
        const SizedBox(height: 16),
        Text(
          'Individual Habits',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...habits.map((habit) => _buildHabitProgress(habit, habitService)).toList(),
      ],
    );
  }

  Widget _buildOverallProgress(Map<String, dynamic> progress) {
    final completionRate = progress['completionRate'] as double;
    final totalCompleted = progress['totalCompleted'] as int;
    final totalExpected = progress['totalExpected'] as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week\'s Progress',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(completionRate * 100).round()}%',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Completion Rate',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalCompleted/$totalExpected',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Habits Completed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: completionRate,
            backgroundColor: AppColors.accentGreen.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(AppColors.accentGreen),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitProgress(WellnessHabit habit, HabitTrackingService habitService) {
    final stats = habitService.getHabitStats(habit.id, days: 7);
    final completionRate = stats['completionRate'] as double;
    final streak = stats['currentStreak'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getHabitTypeIcon(habit.type),
                color: _getHabitTypeColor(habit.type),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  habit.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${(completionRate * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.accentGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: completionRate,
            backgroundColor: _getHabitTypeColor(habit.type).withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(_getHabitTypeColor(habit.type)),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          if (streak > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 12,
                  color: AppColors.accentOrange,
                ),
                const SizedBox(width: 4),
                Text(
                  '$streak day streak',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.accentOrange,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsView(HabitTrackingService habitService) {
    final insights = habitService.insights.take(5).toList();

    if (insights.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.lightbulb_outlined,
              color: AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Building insights...',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Keep tracking your habits and I\'ll provide personalized insights.',
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
          'Coaching Insights',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) => _buildInsightTile(insight, habitService)).toList(),
      ],
    );
  }

  Widget _buildInsightTile(CoachingInsight insight, HabitTrackingService habitService) {
    final color = _getInsightColor(insight.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          Row(
            children: [
              Icon(
                _getInsightIcon(insight.type),
                color: color,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!insight.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatTimeAgo(insight.timestamp),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (!insight.isRead)
                TextButton(
                  onPressed: () {
                    habitService.markInsightAsRead(insight.id);
                    if (widget.onHabitMessage != null) {
                      widget.onHabitMessage!(insight.message);
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Share with ARIA',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _completeHabit(WellnessHabit habit, HabitTrackingService habitService) async {
    await habitService.completeHabit(
      habitId: habit.id,
      notes: 'Completed via habit tracker',
    );

    if (widget.onHabitMessage != null) {
      final messages = [
        'I just completed my ${habit.name}! Feeling great about staying consistent.',
        'Just finished ${habit.name} for today. It\'s becoming such a positive part of my routine.',
        'Completed ${habit.name}! Small steps every day really do make a difference.',
        'Just did my ${habit.name} - love how this habit is supporting my wellness.',
      ];
      final message = messages[Random().nextInt(messages.length)];
      widget.onHabitMessage!(message);
    }

    // Show completion animation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('${habit.name} completed! 🎉'),
          ],
        ),
        backgroundColor: AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Helper methods
  IconData _getProgressIcon(double completionRate) {
    if (completionRate >= 0.9) return Icons.emoji_events_rounded;
    if (completionRate >= 0.7) return Icons.trending_up_rounded;
    if (completionRate >= 0.4) return Icons.timeline_rounded;
    return Icons.flag_rounded;
  }

  String _getStatusText(HabitTrackingService habitService, double completionRate, int todaysCount) {
    if (todaysCount == 0) {
      return 'All habits complete today! ${(completionRate * 100).round()}% this week';
    } else {
      return '$todaysCount habits remaining • ${(completionRate * 100).round()}% this week';
    }
  }

  IconData _getHabitTypeIcon(HabitType type) {
    switch (type) {
      case HabitType.exercise:
        return Icons.fitness_center_rounded;
      case HabitType.meditation:
        return Icons.self_improvement_rounded;
      case HabitType.sleep:
        return Icons.bedtime_rounded;
      case HabitType.hydration:
        return Icons.local_drink_rounded;
      case HabitType.nutrition:
        return Icons.restaurant_rounded;
      case HabitType.socializing:
        return Icons.people_rounded;
      case HabitType.learning:
        return Icons.school_rounded;
      case HabitType.creativity:
        return Icons.palette_rounded;
      case HabitType.outdoors:
        return Icons.park_rounded;
      case HabitType.gratitude:
        return Icons.favorite_rounded;
      case HabitType.breathingExercise:
        return Icons.air_rounded;
      case HabitType.stretching:
        return Icons.accessibility_new_rounded;
      case HabitType.reading:
        return Icons.book_rounded;
      case HabitType.journaling:
        return Icons.edit_note_rounded;
      case HabitType.selfCare:
        return Icons.spa_rounded;
    }
  }

  Color _getHabitTypeColor(HabitType type) {
    switch (type) {
      case HabitType.exercise:
        return AppColors.accentOrange;
      case HabitType.meditation:
        return AppColors.accentViolet;
      case HabitType.sleep:
        return AppColors.accentCyan;
      case HabitType.hydration:
        return Colors.blue;
      case HabitType.nutrition:
        return AppColors.accentGreen;
      case HabitType.socializing:
        return AppColors.accentPink;
      case HabitType.learning:
        return Colors.indigo;
      case HabitType.creativity:
        return Colors.purple;
      case HabitType.outdoors:
        return Colors.green;
      case HabitType.gratitude:
        return AppColors.accentPink;
      case HabitType.breathingExercise:
        return AppColors.accentCyan;
      case HabitType.stretching:
        return AppColors.accentViolet;
      case HabitType.reading:
        return Colors.brown;
      case HabitType.journaling:
        return Colors.teal;
      case HabitType.selfCare:
        return AppColors.accentViolet;
    }
  }

  String _getDifficultyLabel(HabitDifficulty difficulty) {
    switch (difficulty) {
      case HabitDifficulty.easy:
        return 'Easy';
      case HabitDifficulty.moderate:
        return 'Moderate';
      case HabitDifficulty.challenging:
        return 'Challenging';
    }
  }

  Color _getInsightColor(String type) {
    switch (type) {
      case 'celebration':
        return AppColors.accentGreen;
      case 'encouragement':
        return AppColors.accentCyan;
      case 'suggestion':
        return AppColors.accentViolet;
      case 'concern':
        return AppColors.accentOrange;
      default:
        return AppColors.accentCyan;
    }
  }

  IconData _getInsightIcon(String type) {
    switch (type) {
      case 'celebration':
        return Icons.celebration_rounded;
      case 'encouragement':
        return Icons.favorite_rounded;
      case 'suggestion':
        return Icons.lightbulb_rounded;
      case 'concern':
        return Icons.info_rounded;
      default:
        return Icons.lightbulb_rounded;
    }
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}