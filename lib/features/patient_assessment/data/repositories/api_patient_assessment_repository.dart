import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/idempotency/idempotency_key_generator.dart';
import '../../../../core/location/device_location.dart';
import '../../../../core/network/authenticated_request.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../storage/patient_assessment_draft_store.dart';
import '../../domain/entities/assessment_enums.dart';
import '../../domain/entities/patient_assessment_draft.dart';
import '../../domain/entities/transfer_request_receipt.dart';
import '../../domain/repositories/patient_assessment_repository.dart';

class ApiPatientAssessmentRepository implements PatientAssessmentRepository {
  ApiPatientAssessmentRepository(
    this._dio, {
    required this.callbackContact,
    required DeviceLocationService locationService,
    required PatientAssessmentDraftStore draftStore,
    required IdempotencyKeyGenerator idempotencyKeyGenerator,
  }) : _locationService = locationService,
       _draftStore = draftStore,
       _idempotencyKeyGenerator = idempotencyKeyGenerator;

  final Dio _dio;
  final String callbackContact;
  final DeviceLocationService _locationService;
  final PatientAssessmentDraftStore _draftStore;
  final IdempotencyKeyGenerator _idempotencyKeyGenerator;
  Future<void> _draftMutation = Future<void>.value();

  Options _options({String? idempotencyKey}) => Options(
    headers: idempotencyKey == null
        ? null
        : <String, Object>{'Idempotency-Key': idempotencyKey},
    extra: const <String, Object>{NetworkRequestExtraKeys.requiresAuth: true},
  );

  @override
  Future<PatientAssessmentDraft> loadDraft() {
    return DioExceptionMapper.guard(() async {
      final Response<Object?> response = await _dio.get<Object?>(
        '/api/v1/assessment-protocols/active',
        options: _options(),
      );
      final Map<String, Object?> protocol = _jsonObject(response.data);
      final String version = _requiredString(protocol, 'version');
      final String preKtasVersion = _requiredString(
        protocol,
        'preKtasStandardVersion',
      );
      await _draftMutation;
      final PatientAssessmentDraft? saved = await _draftStore.read();
      if (saved != null &&
          saved.assessmentProtocolVersion == version &&
          saved.preKtasStandardVersion == preKtasVersion) {
        return saved;
      }
      if (saved != null) {
        await clearDraft();
      }
      final PatientAssessmentDraft fresh = await _createFreshDraft(
        assessmentProtocolVersion: version,
        preKtasStandardVersion: preKtasVersion,
      );
      return fresh;
    });
  }

  @override
  Future<void> saveDraft(PatientAssessmentDraft draft) {
    return _enqueueDraftMutation(() => _draftStore.write(draft));
  }

  @override
  Future<void> clearDraft() {
    return _enqueueDraftMutation(_draftStore.clear);
  }

