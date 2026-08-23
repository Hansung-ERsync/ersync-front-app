import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_view_model.dart';
import 'pending_transport_command_store.dart';

final Provider<PendingTransportCommandStore>
pendingTransportCommandStoreProvider = Provider<PendingTransportCommandStore>((
  Ref ref,
) {
  final String accountId = ref.watch(
    authViewModelProvider.select(
      (AuthState state) => state.user?.accountId ?? 'signed-out',
    ),
  );
  return SecurePendingTransportCommandStore(accountId: accountId);
});
