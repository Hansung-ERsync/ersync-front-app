import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/idempotency/idempotency_key_generator.dart';
import '../../../../core/network/authenticated_request.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../hospital_search/domain/entities/hospital_search_progress.dart';
import '../../../hospital_search/domain/entities/accepted_hospital.dart';
import '../../../hospital_search/domain/entities/hospital_search_session.dart';
import '../../../patient_assessment/domain/entities/assessment_enums.dart';
import '../../domain/entities/active_transport_recovery.dart';
import '../../domain/entities/clinical_update_result.dart';
import '../../domain/entities/transport_location_snapshot.dart';
import '../../domain/entities/in_transit_clinical_updates.dart';
import '../../domain/entities/in_transit_vital_update.dart';
import '../../domain/entities/patient_transport_summary.dart';
import '../../domain/entities/recent_transport.dart';
import '../../domain/entities/transport_session.dart';
import '../../domain/entities/transport_location_update.dart';
import '../../domain/repositories/transport_repository.dart';
import '../storage/pending_transport_command_store.dart';

class ApiTransportRepository implements TransportRepository {
  ApiTransportRepository(
    this._dio, {
    PendingTransportCommandStore? pendingCommandStore,
    IdempotencyKeyGenerator? idempotencyKeyGenerator,
  }) : _pendingCommandStore =
           pendingCommandStore ?? InMemoryPendingTransportCommandStore(),
       _idempotencyKeyGenerator =
           idempotencyKeyGenerator ?? IdempotencyKeyGenerator();

  final Dio _dio;
  final PendingTransportCommandStore _pendingCommandStore;
  final IdempotencyKeyGenerator _idempotencyKeyGenerator;

  Options _options({String? idempotencyKey, String? method}) => Options(
    method: method,
    headers: idempotencyKey == null
        ? null
        : <String, Object>{'Idempotency-Key': idempotencyKey},
    extra: const <String, Object>{NetworkRequestExtraKeys.requiresAuth: true},
  );

  @override
  Future<ActiveTransportRecovery?> recoverActiveTransport() {
    return DioExceptionMapper.guard(() async {
      await _retryPendingCommands();
      final Response<Object?> listResponse = await _dio.get<Object?>(
        '/api/v1/transport-requests',
        queryParameters: const <String, Object>{
          'view': 'ACTIVE',
          'page': 0,
          'size': 1,
        },
        options: _options(),
      );
      final Object? rawItems = _jsonObject(listResponse.data)['items'];
      if (rawItems is! List<Object?>) {
        throw const AppException(
          '진행 중 이송 응답을 처리할 수 없습니다.',
          code: 'INVALID_RESPONSE',
        );
      }
      if (rawItems.isEmpty) {
        return null;
      }

      final Map<String, Object?> active = _jsonObject(rawItems.first);
      final String requestId = _string(active, 'transportRequestId');
      final String status = _string(active, 'status');
      final DateTime createdAt = _date(active, 'createdAt');

      // 인계 요청을 보낸 건은 메인의 최근 이송에서 확인한다. 자동 복구로
      // 이송 화면에 다시 진입시키면 새 환자 등록이 막힌다.
      if (status == 'HANDOFF_REQUESTED') {
        return null;
      }

      final Response<Object?> detailResponse = await _dio.get<Object?>(
        '/api/v1/transport-requests/$requestId',
        options: _options(),
      );
      final Map<String, Object?> detail = _jsonObject(detailResponse.data);
      final PatientTransportSummary summary = _patientSummary(detail);

      final Response<Object?> searchResponse = await _dio.get<Object?>(
        '/api/v1/transport-requests/$requestId/hospital-search',
        options: _options(),
      );
      final Map<String, Object?> search = _jsonObject(searchResponse.data);

      if (status == 'SEARCHING' || status == 'ACCEPTED_AVAILABLE') {
        return ActiveTransportRecovery.search(
          HospitalSearchSession(
            requestId: requestId,
            startedAt: createdAt,
            initialRadiusKm: 10,
            radiusStepKm: 10,
            expansionIntervalSeconds: 60,
            maximumRadiusKm: 100,
            patientSummary: summary,
          ),
        );
      }

      if (status == 'EN_ROUTE') {
        final AcceptedHospital? destination = _currentDestination(search);
        if (destination == null) {
          throw const AppException(
            '현재 목적지 병원 정보를 복구하지 못했습니다.',
            code: 'INVALID_RESPONSE',
          );
        }
        final Response<Object?> locationResponse = await _dio.get<Object?>(
          '/api/v1/transport-requests/$requestId/location',
          options: _options(),
        );
        return ActiveTransportRecovery.transport(
          TransportSession(
            requestId: requestId,
            requestStartedAt: createdAt,
            destination: destination,
            patientSummary: summary,
            requestStatus: status,
            locationSnapshot: _locationSnapshot(locationResponse.data),
          ),
        );
      }

      return null;
    });
  }

