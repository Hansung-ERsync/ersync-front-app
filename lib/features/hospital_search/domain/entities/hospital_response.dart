enum HospitalResponseStatus {
  pending,
  rejected,
  acceptanceWithdrawn,
  noResponse,
}

class HospitalResponse {
  const HospitalResponse({
    required this.offerId,
    required this.name,
    required this.status,
    required this.offeredAt,
    this.distanceMeters,
    this.etaMinutes,
    this.respondedAt,
    this.withdrawnAt,
    this.rejectionReason,
    this.rejectionDetail,
    this.withdrawalReason,
    this.withdrawalDetail,
  });

  final String offerId;
  final String name;
  final HospitalResponseStatus status;
  final int? distanceMeters;
  final int? etaMinutes;
  final DateTime offeredAt;
  final DateTime? respondedAt;
  final DateTime? withdrawnAt;
  final String? rejectionReason;
  final String? rejectionDetail;
  final String? withdrawalReason;
  final String? withdrawalDetail;

  bool get isPending => status == HospitalResponseStatus.pending;

  bool get isWithdrawn => status == HospitalResponseStatus.acceptanceWithdrawn;

  String get statusLabel => switch (status) {
    HospitalResponseStatus.pending => '응답 대기',
    HospitalResponseStatus.rejected => '거절',
    HospitalResponseStatus.acceptanceWithdrawn => '수락 철회',
    HospitalResponseStatus.noResponse => '응답 대기 종료',
  };

  String? get reasonLabel {
    final String? code = isWithdrawn ? withdrawalReason : rejectionReason;
    final String? detail = isWithdrawn ? withdrawalDetail : rejectionDetail;
    final String? label = switch (code) {
      'ER_GENERAL_BED_SHORTAGE' => '응급실 일반 병상 부족',
      'ISOLATION_BED_SHORTAGE' => '격리 병상 부족',
      'OPERATING_ROOM_SHORTAGE' => '수술실 부족',
      'ICU_SHORTAGE' => '중환자실 부족',
      'SPECIALIST_UNAVAILABLE' => '전문의 부재',
      'EQUIPMENT_UNAVAILABLE' => '장비 사용 불가',
      'BED_SHORTAGE' => '병상 부족',
      'OTHER' => '기타',
      _ => null,
    };
    if (label == null) {
      return detail?.trim().isNotEmpty == true ? detail!.trim() : null;
    }
    if (code == 'OTHER' && detail?.trim().isNotEmpty == true) {
      return '$label · ${detail!.trim()}';
    }
    return label;
  }

  DateTime get statusUpdatedAt => withdrawnAt ?? respondedAt ?? offeredAt;
}
