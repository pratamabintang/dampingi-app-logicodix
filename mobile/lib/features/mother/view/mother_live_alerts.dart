import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../connections/repositories/connection_repository.dart';
import '../repositories/mother_alert_repository.dart';

class MotherLiveAlerts extends ConsumerWidget {
  const MotherLiveAlerts({this.showEmptyState = true, super.key});

  final bool showEmptyState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(motherAlertsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: const Key('mother-notifications-connections'),
          onPressed: () => context.push('/mother/connections'),
          child: const Text('Tukar kode di Koneksi'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => ref.invalidate(motherAlertsProvider),
            child: const Text('Muat ulang'),
          ),
        ),
        state.when(
          skipLoadingOnRefresh: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => AppError(
            message: error is FormatException
                ? 'Respons notifikasi tidak sesuai. Coba lagi.'
                : connectionFailureMessage(error),
            onRetry: () => ref.invalidate(motherAlertsProvider),
          ),
          data: (items) => items.isEmpty
              ? showEmptyState
                    ? const AppEmpty(
                        key: Key('mother-notifications-empty'),
                        title: 'Belum ada notifikasi',
                        message: 'Belum ada kabar baru untuk Anda.',
                      )
                    : const SizedBox.shrink()
              : Column(
                  children: [
                    for (final item in items)
                      Card(
                        key: ValueKey('mother-alert-${item.id}'),
                        color: AppTheme.selectedSurface,
                        child: ListTile(
                          title: const Text('Pembaruan simulasi demo'),
                          subtitle: Text(
                            'Ada pembaruan di aplikasi. Ini simulasi demo.\n'
                            '${item.createdAt.toLocal()}',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
