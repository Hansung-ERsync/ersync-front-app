import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:er_sync/core/error/app_exception.dart';
import 'package:er_sync/core/network/dio_factory.dart';
import 'package:er_sync/features/hospital_search/domain/entities/hospital_search_progress.dart';
import 'package:er_sync/features/patient_assessment/domain/entities/assessment_enums.dart';
import 'package:er_sync/features/transport/data/repositories/api_transport_repository.dart';
import 'package:er_sync/features/transport/data/storage/pending_transport_command_store.dart';
import 'package:er_sync/features/transport/domain/entities/in_transit_clinical_updates.dart';
import 'package:er_sync/features/transport/domain/entities/in_transit_vital_update.dart';
import 'package:er_sync/features/transport/domain/entities/active_transport_recovery.dart';
import 'package:er_sync/features/transport/domain/entities/recent_transport.dart';
import 'package:er_sync/features/transport/domain/entities/transport_location_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('목적지가 없는 취소 이력도 누락하지 않고 표시한다', () async {
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        expect(request.uri.queryParameters['view'], 'RECENT');
        return _jsonResponse(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'transportRequestId': 'REQUEST-1',
              'status': 'CANCELLED',
              'hospitalName': null,
              'createdAt': '2026-08-05T01:00:00Z',
              'statusUpdatedAt': '2026-08-05T01:10:00Z',
              'cancelledAt': '2026-08-05T01:10:00Z',
              'cancellationReason': 'OTHER',
            },
            <String, Object?>{
              'transportRequestId': 'REQUEST-2',
              'status': 'CANCELLED',
              'hospitalName': '한양대학교병원',
              'createdAt': '2026-08-05T01:00:00Z',
              'statusUpdatedAt': '2026-08-05T01:10:00Z',
              'cancelledAt': '2026-08-05T01:10:00Z',
              'cancellationReason': 'OTHER',
            },
          ],
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
        });
      });

    final List<RecentTransport> result = await ApiTransportRepository(
      dio,
    ).getRecentTransports();

    expect(result, hasLength(2));
    expect(result.first.requestId, 'REQUEST-1');
    expect(result.first.handoffStatus, HandoffStatus.cancelled);
    expect(result.first.hospitalDisplayName, '목적지 미정');
    expect(result.last.requestId, 'REQUEST-2');
    expect(result.last.hospitalDisplayName, '한양대학교병원');
  });

  test('OTHER 취소 상세와 안정적인 멱등성 키를 전송한다', () async {
    late RequestOptions captured;
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        captured = request;
        return _jsonResponse(<String, Object?>{
          'transportRequestId': 'REQUEST-1',
          'status': 'CANCELLED',
          'reason': 'OTHER',
          'detail': '현장 처치 후 이송 불필요',
          'cancelledAt': '2026-08-05T01:10:00Z',
          'idempotentReplay': false,
        });
      });

    await ApiTransportRepository(dio).cancelRequest(
      'REQUEST-1',
      const TransportCancellation(
        reason: TransportCancellationReason.other,
        detail: '  현장 처치 후 이송 불필요  ',
      ),
    );

    expect(
      captured.headers['Idempotency-Key'],
      startsWith('cancel-REQUEST-1-'),
    );
    expect(_requestJson(captured), <String, Object?>{
      'reason': 'OTHER',
      'detail': '현장 처치 후 이송 불필요',
    });
  });

  test('응답이 유실된 명령은 같은 멱등성 키와 최초 body로 재시도한다', () async {
    final List<RequestOptions> captured = <RequestOptions>[];
    final InMemoryPendingTransportCommandStore pendingCommandStore =
        InMemoryPendingTransportCommandStore();
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        captured.add(request);
        if (captured.length == 1) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return ResponseBody.fromString('', 200);
      });
    final ApiTransportRepository repository = ApiTransportRepository(
      dio,
      pendingCommandStore: pendingCommandStore,
    );

    await expectLater(
      repository.cancelRequest(
        'REQUEST-RETRY',
        const TransportCancellation(
          reason: TransportCancellationReason.other,
          detail: '최초 body',
        ),
      ),
      throwsA(
        isA<AppException>().having(
          (AppException error) => error.code,
          'code',
          'NETWORK_TIMEOUT',
        ),
      ),
    );
    await repository.cancelRequest(
      'REQUEST-RETRY',
      const TransportCancellation(
        reason: TransportCancellationReason.sceneResolved,
      ),
    );

    expect(captured, hasLength(2));
    expect(
      captured[1].headers['Idempotency-Key'],
      captured[0].headers['Idempotency-Key'],
    );
    expect(_requestJson(captured[1]), _requestJson(captured[0]));
    expect(_requestJson(captured[1])['detail'], '최초 body');
    expect(await pendingCommandStore.read('cancel:REQUEST-RETRY'), isNull);
  });

  test('오래된 임상 기록의 snapshotUpdated false를 호출자에게 전달한다', () async {
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter(
        (_) => _jsonResponse(<String, Object?>{
          'snapshotUpdated': false,
          'lastClinicalUpdateAt': '2026-08-05T00:00:01Z',
        }, statusCode: 201),
      );

    final result = await ApiTransportRepository(dio).addVitalUpdate(
      'REQUEST-OLD',
      InTransitVitalUpdate(
        systolic: 120,
        diastolic: 80,
        pulse: 80,
        respiratoryRate: 18,
        temperature: 36.5,
        oxygenSaturation: 98,
        measuredAt: DateTime.utc(2026, 8, 5),
      ),
    );

    expect(result.snapshotUpdated, isFalse);
    expect(result.lastClinicalUpdateAt, isNotNull);
  });

  test('이송 중 의식·Pre-KTAS·처치 변경을 임상 업데이트 API로 전송한다', () async {
    final List<RequestOptions> captured = <RequestOptions>[];
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        captured.add(request);
        return _jsonResponse(<String, Object?>{
          'snapshotUpdated': true,
          'lastClinicalUpdateAt': '2026-08-05T01:05:07Z',
        }, statusCode: 201);
      });
    final ApiTransportRepository repository = ApiTransportRepository(dio);
    final DateTime observedAt = DateTime.utc(2026, 8, 5, 1, 2, 3);
    final DateTime assessedAt = DateTime.utc(2026, 8, 5, 1, 3, 4);
    final DateTime performedAt = DateTime.utc(2026, 8, 5, 1, 4, 5);
    final DateTime enteredAt = DateTime.utc(2026, 8, 5, 1, 5, 6);

    await repository.addConsciousnessUpdate(
      'REQUEST-1',
      InTransitConsciousnessUpdate(
        avpu: AvpuLevel.unassessable,
        unassessableReason: UnassessableReason.other,
        unassessableDetail: '  안면 외상으로 평가 어려움  ',
        observedAt: observedAt,
        enteredAt: enteredAt,
      ),
    );
    await repository.addPreKtasUpdate(
      'REQUEST-1',
      InTransitPreKtasUpdate(
        classificationStatus: ClassificationStatus.completed,
        level: 2,
        assessedAt: assessedAt,
        standardVersion: 'DEV_UNCONFIRMED',
        enteredAt: enteredAt,
      ),
    );
    await repository.addTreatmentUpdate(
      'REQUEST-1',
      InTransitTreatmentUpdate(
        type: TreatmentType.cpr,
        attemptResult: TreatmentAttemptResult.ongoing,
        details: const <String, Object?>{'currentStatus': '진행 중'},
        performedAt: performedAt,
        enteredAt: enteredAt,
      ),
    );

    expect(captured, hasLength(3));

    expect(
      captured[0].uri.path,
      '/api/v1/transport-requests/REQUEST-1/clinical-updates/consciousness',
    );
    expect(
      captured[0].headers['Idempotency-Key'],
      startsWith('consciousness-REQUEST-1-'),
    );
    expect(_requestJson(captured[0]), <String, Object?>{
      'avpu': 'UNASSESSABLE',
      'unassessableReason': 'OTHER',
      'unassessableDetail': '안면 외상으로 평가 어려움',
      'observedAt': observedAt.toIso8601String(),
      'enteredAt': enteredAt.toIso8601String(),
    });

    expect(
      captured[1].uri.path,
      '/api/v1/transport-requests/REQUEST-1/clinical-updates/pre-ktas',
    );
    expect(
      captured[1].headers['Idempotency-Key'],
      startsWith('prektas-REQUEST-1-'),
    );
    expect(_requestJson(captured[1]), <String, Object?>{
      'classificationStatus': 'COMPLETED',
      'level': 2,
      'exceptionReason': null,
      'exceptionDetail': null,
      'assessedAt': assessedAt.toIso8601String(),
      'standardVersion': 'DEV_UNCONFIRMED',
      'enteredAt': enteredAt.toIso8601String(),
    });

    expect(
      captured[2].uri.path,
      '/api/v1/transport-requests/REQUEST-1/clinical-updates/treatments',
    );
    expect(
      captured[2].headers['Idempotency-Key'],
      startsWith('treatment-REQUEST-1-'),
    );
    expect(_requestJson(captured[2]), <String, Object?>{
      'type': 'CPR',
      'attemptResult': 'ONGOING',
      'details': <String, Object?>{
        'currentStatus': '진행 중',
        'startedAt': performedAt.toIso8601String(),
      },
      'performedAt': performedAt.toIso8601String(),
      'enteredAt': enteredAt.toIso8601String(),
    });
  });

  test('이송 중 현재 위치와 촬영 시각을 PUT으로 전송한다', () async {
    late RequestOptions captured;
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        captured = request;
        return _jsonResponse(<String, Object?>{
          'transportRequestId': 'REQUEST-1',
          'latitude': 37.5665,
          'longitude': 126.978,
          'capturedAt': '2026-08-06T06:30:10Z',
          'freshness': 'CURRENT',
          'ageSeconds': 1,
          'routeEstimateStatus': 'AVAILABLE',
          'routeDistanceMeters': 5000,
          'etaSeconds': 600,
        });
      });
    final DateTime capturedAt = DateTime.utc(2026, 8, 6, 6, 30, 10);

    await ApiTransportRepository(dio).updateLocation(
      'REQUEST-1',
      TransportLocationUpdate(
        latitude: 37.5665,
        longitude: 126.978,
        capturedAt: capturedAt,
      ),
      'location-command-1',
    );

    expect(captured.method, 'PUT');
    expect(captured.uri.path, '/api/v1/transport-requests/REQUEST-1/location');
    expect(captured.headers['Idempotency-Key'], 'location-command-1');
    expect(_requestJson(captured), <String, Object>{
      'latitude': 37.5665,
      'longitude': 126.978,
      'capturedAt': capturedAt.toIso8601String(),
    });
  });

  test('인계 확인 대기 중인 이송은 메인에서 자동으로 다시 열지 않는다', () async {
    final List<RequestOptions> captured = <RequestOptions>[];
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        captured.add(request);
        return _jsonResponse(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'transportRequestId': 'REQUEST-HANDOFF-PENDING',
              'status': 'HANDOFF_REQUESTED',
              'hospitalName': '서울시청 테스트병원',
              'createdAt': '2026-08-06T06:00:00Z',
              'statusUpdatedAt': '2026-08-06T06:10:00Z',
            },
          ],
        });
      });

    final ActiveTransportRecovery? recovery = await ApiTransportRepository(
      dio,
    ).recoverActiveTransport();

    expect(recovery, isNull);
    expect(captured, hasLength(1));
    expect(captured.single.uri.path, '/api/v1/transport-requests');
  });

  test('ACTIVE 목록과 상세·병원 검색·위치로 이동 중 화면을 복구한다', () async {
    final Dio dio = DioFactory.create(baseUri: Uri.parse('http://localhost'))
      ..httpClientAdapter = _MockHttpClientAdapter((RequestOptions request) {
        if (request.uri.path == '/api/v1/transport-requests' &&
            request.uri.queryParameters['view'] == 'ACTIVE') {
          return _jsonResponse(<String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'transportRequestId': 'REQUEST-ACTIVE',
                'status': 'EN_ROUTE',
                'hospitalName': '한양대학교병원',
                'createdAt': '2026-08-06T06:00:00Z',
                'statusUpdatedAt': '2026-08-06T06:10:00Z',
              },
            ],
          });
        }
        if (request.uri.path == '/api/v1/transport-requests/REQUEST-ACTIVE') {
          return _jsonResponse(<String, Object?>{
            'transportRequestId': 'REQUEST-ACTIVE',
            'status': 'EN_ROUTE',
            'patient': <String, Object?>{
              'ageStatus': 'ESTIMATED',
              'ageYears': 45,
              'sex': 'MALE',
            },
            'incident': <String, Object?>{
              'occurrenceType': 'NON_DISEASE',
              'occurrenceDetail': null,
              'injuryMechanism': 'TRAFFIC',
              'injurySites': <Object?>['CHEST'],
              'primarySymptom': 'CHEST_PAIN',
              'primarySymptomDetail': '압박감',
              'secondarySymptoms': <Object?>['DYSPNEA'],
              'onsetTimeStatus': 'ESTIMATED',
              'onsetAt': '2026-08-06T06:01:00Z',
            },
            'supplementalAssessment': <String, Object?>{
              'assessedAt': '2026-08-06T06:08:00Z',
              'enteredAt': '2026-08-06T06:08:30Z',
              'serverReceivedAt': '2026-08-06T06:08:31Z',
              'glucoseMgDl': 132,
              'leftPupil': 'NORMAL',
              'rightPupil': 'SLUGGISH',
              'medicalHistory': '고혈압',
              'allergies': '페니실린',
              'medications': '혈압약',
              'isolationConcern': false,
            },
            'latestSnapshot': <String, Object?>{..._latestSnapshot()},
          });
        }
        if (request.uri.path ==
            '/api/v1/transport-requests/REQUEST-ACTIVE/hospital-search') {
          return _jsonResponse(<String, Object?>{
            'transportRequestId': 'REQUEST-ACTIVE',
            'status': 'EN_ROUTE',
            'currentDestinationOfferId': 'OFFER-1',
            'offers': <Object?>[
              <String, Object?>{
                'offerId': 'OFFER-1',
                'hospitalName': '한양대학교병원',
                'hospitalAddress': '서울특별시 성동구 왕십리로 222-1',
                'hospitalDetailAddress': '본관 1층 응급의료센터',
                'hospitalLatitude': 37.5596,
                'hospitalLongitude': 127.0442,
                'hospitalContact': '02-2290-8119',
                'currentDestination': true,
                'routeDistanceMeters': 8400,
                'etaSeconds': 1080,
                'respondedAt': '2026-08-06T06:05:00Z',
              },
            ],
          });
        }
        if (request.uri.path ==
            '/api/v1/transport-requests/REQUEST-ACTIVE/location') {
          return _jsonResponse(<String, Object?>{
            'transportRequestId': 'REQUEST-ACTIVE',
            'latitude': 37.55,
            'longitude': 127.03,
            'capturedAt': '2026-08-06T06:09:30Z',
            'freshness': 'CURRENT',
            'ageSeconds': 30,
            'routeEstimateStatus': 'AVAILABLE',
            'routeDistanceMeters': 8100,
            'etaSeconds': 1020,
            'lastSuccessfulRouteDistanceMeters': 8100,
            'lastSuccessfulEtaSeconds': 1020,
          });
        }
        throw StateError('예상하지 못한 요청: ${request.uri}');
      });

    final ActiveTransportRecovery? recovery = await ApiTransportRepository(
      dio,
    ).recoverActiveTransport();

    expect(recovery?.transportSession?.requestId, 'REQUEST-ACTIVE');
    expect(recovery?.transportSession?.requestStatus, 'EN_ROUTE');
    expect(recovery?.transportSession?.destination.name, '한양대학교병원');
    expect(
      recovery?.transportSession?.destination.address,
      '서울특별시 성동구 왕십리로 222-1',
    );
    expect(
      recovery?.transportSession?.destination.detailAddress,
      '본관 1층 응급의료센터',
    );
    expect(recovery?.transportSession?.destination.latitude, 37.5596);
    expect(recovery?.transportSession?.patientSummary.ageLabel, '45세 추정');
    expect(
      recovery?.transportSession?.patientSummary.bloodPressureDisplay,
      '120/80 mmHg',
    );
    expect(
      recovery?.transportSession?.patientSummary.respiratoryRateDisplay,
      '측정 불가',
    );
    expect(recovery?.transportSession?.patientSummary.glucoseMgDl, 132);
    expect(recovery?.transportSession?.patientSummary.leftPupilLabel, '정상');
    expect(recovery?.transportSession?.patientSummary.rightPupilLabel, '둔함');
    expect(recovery?.transportSession?.patientSummary.medicalHistory, '고혈압');
    expect(
      recovery?.transportSession?.patientSummary.occurrenceLabel,
      '비질병·외상',
    );
    expect(
      recovery?.transportSession?.patientSummary.injuryMechanismLabel,
      '교통사고',
    );
    expect(recovery?.transportSession?.patientSummary.injurySitesLabel, '흉부');
    expect(
      recovery?.transportSession?.patientSummary.secondarySymptomsLabel,
      '호흡곤란',
    );
    expect(
      recovery?.transportSession?.patientSummary.latestTreatmentLabel,
      '산소 투여 · 성공',
    );
    expect(recovery?.transportSession?.locationSnapshot?.freshness, 'CURRENT');
    expect(recovery?.transportSession?.locationSnapshot?.etaSeconds, 1020);
    expect(
      recovery?.transportSession?.patientSummary.isolationConcern,
      isFalse,
    );
  });
}