  @override
  Future<ClinicalUpdateResult> addVitalUpdate(
    String requestId,
    InTransitVitalUpdate update,
  ) {
    final String enteredAt = DateTime.now().toUtc().toIso8601String();
    final String measuredAt = update.measuredAt.toUtc().toIso8601String();
    return DioExceptionMapper.guard(
      () => _sendIdempotent<ClinicalUpdateResult>(
        operation: 'vitals:$requestId',
        method: 'POST',
        path:
            '/api/v1/transport-requests/$requestId/clinical-updates/vital-signs',
        body: <String, Object?>{
          'measuredAt': measuredAt,
          'enteredAt': enteredAt,
          'measurements': <Map<String, Object?>>[
            _valueMeasurement(
              'BLOOD_PRESSURE',
              update.systolic,
              update.diastolic,
            ),
            _valueMeasurement('PULSE', update.pulse),
            _valueMeasurement('RESPIRATORY_RATE', update.respiratoryRate),
            _valueMeasurement('TEMPERATURE', update.temperature),
            _valueMeasurement('SPO2', update.oxygenSaturation),
          ],
        },
        idempotencyKeyPrefix: 'vitals-$requestId',
        parse: _clinicalUpdateResult,
      ),
    );
  }

  @override
  Future<ClinicalUpdateResult> addConsciousnessUpdate(
    String requestId,
    InTransitConsciousnessUpdate update,
  ) {
    final bool isUnassessable = update.avpu.apiValue == 'UNASSESSABLE';
    return DioExceptionMapper.guard(
      () => _sendIdempotent<ClinicalUpdateResult>(
        operation: 'consciousness:$requestId',
        method: 'POST',
        path:
            '/api/v1/transport-requests/$requestId/clinical-updates/consciousness',
        body: <String, Object?>{
          'avpu': update.avpu.apiValue,
          'unassessableReason': isUnassessable
              ? update.unassessableReason?.apiValue
              : null,
          'unassessableDetail':
              isUnassessable && update.unassessableReason?.apiValue == 'OTHER'
              ? update.unassessableDetail.trim()
              : null,
          'observedAt': update.observedAt.toUtc().toIso8601String(),
          'enteredAt': update.enteredAt.toUtc().toIso8601String(),
        },
        idempotencyKeyPrefix: 'consciousness-$requestId',
        parse: _clinicalUpdateResult,
      ),
    );
  }

  @override
  Future<ClinicalUpdateResult> addPreKtasUpdate(
    String requestId,
    InTransitPreKtasUpdate update,
  ) {
    final bool completed = update.classificationStatus.apiValue == 'COMPLETED';
    return DioExceptionMapper.guard(
      () => _sendIdempotent<ClinicalUpdateResult>(
        operation: 'pre-ktas:$requestId',
        method: 'POST',
        path: '/api/v1/transport-requests/$requestId/clinical-updates/pre-ktas',
        body: <String, Object?>{
          'classificationStatus': update.classificationStatus.apiValue,
          'level': completed ? update.level : null,
          'exceptionReason': completed
              ? null
              : update.exceptionReason?.apiValue,
          'exceptionDetail':
              !completed && update.exceptionReason?.apiValue == 'OTHER'
              ? update.exceptionDetail.trim()
              : null,
          'assessedAt': completed
              ? update.assessedAt?.toUtc().toIso8601String()
              : null,
          'standardVersion': update.standardVersion,
          'enteredAt': update.enteredAt.toUtc().toIso8601String(),
        },
        idempotencyKeyPrefix: 'prektas-$requestId',
        parse: _clinicalUpdateResult,
      ),
    );
  }

