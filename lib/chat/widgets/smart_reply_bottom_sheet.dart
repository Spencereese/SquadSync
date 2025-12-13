import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/grok_service.dart';

class SmartReplyBottomSheet extends StatefulWidget {
  final List<String> lastFiveMessages;
  final ValueChanged<String>? onReplySelected;

  const SmartReplyBottomSheet({
    super.key,
    required this.lastFiveMessages,
    this.onReplySelected,
  });

  @override
  State<SmartReplyBottomSheet> createState() => _SmartReplyBottomSheetState();
}

class _SmartReplyBottomSheetState extends State<SmartReplyBottomSheet>
    with TickerProviderStateMixin {
  List<String> _replies = [];
  String _sentiment = 'neutral';
  List<String> _emojis = ['😊', '👍', '🎮'];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadSmartReplies();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSmartReplies() async {
    try {
      final grokService = GrokService();
      final response = await grokService
          .getSmartRepliesWithSentiment(widget.lastFiveMessages);
      if (mounted) {
        setState(() {
          _replies = response.replies;
          _sentiment = response.sentiment;
          _emojis = response.emojis;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _replies = ['Sorry, couldn\'t load replies'];
          _sentiment = 'neutral';
          _emojis = ['😊', '👍', '🎮'];
          _isLoading = false;
        });
        _animationController.forward();
      }
    }
  }

  Color _getSentimentColor() {
    switch (_sentiment.toLowerCase()) {
      case 'positive':
      case 'excited':
        return Colors.green;
      case 'negative':
        return Colors.red;
      case 'questioning':
      case 'curious':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getSentimentIcon() {
    switch (_sentiment.toLowerCase()) {
      case 'positive':
      case 'excited':
        return Icons.sentiment_satisfied_alt;
      case 'negative':
        return Icons.sentiment_dissatisfied;
      case 'questioning':
      case 'curious':
        return Icons.help_outline;
      default:
        return Icons.sentiment_neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.smart_toy,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Smart Replies',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  if (!_isLoading) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _getSentimentIcon(),
                          color: _getSentimentColor(),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sentiment.toUpperCase(),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _getSentimentColor(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                        ),
                        const SizedBox(width: 16),
                        ...(_emojis.take(3).map((emoji) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  if (widget.onReplySelected != null) {
                                    widget.onReplySelected!(emoji);
                                  }
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ))),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _replies.length,
                        itemBuilder: (context, index) {
                          final reply = _replies[index];
                          return AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              final delay = index * 0.1;
                              final animation =
                                  Tween<double>(begin: 0.0, end: 1.0)
                                      .animate(CurvedAnimation(
                                parent: _animationController,
                                curve: Interval(delay, delay + 0.3,
                                    curve: Curves.easeOut),
                              ));

                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: animation.drive(
                                    Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ),
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: InkWell(
                              onTap: () {
                                if (widget.onReplySelected != null) {
                                  widget.onReplySelected!(reply);
                                } else {
                                  // Fallback: copy to clipboard
                                  Clipboard.setData(ClipboardData(text: reply));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('"$reply" copied to clipboard'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        reply,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.send,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.6),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