  Future<void> _enqueueDraftMutation(Future<void> Function() mutation) {
    final Future<void> operation = _draftMutation.then((_) => mutation());
    _draftMutation = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<TransferRequestReceipt> submit(PatientAssessmentDraft draft) {
    return DioExceptionMapper.guard(() async {
      final Response<Object?> response = await _dio.post<Object?>(
        '/api/v1/transport-requests',
        data: _requestBody(draft),
        options: _options(idempotencyKey: draft.clientRequestKey),
      );
      final Map<String, Object?> json = _jsonObject(response.data);
      return TransferRequestReceipt(
        requestId: _requiredString(json, 'transportRequestId'),
        status: _requiredString(json, 'status'),
        protocolVersion: _requiredString(json, 'assessmentProtocolVersion'),
        createdAt: DateTime.parse(_requiredString(json, 'createdAt')).toLocal(),
        currentSearchRadiusKm: 10,
        radiusStepKm: 10,
        expansionIntervalSeconds: 60,
        maximumSearchRadiusKm: 100,
      );
    });
  }

  Future<PatientAssessmentDraft> _createFreshDraft({
    required String assessmentProtocolVersion,
    required String preKtasStandardVersion,
  }) async {
    final DeviceLocationPoint? lastKnownLocation = await _locationService
        .getLastKnownLocation();
    final DeviceLocationPoint location =
        lastKnownLocation ?? await _locationService.getCurrentLocation();
    final DateTime now = DateTime.now();
    return PatientAssessmentDraft(
      assessmentProtocolVersion: assessmentProtocolVersion,
      preKtasStandardVersion: preKtasStandardVersion,
      clientRequestKey: _idempotencyKeyGenerator.create('transport'),
      sceneAddress: lastKnownLocation == null ? '현재 GPS 위치' : '최근 GPS 위치',
      latitude: location.latitude,
      longitude: location.longitude,
      locationSource: 'GPS',
      callbackContact: callbackContact,
      ageStatus: null,
      ageYears: null,
      sex: null,
      occurrenceType: null,
      occurrenceDetail: '',
      mechanism: null,
      injurySites: const <InjurySite>{},
      primarySymptom: null,
      primarySymptomDetail: '',
      secondarySymptoms: const <PatientSymptom>{},
      onsetTimeStatus: null,
      onsetAt: null,
      classificationStatus: null,
      preKtasLevel: null,
      exceptionReason: null,
      exceptionDetail: '',
      avpu: null,
      unassessableReason: null,
      unassessableDetail: '',
      assessedAt: now,
      observedAt: now,
      vitals: const <VitalType, VitalReadingDraft>{},
      measuredAt: now,
      treatments: const <TreatmentType>{},
      treatmentEntries: const <TreatmentType, TreatmentEntryDraft>{},
      performedAt: now,
      glucoseMgDl: null,
      leftPupil: null,
      rightPupil: null,
      medicalHistory: '',
      allergies: '',
      medications: '',
      isolationConcern: null,
      enteredAt: now,
    );
  }

  Map<String, Object?> _requestBody(PatientAssessmentDraft draft) {
    final bool isTrauma = draft.occurrenceType == OccurrenceType.nonDisease;
    final bool isCompleted =
        draft.classificationStatus == ClassificationStatus.completed;
    final bool isUnassessable = draft.avpu == AvpuLevel.unassessable;
    final String enteredAt = draft.enteredAt.toUtc().toIso8601String();
    return <String, Object?>{
      'assessmentProtocolVersion': draft.assessmentProtocolVersion,
      'origin': <String, Object?>{
        'latitude': draft.latitude,
        'longitude': draft.longitude,
        'source': draft.locationSource,
      },
      'patient': <String, Object?>{
        'ageStatus': draft.ageStatus!.apiValue,
        'ageYears': draft.ageStatus == AgeStatus.unknown
            ? null
            : draft.ageYears,
        'sex': draft.sex!.apiValue,
      },
      'incident': <String, Object?>{
        'occurrenceType': draft.occurrenceType!.apiValue,
        'mechanism': isTrauma ? draft.mechanism?.apiValue : null,
        'occurrenceDetail': draft.occurrenceType == OccurrenceType.other
            ? draft.occurrenceDetail.trim()
            : null,
        'injurySites': isTrauma
            ? draft.injurySites
                  .map((InjurySite value) => value.apiValue)
                  .toList()
            : const <String>[],
        'primarySymptom': draft.primarySymptom!.apiValue,
        'primarySymptomDetail': draft.primarySymptom == PatientSymptom.other
            ? draft.primarySymptomDetail.trim()
            : null,
        'secondarySymptoms': draft.secondarySymptoms
            .map((PatientSymptom value) => value.apiValue)
            .toList(),
        'onsetTimeStatus': draft.onsetTimeStatus!.apiValue,
        'onsetAt': draft.onsetTimeStatus == ClinicalTimeStatus.unknown
            ? null
            : draft.onsetAt?.toUtc().toIso8601String(),
        'enteredAt': enteredAt,
      },
      'preKtas': <String, Object?>{
        'classificationStatus': draft.classificationStatus!.apiValue,
        'level': isCompleted ? draft.preKtasLevel : null,
        'exceptionReason': isCompleted ? null : draft.exceptionReason?.apiValue,
        'exceptionDetail':
            !isCompleted &&
                draft.exceptionReason == EmergencyExceptionReason.other
            ? draft.exceptionDetail.trim()
            : null,
        'assessedAt': isCompleted
            ? draft.assessedAt.toUtc().toIso8601String()
            : null,
        'standardVersion': draft.preKtasStandardVersion,
        'enteredAt': enteredAt,
      },
      'consciousness': <String, Object?>{
        'avpu': draft.avpu!.apiValue,
        'unassessableReason': isUnassessable
            ? draft.unassessableReason?.apiValue
            : null,
        'unassessableDetail':
            isUnassessable &&
                draft.unassessableReason == UnassessableReason.other
            ? draft.unassessableDetail.trim()
            : null,
        'observedAt': draft.observedAt.toUtc().toIso8601String(),
        'enteredAt': enteredAt,
      },
      'vitalSigns': <String, Object?>{
        'measuredAt': draft.measuredAt.toUtc().toIso8601String(),
        'enteredAt': enteredAt,
        'measurements': VitalType.values
            .map(
              (VitalType type) => _vitalMeasurement(type, draft.vitals[type]!),
            )
            .toList(),
      },
      'treatments': draft.treatments
          .map((TreatmentType type) => _treatment(type, draft, enteredAt))
          .toList(),
      if (_hasSupplementalAssessment(draft))
        'supplementalAssessment': _supplementalAssessment(draft),
    };
  }

  bool _hasSupplementalAssessment(PatientAssessmentDraft draft) {
    return draft.glucoseMgDl != null ||
        draft.leftPupil != null ||
        draft.rightPupil != null ||
        draft.medicalHistory.trim().isNotEmpty ||
        draft.allergies.trim().isNotEmpty ||
        draft.medications.trim().isNotEmpty ||
        draft.isolationConcern != null;
  }

  Map<String, Object?> _supplementalAssessment(PatientAssessmentDraft draft) {
    final DateTime assessedAt = draft.performedAt;
    final DateTime enteredAt = draft.enteredAt.isBefore(assessedAt)
        ? assessedAt
        : draft.enteredAt;
    return <String, Object?>{
      'assessedAt': assessedAt.toUtc().toIso8601String(),
      'enteredAt': enteredAt.toUtc().toIso8601String(),
      'glucoseMgDl': draft.glucoseMgDl,
      'leftPupil': draft.leftPupil?.name.toUpperCase(),
      'rightPupil': draft.rightPupil?.name.toUpperCase(),
      'medicalHistory': _trimToNull(draft.medicalHistory),
      'allergies': _trimToNull(draft.allergies),
      'medications': _trimToNull(draft.medications),
      'isolationConcern': draft.isolationConcern,
    };
  }

  String? _trimToNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, Object?> _vitalMeasurement(
    VitalType type,
    VitalReadingDraft reading,
  ) {
    final bool hasValue = reading.state == MeasurementState.value;
    final bool unavailable = reading.state == MeasurementState.unavailable;
    return <String, Object?>{
      'type': switch (type) {
        VitalType.bloodPressure => 'BLOOD_PRESSURE',
        VitalType.pulse => 'PULSE',
        VitalType.respiratoryRate => 'RESPIRATORY_RATE',
        VitalType.temperature => 'TEMPERATURE',
        VitalType.oxygenSaturation => 'SPO2',
      },
      'state': reading.state!.apiValue,
      'primaryValue': hasValue ? reading.value : null,
      'secondaryValue': hasValue && type == VitalType.bloodPressure
          ? reading.secondaryValue
          : null,
      'unavailableReason': unavailable
          ? reading.unavailableReason?.apiValue
          : null,
      'unavailableDetail':
          unavailable &&
              reading.unavailableReason == MeasurementUnavailableReason.other
          ? reading.unavailableReasonDetail.trim()
          : null,
    };
  }

  Map<String, Object?> _treatment(
    TreatmentType type,
    PatientAssessmentDraft draft,
    String enteredAt,
  ) {
    if (type == TreatmentType.none) {
      return <String, Object?>{
        'type': type.apiValue,
        'attemptResult': null,
        'details': null,
        'performedAt': null,
        'enteredAt': enteredAt,
      };
    }
    final TreatmentEntryDraft entry = draft.treatmentEntries[type]!;
    final Map<String, Object?> details = entry.details.map(
      (String key, String value) => MapEntry<String, Object?>(
        key,
        _treatmentDetailValue(key, value.trim()),
      ),
    );
    if (type == TreatmentType.cpr) {
      details['startedAt'] = draft.performedAt.toUtc().toIso8601String();
    }
    return <String, Object?>{
      'type': type.apiValue,
      'attemptResult': entry.attemptResult!.apiValue,
      'details': details,
      'performedAt': draft.performedAt.toUtc().toIso8601String(),
      'enteredAt': enteredAt,
    };
  }

  Object _treatmentDetailValue(String key, String value) {
    if (key == 'shockCount') {
      return int.tryParse(value) ?? value;
    }
    if (key == 'flowRateLpm' || key == 'amountMl') {
      return num.tryParse(value) ?? value;
    }
    return value;
  }

  Map<String, Object?> _jsonObject(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map<dynamic, dynamic>) {
      return Map<String, Object?>.from(value);
    }
    throw const AppException('서버 응답을 처리할 수 없습니다.', code: 'INVALID_RESPONSE');
  }

  String _requiredString(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw const AppException('서버 응답을 처리할 수 없습니다.', code: 'INVALID_RESPONSE');
  }
}
