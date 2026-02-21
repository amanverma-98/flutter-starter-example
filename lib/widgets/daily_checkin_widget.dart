import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/chat_models.dart';
import '../services/daily_checkin_service.dart';
import '../theme/app_theme.dart';

class DailyCheckInWidget extends StatefulWidget {
  final Function(String)? onCheckInMessage;
  
  const DailyCheckInWidget({
    super.key,
    this.onCheckInMessage,
  });

  @override
  State<DailyCheckInWidget> createState() => _DailyCheckInWidgetState();
}

class _DailyCheckInWidgetState extends State<DailyCheckInWidget> 
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  
  DailyCheckInService? _checkInService;
  bool _isExpanded = false;
  String _selectedView = 'checkin'; // 'checkin', 'insights', 'history'

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCheckInService();
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _pulseController.repeat(reverse: true);
  }

  void _initializeCheckInService() async {
    // This will be initialized when integrated with other services
    setState(() {});
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DailyCheckInService>(
      builder: (context, checkInService, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accentOrange.withOpacity(0.1),
                AppColors.accentPink.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentOrange.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(checkInService),
                if (_isExpanded) ...[
                  const SizedBox(height: 16),
                  _buildViewSelector(),
                  const SizedBox(height: 16),
                  _buildSelectedView(checkInService),
                ],
              ],
            ),
          ),
        ).animate().fadeIn(duration: 400.ms);
      },
    );
  }

  Widget _buildHeader(DailyCheckInService checkInService) {
    final hasCheckedIn = checkInService.hasCheckedInToday;
    final completionScore = checkInService.todaysCheckIn?.completionScore ?? 0.0;
    final unreadInsights = checkInService.unreadInsights.length;

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
                      value: completionScore * _progressAnimation.value,
                      backgroundColor: AppColors.accentOrange.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(AppColors.accentOrange),
                      strokeWidth: 3,
                    );
                  },
                ),
              ),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: hasCheckedIn ? 1.0 : _pulseAnimation.value,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: hasCheckedIn
                              ? [AppColors.accentGreen, AppColors.accentCyan]
                              : [AppColors.accentOrange, AppColors.accentPink],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (hasCheckedIn ? AppColors.accentGreen : AppColors.accentOrange)
                                .withOpacity(0.4),
                            blurRadius: hasCheckedIn ? 8 : 12,
                            spreadRadius: hasCheckedIn ? 1 : 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        hasCheckedIn 
                            ? Icons.check_rounded 
                            : Icons.favorite_border_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Check-In',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.accentOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getStatusText(checkInService),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (unreadInsights > 0) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentPink,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$unreadInsights',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: AppColors.accentOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildViewSelector() {
    return Row(
      children: [
        _buildViewTab('checkin', 'Check-In', Icons.favorite_rounded),
        _buildViewTab('insights', 'Insights', Icons.psychology_rounded),
        _buildViewTab('history', 'History', Icons.calendar_today_rounded),
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
                ? AppColors.accentOrange.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? AppColors.accentOrange 
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
                color: isSelected ? AppColors.accentOrange : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected ? AppColors.accentOrange : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedView(DailyCheckInService checkInService) {
    switch (_selectedView) {
      case 'checkin':
        return _buildCheckInView(checkInService);
      case 'insights':
        return _buildInsightsView(checkInService);
      case 'history':
        return _buildHistoryView(checkInService);
      default:
        return _buildCheckInView(checkInService);
    }
  }

  Widget _buildCheckInView(DailyCheckInService checkInService) {
    final hasCheckedIn = checkInService.hasCheckedInToday;
    final completionScore = checkInService.todaysCheckIn?.completionScore ?? 0.0;

    if (hasCheckedIn && completionScore >= 0.8) {
      return _buildCompletedCheckIn(checkInService);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasCheckedIn ? 'Continue Your Check-In' : 'How Are You Today?',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Quick mood buttons
        Text(
          'Current Mood',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _buildMoodChips(checkInService),
        ),
        
        const SizedBox(height: 16),
        
        // Energy level
        _buildEnergySelector(checkInService),
        
        const SizedBox(height: 16),
        
        // Stress level
        _buildStressSelector(checkInService),
        
        const SizedBox(height: 16),
        
        // Gratitude prompt
        _buildGratitudePrompt(checkInService),
      ],
    );
  }

  List<Widget> _buildMoodChips(DailyCheckInService checkInService) {
    final moods = [
      ('😊', 'Happy', MoodType.happy),
      ('⚡', 'Energetic', MoodType.energetic),
      ('🧘', 'Calm', MoodType.calm),
      ('😰', 'Stressed', MoodType.stressed),
      ('😴', 'Tired', MoodType.tired),
      ('😟', 'Anxious', MoodType.anxious),
    ];

    final currentMood = checkInService.todaysCheckIn?.responses[CheckInCategory.mood];

    return moods.map((moodData) {
      final emoji = moodData.$1;
      final label = moodData.$2;
      final moodType = moodData.$3;
      final isSelected = currentMood == moodType.name;

      return ActionChip(
        avatar: Text(emoji, style: const TextStyle(fontSize: 16)),
        label: Text(label),
        backgroundColor: isSelected 
            ? AppColors.accentOrange.withOpacity(0.2)
            : AppColors.primaryMid,
        side: BorderSide(
          color: isSelected 
              ? AppColors.accentOrange 
              : AppColors.accentOrange.withOpacity(0.3),
        ),
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isSelected ? AppColors.accentOrange : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        onPressed: () => _updateCheckIn(checkInService, CheckInCategory.mood, moodType.name),
      );
    }).toList();
  }

  Widget _buildEnergySelector(DailyCheckInService checkInService) {
    final currentEnergy = checkInService.todaysCheckIn?.responses[CheckInCategory.energy] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Energy Level (1-10)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: (currentEnergy ?? 5).toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: (currentEnergy ?? 5).toString(),
                activeColor: AppColors.accentGreen,
                inactiveColor: AppColors.accentGreen.withOpacity(0.3),
                onChanged: (value) => _updateCheckIn(
                  checkInService, 
                  CheckInCategory.energy, 
                  value.round(),
                ),
              ),
            ),
            Container(
              width: 40,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${currentEnergy ?? 5}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStressSelector(DailyCheckInService checkInService) {
    final currentStress = checkInService.todaysCheckIn?.responses[CheckInCategory.stress] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stress Level (1-10)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: (currentStress ?? 5).toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: (currentStress ?? 5).toString(),
                activeColor: AppColors.accentOrange,
                inactiveColor: AppColors.accentOrange.withOpacity(0.3),
                onChanged: (value) => _updateCheckIn(
                  checkInService, 
                  CheckInCategory.stress, 
                  value.round(),
                ),
              ),
            ),
            Container(
              width: 40,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${currentStress ?? 5}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.accentOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGratitudePrompt(DailyCheckInService checkInService) {
    final hasGratitude = checkInService.todaysCheckIn?.responses
        .containsKey(CheckInCategory.gratitude) == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentPink.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentPink.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                color: AppColors.accentPink,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Gratitude Moment',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.accentPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasGratitude 
                ? '✨ ${checkInService.todaysCheckIn!.responses[CheckInCategory.gratitude]}'
                : 'What\'s one thing you\'re grateful for today?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: hasGratitude ? AppColors.textPrimary : AppColors.textSecondary,
              fontStyle: hasGratitude ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (!hasGratitude) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showGratitudeDialog(checkInService),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Share Gratitude'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedCheckIn(DailyCheckInService checkInService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentGreen.withOpacity(0.2),
            AppColors.accentCyan.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.accentGreen,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Check-In Complete!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.accentGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thank you for taking time to reflect on your wellbeing today. Your self-awareness is a gift to your future self.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _shareCheckInWithAria(checkInService),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('Share with ARIA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsView(DailyCheckInService checkInService) {
    final insights = checkInService.insights.take(8).toList();

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
              Icons.psychology_outlined,
              color: AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Building Insights...',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete a few check-ins and I\'ll start generating personalized wellness insights for you.',
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
          'Wellness Insights',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) => _buildInsightTile(insight, checkInService)).toList(),
      ],
    );
  }

  Widget _buildInsightTile(WellnessInsight insight, DailyCheckInService checkInService) {
    final color = _getInsightColor(insight.category);
    
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
                _getInsightIcon(insight.category),
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
                  onPressed: () => _shareInsightWithAria(insight, checkInService),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Discuss with ARIA',
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

  Widget _buildHistoryView(DailyCheckInService checkInService) {
    final recentCheckIns = checkInService.checkIns.take(10).toList();
    
    if (recentCheckIns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No Check-Ins Yet',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start your first daily check-in to see your wellness journey here.',
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
          'Recent Check-Ins',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...recentCheckIns.map((checkIn) => _buildHistoryTile(checkIn)).toList(),
      ],
    );
  }

  Widget _buildHistoryTile(DailyCheckIn checkIn) {
    final completionPercentage = (checkIn.completionScore * 100).round();
    
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
              color: _getCompletionColor(checkIn.completionScore).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${checkIn.date.day}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _getCompletionColor(checkIn.completionScore),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(checkIn.date),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$completionPercentage% complete • ${checkIn.responses.length} categories',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: checkIn.completionScore,
            backgroundColor: AppColors.accentOrange.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(_getCompletionColor(checkIn.completionScore)),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  // Actions
  void _updateCheckIn(DailyCheckInService checkInService, CheckInCategory category, dynamic value) async {
    await checkInService.updateCheckIn(category, value);
    
    // Trigger progress animation
    _progressController.forward();
    
    if (widget.onCheckInMessage != null) {
      final message = _generateCheckInMessage(category, value);
      widget.onCheckInMessage!(message);
    }
  }

  void _showGratitudeDialog(DailyCheckInService checkInService) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryDark,
        title: Row(
          children: [
            Icon(Icons.favorite_rounded, color: AppColors.accentPink),
            const SizedBox(width: 8),
            const Text('Gratitude'),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'What are you grateful for today?',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _updateCheckIn(checkInService, CheckInCategory.gratitude, controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPink,
            ),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _shareCheckInWithAria(DailyCheckInService checkInService) {
    if (widget.onCheckInMessage != null) {
      widget.onCheckInMessage!(checkInService.generateCheckInMessage());
    }
  }

  void _shareInsightWithAria(WellnessInsight insight, DailyCheckInService checkInService) {
    checkInService.markInsightAsRead(insight.id);
    if (widget.onCheckInMessage != null) {
      widget.onCheckInMessage!(insight.message);
    }
  }

  // Helper methods
  String _getStatusText(DailyCheckInService checkInService) {
    if (!checkInService.hasCheckedInToday) {
      final hour = DateTime.now().hour;
      if (hour < 12) {
        return 'Good morning! Ready for today\'s check-in?';
      } else if (hour < 17) {
        return 'How\'s your day going?';
      } else {
        return 'Evening reflection time';
      }
    } else {
      final completion = (checkInService.todaysCheckIn!.completionScore * 100).round();
      return '$completion% complete • Keep reflecting!';
    }
  }

  String _generateCheckInMessage(CheckInCategory category, dynamic value) {
    switch (category) {
      case CheckInCategory.mood:
        return 'I\'m feeling $value today. It helps to acknowledge and name my emotions.';
      case CheckInCategory.energy:
        return 'My energy level is at $value/10 today. Being aware of this helps me plan my activities mindfully.';
      case CheckInCategory.stress:
        return 'My stress level is $value/10 right now. Tracking this helps me understand my patterns and triggers.';
      case CheckInCategory.gratitude:
        return 'I\'m feeling grateful for: $value. Taking time for gratitude always lifts my spirits.';
      default:
        return 'I just updated my daily check-in. This self-reflection practice is so valuable for my wellbeing.';
    }
  }

  Color _getInsightColor(String category) {
    switch (category) {
      case 'achievement':
        return AppColors.accentGreen;
      case 'concern':
        return AppColors.accentOrange;
      case 'pattern':
        return AppColors.accentViolet;
      case 'suggestion':
        return AppColors.accentCyan;
      default:
        return AppColors.accentOrange;
    }
  }

  IconData _getInsightIcon(String category) {
    switch (category) {
      case 'achievement':
        return Icons.emoji_events_rounded;
      case 'concern':
        return Icons.warning_rounded;
      case 'pattern':
        return Icons.trending_up_rounded;
      case 'suggestion':
        return Icons.lightbulb_rounded;
      default:
        return Icons.insights_rounded;
    }
  }

  Color _getCompletionColor(double score) {
    if (score >= 0.8) return AppColors.accentGreen;
    if (score >= 0.5) return AppColors.accentCyan;
    if (score >= 0.3) return AppColors.accentOrange;
    return AppColors.textSecondary;
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}';
    }
  }
}