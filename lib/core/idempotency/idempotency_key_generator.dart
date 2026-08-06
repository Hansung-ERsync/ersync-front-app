import 'dart:math';

class IdempotencyKeyGenerator {
  IdempotencyKeyGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  String create(String prefix) {
    final String randomHex = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((int value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-${DateTime.now().toUtc().microsecondsSinceEpoch}-$randomHex';
  }
}
