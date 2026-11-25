import 'dart:async';

import 'package:app_hiker/components/profile_summary_header.dart';
import 'package:app_hiker/src/models/user_profile.dart';
import 'package:app_hiker/src/services/trail_tracker.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:app_hiker/src/utils/trail_format.dart';
import 'package:flutter/material.dart';

// RF24/RF25: live counters and the play, pause and stop controls.
class TrailTrackingView extends StatefulWidget {
  final UserProfile? profile;
  final int? postsCount;
  final VoidCallback onBack;

  const TrailTrackingView({super.key, required this.profile, this.postsCount, required this.onBack});

  @override
  State<TrailTrackingView> createState() => _TrailTrackingViewState();
}

class _TrailTrackingViewState extends State<TrailTrackingView> {
  final _tracker = TrailTracker.instance;
  Timer? _clock;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    // Refreshes the elapsed time; steps and distance already notify the tracker listeners.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tracker.status == TrailStatus.tracking) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _play() async {
    setState(() => _starting = true);
    try {
      if (_tracker.status == TrailStatus.paused) {
        await _tracker.resume();
      } else {
        await _tracker.start();
      }
    } on TrailPermissionException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Não foi possível iniciar o rastreio da trilha.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _EndTrailDialog(),
    );
    if (confirmed == true) await _tracker.finish();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _title {
    final cidade = _tracker.cidade;
    if (cidade != null && cidade.isNotEmpty) return cidade;
    return _tracker.status == TrailStatus.idle ? 'Nova trilha' : 'Localizando...';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _tracker,
      builder: (context, _) {
        final status = _tracker.status;
        final tracking = status == TrailStatus.tracking;
        final canPlay = !_starting && (status == TrailStatus.idle || status == TrailStatus.paused);

        return Column(
          children: [
            ProfileSummaryHeader(profile: widget.profile, postsCount: widget.postsCount, onBack: widget.onBack),
            Divider(height: 1, color: Pallete.whiteColor.withAlpha(20)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_title, style: const TextStyle(color: Pallete.whiteColor, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          _tracker.estado ?? '',
                          style: TextStyle(color: Pallete.whiteColor.withAlpha(200), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatTrailDate(_tracker.startedAt ?? DateTime.now()),
                    style: const TextStyle(color: Pallete.whiteColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Pallete.surfaceColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _counter(formatKm(_tracker.distanceM), 'KM'),
                    const SizedBox(height: 24),
                    _counter('${_tracker.steps}', 'passos'),
                    const SizedBox(height: 24),
                    Text(
                      formatDuration(_tracker.elapsed),
                      style: TextStyle(color: Pallete.whiteColor.withAlpha(160), fontSize: 16),
                    ),
                    if (status == TrailStatus.paused) ...[
                      const SizedBox(height: 8),
                      const Text('Trilha pausada', style: TextStyle(color: Pallete.primaryColor)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Keeps the play/pause button centered and the stop button where it was.
                  const SizedBox(width: 56),
                  // Play and pause share the main button: pause while tracking, play otherwise.
                  _ControlButton(
                    icon: tracking ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 88,
                    tooltip: tracking ? 'Pausar' : (status == TrailStatus.paused ? 'Continuar' : 'Iniciar'),
                    highlighted: tracking,
                    loading: _starting,
                    onPressed: tracking ? _tracker.pause : (canPlay ? _play : null),
                  ),
                  _ControlButton(
                    icon: Icons.stop_rounded,
                    size: 56,
                    tooltip: 'Encerrar',
                    onPressed: status == TrailStatus.idle || _starting ? null : _stop,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _counter(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Pallete.whiteColor, fontSize: 40, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Pallete.whiteColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool highlighted;
  final bool loading;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.tooltip,
    required this.onPressed,
    this.highlighted = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final background = highlighted ? Pallete.primaryColor : Pallete.whiteColor.withAlpha(enabled ? 70 : 30);
    final foreground = highlighted ? Pallete.textDarkColor : Pallete.whiteColor.withAlpha(enabled ? 255 : 90);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: loading
                ? const Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator(strokeWidth: 3))
                : Icon(icon, color: foreground, size: size * 0.55),
          ),
        ),
      ),
    );
  }
}

// Prototype modal: "Encerrar Trilha?" with "Sim" (grey) and "Não" (red).
class _EndTrailDialog extends StatelessWidget {
  const _EndTrailDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Pallete.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Encerrar Trilha?', style: TextStyle(color: Pallete.whiteColor, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogButton(context, 'Sim', Pallete.whiteColor.withAlpha(60), true),
                const SizedBox(width: 12),
                _dialogButton(context, 'Não', const Color(0xFFEF5350), false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogButton(BuildContext context, String label, Color color, bool result) {
    return SizedBox(
      width: 72,
      height: 40,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(result),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(label, style: const TextStyle(color: Pallete.whiteColor, fontSize: 16)),
      ),
    );
  }
}
