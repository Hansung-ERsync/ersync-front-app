import 'realtime_signal.dart';

abstract interface class RealtimeSignalSource {
  Stream<RealtimeSignal> watchSignals();
}

class NoopRealtimeSignalSource implements RealtimeSignalSource {
  const NoopRealtimeSignalSource();

  @override
  Stream<RealtimeSignal> watchSignals() => const Stream<RealtimeSignal>.empty();
}
