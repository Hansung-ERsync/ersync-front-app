class TransportLocationSnapshot {
  const TransportLocationSnapshot({
    required this.freshness,
    this.latitude,
    this.longitude,
    this.capturedAt,
    this.ageSeconds,
    this.routeEstimateStatus,
    this.routeDistanceMeters,
    this.etaSeconds,
    this.lastSuccessfulRouteDistanceMeters,
    this.lastSuccessfulEtaSeconds,
    this.lastSuccessfulEtaCalculatedAt,
  });

  final String freshness;
  final double? latitude;
  final double? longitude;
  final DateTime? capturedAt;
  final int? ageSeconds;
  final String? routeEstimateStatus;
  final int? routeDistanceMeters;
  final int? etaSeconds;
  final int? lastSuccessfulRouteDistanceMeters;
  final int? lastSuccessfulEtaSeconds;
  final DateTime? lastSuccessfulEtaCalculatedAt;

  bool get isStale => freshness == 'STALE';

  String get freshnessLabel => switch (freshness) {
    'CURRENT' => '현재 위치 기준',
    'STALE' when ageSeconds != null => '마지막 위치 ${_elapsedLabel(ageSeconds!)} 전',
    'STALE' => '마지막 위치 기준',
    _ => '위치 수신 대기 중',
  };

  String? get routeDistanceLabel {
    final int? meters = routeEstimateStatus == 'AVAILABLE'
        ? routeDistanceMeters
        : lastSuccessfulRouteDistanceMeters;
    if (meters == null) {
      return null;
    }
    if (meters < 1000) {
      return '${meters}m';
    }
    final double kilometers = meters / 1000;
    return '${kilometers.toStringAsFixed(kilometers >= 10 ? 0 : 1)}km';
  }

  String get etaLabel {
    final int? seconds = routeEstimateStatus == 'AVAILABLE'
        ? etaSeconds
        : lastSuccessfulEtaSeconds;
    if (seconds == null) {
      return switch (routeEstimateStatus) {
        'CALCULATING' => '경로 계산 중',
        'UNAVAILABLE' => 'ETA 계산 불가',
        _ => 'ETA 확인 중',
      };
    }
    final int minutes = (seconds / 60).ceil();
    return routeEstimateStatus == 'AVAILABLE'
        ? '예상 $minutes분'
        : '이전 ETA 약 $minutes분';
  }

  String? get routeStatusLabel {
    if (routeEstimateStatus == 'AVAILABLE') {
      return null;
    }
    if (lastSuccessfulRouteDistanceMeters == null &&
        lastSuccessfulEtaSeconds == null) {
      return switch (routeEstimateStatus) {
        'CALCULATING' => '현재 경로 계산 중',
        'UNAVAILABLE' => '현재 ETA 계산 불가',
        _ => null,
      };
    }
    final String calculatedAt = lastSuccessfulEtaCalculatedAt == null
        ? ''
        : ' · ${_clockLabel(lastSuccessfulEtaCalculatedAt!)} 기준';
    return switch (routeEstimateStatus) {
      'CALCULATING' => '현재 경로 계산 중 · 이전 성공값$calculatedAt',
      'UNAVAILABLE' => '현재 ETA 계산 불가 · 이전 성공값$calculatedAt',
      _ => '이전 성공값$calculatedAt',
    };
  }

  static String _elapsedLabel(int seconds) {
    if (seconds < 60) {
      return '$seconds초';
    }
    return '${seconds ~/ 60}분';
  }

  static String _clockLabel(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
