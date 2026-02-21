import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:runanywhere/runanywhere.dart';

import '../services/model_service.dart';
import '../services/wellness_service.dart';
import '../services/mood_analysis_service.dart';
import '../services/habit_tracking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/model_loader_widget.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/mood_tracking_widget.dart';
import '../widgets/habit_tracking_widget.dart';
import '../widgets/mindfulness_widget.dart';
import '../models/chat_models.dart';

class AriaView extends StatefulWidget {
  const AriaView({super.key});

  @override
  State<AriaView> createState() => _AriaViewState();
}

class _AriaViewState extends State<AriaView> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  String _currentResponse = '';
  LLMStreamingResult? _streamingResult;
  
  late AnimationController _pulseController;
  late AnimationController _breathingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _breathingAnimation;
  
  WellnessService? _wellnessService;
  bool _showWellnessPrompts = false;
  MoodAnalysisService? _moodService;
  HabitTrackingService? _habitService;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeWellnessService();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _breathingAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
    
    _pulseController.repeat(reverse: true);
  }

  void _initializeWellnessService() async {
    _wellnessService = WellnessService();
    await _wellnessService!.initialize();
    
    // Initialize mood analysis service
    _moodService = MoodAnalysisService(_wellnessService!);
    
    // Initialize habit tracking service
    _habitService = Provider.of<HabitTrackingService>(context, listen: false);
    await _habitService!.initialize();
    
    if (mounted) {
      setState(() {});
      _startWithWellnessGreeting();
    }
  }

  void _startWithWellnessGreeting() {
    // Add an initial ARIA greeting if no messages exist
    if (_messages.isEmpty && _wellnessService != null) {
      final greeting = _generateContextualGreeting();
      setState(() {
        _messages.add(ChatMessage(
          text: greeting,
          isUser: false,
          timestamp: DateTime.now(),
          isAriaMessage: true,
        ));
      });
      _scrollToBottom();
    }
  }

  String _generateContextualGreeting() {
    final hour = DateTime.now().hour;
    final recentEntries = _wellnessService?.getRecentEntries(days: 1) ?? [];
    
    List<String> greetings = [];
    
    if (hour < 12) {
      greetings.addAll([
        'Good morning! I hope you slept well. How are you feeling as you start your day?',
        'Morning! What\'s on your mind today? I\'m here to listen and support you.',
        'Hello there! Ready to tackle a new day? I\'d love to hear how you\'re doing.',
      ]);
    } else if (hour < 17) {
      greetings.addAll([
        'Good afternoon! How has your day been treating you so far?',
        'Hey! Hope your day is going well. Want to share what\'s on your mind?',
        'Afternoon check-in! I\'m curious how you\'re feeling right now.',
      ]);
    } else {
      greetings.addAll([
        'Good evening! How are you winding down after your day?',
        'Evening! I hope you\'re taking some time for yourself. How are you feeling?',
        'Hey there! As the day comes to a close, how are you doing emotionally?',
      ]);
    }
    
    if (recentEntries.isEmpty) {
      greetings.add('I\'m ARIA, your personal wellness companion. I\'m here to listen, support, and help you with your wellbeing journey. What would you like to talk about?');
    }
    
    return greetings[Random().nextInt(greetings.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _streamingResult?.cancel();
    _pulseController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accentPink, AppColors.accentViolet],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentPink.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ARIA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(
                  'Wellness Companion',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.accentPink.withOpacity(0.8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _startNewSession,
              tooltip: 'New session',
            ),
          IconButton(
            icon: Icon(
              _showWellnessPrompts ? Icons.psychology : Icons.psychology_outlined,
              color: AppColors.accentPink,
            ),
            onPressed: _toggleWellnessPrompts,
            tooltip: 'Wellness tools',
          ),
        ],
      ),
      body: Consumer<ModelService>(
        builder: (context, modelService, child) {
          if (!modelService.isLLMLoaded) {
            return ModelLoaderWidget(
              title: 'ARIA needs her AI brain',
              subtitle: 'Download and load the language model so ARIA can chat with you',
              icon: Icons.favorite_rounded,
              accentColor: AppColors.accentPink,
              isDownloading: modelService.isLLMDownloading,
              isLoading: modelService.isLLMLoading,
              progress: modelService.llmDownloadProgress,
              onLoad: () => modelService.downloadAndLoadLLM(),
            );
          }

          return Column(
            children: [
              if (_showWellnessPrompts) _buildWellnessPrompts(),
              // Add mood tracking widget
              MoodTrackingWidget(
                onMoodMessage: (message) {
                  _controller.text = message;
                  _sendMessage();
                },
              ),
              // Add habit tracking widget
              HabitTrackingWidget(
                onHabitMessage: (message) {
                  _controller.text = message;
                  _sendMessage();
                },
              ),
              // Add mindfulness widget
              MindfulnessWidget(
                onMindfulnessMessage: (message) {
                  _controller.text = message;
                  _sendMessage();
                },
              ),
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessagesList(),
              ),
              _buildInputArea(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWellnessPrompts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.7),
        border: Border(
          bottom: BorderSide(
            color: AppColors.accentPink.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wellness Quick Actions',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.accentPink,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildWellnessChip('I\'m feeling stressed', Icons.sentiment_dissatisfied_rounded),
              _buildWellnessChip('Help me relax', Icons.spa_rounded),
              _buildWellnessChip('I need motivation', Icons.emoji_emotions_rounded),
              _buildWellnessChip('Breathing exercise', Icons.air_rounded),
              _buildWellnessChip('Daily check-in', Icons.favorite_rounded),
            ],
          ),
        ],
      ),
    ).animate().slideY(begin: -1, duration: 300.ms);
  }

  Widget _buildWellnessChip(String text, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.accentPink),
      label: Text(text),
      backgroundColor: AppColors.primaryMid,
      side: BorderSide(color: AppColors.accentPink.withOpacity(0.3)),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textPrimary,
      ),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _breathingAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _breathingAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accentPink.withOpacity(0.2),
                          AppColors.accentViolet.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accentPink, AppColors.accentViolet],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentPink.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Hello! I\'m ARIA',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.accentPink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your personal wellness companion.\nI\'m here to listen, support, and help you feel your best.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                _breathingController.repeat(reverse: true);
                Timer(const Duration(seconds: 8), () {
                  if (mounted) _breathingController.stop();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accentPink.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.air_rounded,
                      color: AppColors.accentPink,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tap for breathing exercise',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accentPink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isGenerating ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isGenerating) {
          return ChatMessageBubble(
            message: ChatMessage(
              text: _currentResponse.isEmpty ? 'ARIA is thinking...' : _currentResponse,
              isUser: false,
              timestamp: DateTime.now(),
              isAriaMessage: true,
            ),
            isStreaming: true,
          ).animate().fadeIn(duration: 300.ms);
        }

        return ChatMessageBubble(
          message: _messages[index],
        ).animate().fadeIn(duration: 300.ms).slideX(
          begin: _messages[index].isUser ? 0.1 : -0.1,
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.9),
        border: Border(
          top: BorderSide(
            color: AppColors.accentPink.withOpacity(0.2),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Share what\'s on your mind...',
                  filled: true,
                  fillColor: AppColors.primaryMid,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: !_isGenerating,
                maxLines: 3,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 12),
            _isGenerating
                ? Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.stop_rounded),
                      color: AppColors.error,
                      onPressed: _stopGeneration,
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accentPink, AppColors.accentViolet],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentPink.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded),
                      color: Colors.white,
                      onPressed: _sendMessage,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isGenerating) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _controller.clear();
      _isGenerating = true;
      _currentResponse = '';
    });

    _scrollToBottom();

    try {
      // Generate wellness-focused system prompt with current mood and habit context
      final currentMood = _moodService?.currentMood;
      
      // Get habit context for ARIA
      Map<String, dynamic>? habitContext;
      if (_habitService != null) {
        final progress = _habitService!.getOverallProgress(days: 7);
        final todaysHabits = _habitService!.getTodaysHabits();
        final unreadInsights = _habitService!.unreadInsights;
        
        habitContext = {
          'completionRate': progress['completionRate'],
          'todaysCount': todaysHabits.length,
          'recentInsight': unreadInsights.isNotEmpty ? unreadInsights.first.message : null,
        };
      }
      
      final systemPrompt = _wellnessService?.generateWellnessSystemPrompt(currentMood, habitContext) ?? '';
      
      _streamingResult = await RunAnywhere.generateStream(
        text,
        options: LLMGenerationOptions(
          maxTokens: 512,
          temperature: 0.7,
          systemPrompt: systemPrompt,
        ),
      );

      await for (final token in _streamingResult!.stream) {
        if (!mounted) return;
        setState(() {
          _currentResponse += token;
        });
        _scrollToBottom();
      }

      // Wait for final result to get metrics
      final result = await _streamingResult!.result;

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: _currentResponse,
            isUser: false,
            timestamp: DateTime.now(),
            tokensPerSecond: result.tokensPerSecond,
            totalTokens: result.tokensUsed,
            isAriaMessage: true,
          ));
          _isGenerating = false;
          _currentResponse = '';
        });
        
        // Update conversation context
        _wellnessService?.updateContext(
          conversationDepth: _messages.length,
          lastWellnessCheckIn: DateTime.now(),
        );
        
        // Automatically analyze mood from user's message
        _moodService?.analyzeTextInput(text);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'I apologize, but I\'m having trouble connecting right now. Please try again in a moment.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
            isAriaMessage: true,
          ));
          _isGenerating = false;
          _currentResponse = '';
        });
      }
    }
  }

  void _stopGeneration() {
    _streamingResult?.cancel();
    setState(() {
      if (_currentResponse.isNotEmpty) {
        _messages.add(ChatMessage(
          text: _currentResponse,
          isUser: false,
          timestamp: DateTime.now(),
          wasCancelled: true,
          isAriaMessage: true,
        ));
      }
      _isGenerating = false;
      _currentResponse = '';
    });
  }

  void _toggleWellnessPrompts() {
    setState(() {
      _showWellnessPrompts = !_showWellnessPrompts;
    });
  }

  void _startNewSession() {
    _wellnessService?.startNewSession();
    setState(() {
      _messages.clear();
    });
    _startWithWellnessGreeting();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
}