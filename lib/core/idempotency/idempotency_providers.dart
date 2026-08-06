import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'idempotency_key_generator.dart';

final Provider<IdempotencyKeyGenerator> idempotencyKeyGeneratorProvider =
    Provider<IdempotencyKeyGenerator>((Ref ref) => IdempotencyKeyGenerator());
