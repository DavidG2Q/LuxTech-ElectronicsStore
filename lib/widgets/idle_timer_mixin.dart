import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_assistant_service.dart';

mixin IdleTimerMixin<T extends StatefulWidget> on State<T> {
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _startIdleTimer();
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 1), _onIdleTimeout);
  }

  void _resetIdleTimer() {
    _startIdleTimer();
  }

  void _onIdleTimeout() {
    if (!mounted) return;
    final voiceService = Provider.of<VoiceAssistantService>(context, listen: false);
    voiceService.speakIdleMessage();
    _startIdleTimer(); // Restart timer after speaking
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  /// Wrap your screen's body with this to enable idle detection.
  Widget withIdleTimer({required Widget child}) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _resetIdleTimer();
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _resetIdleTimer,
        onPanDown: (_) => _resetIdleTimer(),
        child: child,
      ),
    );
  }
} 