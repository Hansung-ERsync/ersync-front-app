import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/network/authenticated_request.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../hospital_search/domain/entities/hospital_search_progress.dart';
import '../../../hospital_search/domain/entities/accepted_hospital.dart';
import '../../../hospital_search/domain/entities/hospital_search_session.dart';
import '../../domain/entities/active_transport_recovery.dart';
import '../../domain/entities/in_transit_clinical_updates.dart';
import '../../domain/entities/in_transit_vital_update.dart';
import '../../domain/entities/patient_transport_summary.dart';
import '../../domain/entities/recent_transport.dart';
import '../../domain/entities/transport_session.dart';
import '../../domain/entities/transport_location_update.dart';
import '../../domain/repositories/transport_repository.dart';

class ApiTransportRepository implements TransportRepository {
  const ApiTransportRepository(this._dio);

  final Dio _dio;

  Options _options({String? idempotencyKey}) => Options(
    headers: idempotencyKey == null
        ? null
        : <String, Object>{'Idempotency-Key': idempotencyKey},
    extra: const <String, Object>{NetworkRequestExtraKeys.requiresAuth: true},
  );

  @override
  Future<ActiveTransportRecovery?> recoverActiveTransport() {
    return DioExceptionMapper.guard(() async {
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

      final Response<Object?> detailResponse = await _dio.get<Object?>(
        '/api/v1/transport-requests/$requestId',
        options: _options(),
      );
      final PatientTransportSummary summary = _patientSummary(
        _jsonObject(detailResponse.data),
      );

      final Response<Object?> searchResponse = await _dio.get<Object?>(
        '/api/v1/transport-requests/$requestId/hospital-search',
        options: _options(),
      );
      final Map<String, Object?> search = _jsonObject(searchResponse.data);

      if (status == 'SEARCHING' ||
          status == 'CANDIDATES_EXHAUSTED' ||
          status == 'ACCEPTED_AVAILABLE') {
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

      if (status == 'EN_ROUTE' || status == 'HANDOFF_REQUESTED') {
        final AcceptedHospital? destination = _currentDestination(search);
        if (destination == null) {
          throw const AppException(
            '현재 목적지 병원 정보를 복구하지 못했습니다.',
            code: 'INVALID_RESPONSE',
          );
        }
        return ActiveTransportRecovery.transport(
          TransportSession(
            requestId: requestId,
            requestStartedAt: createdAt,
            destination: destination,
            patientSummary: summary,
            requestStatus: status,
          ),
        );
      }

      return null;
    });
  }

  @override
  Future<void> addVitalUpdate(String requestId, InTransitVitalUpdate update) {
    final String enteredAt = DateTime.now().toUtc().toIso8601String();
    final String measuredAt = update.measuredAt.toUtc().toIso8601String();
    return DioExceptionMapper.guard(() async {
      await _dio.post<Object?>(
        '/api/v1/transport-requests/$requestId/clinical-updates/vital-signs',
        data: <String, Object?>{
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
        options: _options(
          idempotencyKey:
              'vitals-$requestId-${update.measuredAt.microsecondsSinceEpoch}',
        ),
      );
    });
  }

  @override
  Future<void> addConsciousnessUpdate(
    String requestId,
    InTransitConsciousnessUpdate update,
  ) {
    final bool isUnassessable = update.avpu.apiValue == 'UNASSESSABLE';
    return DioExceptionMapper.guard(() async {
      await _dio.post<Object?>(
        '/api/v1/transport-requests/$requestId/clinical-updates/consciousness',
        data: <String, Object?>{
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
        options: _options(
          idempotencyKey:
              'consciousness-$requestId-${update.observedAt.microsecondsSinceEpoch}',
        ),
      );
    });
  }

  @override
  Future<void> addPreKtasUpdate(
    String requestId,
    InTransitPreKtasUpdate update,
  ) {
    final bool completed = update.classificationStatus.apiValue == 'COMPLETED';
    final DateTime keyTime = update.assessedAt ?? update.enteredAt;
    return DioExceptionMapper.guard(() async {
      await _dio.post<Object?>(
        '/api/v1/transport-requests/$requestId/clinical-updates/pre-ktas',
        data: <String, Object?>{
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
        options: _options(
          idempotencyKey:
              'prektas-$requestId-${keyTime.microsecondsSinceEpoch}',
        ),
      );
    });
  }

  @override
  Future<void> addTreatmentUpdate(
    String requestId,
    InTransitTreatmentUpdate update,
  ) {
    final String performedAt = update.performedAt.toUtc().toIso8601String();
    final Map<String, Object?> details = <String, Object?>{
      ...update.details,
      if (update.type.apiValue == 'CPR') 'startedAt': performedAt,
    };
    return DioExceptionMapper.guard(() async {
      await _dio.post<Object?>(
        '/api/v1/transport-requests/$requestId/clinical-updates/treatments',
        data: <String, Object?>{
          'type': update.type.apiValue,
          'attemptResult': update.attemptResult.apiValue,
          'details': details,
          'performedAt': performedAt,
          'enteredAt': update.enteredAt.toUtc().toIso8601String(),
        },
        options: _options(
          idempotencyKey:
              'treatment-$requestId-${update.type.apiValue}-${update.performedAt.microsecondsSinceEpoch}',
        ),
      );
    });
  }

  @override
  Future<void> requestHandoff(TransportSession session) {
    return DioExceptionMapper.guard(() async {
      await _dio.post<Object?>(
        '/api/v1/transport-requests/${session.requestId}/handoff-request',
        options: _options(idempotencyKey: 'handoff-${session.requestId}'),
      );
    });
  }

  @override
  Future<void> updateLocation(
    String requestId,
    TransportLocationUpdate update,
    String idempotencyKey,
  ) {
    return DioExceptionMapper.guard(() async {
      await _dio.put<Object?>(
        '/api/v1/transport-requests/$requestId/location',
        data: <String, Object>{
          'latitude': update.latitude,
          'longitude': update.longitude,
          'capturedAt': update.capturedAt.toUtc().toIso8601String(),
        },
        options: _options(idempotencyKey: idempotencyKey),
      );
    });
  }

  @override
  Future<void> cancelRequest(
    String requestId,
    TransportCancellation cancellation,
  ) {
    return DioExceptionMapper.guard(() async {
      await _dio.post<Object?>(
        '/api/v1/transport-requests/$requestId/cancel',
        data: <String, Object?>{
          'reason': cancellation.reason.apiValue,
          if (cancellation.normalizedDetail != null)
            'detail': cancellation.normalizedDetail,
        },
        options: _options(idempotencyKey: 'cancel-$requestId'),
      );
    });
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
      return rawItems
          .map(_recentTransport)
          .where(
            (RecentTransport transport) =>
                transport.handoffStatus != HandoffStatus.cancelled ||
                transport.hasDestination,
          )
          .toList(growable: false);
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
    );
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
      final int distanceMeters =
          _int(offer['routeDistanceMeters']) ??
          _int(offer['straightLineDistanceMeters']) ??
          0;
      final int? etaSeconds = _int(offer['etaSeconds']);
      return AcceptedHospital(
        offerId: offerId,
        name: _string(offer, 'hospitalName'),
        address: '주소 정보 없음',
        emergencyRoomPhone: offer['hospitalContact'] as String? ?? '연락처 정보 없음',
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

  String _string(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw const AppException('서버 응답을 처리할 수 없습니다.', code: 'INVALID_RESPONSE');
  }

  int? _int(Object? value) => value is num ? value.toInt() : null;

  DateTime _date(Map<String, Object?> json, String key) =>
      DateTime.parse(_string(json, key)).toLocal();

  DateTime? _nullableDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
