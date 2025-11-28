// lib/services/card_animation_service.dart
import 'package:flutter/material.dart';
import 'package:naija_whot_trail/services/sound_service.dart';

class CardAnimationService {
  static final CardAnimationService _instance = CardAnimationService._internal();
  factory CardAnimationService() => _instance;
  CardAnimationService._internal();

  final SoundService _soundService = SoundService();

  /// Animate a card flying from the hand to the top card
  Future<void> animateCardToTop({
    required BuildContext context,
    required GlobalKey handKey,   // Key of the card in the hand
    required GlobalKey topKey,    // Key of the top card widget
    required String card,         // Card id / name
  }) async {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final handRender = handKey.currentContext?.findRenderObject() as RenderBox?;
    final topRender = topKey.currentContext?.findRenderObject() as RenderBox?;
    if (handRender == null || topRender == null) return;

    final handPos = handRender.localToGlobal(Offset.zero);
    final topPos = topRender.localToGlobal(Offset.zero);

    final overlayEntry = OverlayEntry(builder: (context) {
      return _AnimatedCard(
        card: card,
        start: handPos,
        end: topPos,
      );
    });

    overlay.insert(overlayEntry);

    // Play sound for card being played
    _soundService.playEffect("card_play.mp3");

    // Wait for animation to complete (duration matches _AnimatedCard)
    await Future.delayed(const Duration(milliseconds: 500));
    overlayEntry.remove();
  }
}

class _AnimatedCard extends StatefulWidget {
  final String card;
  final Offset start;
  final Offset end;
  const _AnimatedCard({required this.card, required this.start, required this.end, Key? key}) : super(key: key);

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _animation = Tween<Offset>(
      begin: widget.start,
      end: widget.end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        return Positioned(
          left: _animation.value.dx,
          top: _animation.value.dy,
          child: Image.asset(
            "assets/images/${widget.card}.png", // adjust to match your card image path
            width: 80,
            height: 120,
            fit: BoxFit.fill,
          ),
        );
      },
    );
  }
}
