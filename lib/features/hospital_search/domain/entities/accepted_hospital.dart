class AcceptedHospital {
  const AcceptedHospital({
    required this.offerId,
    required this.name,
    required this.address,
    required this.emergencyRoomPhone,
    required this.distanceMeters,
    required this.etaMinutes,
    required this.acceptedAt,
  });

  final String offerId;
  final String name;
  final String address;
  final String emergencyRoomPhone;
  final int? distanceMeters;
  final int? etaMinutes;
  final DateTime acceptedAt;

  String get distanceLabel {
    final int? meters = distanceMeters;
    if (meters == null) {
      return '거리 정보 없음';
    }
    if (meters < 100) {
      return '100m 미만';
    }
    if (meters < 1000) {
      return '${meters}m';
    }
    final double kilometers = meters / 1000;
    return '${kilometers.toStringAsFixed(kilometers >= 10 ? 0 : 1)}km';
  }

  String? get etaLabel => etaMinutes == null ? null : '예상 $etaMinutes분';
}
