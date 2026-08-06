import '../../../patient_assessment/domain/entities/assessment_enums.dart';

class InTransitConsciousnessUpdate {
  const InTransitConsciousnessUpdate({
    required this.avpu,
    required this.observedAt,
    required this.enteredAt,
    this.unassessableReason,
    this.unassessableDetail = '',
  });

  final AvpuLevel avpu;
  final UnassessableReason? unassessableReason;
  final String unassessableDetail;
  final DateTime observedAt;
  final DateTime enteredAt;
}

class InTransitPreKtasUpdate {
  const InTransitPreKtasUpdate({
    required this.classificationStatus,
    required this.standardVersion,
    required this.enteredAt,
    this.level,
    this.exceptionReason,
    this.exceptionDetail = '',
    this.assessedAt,
  });

  final ClassificationStatus classificationStatus;
  final int? level;
  final EmergencyExceptionReason? exceptionReason;
  final String exceptionDetail;
  final DateTime? assessedAt;
  final String standardVersion;
  final DateTime enteredAt;
}

class InTransitTreatmentUpdate {
  const InTransitTreatmentUpdate({
    required this.type,
    required this.attemptResult,
    required this.details,
    required this.performedAt,
    required this.enteredAt,
  });

  final TreatmentType type;
  final TreatmentAttemptResult attemptResult;
  final Map<String, Object?> details;
  final DateTime performedAt;
  final DateTime enteredAt;
}