  @override
  Future<ClinicalUpdateResult> addTreatmentUpdate(
    String requestId,
    InTransitTreatmentUpdate update,
  ) {
    final String performedAt = update.performedAt.toUtc().toIso8601String();
    final Map<String, Object?> details = <String, Object?>{
      ...update.details,
      if (update.type.apiValue == 'CPR') 'startedAt': performedAt,
    };
    return DioExceptionMapper.guard(
      () => _sendIdempotent<ClinicalUpdateResult>(
        operation: 'treatment:$requestId',
        method: 'POST',
        path:
            '/api/v1/transport-requests/$requestId/clinical-updates/treatments',
        body: <String, Object?>{
          'type': update.type.apiValue,
          'attemptResult': update.attemptResult.apiValue,
          'details': details,
          'performedAt': performedAt,
          'enteredAt': update.enteredAt.toUtc().toIso8601String(),
        },
        idempotencyKeyPrefix: 'treatment-$requestId',
        parse: _clinicalUpdateResult,
      ),
    );
  }

  @override
  Future<void> requestHandoff(TransportSession session) {
    return DioExceptionMapper.guard(
      () => _sendIdempotent<void>(
        operation: 'handoff:${session.requestId}',
        method: 'POST',
        path: '/api/v1/transport-requests/${session.requestId}/handoff-request',
        idempotencyKeyPrefix: 'handoff-${session.requestId}',
        parse: (_) {},
      ),
    );
  }

  @override
  Future<TransportLocationSnapshot> updateLocation(
    String requestId,
    TransportLocationUpdate update,
    String idempotencyKey,
  ) {
    return DioExceptionMapper.guard(
      () => _sendIdempotent<TransportLocationSnapshot>(
        operation: 'location:$requestId',
        method: 'PUT',
        path: '/api/v1/transport-requests/$requestId/location',
        body: <String, Object?>{
          'latitude': update.latitude,
          'longitude': update.longitude,
          'capturedAt': update.capturedAt.toUtc().toIso8601String(),
        },
        idempotencyKeyPrefix: 'location-$requestId',
        preferredIdempotencyKey: idempotencyKey,
        parse: _locationSnapshot,
      ),
    );
  }

  @override
  Future<void> cancelRequest(
    String requestId,
    TransportCancellation cancellation,
  ) {
    return DioExceptionMapper.guard(
      () => _sendIdempotent<void>(
        operation: 'cancel:$requestId',
        method: 'POST',
        path: '/api/v1/transport-requests/$requestId/cancel',
        body: <String, Object?>{
          'reason': cancellation.reason.apiValue,
          if (cancellation.normalizedDetail != null)
            'detail': cancellation.normalizedDetail,
        },
        idempotencyKeyPrefix: 'cancel-$requestId',
        parse: (_) {},
      ),
    );
  }

  Future<T> _sendIdempotent<T>({
    required String operation,
    required String method,
    required String path,
    required String idempotencyKeyPrefix,
    required T Function(Object? value) parse,
    Map<String, Object?>? body,
    String? preferredIdempotencyKey,
  }) async {
    PendingTransportCommand? command = await _pendingCommandStore.read(
      operation,
    );
    command ??= PendingTransportCommand(
      operation: operation,
      method: method,
      path: path,
      idempotencyKey:
          preferredIdempotencyKey ??
          _idempotencyKeyGenerator.create(idempotencyKeyPrefix),
      body: body,
    );
    await _pendingCommandStore.write(command);
    try {
      final Response<Object?> response = await _dio.request<Object?>(
        command.path,
        data: command.body,
        options: _options(
          method: command.method,
          idempotencyKey: command.idempotencyKey,
        ),
      );
      final T result = parse(response.data);
      await _pendingCommandStore.remove(operation);
      return result;
    } on DioException catch (error) {
      if (_isDefinitiveCommandFailure(error)) {
        await _pendingCommandStore.remove(operation);
      }
      rethrow;
    }
  }

  Future<void> _retryPendingCommands() async {
    final List<PendingTransportCommand> commands = await _pendingCommandStore
        .readAll();
    for (final PendingTransportCommand command in commands) {
      try {
        await _dio.request<Object?>(
          command.path,
          data: command.body,
          options: _options(
            method: command.method,
            idempotencyKey: command.idempotencyKey,
          ),
        );
        await _pendingCommandStore.remove(command.operation);
      } on DioException catch (error) {
        if (!_isDefinitiveCommandFailure(error)) {
          rethrow;
        }
        await _pendingCommandStore.remove(command.operation);
      }
    }
  }

  bool _isDefinitiveCommandFailure(DioException error) {
    final int? statusCode = error.response?.statusCode;
    return statusCode != null &&
        statusCode >= 400 &&
        statusCode < 500 &&
        statusCode != 401;
  }

