import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../connections/repositories/connection_repository.dart';
import '../../mother/repositories/daily_entry_repository.dart';
import '../repositories/companion_history_repository.dart';

Future<void> openCompanionNote(BuildContext context, String id) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => _LiveNoteDetail(id: id)),
  );
}

Future<void> openCompanionNoteEditor(
  BuildContext context,
  WidgetRef ref, {
  JournalEntry? existing,
}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => _LiveNoteEditor(existing: existing),
    ),
  );
  if (saved != true || !context.mounted) return;
  ref.invalidate(companionRecentNotesProvider);
  ref.invalidate(companionWeekProvider);
  if (existing != null) ref.invalidate(companionNoteProvider(existing.id));
}

class CompanionRecentNotesCard extends ConsumerWidget {
  const CompanionRecentNotesCard({required this.onSeeAll, super.key});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      key: const Key('companion-stories-card'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Catatan terakhirmu')),
              TextButton(onPressed: onSeeAll, child: const Text('Lihat Semua')),
            ],
          ),
          ref
              .watch(companionRecentNotesProvider)
              .when(
                skipLoadingOnRefresh: false,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => AppError(
                  message:
                      'Catatan gagal dimuat. ${connectionFailureMessage(error)}',
                  onRetry: () => ref.invalidate(companionRecentNotesProvider),
                ),
                data: (notes) => notes.isEmpty
                    ? const AppEmpty(message: 'Belum ada catatan tersimpan.')
                    : Column(
                        children: [
                          for (final note in notes) _NoteTile(note: note),
                        ],
                      ),
              ),
          TextButton(
            onPressed: () => openCompanionNoteEditor(context, ref),
            child: const Text('Tulis catatan hari ini (opsional)'),
          ),
        ],
      ),
    );
  }
}

class CompanionLiveObservationPage extends ConsumerStatefulWidget {
  const CompanionLiveObservationPage({
    required this.onStartObservation,
    super.key,
  });
  final VoidCallback onStartObservation;

  @override
  ConsumerState<CompanionLiveObservationPage> createState() =>
      _CompanionLiveObservationPageState();
}

class _CompanionLiveObservationPageState
    extends ConsumerState<CompanionLiveObservationPage> {
  DateTime _start = companionMonday(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final key = companionDay(_start);
    final end = companionDay(
      DateTime(_start.year, _start.month, _start.day + 6),
    );
    final currentMonday = companionMonday(DateTime.now());
    return ListView(
      key: const Key('companion-observation-scroll'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Observasi', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              key: const Key('companion-week-previous'),
              tooltip: 'Minggu sebelumnya',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(
                () => _start = DateTime(
                  _start.year,
                  _start.month,
                  _start.day - 7,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '$key — $end',
                key: const Key('companion-week-label'),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              key: const Key('companion-week-next'),
              tooltip: 'Minggu berikutnya',
              icon: const Icon(Icons.arrow_forward),
              onPressed: !_start.isBefore(currentMonday)
                  ? null
                  : () => setState(
                      () => _start = DateTime(
                        _start.year,
                        _start.month,
                        _start.day + 7,
                      ),
                    ),
            ),
          ],
        ),
        FilledButton(
          onPressed: widget.onStartObservation,
          child: const Text('Isi observasi hari ini'),
        ),
        OutlinedButton(
          key: const Key('companion-write-note'),
          onPressed: () => openCompanionNoteEditor(context, ref),
          child: const Text('Tulis catatan hari ini (opsional)'),
        ),
        TextButton(
          onPressed: () => ref.invalidate(companionWeekProvider(key)),
          child: const Text('Muat ulang minggu ini'),
        ),
        ref
            .watch(companionWeekProvider(key))
            .when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => AppError(
                message:
                    'Riwayat gagal dimuat. ${connectionFailureMessage(error)}',
                onRetry: () => ref.invalidate(companionWeekProvider(key)),
              ),
              data: (week) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Jawaban observasi pendamping'),
                  const Text(
                    'Laporan pengamatan, bukan jawaban langsung dari Ibu.',
                  ),
                  if (week.observations.isEmpty)
                    const AppEmpty(
                      message: 'Belum ada observasi selesai pada minggu ini.',
                    ),
                  for (final observation in week.observations)
                    Card(
                      child: ExpansionTile(
                        key: ValueKey('observation-${observation.id}'),
                        title: Text(observation.day),
                        subtitle: const Text('Laporan pengamatan pendamping'),
                        children: [
                          for (final answer in observation.answers)
                            ListTile(
                              title: Text(answer.question),
                              subtitle: Text(answer.answer),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text('Catatan pribadi pendamping'),
                  if (week.journals.isEmpty)
                    const AppEmpty(
                      message: 'Belum ada catatan pada minggu ini.',
                    ),
                  for (final note in week.journals) _NoteTile(note: note),
                ],
              ),
            ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});
  final JournalEntry note;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('companion-journal-${note.id}'),
    title: Text(note.title, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      '${note.date}\n${note.content}',
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => openCompanionNote(context, note.id),
  );
}

class _LiveNoteDetail extends ConsumerWidget {
  const _LiveNoteDetail({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Catatan pendamping')),
    body: ref
        .watch(companionNoteProvider(id))
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => AppError(
            message: 'Catatan gagal dibuka. ${connectionFailureMessage(error)}',
            onRetry: () => ref.invalidate(companionNoteProvider(id)),
          ),
          data: (note) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(note.date),
              const SizedBox(height: 16),
              Text(
                note.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              SelectableText(note.content),
              const SizedBox(height: 24),
              OutlinedButton(
                key: const Key('companion-note-edit'),
                onPressed: () =>
                    openCompanionNoteEditor(context, ref, existing: note),
                child: const Text('Ubah catatan'),
              ),
            ],
          ),
        ),
  );
}

class _LiveNoteEditor extends ConsumerStatefulWidget {
  const _LiveNoteEditor({this.existing});
  final JournalEntry? existing;

  @override
  ConsumerState<_LiveNoteEditor> createState() => _LiveNoteEditorState();
}

class _LiveNoteEditorState extends ConsumerState<_LiveNoteEditor> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _content = TextEditingController(
    text: widget.existing?.content ?? '',
  );
  // Hari dikunci ketika editor dibuka, bukan berubah saat melewati tengah malam.
  late final _day = widget.existing?.date ?? companionDay(DateTime.now());
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(
        () => _error = 'Isi judul dan catatan, atau kembali tanpa menyimpan.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(companionHistoryRepositoryProvider)
          .save(
            id: widget.existing?.id,
            day: _day,
            title: title,
            content: content,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = connectionFailureMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Tulis catatan pendamping')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_day),
          const Text('Opsional. Anda boleh kembali tanpa membuat catatan.'),
          TextField(
            key: const Key('companion-live-note-title'),
            controller: _title,
            enabled: !_busy,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Judul'),
          ),
          TextField(
            key: const Key('companion-live-note-content'),
            controller: _content,
            enabled: !_busy,
            maxLength: 10000,
            minLines: 5,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Catatan pengamatan Anda',
            ),
          ),
          if (_error != null)
            Text(_error!, key: const Key('companion-note-error')),
          FilledButton(
            key: const Key('companion-live-note-save'),
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}