Map<String, Object?> _latestSnapshot() => <String, Object?>{
  'preKtas': <String, Object?>{
    'classificationStatus': 'COMPLETED',
    'level': 2,
    'exceptionReason': null,
    'exceptionDetail': null,
    'assessedAt': '2026-08-06T06:07:00Z',
    'standardVersion': 'DEV_UNCONFIRMED',
  },
  'consciousness': <String, Object?>{
    'avpu': 'A',
    'unassessableReason': null,
    'unassessableDetail': null,
    'observedAt': '2026-08-06T06:08:00Z',
  },
  'vitalSigns': <String, Object?>{
    'measuredAt': '2026-08-06T06:09:00Z',
    'measurements': <Object?>[
      <String, Object?>{
        'type': 'BLOOD_PRESSURE',
        'state': 'VALUE',
        'primaryValue': 120,
        'secondaryValue': 80,
      },
      <String, Object?>{'type': 'PULSE', 'state': 'VALUE', 'primaryValue': 82},
      <String, Object?>{
        'type': 'RESPIRATORY_RATE',
        'state': 'MEASUREMENT_UNAVAILABLE',
      },
      <String, Object?>{'type': 'TEMPERATURE', 'state': 'PATIENT_REFUSED'},
      <String, Object?>{'type': 'SPO2', 'state': 'VALUE', 'primaryValue': 97},
    ],
  },
  'treatments': <Object?>[
    <String, Object?>{
      'type': 'OXYGEN',
      'attemptResult': 'SUCCESS',
      'performedAt': '2026-08-06T06:09:10Z',
      'details': <String, Object?>{'flowRateLpm': 5},
    },
  ],
  'lastClinicalUpdateAt': '2026-08-06T06:09:11Z',
};

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
