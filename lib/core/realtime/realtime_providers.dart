import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_providers.dart';
import 'api_realtime_signal_source.dart';
import 'realtime_signal_source.dart';

final Provider<RealtimeSignalSource> realtimeSignalSourceProvider =
    Provider<RealtimeSignalSource>(
      (Ref ref) => const NoopRealtimeSignalSource(),
    );

final Provider<RealtimeSignalSource> apiRealtimeSignalSourceProvider =
    Provider<RealtimeSignalSource>(
      (Ref ref) => ApiRealtimeSignalSource(ref.watch(dioProvider)),
    );
