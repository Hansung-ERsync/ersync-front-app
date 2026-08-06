import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/network/authenticated_request.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../domain/entities/accepted_hospital.dart';
import '../../domain/entities/hospital_search_progress.dart';
import '../../domain/entities/hospital_search_session.dart';
import '../../domain/repositories/hospital_search_repository.dart';

class ApiHospitalSearchRepository implements HospitalSearchRepository {
  const ApiHospitalSearchRepository(this._dio);

  final Dio _dio;

  Options _options({String? idempotencyKey}) => Options(
    headers: idempotencyKey == null
        ? null
        : <String, Object>{'Idempotency-Key': idempotencyKey},
    extra: const <String, Object>{NetworkRequestExtraKeys.requiresAuth: true},
  );

  @override
  Future<HospitalSearchProgress> getProgress(HospitalSearchSession session) {
    return DioExceptionMapper.guard(() async {
      final Response<Object?> response = await _dio.get<Object?>(
        '/api/v1/transport-requests/${session.requestId}/hospital-search',
        options: _options(),
      );
      final Map<String, Object?> body = _jsonObject(response.data);
      final Map<String, Object?>? attempt = _nullableJsonObject(
        body['currentAttempt'],
      );
      final DateTime serverNow = _dateTime(body['serverNow']) ?? DateTime.now();
      final DateTime startedAt =
          _dateTime(attempt?['startedAt']) ?? session.startedAt;
      final DateTime? endedAt = _dateTime(attempt?['endedAt']);
      final String requestStatus = _requiredString(body, 'status');
      final bool isCancelled = requestStatus == 'CANCELLED';
      final DateTime? nextExpansionAt = _dateTime(attempt?['nextExpansionAt']);
      final int? expansionRemainingSeconds = nextExpansionAt == null
          ? null
          : (nextExpansionAt.difference(serverNow).inMilliseconds / 1000)
                .ceil()
                .clamp(0, 86400)
                .toInt();
      final DateTime elapsedUntil = isCancelled
          ? endedAt ?? serverNow
          : serverNow;
      final List<AcceptedHospital> accepted = <AcceptedHospital>[];
      final Object? rawOffers = body['offers'];
      if (rawOffers is List<Object?>) {
        for (final Object? rawOffer in rawOffers) {
          final Map<String, Object?> offer = _jsonObject(rawOffer);
          if (offer['status'] != 'ACCEPTED') {
            continue;
          }
          final int distanceMeters =
              _int(offer['routeDistanceMeters']) ??
              _int(offer['straightLineDistanceMeters']) ??
              0;
          final int? etaSeconds = _int(offer['etaSeconds']);
          accepted.add(
            AcceptedHospital(
              offerId: _requiredString(offer, 'offerId'),
              name: _requiredString(offer, 'hospitalName'),
              address: '주소 정보 없음',
              emergencyRoomPhone:
                  offer['hospitalContact'] as String? ?? '연락처 정보 없음',
              distanceMeters: distanceMeters,
              etaMinutes: etaSeconds == null ? null : (etaSeconds / 60).ceil(),
              acceptedAt:
                  _dateTime(offer['respondedAt']) ??
                  _dateTime(offer['offeredAt']) ??
                  serverNow,
            ),
          );
        }
      }
      return HospitalSearchProgress(
        requestId: _requiredString(body, 'transportRequestId'),
        requestStatus: requestStatus,
        isElapsedRunning: requestStatus == 'SEARCHING',
        expansionRemainingSeconds: requestStatus == 'SEARCHING'
            ? expansionRemainingSeconds
            : null,
        nextExpansionAt: requestStatus == 'SEARCHING' ? nextExpansionAt : null,
        candidateShortage: attempt?['candidateShortage'] == true,
        exhaustionReason: body['exhaustionReason'] as String?,
        currentRadiusKm:
            _int(attempt?['currentRadiusKm']) ?? session.initialRadiusKm,
        elapsedSeconds: elapsedUntil
            .difference(startedAt)
            .inSeconds
            .clamp(0, 86400)
            .toInt(),
        acceptedHospitals: accepted,
      );
    });
  }

  @override
  Future<void> selectDestination(
    String requestId,
    String offerId,
    String idempotencyKey,
  ) {
    return DioExceptionMapper.guard(() async {
      await _dio.post<Object?>(
        '/api/v1/transport-requests/$requestId/destination',
        data: <String, Object>{'offerId': offerId},
        options: _options(idempotencyKey: idempotencyKey),
      );
    });
  }

  @override
  Future<void> retrySearch(String requestId, String idempotencyKey) {
    return DioExceptionMapper.guard(() async {
      await _dio.post<Object?>(
        '/api/v1/transport-requests/$requestId/dispatch-attempts',
        data: const <String, Object>{},
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

  Map<String, Object?> _jsonObject(Object? value) {
    final Map<String, Object?>? result = _nullableJsonObject(value);
    if (result != null) {
      return result;
    }
    throw const AppException('서버 응답을 처리할 수 없습니다.', code: 'INVALID_RESPONSE');
  }

  Map<String, Object?>? _nullableJsonObject(Object? value) {
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

  String _requiredString(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw const AppException('서버 응답을 처리할 수 없습니다.', code: 'INVALID_RESPONSE');
  }

  int? _int(Object? value) => value is num ? value.toInt() : null;

  DateTime? _dateTime(Object? value) {
    return value is String ? DateTime.tryParse(value)?.toLocal() : null;
  }
}
