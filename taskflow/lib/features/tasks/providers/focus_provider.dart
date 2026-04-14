import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

const _defaultFocusMinutes = 25;
const _defaultBreakMinutes = 5;

enum FocusPhase { focus, breakTime }

class FocusSessionState {
  const FocusSessionState({
    required this.taskId,
    required this.phase,
    required this.isRunning,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.remainingSeconds,
    required this.completedFocusSessions,
  });

  factory FocusSessionState.initial() {
    return const FocusSessionState(
      taskId: null,
      phase: FocusPhase.focus,
      isRunning: false,
      focusMinutes: _defaultFocusMinutes,
      breakMinutes: _defaultBreakMinutes,
      remainingSeconds: _defaultFocusMinutes * 60,
      completedFocusSessions: 0,
    );
  }

  final int? taskId;
  final FocusPhase phase;
  final bool isRunning;
  final int focusMinutes;
  final int breakMinutes;
  final int remainingSeconds;
  final int completedFocusSessions;

  bool get hasTask => taskId != null;

  Duration get focusDuration => Duration(minutes: focusMinutes);

  Duration get breakDuration => Duration(minutes: breakMinutes);

  Duration get remainingDuration => Duration(seconds: remainingSeconds);

  FocusSessionState copyWith({
    int? taskId,
    FocusPhase? phase,
    bool? isRunning,
    int? focusMinutes,
    int? breakMinutes,
    int? remainingSeconds,
    int? completedFocusSessions,
    bool clearTaskId = false,
  }) {
    return FocusSessionState(
      taskId: clearTaskId ? null : (taskId ?? this.taskId),
      phase: phase ?? this.phase,
      isRunning: isRunning ?? this.isRunning,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      completedFocusSessions:
          completedFocusSessions ?? this.completedFocusSessions,
    );
  }
}

final focusSessionProvider =
    StateNotifierProvider<FocusSessionController, FocusSessionState>((ref) {
  return FocusSessionController();
});

class FocusSessionController extends StateNotifier<FocusSessionState> {
  FocusSessionController() : super(FocusSessionState.initial());

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void selectTask(int? taskId) {
    _stopTimer();
    state = state.copyWith(
      taskId: taskId,
      clearTaskId: taskId == null,
      phase: FocusPhase.focus,
      isRunning: false,
      remainingSeconds: state.focusDuration.inSeconds,
      completedFocusSessions: 0,
    );
  }

  void setPresetDurations({
    required int focusMinutes,
    required int breakMinutes,
  }) {
    _stopTimer();
    state = state.copyWith(
      focusMinutes: focusMinutes,
      breakMinutes: breakMinutes,
      phase: FocusPhase.focus,
      isRunning: false,
      remainingSeconds: Duration(minutes: focusMinutes).inSeconds,
      completedFocusSessions: 0,
    );
  }

  void toggleRunning() {
    if (state.isRunning) {
      pause();
    } else {
      start();
    }
  }

  void start() {
    if (state.taskId == null || state.isRunning) return;

    if (state.remainingSeconds <= 0) {
      state = state.copyWith(
        remainingSeconds: _durationForPhase(state.phase).inSeconds,
      );
    }

    state = state.copyWith(isRunning: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    _stopTimer();
    state = state.copyWith(isRunning: false);
  }

  void reset() {
    _stopTimer();
    state = state.copyWith(
      phase: FocusPhase.focus,
      isRunning: false,
      remainingSeconds: state.focusDuration.inSeconds,
      completedFocusSessions: 0,
    );
  }

  void skipPhase() {
    _advancePhase(forceRunning: state.isRunning);
  }

  Duration _durationForPhase(FocusPhase phase) {
    return phase == FocusPhase.focus
        ? state.focusDuration
        : state.breakDuration;
  }

  void _tick() {
    if (!state.isRunning) return;

    if (state.remainingSeconds <= 1) {
      _advancePhase(forceRunning: true);
      return;
    }

    state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
  }

  void _advancePhase({required bool forceRunning}) {
    final nextPhase = state.phase == FocusPhase.focus
        ? FocusPhase.breakTime
        : FocusPhase.focus;

    final nextRemaining = _durationForPhase(nextPhase).inSeconds;
    final nextCompletedFocusSessions = state.phase == FocusPhase.focus
        ? state.completedFocusSessions + 1
        : state.completedFocusSessions;

    state = state.copyWith(
      phase: nextPhase,
      remainingSeconds: nextRemaining,
      completedFocusSessions: nextCompletedFocusSessions,
      isRunning: forceRunning,
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
