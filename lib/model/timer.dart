import 'dart:async';

import 'types.dart';

typedef TimerAction = Future<void> Function(ScheduleTimer timer);

enum ScheduleTimerState {
  notStarted,
  running,
  paused,
  componentTimeOver,
  completed,
}

class ScheduleTimer {
  static Future<void> _doNothing(ScheduleTimer timer) async {}

  ScheduleTimer({
    required this.schedule,
    this.tickDuration = const Duration(seconds: 10),
    this.afterTogglePause = _doNothing,
    this.nextComponentPrompt = _doNothing,
    this.afterEachMinute = _doNothing,
    this.afterEachTick = _doNothing,
    this.onIncrement = _doNothing,
    this.onCompleted = _doNothing,
  });

  Duration tickDuration;

  final Schedule schedule;

  TimerAction afterTogglePause,
      nextComponentPrompt,
      afterEachMinute,
      afterEachTick,
      onIncrement,
      onCompleted;

  ScheduleTimerState state = ScheduleTimerState.notStarted;

  bool get isNotStarted => state == ScheduleTimerState.notStarted;
  bool get isRunning => state == ScheduleTimerState.running;
  bool get isPaused => state == ScheduleTimerState.paused;
  bool get isComponentTimeOver => state == ScheduleTimerState.componentTimeOver;
  bool get isCompleted => state == ScheduleTimerState.completed;

  Timer? _timer;

  int _ticks = 0, pastMinutes = 0, index = 0;

  int get currentStep =>
      (index == schedule.components.length) ? index - 1 : index;

  ScheduleComponent get component => schedule.components[currentStep];

  int get componentMinutes =>
      schedule.components[currentStep].duration.inMinutes;

  int get minutes => (_ticks / 6).floor();

  double get progress => _ticks / (componentMinutes * 6);

  void _onTick(Timer _) {
    _ticks++;
    afterEachTick(this);
    if (_ticks % 6 == 0) {
      afterEachMinute(this);
      if (componentMinutes == minutes) {
        pause();
        if (index == schedule.components.length - 1) {
          state = ScheduleTimerState.completed;
          onCompleted(this);
        } else {
          state = ScheduleTimerState.componentTimeOver;
        }
        nextComponentPrompt(this);
      }
    }
  }

  void pause() {
    _timer?.cancel();
    state = ScheduleTimerState.paused;
    _timer = null;
    afterTogglePause(this);
  }

  void resume() {
    state = ScheduleTimerState.running;
    _timer = Timer.periodic(tickDuration, _onTick);
    afterTogglePause(this);
  }

  void togglePause() {
    (isRunning) ? pause() : resume();
  }

  void next() {
    index++;
    pause();
    if (index == schedule.components.length) {
      state = ScheduleTimerState.completed;
      onCompleted(this);
      return;
    }
    // Reset only if not the last stage
    pastMinutes += minutes;
    _ticks = 0;
    state = ScheduleTimerState.running;
    resume();
    onIncrement(this);
  }
}
