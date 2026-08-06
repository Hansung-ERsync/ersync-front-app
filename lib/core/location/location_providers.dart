import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_location.dart';

final Provider<DeviceLocationService> deviceLocationServiceProvider =
    Provider<DeviceLocationService>(
      (Ref ref) => const GeolocatorDeviceLocationService(),
    );
