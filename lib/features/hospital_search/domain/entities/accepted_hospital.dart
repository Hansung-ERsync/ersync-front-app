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
  final int distanceMeters;
  final int? etaMinutes;
  final DateTime acceptedAt;

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters}m';
    }
    final double kilometers = distanceMeters / 1000;
    return '${kilometers.toStringAsFixed(kilometers >= 10 ? 0 : 1)}km';
  }

  String get etaLabel => etaMinutes == null ? 'ETA 계산 중' : '예상 $etaMinutes분';
}
