import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:er_sync/core/idempotency/idempotency_key_generator.dart';
import 'package:er_sync/core/location/device_location.dart';
import 'package:er_sync/core/network/dio_factory.dart';
import 'package:er_sync/features/patient_assessment/data/repositories/api_patient_assessment_repository.dart';
import 'package:er_sync/features/patient_assessment/data/storage/patient_assessment_draft_store.dart';
import 'package:er_sync/features/patient_assessment/domain/entities/assessment_enums.dart';
import 'package:er_sync/features/patient_assessment/domain/entities/patient_assessment_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('활성 프로토콜 버전으로 환자정보와 5개 활력징후를 전송한다', () async {
    late RequestOptions createRequest;
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        if (request.uri.path == '/api/v1/assessment-protocols/active') {
          return _jsonResponse(<String, Object?>{
            'version': 'ERSYNC_MVP_1.0',
            'status': 'DEVELOPMENT',
            'preKtasStandardVersion': 'DEV_UNCONFIRMED',
            'requiredSections': <String>[],
            'enumValues': <String, Object?>{},
            'vitalSignUnits': <String, Object?>{},
            'conditionalRules': <String>[],
          });
        }
        if (request.uri.path == '/api/v1/transport-requests') {
          createRequest = request;
          return _jsonResponse(<String, Object?>{
            'transportRequestId': 'REQUEST-1',
            'status': 'SEARCHING',
            'assessmentProtocolVersion': 'ERSYNC_MVP_1.0',
            'createdAt': '2026-08-05T01:00:00Z',
          }, statusCode: 201);
        }
        throw StateError('예상하지 못한 요청: ${request.uri}');
      });
    final ApiPatientAssessmentRepository repository =
        ApiPatientAssessmentRepository(
          dio,
          callbackContact: '010-0000-0000',
          locationService: const _FakeDeviceLocationService(),
          draftStore: InMemoryPatientAssessmentDraftStore(),
          idempotencyKeyGenerator: IdempotencyKeyGenerator(),
        );
    final PatientAssessmentDraft empty = await repository.loadDraft();
    final DateTime measuredAt = DateTime.utc(2026, 8, 5, 0, 59);
    final PatientAssessmentDraft completed = empty.copyWith(
      ageStatus: AgeStatus.estimated,
      ageYears: 45,
      sex: PatientSex.unknown,
      occurrenceType: OccurrenceType.disease,
      primarySymptom: PatientSymptom.chestPain,
      secondarySymptoms: const <PatientSymptom>{PatientSymptom.dyspnea},
      onsetTimeStatus: ClinicalTimeStatus.unknown,
      classificationStatus: ClassificationStatus.completed,
      preKtasLevel: 2,
      avpu: AvpuLevel.alert,
      assessedAt: measuredAt,
      observedAt: measuredAt,
      measuredAt: measuredAt,
      vitals: <VitalType, VitalReadingDraft>{
        VitalType.bloodPressure: const VitalReadingDraft(
          state: MeasurementState.value,
          value: 120,
          secondaryValue: 80,
        ),
        VitalType.pulse: const VitalReadingDraft(
          state: MeasurementState.value,
          value: 80,
        ),
        VitalType.respiratoryRate: const VitalReadingDraft(
          state: MeasurementState.value,
          value: 18,
        ),
        VitalType.temperature: const VitalReadingDraft(
          state: MeasurementState.value,
          value: 36.5,
        ),
        VitalType.oxygenSaturation: const VitalReadingDraft(
          state: MeasurementState.value,
          value: 98,
        ),
      },
      treatments: const <TreatmentType>{TreatmentType.none},
    );

    final receipt = await repository.submit(completed);
    final Map<String, dynamic> body = _requestJson(createRequest);
    final Map<String, dynamic> preKtas = Map<String, dynamic>.from(
      body['preKtas'] as Map<dynamic, dynamic>,
    );
    final Map<String, dynamic> vitalSigns = Map<String, dynamic>.from(
      body['vitalSigns'] as Map<dynamic, dynamic>,
    );

    expect(createRequest.headers['Idempotency-Key'], empty.clientRequestKey);
    expect(body['assessmentProtocolVersion'], 'ERSYNC_MVP_1.0');
    expect(preKtas['standardVersion'], 'DEV_UNCONFIRMED');
    expect(vitalSigns['measurements'], hasLength(5));
    expect(
      (vitalSigns['measurements'] as List<dynamic>).map(
        (dynamic item) => (item as Map<dynamic, dynamic>)['type'],
      ),
      <String>[
        'BLOOD_PRESSURE',
        'PULSE',
        'RESPIRATORY_RATE',
        'TEMPERATURE',
        'SPO2',
      ],
    );
    expect(receipt.requestId, 'REQUEST-1');

    await repository.saveDraft(completed);
    final PatientAssessmentDraft restored = await repository.loadDraft();
    expect(restored.ageStatus, AgeStatus.estimated);
    expect(restored.primarySymptom, PatientSymptom.chestPain);
    expect(restored.clientRequestKey, completed.clientRequestKey);
    await repository.clearDraft();
    final PatientAssessmentDraft fresh = await repository.loadDraft();
    expect(fresh.ageStatus, isNull);
    expect(fresh.primarySymptom, isNull);
    expect(fresh.vitals, isEmpty);
    expect(fresh.clientRequestKey, isNot(completed.clientRequestKey));
  });
}

class _FakeDeviceLocationService implements DeviceLocationService {
  const _FakeDeviceLocationService();

  @override
  Future<DeviceLocationPoint> getCurrentLocation() async => DeviceLocationPoint(
    latitude: 37.5665,
    longitude: 126.978,
    capturedAt: DateTime.utc(2026, 8, 5),
  );
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions request) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => _handler(options);

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _requestJson(RequestOptions request) {
  final Object? data = request.data;
  if (data is Map<dynamic, dynamic>) {
    return Map<String, dynamic>.from(data);
  }
  throw StateError('JSON 요청 본문이 아닙니다: $data');
}

ResponseBody _jsonResponse(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
