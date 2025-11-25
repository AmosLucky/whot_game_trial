import 'package:flutter/material.dart';

/// Beautiful animated bet-selection dialog for the Naija Whot game.
///
/// Usage:
/// ```dart
/// final chosen = await showBetDialog(context);
/// if (chosen != null) print('User chose ₦$chosen');
/// ```

Future<int?> showBetDialog(BuildContext context) {
  return showGeneralDialog<int?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Choose Bet',
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (ctx, anim1, anim2) => _BetDialog(),
    transitionBuilder: (ctx, anim, secAnim, child) {
      // Combined scale + fade transition
      final curved = Curves.easeOutBack.transform(anim.value);
      return Opacity(
        opacity: anim.value,
        child: Transform.scale(
          scale: 0.9 + 0.1 * curved,
          child: child,
        ),
      );
    },
  );
}

class _BetDialog extends StatefulWidget {
  @override
  State<_BetDialog> createState() => _BetDialogState();
}

class _BetDialogState extends State<_BetDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _choose(int value) async {
    setState(() => _selected = value);
    // short scale feedback before closing
    await Future.delayed(const Duration(milliseconds: 220));
    if (mounted) Navigator.of(context).pop(value);
  }

  Widget _optionButton(int amount) {
    final isChosen = _selected == amount;
    return GestureDetector(
      onTap: () => _choose(amount),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isChosen
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.orangeAccent, Colors.deepOrange],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey.shade100],
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isChosen ? 0.28 : 0.08),
              blurRadius: isChosen ? 18 : 6,
              offset: Offset(0, isChosen ? 10 : 4),
            ),
          ],
          border: Border.all(
            color: isChosen ? Colors.deepOrange.shade700 : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated coin icon
            ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.06)
                  .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Colors.yellow.shade600, Colors.amber.shade800]),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
                child: Icon(Icons.monetization_on_sharp, size: 20, color: Colors.white),
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₦$amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 2),
                Text('Play', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.38),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: width < 420 ? width : 420,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 12))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row with animated badge
                    Row(
                      children: [
                        // Animated glowing circle with coin
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale = 1.0 + 0.06 * (1 + (_pulseController.value - 0.5) * 2);
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange]),
                                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.22), blurRadius: 18, offset: Offset(0, 8))],
                                ),
                                child: Icon(Icons.attach_money, color: Colors.white, size: 28),
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Choose stake', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              SizedBox(height: 6),
                              Text('Pick how much Naira to play with', style: TextStyle(color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                        // Close icon
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).pop(),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(Icons.close, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 18),

                    // Options row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _optionButton(200),
                          _optionButton(500),
                          _optionButton(1000),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Extra info and action
                    Row(
                      children: [
                        Expanded(
                          child: Text('Tip: Higher stakes give bigger match rewards.', style: TextStyle(color: Colors.grey.shade600)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // default quick pick: 200 if nothing chosen
                            final value = _selected ?? 200;
                            Navigator.of(context).pop(value);
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            elevation: 8,
                          ),
                          child: Text('Confirm'),
                        )
                      ],
                    ),

                    SizedBox(height: 8),

                    // Small animated affordance (rising dots)
                    SizedBox(
                      height: 28,
                      child: Center(
                        child: _RisingDotsAnimation(),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RisingDotsAnimation extends StatefulWidget {
  @override
  State<_RisingDotsAnimation> createState() => _RisingDotsAnimationState();
}

class _RisingDotsAnimationState extends State<_RisingDotsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        double y(int i) => (0.5 + 0.5 * (i == 0 ? (t) : (i == 1 ? (t + 0.33) : (t + 0.66)))) % 1.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final val = y(i);
            return Transform.translate(
              offset: Offset(0, -8 * val),
              child: Opacity(opacity: 0.35 + 0.65 * val, child: Container(width: 8, height: 8, margin: EdgeInsets.symmetric(horizontal: 6), decoration: BoxDecoration(color: Colors.grey.shade600, shape: BoxShape.circle))),
            );
          }),
        );
      },
    );
  }
}


// Example minimal app showing how to call the dialog.
// Remove this `main()` from your real app and use `showBetDialog(context)` from any widget.

