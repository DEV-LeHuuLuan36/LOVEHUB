import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:rive/rive.dart' hide RadialGradient;
import '../../domain/entities/pet_entity.dart';

/// Renders an interactive Rive pet (Cat / Habit Cat / Muza) with a
/// graceful flutter_animate fallback when the underlying `.riv` file
/// does not expose the expected State Machine inputs (`Chin hold` /
/// `Forehead click`).
///
/// Debug note (from binary probe of `assets/rive/*.riv`):
///   • cat.riv                     → has 'Chin hold', 'Forehead click', 'State Machine 1'
///   • habitspet.riv               → has 'State Machine 1', NO interaction inputs
///   • muza-your-cat-companion.riv → identical structure to cat.riv
///
/// Hold-to-purr: when the user long-presses the pet, an
/// `AnimationController` drives a subtle 0.97–1.03 scale oscillation
/// so the pet feels alive even when the `.riv` has no chin-hold input.
/// The tap feedback is a separate one-shot flutter_animate pulse.
class RivePet extends StatefulWidget {
  const RivePet({super.key, required this.petType, this.width = 220, this.height = 220});

  final PetType petType;
  final double width;
  final double height;

  @override
  State<RivePet> createState() => RivePetState();
}

class RivePetState extends State<RivePet> with TickerProviderStateMixin {
  static const _tag = 'RivePet';

  Artboard? _artboard;
  StateMachineController? _smController;
  SMIBool? _chinHold;
  SMITrigger? _foreheadClick;
  bool _isHolding = false;
  bool _loaded = false;
  String? _error;

  /// Drives the hold-to-purr pulse: a gentle 0.97–1.03 scale oscillation
  /// that fires when the user is pressing down on the pet.
  late final AnimationController _holdPulseController;
  late final Animation<double> _holdPulse;

  /// Bump on every tap so the fallback animation can rebuild its chain.
  int _fallbackTick = 0;

  @override
  void initState() {
    super.initState();
    _holdPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _holdPulse = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _holdPulseController,
        curve: Curves.easeInOut,
      ),
    );
    _loadPet();
  }

  @override
  void didUpdateWidget(RivePet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petType != widget.petType) {
      _smController?.dispose();
      _smController = null;
      _chinHold = null;
      _foreheadClick = null;
      _loaded = false;
      _artboard = null;
      _loadPet();
    }
  }

  @override
  void dispose() {
    _smController?.dispose();
    _holdPulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPet() async {
    try {
      final bytes = await rootBundle.load(widget.petType.assetPath);
      final file = RiveFile.import(bytes);

      Artboard artboard =
          file.artboardByName(widget.petType.artboardName) ?? file.mainArtboard;

      final smCtrl = StateMachineController.fromArtboard(
        artboard,
        widget.petType.stateMachineName,
      );
      if (smCtrl != null) {
        artboard.addController(smCtrl);
        _smController = smCtrl;

        // Dump every input the SM exposes so we can spot mismatches
        // between hardcoded input names ('Chin hold', 'Forehead click')
        // and what the .riv actually contains. This log is the source
        // of truth when the State Machine file is updated.
        for (final input in smCtrl.inputs) {
          debugPrint('$_tag ${widget.petType.name} '
              'input: ${input.name} (${input.runtimeType})');
        }

        if (widget.petType.isInteractive) {
          _chinHold = smCtrl.getBoolInput('Chin hold');
          _foreheadClick = smCtrl.getTriggerInput('Forehead click');
        }
        debugPrint('$_tag Loaded ${widget.petType.name}: '
            'chinHold=${_chinHold != null}, '
            'foreheadClick=${_foreheadClick != null}, '
            'interactive=${widget.petType.isInteractive}');
      } else {
        debugPrint(
            '$_tag WARNING: no StateMachineController for ${widget.petType.name}');
      }

      if (mounted) {
        setState(() {
          _artboard = artboard;
          _loaded = true;
        });
      }
    } catch (e, st) {
      debugPrint('$_tag ERROR loading ${widget.petType.assetPath}: $e\n$st');
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  /// Fire the "tap reaction" animation on the pet. If the State Machine
  /// exposes a `Forehead click` trigger, we use it; otherwise we play a
  /// short flutter_animate pulse so the tap is always acknowledged.
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
    // Hold-to-purr: start the gentle scale oscillation.
    // Works even when the .riv has no chin-hold SM input.
    _holdPulseController.repeat(reverse: true);
    setState(() {});
  }

  void _onTapUp(TapUpDetails details) {
    _chinHold?.value = false;
    _isHolding = false;
    _holdPulseController.stop();
    _holdPulseController.value = 0.0;
    setState(() {});
  }

  void _onTapCancel() {
    _chinHold?.value = false;
    _isHolding = false;
    _holdPulseController.stop();
    _holdPulseController.value = 0.0;
    setState(() {});
  }

  void _onTap() {
    if (_foreheadClick != null) {
      _foreheadClick!.fire();
      debugPrint('$_tag: foreheadClick fired (tap)');
    } else {
      // Fallback: pulse so the user gets visual feedback even when
      // the .riv doesn't expose the expected trigger.
      debugPrint('$_tag: tap → fallback animation');
      setState(() => _fallbackTick++);
    }
    setState(() {});
  }

  /// Returns the widget tree for the pet body — either the Rive widget
  /// with the hold-pulse animation, or the emoji fallback.
  Widget _buildPetBody() {
    if (_error != null) return _buildEmojiFallback(_getEmojiFallback());

    if (!_loaded || _artboard == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: const Color(0xFFFFD700).withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    // Hold pulse: gentle 1.0–1.03 scale oscillation driven by
    // _holdPulseController, which starts on tap-down and stops on release.
    // Works even when _foreheadClick is null (e.g. habitspet.riv).
    final riveWidget = Rive(
      artboard: _artboard!,
      fit: BoxFit.contain,
      useArtboardSize: true,
    );

    final petWithHoldPulse = AnimatedBuilder(
      animation: _holdPulse,
      builder: (context, child) {
        return Transform.scale(
          scale: _holdPulse.value,
          child: child,
        );
      },
      child: riveWidget,
    );

    // Tap pulse: a one-shot flutter_animate scale that fires whenever
    // _fallbackTick changes. This is the fallback when _foreheadClick is
    // null, but it also layers on top of the Rive animation for extra
    // responsiveness on interactive pets.
    if (_foreheadClick == null) {
      return petWithHoldPulse
          .animate(key: ValueKey('rive-fallback-$_fallbackTick'))
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
          );
    }

    return petWithHoldPulse;
  }

  @override
  Widget build(BuildContext context) {
    final petBody = _buildPetBody();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: widget.petType.isInteractive ? _onTapDown : null,
          onTapUp: widget.petType.isInteractive ? _onTapUp : null,
          onTapCancel: widget.petType.isInteractive ? _onTapCancel : null,
          onTap: _onTap,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.width,
                  height: widget.height,
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
                      child: const Text('😻', style: TextStyle(fontSize: 16)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.petType.patHintKey.tr(),
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  String _getEmojiFallback() => widget.petType.emoji;

  Widget _buildEmojiFallback(String emoji) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.width,
            height: widget.height,
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
          Text(emoji, style: const TextStyle(fontSize: 100))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: 0,
                end: -10,
                duration: const Duration(milliseconds: 1800),
                curve: Curves.easeInOut,
              )
              .fadeIn(duration: const Duration(milliseconds: 400)),
        ],
      ),
    );
  }
}
