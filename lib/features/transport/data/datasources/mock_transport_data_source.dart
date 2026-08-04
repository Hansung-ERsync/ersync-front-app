import 'dart:async';

import '../../domain/entities/in_transit_vital_update.dart';
import '../../domain/entities/recent_transport.dart';
import '../../domain/entities/transport_session.dart';

class MockTransportDataSource {
  final Map<String, List<InTransitVitalUpdate>> _updates =
      <String, List<InTransitVitalUpdate>>{};
  final StreamController<List<RecentTransport>> _recentTransportController =
      StreamController<List<RecentTransport>>.broadcast();
  late final List<RecentTransport> _recentTransports = <RecentTransport>[
    RecentTransport(
      requestId: 'REQ-MOCK-HANYANG-COMPLETED',
      hospitalName: '한양대학교병원',
      statusUpdatedAt: DateTime.now().subtract(const Duration(hours: 4)),
      handoffStatus: HandoffStatus.completed,
    ),
    RecentTransport(
      requestId: 'REQ-MOCK-ASAN-COMPLETED',
      hospitalName: '서울아산병원',
      statusUpdatedAt: DateTime.now().subtract(const Duration(hours: 7)),
      handoffStatus: HandoffStatus.completed,
    ),
    RecentTransport(
      requestId: 'REQ-MOCK-KYUNGHEE-COMPLETED',
      hospitalName: '강동경희대학교병원',
      statusUpdatedAt: DateTime.now().subtract(const Duration(days: 1)),
      handoffStatus: HandoffStatus.completed,
    ),
  ];

  Future<void> addVitalUpdate(
    String requestId,
    InTransitVitalUpdate update,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _updates.putIfAbsent(requestId, () => <InTransitVitalUpdate>[]).add(update);
  }

  Future<void> requestHandoff(TransportSession session) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final int existingIndex = _recentTransports.indexWhere(
      (RecentTransport transport) => transport.requestId == session.requestId,
    );
    if (existingIndex >= 0) {
      return;
    }
    _recentTransports.insert(
      0,
      RecentTransport(
        requestId: session.requestId,
        hospitalName: session.destination.name,
        statusUpdatedAt: DateTime.now(),
        handoffStatus: HandoffStatus.requested,
      ),
    );
    _emitRecentTransports();
  }

  Future<List<RecentTransport>> getRecentTransports() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return List<RecentTransport>.unmodifiable(_recentTransports);
  }

  Stream<List<RecentTransport>> watchRecentTransports() async* {
    yield await getRecentTransports();
    yield* _recentTransportController.stream;
  }

  /// 병원 화면의 인계 확인 이벤트를 대신하는 목 전용 진입점입니다.
  ///
  /// 구급대원 앱 UI에서는 이 동작을 직접 호출하지 않습니다.
  Future<void> confirmHandoffByHospital(String requestId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final int index = _recentTransports.indexWhere(
      (RecentTransport transport) => transport.requestId == requestId,
    );
    if (index < 0 ||
        _recentTransports[index].handoffStatus == HandoffStatus.completed) {
      return;
    }
    _recentTransports[index] = _recentTransports[index].copyWith(
      statusUpdatedAt: DateTime.now(),
      handoffStatus: HandoffStatus.completed,
    );
    _emitRecentTransports();
  }

  void dispose() => _recentTransportController.close();

  void _emitRecentTransports() {
    _recentTransportController.add(
      List<RecentTransport>.unmodifiable(_recentTransports),
    );
  }
}
