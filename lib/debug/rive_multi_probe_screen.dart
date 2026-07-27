import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' hide RadialGradient;

class RiveMultiProbeScreen extends StatefulWidget {
  const RiveMultiProbeScreen({super.key});

  @override
  State<RiveMultiProbeScreen> createState() => _RiveMultiProbeScreenState();
}

class _RiveMultiProbeScreenState extends State<RiveMultiProbeScreen> {
  static const _files = [
    _RiveFileEntry(
      assetPath: 'assets/rive/habitspet.riv',
      label: 'habitspet',
    ),
    _RiveFileEntry(
      assetPath: 'assets/rive/muza-your-cat-companion.riv',
      label: 'muza',
    ),
  ];

  final List<String> _probeLines = [];
  bool _copied = false;

  Future<void> _loadAndProbe(_RiveFileEntry entry) async {
    try {
      final bytes = await rootBundle.load(entry.assetPath);
      final file = RiveFile.import(bytes);

      final artboards = file.artboards;

      // Enumerate all artboard names
      for (final ab in artboards) {
        _addLine('RIVE_PROBE[${entry.label}]: artboard="${ab.name}"');
      }

      // Find all state machines across all artboards
      bool foundSm = false;
      for (final ab in artboards) {
        for (final sm in ab.stateMachines) {
          foundSm = true;
          final smName = sm.name;
          _addLine('RIVE_PROBE[${entry.label}]: artboard="${ab.name}" stateMachine="$smName"');
          final smCtrl = StateMachineController.fromArtboard(ab, smName);
          if (smCtrl != null) {
            ab.addController(smCtrl);
            for (final input in smCtrl.inputs) {
              _addLine('RIVE_PROBE[${entry.label}]:   INPUT name="${input.name}" type=${input.runtimeType}');
            }
          }
        }
      }

      if (!foundSm) {
        _addLine('RIVE_PROBE[${entry.label}]: LOAD FAILED no state machine found');
      } else {
        _addLine('RIVE_PROBE[${entry.label}]: --- done ---');
      }

      if (mounted) setState(() {});
    } catch (e, st) {
      _addLine('RIVE_PROBE[${entry.label}]: LOAD FAILED $e');
      debugPrint('RIVE_PROBE[${entry.label}] ERROR: $e\n$st');
      if (mounted) setState(() {});
    }
  }

  void _addLine(String line) {
    _probeLines.add(line);
    debugPrint(line);
  }

  Future<void> _loadAll() async {
    for (final entry in _files) {
      await _loadAndProbe(entry);
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _probeLines.join('\n')));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1025),
      appBar: AppBar(
        title: const Text('Rive Multi-Probe'),
        backgroundColor: const Color(0xFF1A1025),
        actions: [
          IconButton(
            icon: Icon(_copied ? Icons.check : Icons.copy),
            onPressed: _probeLines.isEmpty ? null : _copyToClipboard,
            tooltip: 'Copy probe lines',
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _probeLines.isEmpty ? _loadAll : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Probe All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC2185B),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                if (_probeLines.isNotEmpty)
                  Text(
                    '${_probeLines.length} lines',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ),

          // Artboards row — render each loaded artboard
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _files.length,
              itemBuilder: (context, i) {
                return _ArtboardPreview(entry: _files[i]);
              },
            ),
          ),

          const Divider(color: Colors.white24),

          // Probe output log
          Expanded(
            child: _probeLines.isEmpty
                ? const Center(
                    child: Text(
                      'Tap "Probe All" to discover inputs',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _probeLines.length,
                    itemBuilder: (context, i) {
                      final line = _probeLines[i];
                      Color color = Colors.white70;
                      if (line.contains('ERROR')) {
                        color = Colors.redAccent;
                      } else if (line.contains('input=')) {
                        color = const Color(0xFFFFD700);
                      } else if (line.contains('artboard=')) {
                        color = const Color(0xFF4CAF50);
                      } else if (line.contains('SM=')) {
                        color = const Color(0xFF64B5F6);
                      }
                      return Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: color,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RiveFileEntry {
  const _RiveFileEntry({
    required this.assetPath,
    required this.label,
  });

  final String assetPath;
  final String label;
}

class _ArtboardPreview extends StatefulWidget {
  const _ArtboardPreview({required this.entry});

  final _RiveFileEntry entry;

  @override
  State<_ArtboardPreview> createState() => _ArtboardPreviewState();
}

class _ArtboardPreviewState extends State<_ArtboardPreview> {
  Artboard? _artboard;
  StateMachineController? _smCtrl;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _smCtrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await rootBundle.load(widget.entry.assetPath);
      final file = RiveFile.import(bytes);

      Artboard artboard = file.artboardByName(widget.entry.label) ??
          file.artboardByName(widget.entry.assetPath.split('/').last.replaceAll('.riv', '')) ??
          file.artboardByName('Artboard') ??
          file.artboards.firstOrNull ??
          file.mainArtboard;

      // Try to attach any state machine from the best artboard
      for (final sm in artboard.stateMachines) {
        final ctrl = StateMachineController.fromArtboard(artboard, sm.name);
        if (ctrl != null) {
          artboard.addController(ctrl);
          _smCtrl = ctrl;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _artboard = artboard;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              widget.entry.label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 9,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _artboard != null
                        ? Rive(
                            artboard: _artboard!,
                            fit: BoxFit.contain,
                            useArtboardSize: true,
                          )
                        : const SizedBox(),
          ),
        ],
      ),
    );
  }
}
