import 'package:geolocator/geolocator.dart';

import '../error/app_exception.dart';

class DeviceLocationPoint {
  const DeviceLocationPoint({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final double? accuracyMeters;
}

abstract interface class DeviceLocationService {
  Future<DeviceLocationPoint?> getLastKnownLocation();

  Future<DeviceLocationPoint> getCurrentLocation();
}

class GeolocatorDeviceLocationService implements DeviceLocationService {
  const GeolocatorDeviceLocationService();

  @override
  Future<DeviceLocationPoint?> getLastKnownLocation() async {
    await _ensureLocationAvailable();
    try {
      final Position? position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        return null;
      }
      return _toPoint(position);
    } on AppException {
      rethrow;
    } on Object {
      return null;
    }
  }

  @override
  Future<DeviceLocationPoint> getCurrentLocation() async {
    await _ensureLocationAvailable();
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return _toPoint(position);
    } on AppException {
      rethrow;
    } on Object {
      throw const AppException(
        '현재 GPS 위치를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.',
        code: 'LOCATION_UNAVAILABLE',
      );
    }
  }

  Future<void> _ensureLocationAvailable() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppException(
        '기기의 위치 서비스를 켠 뒤 다시 시도해주세요.',
        code: 'LOCATION_SERVICE_DISABLED',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AppException(
        '설정에서 ERSync의 위치 권한을 허용해주세요.',
        code: 'LOCATION_PERMISSION_DENIED_FOREVER',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const AppException(
        '환자 이송 요청에는 위치 권한이 필요합니다.',
        code: 'LOCATION_PERMISSION_DENIED',
      );
    }
  }

  DeviceLocationPoint _toPoint(Position position) {
    return DeviceLocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      capturedAt: position.timestamp,
      accuracyMeters: position.accuracy,
    );
  }
}
