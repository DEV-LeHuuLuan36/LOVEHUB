import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:rive/rive.dart' hide RadialGradient;

/// Lightweight interactive cat used outside of the full PetScreen.
/// Mirrors [RivePet] but loads `assets/rive/cat.riv` with a fixed
/// artboard + State Machine. Taps fall back to a flutter_animate
/// pulse when the State Machine doesn't expose the expected inputs.
class InteractiveCat extends StatefulWidget {
  const InteractiveCat({super.key});

  @override
  State<InteractiveCat> createState() => InteractiveCatState();
}

class InteractiveCatState extends State<InteractiveCat> {
  static const String _tag = 'InteractiveCat';

  Artboard? _artboard;
  StateMachineController? _smController;
  SMIBool? _chinHold;
  SMITrigger? _foreheadClick;

  bool _isHolding = false;
  bool _loaded = false;
  String? _error;

  /// Bump on every tap so the fallback animation can rebuild its chain.
  int _fallbackTick = 0;

  @override
  void initState() {
    super.initState();
    _loadCat();
  }

  @override
  void dispose() {
    _smController?.dispose();
    super.dispose();
  }

  Future<void> _loadCat() async {
    try {
      final bytes = await rootBundle.load('assets/rive/cat.riv');
      final file = RiveFile.import(bytes);

      Artboard artboard = file.artboardByName('Artboard') ?? file.mainArtboard;

      final smCtrl = StateMachineController.fromArtboard(artboard, 'State Machine 1');
      if (smCtrl != null) {
        // BUG FIX: _buildAnimationResetForTransition crash.
        //
        // `getBoolInput` / `getTriggerInput` must be called AFTER
        // `addController` has attached the controller to the artboard.
        // Calling them before causes the input to be resolved against a
        // "reset" animation that hasn't been initialised yet, which makes
        // `LayerController.tryChangeState` throw a null-pointer inside
        // the rive library.  Fix: move input acquisition to after
        // `addController`.
        artboard.addController(smCtrl);
        _smController = smCtrl;

        // Dump every available SM input so we can spot name mismatches.
        for (final input in smCtrl.inputs) {
          debugPrint('$_tag input: ${input.name} (${input.runtimeType})');
        }

        _chinHold = smCtrl.getBoolInput('Chin hold');
        _foreheadClick = smCtrl.getTriggerInput('Forehead click');
        debugPrint('$_tag Loaded: chinHold=${_chinHold != null}, '
            'foreheadClick=${_foreheadClick != null}');
      } else {
        debugPrint('$_tag WARNING: StateMachineController.fromArtboard returned null');
      }

      if (mounted) {
        setState(() {
          _artboard = artboard;
          _loaded = true;
        });
      }
    } catch (e, st) {
      debugPrint('$_tag ERROR loading cat.riv: $e\n$st');
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  /// Fire the tap reaction. Falls back to a flutter_animate pulse
  /// when the State Machine doesn't expose a `Forehead click` trigger.
  void triggerReaction() {
    if (_foreheadClick != null) {
      _foreheadClick!.fire();
      debugPrint('$_tag: triggerReaction fired (rive trigger)');
      return;
    }
    debugPrint('$_tag: triggerReaction fired (fallback animation)');
    if (!mounted) return;
    setState(() => _fallbackTick++);
  }

  void _onTapDown(TapDownDetails details) {
    _chinHold?.value = true;
    _isHolding = true;
    debugPrint('$_tag: chinHold = true (hold)');
    setState(() {});
  }

  void _onTapUp(TapUpDetails details) {
    _chinHold?.value = false;
    _isHolding = false;
    debugPrint('$_tag: chinHold = false (release)');
    setState(() {});
  }

  void _onTapCancel() {
    _chinHold?.value = false;
    _isHolding = false;
    debugPrint('$_tag: chinHold = false (cancel)');
    setState(() {});
  }

  void _onTap() {
    if (_foreheadClick != null) {
      _foreheadClick!.fire();
      debugPrint('$_tag: foreheadClick fired (tap)');
    } else {
      debugPrint('$_tag: tap → fallback animation');
      setState(() => _fallbackTick++);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildEmojiFallback('😿');
    }
    if (!_loaded || _artboard == null) {
      return const SizedBox(
        width: 220,
        height: 220,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)),
        ),
      );
    }

    final riveWidget = Rive(
      artboard: _artboard!,
      fit: BoxFit.contain,
      useArtboardSize: true,
    );

    final petBody = _foreheadClick == null
        ? riveWidget
            .animate(key: ValueKey('cat-fallback-$_fallbackTick'))
            .scale(
              duration: 120.ms,
              begin: const Offset(1.0, 1.0),
              end: const Offset(0.92, 0.92),
              curve: Curves.easeOut,
            )
            .then()
            .scale(
              duration: 220.ms,
              begin: const Offset(0.92, 0.92),
              end: const Offset(1.0, 1.0),
              curve: Curves.elasticOut,
            )
        : riveWidget;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: _onTap,
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFF6B9D).withValues(alpha: 0.25),
                        const Color(0xFFFF8E53).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                petBody,
                if (_isHolding)
                  Positioned(
                    bottom: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '😻',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'pet.tapToPatHint'.tr(),
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiFallback(String emoji) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF6B9D).withValues(alpha: 0.25),
                      const Color(0xFFFF8E53).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              Text(emoji, style: const TextStyle(fontSize: 120))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -12, duration: const Duration(milliseconds: 1800), curve: Curves.easeInOut)
                  .fadeIn(duration: const Duration(milliseconds: 400)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'pet.tapToPatHint'.tr(),
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