  @override
  Future<List<RecentTransport>> getRecentTransports() {
    return DioExceptionMapper.guard(() async {
      final Response<Object?> response = await _dio.get<Object?>(
        '/api/v1/transport-requests',
        queryParameters: const <String, Object>{
          'view': 'RECENT',
          'page': 0,
          'size': 20,
        },
        options: _options(),
      );
      final Map<String, Object?> body = _jsonObject(response.data);
      final Object? rawItems = body['items'];
      if (rawItems is! List<Object?>) {
        throw const AppException(
          '최근 이송 응답을 처리할 수 없습니다.',
          code: 'INVALID_RESPONSE',
        );
      }
      return rawItems.map(_recentTransport).toList(growable: false);
    });
  }

  @override
  Stream<List<RecentTransport>> watchRecentTransports() async* {
    while (true) {
      yield await getRecentTransports();
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  }

  PatientTransportSummary _patientSummary(Map<String, Object?> detail) {
    final Map<String, Object?> patient = _jsonObject(detail['patient']);
    final Map<String, Object?> incident = _jsonObject(detail['incident']);
    final Map<String, Object?> snapshot = _jsonObject(detail['latestSnapshot']);
    final Map<String, Object?> preKtas = _jsonObject(snapshot['preKtas']);
    final Map<String, Object?> consciousness = _jsonObject(
      snapshot['consciousness'],
    );
    final Map<String, Object?> vitalSigns = _jsonObject(snapshot['vitalSigns']);
    final List<Map<String, Object?>> treatments = _jsonObjectList(
      snapshot['treatments'],
    );
    final Map<String, Object?> supplemental =
        _optionalJsonObject(detail['supplementalAssessment']) ??
        const <String, Object?>{};

    final Map<String, Map<String, Object?>> measurements =
        <String, Map<String, Object?>>{};
    final Object? rawMeasurements = vitalSigns['measurements'];
    if (rawMeasurements is List<Object?>) {
      for (final Object? raw in rawMeasurements) {
        final Map<String, Object?> measurement = _jsonObject(raw);
        measurements[_string(measurement, 'type')] = measurement;
      }
    }

    final Map<String, Object?> bloodPressure =
        measurements['BLOOD_PRESSURE'] ?? const <String, Object?>{};
    final Map<String, Object?> pulse =
        measurements['PULSE'] ?? const <String, Object?>{};
    final Map<String, Object?> respiratoryRate =
        measurements['RESPIRATORY_RATE'] ?? const <String, Object?>{};
    final Map<String, Object?> temperature =
        measurements['TEMPERATURE'] ?? const <String, Object?>{};
    final Map<String, Object?> oxygenSaturation =
        measurements['SPO2'] ?? const <String, Object?>{};

    final String ageStatus = _string(patient, 'ageStatus');
    final int? ageYears = _int(patient['ageYears']);
    final String classificationStatus = _string(
      preKtas,
      'classificationStatus',
    );
    final int? preKtasLevel = _int(preKtas['level']);
    final Map<String, Object?>? latestTreatment = _latestTreatment(treatments);
    return PatientTransportSummary(
      ageLabel: switch (ageStatus) {
        'EXACT' when ageYears != null => '$ageYears세',
        'ESTIMATED' when ageYears != null => '$ageYears세 추정',
        _ => '확인 불가',
      },
      sexLabel: switch (_string(patient, 'sex')) {
        'MALE' => '남성',
        'FEMALE' => '여성',
        _ => '확인 불가',
      },
      primarySymptomLabel: _symptomLabel(_string(incident, 'primarySymptom')),
      preKtasLabel: classificationStatus == 'COMPLETED' && preKtasLevel != null
          ? 'Pre-KTAS $preKtasLevel'
          : '긴급 전송',
      avpuLabel: switch (_string(consciousness, 'avpu')) {
        'A' => 'A · 명료',
        'V' => 'V · 음성 반응',
        'P' => 'P · 통증 반응',
        'U' => 'U · 무반응',
        _ => '평가 불가',
      },
      preKtasStandardVersion:
          preKtas['standardVersion'] as String? ?? 'DEV_UNCONFIRMED',
      systolic: _measurementValue(bloodPressure),
      diastolic: _measurementValue(bloodPressure, secondary: true),
      pulse: _measurementValue(pulse),
      respiratoryRate: _measurementValue(respiratoryRate),
      temperature: _measurementValue(temperature),
      oxygenSaturation: _measurementValue(oxygenSaturation),
      vitalsMeasuredAt: _nullableDate(vitalSigns['measuredAt']),
      bloodPressureStateLabel: _measurementStateLabel(bloodPressure),
      pulseStateLabel: _measurementStateLabel(pulse),
      respiratoryRateStateLabel: _measurementStateLabel(respiratoryRate),
      temperatureStateLabel: _measurementStateLabel(temperature),
      oxygenSaturationStateLabel: _measurementStateLabel(oxygenSaturation),
      glucoseMgDl: _int(supplemental['glucoseMgDl']),
      leftPupilLabel: _pupilLabel(supplemental['leftPupil']),
      rightPupilLabel: _pupilLabel(supplemental['rightPupil']),
      medicalHistory: _optionalString(supplemental['medicalHistory']),
      allergies: _optionalString(supplemental['allergies']),
      medications: _optionalString(supplemental['medications']),
      isolationConcern: supplemental['isolationConcern'] as bool?,
      supplementalAssessedAt: _nullableDate(supplemental['assessedAt']),
      occurrenceLabel: _enumLabel(
        OccurrenceType.values.map(
          (OccurrenceType value) => (value.apiValue, value.label),
        ),
        _optionalString(incident['occurrenceType']),
      ),
      occurrenceDetail: _optionalString(incident['occurrenceDetail']),
      injuryMechanismLabel: _enumLabel(
        InjuryMechanism.values.map(
          (InjuryMechanism value) => (value.apiValue, value.label),
        ),
        _optionalString(incident['injuryMechanism']),
      ),
      injurySitesLabel: _enumLabels(
        InjurySite.values.map(
          (InjurySite value) => (value.apiValue, value.label),
        ),
        incident['injurySites'],
      ),
      primarySymptomDetail: _optionalString(incident['primarySymptomDetail']),
      secondarySymptomsLabel: _enumLabels(
        PatientSymptom.values.map(
          (PatientSymptom value) => (value.apiValue, value.label),
        ),
        incident['secondarySymptoms'],
      ),
      onsetLabel: _onsetLabel(incident),
      preKtasDetailLabel: _clinicalExceptionLabel(
        reason: _optionalString(preKtas['exceptionReason']),
        detail: _optionalString(preKtas['exceptionDetail']),
        values: EmergencyExceptionReason.values.map(
          (EmergencyExceptionReason value) => (value.apiValue, value.label),
        ),
      ),
      consciousnessDetailLabel: _clinicalExceptionLabel(
        reason: _optionalString(consciousness['unassessableReason']),
        detail: _optionalString(consciousness['unassessableDetail']),
        values: UnassessableReason.values.map(
          (UnassessableReason value) => (value.apiValue, value.label),
        ),
      ),
      latestTreatmentLabel: latestTreatment == null
          ? null
          : _treatmentLabel(latestTreatment),
      latestTreatmentAt: latestTreatment == null
          ? null
          : _nullableDate(latestTreatment['performedAt']),
      lastClinicalUpdateAt: _nullableDate(snapshot['lastClinicalUpdateAt']),
    );
  }

  String? _onsetLabel(Map<String, Object?> incident) {
    final String? status = _optionalString(incident['onsetTimeStatus']);
    if (status == null) {
      return null;
    }
    if (status == 'UNKNOWN') {
      return '확인 불가';
    }
    final DateTime? onsetAt = _nullableDate(incident['onsetAt']);
    if (onsetAt == null) {
      return _enumLabel(
        ClinicalTimeStatus.values.map(
          (ClinicalTimeStatus value) => (value.apiValue, value.label),
        ),
        status,
      );
    }
    final String prefix = status == 'ESTIMATED' ? '추정 · ' : '';
    return '$prefix${_dateTimeLabel(onsetAt)}';
  }

  Map<String, Object?>? _latestTreatment(
    List<Map<String, Object?>> treatments,
  ) {
    Map<String, Object?>? latest;
    DateTime? latestAt;
    for (final Map<String, Object?> treatment in treatments) {
      if (treatment['type'] == 'NONE') {
        continue;
      }
      final DateTime? performedAt = _nullableDate(treatment['performedAt']);
      if (latest == null ||
          (performedAt != null &&
              (latestAt == null || performedAt.isAfter(latestAt)))) {
        latest = treatment;
        latestAt = performedAt;
      }
    }
    return latest;
  }

  String _dateTimeLabel(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}.${twoDigits(value.month)}.${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  String? _clinicalExceptionLabel({
    required String? reason,
    required String? detail,
    required Iterable<(String, String)> values,
  }) {
    if (reason == null) {
      return detail;
    }
    final String label = _enumLabel(values, reason) ?? reason;
    return detail == null ? label : '$label · $detail';
  }

  String? _treatmentLabel(Map<String, Object?> treatment) {
    final String? type = _optionalString(treatment['type']);
    if (type == null || type == 'NONE') {
      return null;
    }
    final String typeLabel =
        _enumLabel(
          TreatmentType.values.map(
            (TreatmentType value) => (value.apiValue, value.label),
          ),
          type,
        ) ??
        type;
    final String? attemptResult = _optionalString(treatment['attemptResult']);
    if (attemptResult == null) {
      return typeLabel;
    }
    final String resultLabel =
        _enumLabel(
          TreatmentAttemptResult.values.map(
            (TreatmentAttemptResult value) => (value.apiValue, value.label),
          ),
          attemptResult,
        ) ??
        attemptResult;
    return '$typeLabel · $resultLabel';
  }

  String? _enumLabel(Iterable<(String, String)> values, String? apiValue) {
    if (apiValue == null) {
      return null;
    }
    for (final (String value, String label) in values) {
      if (value == apiValue) {
        return label;
      }
    }
    return null;
  }

  String? _enumLabels(Iterable<(String, String)> values, Object? rawValues) {
    if (rawValues is! List<Object?> || rawValues.isEmpty) {
      return null;
    }
    final List<String> labels = rawValues
        .whereType<String>()
        .map((String value) => _enumLabel(values, value) ?? value)
        .toList(growable: false);
    return labels.isEmpty ? null : labels.join(', ');
  }

  ClinicalUpdateResult _clinicalUpdateResult(Object? value) {
    final Map<String, Object?> json = _jsonObject(value);
    final Object? snapshotUpdated = json['snapshotUpdated'];
    if (snapshotUpdated is! bool) {
      throw const AppException(
        '임상 갱신 응답을 처리할 수 없습니다.',
        code: 'INVALID_RESPONSE',
      );
    }
    return ClinicalUpdateResult(
      snapshotUpdated: snapshotUpdated,
      lastClinicalUpdateAt: _nullableDate(json['lastClinicalUpdateAt']),
    );
  }

  TransportLocationSnapshot _locationSnapshot(Object? value) {
    final Map<String, Object?> json = _jsonObject(value);
    final String freshness = _string(json, 'freshness');
    return TransportLocationSnapshot(
      freshness: freshness,
      ageSeconds: _int(json['ageSeconds']),
      routeEstimateStatus: _optionalString(json['routeEstimateStatus']),
      routeDistanceMeters: _int(json['routeDistanceMeters']),
      etaSeconds: _int(json['etaSeconds']),
      lastSuccessfulRouteDistanceMeters: _int(
        json['lastSuccessfulRouteDistanceMeters'],
      ),
      lastSuccessfulEtaSeconds: _int(json['lastSuccessfulEtaSeconds']),
      lastSuccessfulEtaCalculatedAt: _nullableDate(
        json['lastSuccessfulEtaCalculatedAt'],
      ),
    );
  }

  String? _pupilLabel(Object? value) {
    return switch (value) {
      'NORMAL' => '정상',
      'SLUGGISH' => '둔함',
      'FIXED' => '고정',
      'UNASSESSABLE' => '확인 불가',
      _ => null,
    };
  }

  AcceptedHospital? _currentDestination(Map<String, Object?> search) {
    final String? destinationOfferId =
        search['currentDestinationOfferId'] as String?;
    final Object? rawOffers = search['offers'];
    if (rawOffers is! List<Object?>) {
      return null;
    }
    for (final Object? raw in rawOffers) {
      final Map<String, Object?> offer = _jsonObject(raw);
      final String offerId = _string(offer, 'offerId');
      if (offerId != destinationOfferId &&
          offer['currentDestination'] != true) {
        continue;
      }
      final int? distanceMeters =
          _int(offer['routeDistanceMeters']) ??
          _int(offer['straightLineDistanceMeters']);
      final int? etaSeconds = _int(offer['etaSeconds']);
      return AcceptedHospital(
        offerId: offerId,
        name: _string(offer, 'hospitalName'),
        address: _hospitalAddress(offer),
        detailAddress: _optionalString(offer['hospitalDetailAddress']),
        emergencyRoomPhone: offer['hospitalContact'] as String? ?? '연락처 정보 없음',
        latitude: _double(offer['hospitalLatitude']),
        longitude: _double(offer['hospitalLongitude']),
        distanceMeters: distanceMeters,
        etaMinutes: etaSeconds == null ? null : (etaSeconds / 60).ceil(),
        acceptedAt:
            _nullableDate(offer['respondedAt']) ??
            _nullableDate(offer['offeredAt']) ??
            DateTime.now(),
      );
    }
    return null;
  }

  double? _measurementValue(
    Map<String, Object?> measurement, {
    bool secondary = false,
  }) {
    if (measurement['state'] != 'VALUE') {
      return null;
    }
    final Object? raw =
        measurement[secondary ? 'secondaryValue' : 'primaryValue'];
    return raw is num ? raw.toDouble() : null;
  }

  String _measurementStateLabel(Map<String, Object?> measurement) {
    return switch (measurement['state']) {
      'MEASUREMENT_UNAVAILABLE' => '측정 불가',
      'PATIENT_REFUSED' => '환자 거부',
      _ => '확인 불가',
    };
  }

  String _symptomLabel(String value) {
    return switch (value) {
      'ALTERED_CONSCIOUSNESS' => '의식 저하',
      'DYSPNEA' => '호흡곤란',
      'RESPIRATORY_ARREST' => '호흡정지',
      'CHEST_PAIN' => '흉통',
      'CARDIAC_ARREST' => '심정지',
      'SUSPECTED_STROKE' => '뇌졸중 의심',
      'SEIZURE_SYNCOPE' => '경련·실신',
      'TRAUMA' => '외상',
      'BLEEDING' => '출혈',
      'GASTROINTESTINAL' => '소화기 증상',
      'POISONING' => '중독',
      'BURN' => '화상',
      'PREGNANCY_DELIVERY' => '임신·분만',
      'BEHAVIORAL_SELF_HARM' => '행동 이상·자해',
      'FEVER_INFECTION' => '발열·감염',
      'OTHER' => '기타',
      _ => '확인 불가',
    };
  }

  Map<String, Object?> _valueMeasurement(
    String type,
    double primaryValue, [
    double? secondaryValue,
  ]) {
    return <String, Object?>{
      'type': type,
      'state': 'VALUE',
      'primaryValue': primaryValue,
      'secondaryValue': secondaryValue,
    };
  }

  RecentTransport _recentTransport(Object? value) {
    final Map<String, Object?> json = _jsonObject(value);
    final String status = _string(json, 'status');
    final HandoffStatus handoffStatus = switch (status) {
      'HANDOFF_REQUESTED' => HandoffStatus.requested,
      'COMPLETED' => HandoffStatus.completed,
      'CANCELLED' => HandoffStatus.cancelled,
      _ => throw const AppException(
        '지원하지 않는 최근 이송 상태입니다.',
        code: 'INVALID_RESPONSE',
      ),
    };
    return RecentTransport(
      requestId: _string(json, 'transportRequestId'),
      hospitalName: json['hospitalName'] as String?,
      statusUpdatedAt: DateTime.parse(
        _string(json, 'statusUpdatedAt'),
      ).toLocal(),
      handoffStatus: handoffStatus,
    );
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

  Map<String, Object?>? _optionalJsonObject(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map<dynamic, dynamic>) {
      return Map<String, Object?>.from(value);
    }
    return null;
  }

  List<Map<String, Object?>> _jsonObjectList(Object? value) {
    if (value is! List<Object?>) {
      return const <Map<String, Object?>>[];
    }
    return value.map(_jsonObject).toList(growable: false);
  }

  String _string(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw const AppException('서버 응답을 처리할 수 없습니다.', code: 'INVALID_RESPONSE');
  }

  String _hospitalAddress(Map<String, Object?> offer) {
    final Object? value = offer['hospitalAddress'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return '주소 정보 동기화 중';
  }

  String? _optionalString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  double? _double(Object? value) => value is num ? value.toDouble() : null;

  int? _int(Object? value) => value is num ? value.toInt() : null;

  DateTime _date(Map<String, Object?> json, String key) =>
      DateTime.parse(_string(json, key)).toLocal();

  DateTime? _nullableDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
