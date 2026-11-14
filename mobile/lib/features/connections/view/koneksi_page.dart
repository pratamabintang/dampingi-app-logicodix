import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty.dart';
import '../../../core/widgets/app_error.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../models/app_role.dart';
import '../../mother/repositories/mother_story_repository.dart';
import '../preview_invite_codes.dart';
import '../repositories/connection_repository.dart';

const _monthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// "14 Nov 2026, 22.05" — waktu lokal, tanpa zona waktu dan tanpa dependensi
/// pemformat tanggal.
String formatInviteExpiry(String expiresAt) {
  final parsed = DateTime.tryParse(expiresAt);
  if (parsed == null) return expiresAt;
  final local = parsed.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_monthAbbreviations[local.month - 1]} ${local.year}, '
      '$hour.$minute';
}

/// Peran target yang boleh disebut pemanggil. Ibu memilih antara Pendamping
/// dan Tenaga kesehatan; Peran lain hanya boleh menyebut Ibu.
List<String> candidateTargetRoles(AppRole role) => role == AppRole.mother
    ? const ['companion', 'professional']
    : const ['mother'];

/// Halaman Koneksi: satu layar untuk semua Peran. Isinya ditentukan oleh apa
/// yang backend izinkan sekarang, bukan oleh Peran yang membuka layar ini.
///
/// Membuka layar ini hanya membaca. Kode undangan dibuat hanya kalau pemiliknya
/// memintanya lewat tindakan eksplisit.
class KoneksiPage extends ConsumerStatefulWidget {
  const KoneksiPage({required this.role, super.key});

  final AppRole role;

  @override
  ConsumerState<KoneksiPage> createState() => _KoneksiPageState();
}

class _KoneksiPageState extends ConsumerState<KoneksiPage> {
  /// Kode contoh mode preview. Hanya dipakai saat tidak bicara dengan backend.
  late final List<InviteCode> _previewCodes;

  /// Koneksi contoh mode preview. Hanya dipakai saat tidak bicara dengan
  /// backend.
  final List<ConnectionPerson> _previewConnections = [];
  final TextEditingController _codeController = TextEditingController();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _previewCodes = previewInviteCodesFor(candidateTargetRoles(widget.role));
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(backendTokenProvider) == null;
    final codesAsync = ref.watch(liveInviteCodesProvider);
    final connectionsAsync = ref.watch(activeConnectionsProvider);
    final people = preview
        ? _previewConnections
        : connectionsAsync.asData?.value ?? const <ConnectionPerson>[];
    final connectedRoles = <String>{for (final person in people) person.role};

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 390)
                .clamp(0.7, 1.15)
                .toDouble();
            final width = math.min(constraints.maxWidth, 390 * scale);
            double scaled(double value) => value * scale;

            return Center(
              child: SizedBox(
                width: width,
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    key: const Key('koneksi-scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      scaled(24),
                      scaled(20),
                      scaled(24),
                      scaled(34),
                    ),
                    children: [
                      _KoneksiBackButton(scale: scaled, role: widget.role),
                      SizedBox(height: scaled(36)),
                      Text(
                        'Koneksi',
                        key: const Key('koneksi-title'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.ink,
                          fontSize: scaled(24),
                          fontWeight: FontWeight.w600,
                          height: 32 / 24,
                        ),
                      ),
                      SizedBox(height: scaled(24)),
                      _sectionTitle('Koneksi Aktif', scaled),
                      SizedBox(height: scaled(12)),
                      ...(preview
                          ? _buildConnectionList(_previewConnections, scaled)
                          : connectionsAsync.when(
                              data: (people) => _buildConnectionList(
                                people ?? const [],
                                scaled,
                              ),
                              loading: () => [
                                SizedBox(
                                  key: const Key('koneksi-connections-loading'),
                                  height: scaled(120),
                                  child: const AppLoading(
                                    message: 'Memuat Koneksi',
                                  ),
                                ),
                              ],
                              error: (error, stackTrace) => [
                                SizedBox(
                                  key: const Key('koneksi-connections-error'),
                                  height: scaled(120),
                                  child: AppError(
                                    message: connectionFailureMessage(error),
                                    onRetry: () => ref.invalidate(
                                      activeConnectionsProvider,
                                    ),
                                  ),
                                ),
                              ],
                            )),
                      if (widget.role == AppRole.mother) ...[
                        SizedBox(height: scaled(16)),
                        Text(
                          'Orang yang terhubung hanya dapat melihat ringkasan '
                          'mingguan Anda. Jurnal, mood harian, dan hasil EPDS '
                          'tetap pribadi.',
                          key: const Key('koneksi-sharing-note'),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.muted,
                            fontSize: scaled(12),
                            height: 16 / 12,
                          ),
                        ),
                      ],
                      SizedBox(height: scaled(28)),
                      _sectionTitle('Tukar Kode', scaled),
                      SizedBox(height: scaled(12)),
                      AppTextField(
                        key: const Key('koneksi-redeem-field'),
                        controller: _codeController,
                        label: 'Kode Undangan',
                        hintText: 'Masukkan kode',
                        inputHeight: scaled(44),
                        autocorrect: false,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_busy) _redeem();
                        },
                      ),
                      SizedBox(height: scaled(12)),
                      FilledButton(
                        key: const Key('koneksi-redeem'),
                        onPressed: _busy ? null : _redeem,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.coral,
                          padding: EdgeInsets.symmetric(vertical: scaled(12)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(scaled(16)),
                          ),
                        ),
                        child: Text(
                          'Tukar Kode',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Colors.white,
                            fontSize: scaled(16),
                            fontWeight: FontWeight.w600,
                            height: 24 / 16,
                          ),
                        ),
                      ),
                      SizedBox(height: scaled(28)),
                      _sectionTitle('Kode Undangan', scaled),
                      SizedBox(height: scaled(12)),
                      _IssueButton(
                        scale: scaled,
                        busy: _busy,
                        blockedReason: _issuanceBlockedReason(connectedRoles),
                        onPressed: _onIssueTapped,
                      ),
                      SizedBox(height: scaled(24)),
                      if (preview)
                        ..._buildCodes(_previewCodes, scaled)
                      else
                        ...codesAsync.when(
                          data: (codes) =>
                              _buildCodes(codes ?? const [], scaled),
                          loading: () => [
                            SizedBox(
                              key: const Key('koneksi-loading'),
                              height: scaled(160),
                              child: const AppLoading(
                                message: 'Memuat Kode Undangan',
                              ),
                            ),
                          ],
                          error: (error, stackTrace) => [
                            SizedBox(
                              key: const Key('koneksi-error'),
                              height: scaled(160),
                              child: AppError(
                                message: connectionFailureMessage(error),
                                onRetry: () =>
                                    ref.invalidate(liveInviteCodesProvider),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Alasan pemanggil tidak boleh menerbitkan kode sama sekali, atau null.
  ///
  /// Ibu tidak pernah diblokir seluruhnya; hanya opsi tenaga kesehatan yang
  /// bisa dimatikan. Pendamping yang sudah punya Ibu aktif tidak ditawari
  /// penerbitan sama sekali. Tenaga kesehatan tidak pernah diblokir.
  String? _issuanceBlockedReason(Set<String> connectedRoles) {
    if (widget.role != AppRole.companion) return null;
    if (connectedRoles.contains('mother')) {
      return 'Anda sudah terhubung dengan seorang Ibu.';
    }
    return null;
  }

  /// Alasan satu Peran target tidak boleh dipilih sekarang, atau null.
  String? _targetBlockedReason(String targetRole, Set<String> connectedRoles) {
    if (widget.role == AppRole.mother &&
        targetRole == 'professional' &&
        connectedRoles.contains('professional')) {
      return 'Anda sudah terhubung dengan tenaga kesehatan.';
    }
    return null;
  }

  Widget _sectionTitle(String label, double Function(double) scaled) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        color: AppTheme.ink,
        fontSize: scaled(16),
        fontWeight: FontWeight.w600,
        height: 24 / 16,
      ),
    );
  }

  List<Widget> _buildConnectionList(
    List<ConnectionPerson> people,
    double Function(double) scaled,
  ) {
    if (people.isEmpty) {
      return [
        AppEmpty(
          key: const Key('koneksi-connections-empty'),
          title: 'Belum ada Koneksi',
          message:
              'Orang yang terhubung akan muncul di sini setelah Kode Undangan '
              'ditukar.',
        ),
      ];
    }
    return [
      for (var index = 0; index < people.length; index++) ...[
        if (index > 0) SizedBox(height: scaled(10)),
        _ConnectionCard(
          person: people[index],
          scale: scaled,
          onEnd: _busy ? null : () => _onEndTapped(people[index]),
        ),
      ],
    ];
  }

  Future<void> _onEndTapped(ConnectionPerson person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _EndDialog(person: person),
    );
    if (confirmed != true || !mounted) return;
    await _endConnection(person);
  }

  Future<void> _endConnection(ConnectionPerson person) async {
    final token = ref.read(backendTokenProvider);
    if (token == null) return;
    await _runWrite(
      (accessToken) => ref
          .read(connectionRepositoryProvider)
          .endConnection(accessToken: accessToken, id: person.id),
    );
  }

  List<Widget> _buildCodes(
    List<InviteCode> codes,
    double Function(double) scaled,
  ) {
    if (codes.isEmpty) {
      final invitee = widget.role == AppRole.mother
          ? 'pendamping atau tenaga kesehatan'
          : 'Ibu';
      return [
        AppEmpty(
          key: const Key('koneksi-empty'),
          title: 'Belum ada Kode Undangan',
          message:
              'Kode Undangan hanya berlaku satu jam. Kalau kode sebelumnya '
              'sudah kedaluwarsa atau terpakai, buat kode baru untuk '
              'mengundang $invitee.',
        ),
      ];
    }
    return [
      for (var index = 0; index < codes.length; index++) ...[
        if (index > 0) SizedBox(height: scaled(10)),
        _InviteCodeCard(
          code: codes[index],
          scale: scaled,
          onCopy: () => _copy(codes[index].code),
          onRevoke: _busy ? null : () => _onRevokeTapped(codes[index]),
        ),
      ],
    ];
  }

  Future<void> _onIssueTapped() async {
    final connections =
        ref.read(activeConnectionsProvider).asData?.value ?? const [];
    final connectedRoles = <String>{
      for (final person in connections) person.role,
    };
    final targets = candidateTargetRoles(widget.role);

    String? chosen;
    if (targets.length == 1) {
      chosen = targets.single;
      final reason = _targetBlockedReason(chosen, connectedRoles);
      if (reason != null) {
        _showMessage(reason);
        return;
      }
    } else {
      chosen = await showDialog<String>(
        context: context,
        builder: (dialogContext) => _TargetRoleDialog(
          targets: targets,
          reasonFor: (target) => _targetBlockedReason(target, connectedRoles),
        ),
      );
    }
    if (chosen == null || !mounted) return;
    await _issue(chosen);
  }

  Future<void> _issue(String targetRole) async {
    final token = ref.read(backendTokenProvider);
    if (token == null) {
      setState(() {
        final fresh = freshPreviewInviteCodeFor(targetRole);
        final index = _previewCodes.indexWhere(
          (code) => code.targetRole == targetRole,
        );
        if (index >= 0) {
          _previewCodes[index] = fresh;
        } else {
          _previewCodes.add(fresh);
        }
      });
      return;
    }

    await _runWrite(
      (accessToken) => ref
          .read(connectionRepositoryProvider)
          .issueInviteCode(accessToken: accessToken, targetRole: targetRole),
    );
  }

  Future<void> _onRevokeTapped(InviteCode code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _RevokeDialog(code: code),
    );
    if (confirmed != true || !mounted) return;
    await _revoke(code);
  }

  Future<void> _revoke(InviteCode code) async {
    final token = ref.read(backendTokenProvider);
    if (token == null) {
      setState(() => _previewCodes.removeWhere((item) => item.id == code.id));
      return;
    }

    await _runWrite(
      (accessToken) => ref
          .read(connectionRepositoryProvider)
          .revokeInviteCode(accessToken: accessToken, id: code.id),
    );
  }

  Future<void> _redeem() async {
    final token = ref.read(backendTokenProvider);
    if (token == null) {
      _redeemPreview();
      return;
    }
    final code = _codeController.text;
    await _runWrite(
      (accessToken) => ref
          .read(connectionRepositoryProvider)
          .redeem(accessToken: accessToken, code: code),
      onSuccess: () {
        _codeController.clear();
        FocusScope.of(context).unfocus();
        _showMessage('Kode berhasil ditukar.');
      },
    );
  }

  /// Pratinjau tanpa backend: satu kode contoh per Peran, dinilai lokal. Tidak
  /// ada pesan backend yang bisa ditampilkan di sini.
  void _redeemPreview() {
    final code = _codeController.text.trim().toUpperCase();
    if (code != previewInviteCodeForRole(widget.role.name)) {
      _showMessage('Kode tidak valid atau sudah kedaluwarsa (berlaku 1 jam).');
      return;
    }
    final id = 'preview-connection-${widget.role.name}';
    setState(() {
      if (!_previewConnections.any((person) => person.id == id)) {
        _previewConnections.add(
          widget.role == AppRole.mother
              ? const ConnectionPerson(
                  id: 'preview-connection-mother',
                  name: 'Tn. Enzokulin',
                  role: 'companion',
                )
              : const ConnectionPerson(
                  id: 'preview-connection-other',
                  name: 'Ibu Demo',
                  role: 'mother',
                ),
        );
      }
      _codeController.clear();
    });
    FocusScope.of(context).unfocus();
    _showMessage('Kode berhasil ditukar.');
  }

  /// Satu jalur tulis: tandai sibuk, jalankan, lalu segarkan daftar. Kegagalan
  /// tampil sebagai pesan, bukan diam.
  Future<void> _runWrite(
    Future<void> Function(String accessToken) write, {
    VoidCallback? onSuccess,
  }) async {
    final token = ref.read(backendTokenProvider);
    if (token == null) return;

    setState(() => _busy = true);
    try {
      await write(token);
      await _refresh();
      if (mounted) onSuccess?.call();
    } catch (error) {
      if (mounted) _showMessage(connectionFailureMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (ref.read(backendTokenProvider) == null) return;
    ref.invalidate(liveInviteCodesProvider);
    ref.invalidate(activeConnectionsProvider);
    try {
      await ref.read(liveInviteCodesProvider.future);
    } catch (_) {
      // Kegagalannya tampil sebagai keadaan galat di halaman ini.
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _showMessage('Kode Undangan disalin.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _IssueButton extends StatelessWidget {
  const _IssueButton({
    required this.scale,
    required this.busy,
    required this.blockedReason,
    required this.onPressed,
  });

  final double Function(double) scale;
  final bool busy;
  final String? blockedReason;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final reason = blockedReason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const Key('koneksi-issue'),
          onPressed: reason != null || busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.coral,
            disabledBackgroundColor: AppTheme.pink6.withValues(alpha: 0.4),
            padding: EdgeInsets.symmetric(vertical: scale(12)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(scale(16)),
            ),
          ),
          child: Text(
            'Buat Kode Undangan',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: Colors.white,
              fontSize: scale(16),
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
        ),
        if (reason != null) ...[
          SizedBox(height: scale(8)),
          Text(
            reason,
            key: const Key('koneksi-issue-blocked'),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.muted,
              fontSize: scale(14),
              height: 20 / 14,
            ),
          ),
        ],
      ],
    );
  }
}

class _TargetRoleDialog extends StatelessWidget {
  const _TargetRoleDialog({required this.targets, required this.reasonFor});

  final List<String> targets;
  final String? Function(String target) reasonFor;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('koneksi-issue-dialog'),
      title: const Text('Untuk siapa kode ini?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final target in targets) ...[
            _TargetOption(
              target: target,
              blockedReason: reasonFor(target),
              onPressed: () => Navigator.of(context).pop(target),
            ),
            if (target != targets.last) const SizedBox(height: 8),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('koneksi-issue-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kembali'),
        ),
      ],
    );
  }
}

class _TargetOption extends StatelessWidget {
  const _TargetOption({
    required this.target,
    required this.blockedReason,
    required this.onPressed,
  });

  final String target;
  final String? blockedReason;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final reason = blockedReason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton(
          key: Key('koneksi-issue-target-$target'),
          onPressed: reason != null ? null : onPressed,
          child: Text(connectionRoleLabel(target)),
        ),
        if (reason != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              reason,
              key: Key('koneksi-issue-block-$target'),
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ),
        ],
      ],
    );
  }
}

class _RevokeDialog extends StatelessWidget {
  const _RevokeDialog({required this.code});

  final InviteCode code;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('koneksi-revoke-dialog'),
      title: const Text('Cabut Kode Undangan ini?'),
      content: Text(
        'Kode ${code.code} untuk ${code.targetRoleLabel} tidak akan bisa '
        'ditukar lagi.',
      ),
      actions: [
        TextButton(
          key: const Key('koneksi-revoke-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Kembali'),
        ),
        FilledButton(
          key: const Key('koneksi-revoke-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cabut'),
        ),
      ],
    );
  }
}

class _EndDialog extends StatelessWidget {
  const _EndDialog({required this.person});

  final ConnectionPerson person;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('koneksi-end-dialog'),
      title: Text('Akhiri Koneksi dengan ${person.name}?'),
      content: const Text('Koneksi ini akan berakhir untuk kedua pihak.'),
      actions: [
        TextButton(
          key: const Key('koneksi-end-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Kembali'),
        ),
        FilledButton(
          key: const Key('koneksi-end-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Akhiri'),
        ),
      ],
    );
  }
}

class _KoneksiBackButton extends StatelessWidget {
  const _KoneksiBackButton({required this.scale, required this.role});

  final double Function(double) scale;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: scale(24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          key: const Key('koneksi-back'),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(role.location);
            }
          },
          tooltip: 'Kembali',
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(
            width: scale(24),
            height: scale(24),
          ),
          icon: SvgPicture.asset(
            'assets/images/mother_profile/notification-back.svg',
            width: 24,
            height: 24,
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.person,
    required this.scale,
    required this.onEnd,
  });

  final ConnectionPerson person;
  final double Function(double) scale;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('koneksi-connection-${person.id}'),
      padding: EdgeInsets.all(scale(20)),
      borderRadius: scale(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            person.name,
            key: Key('koneksi-connection-name-${person.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.ink,
              fontSize: scale(18),
              fontWeight: FontWeight.w600,
              height: 26 / 18,
            ),
          ),
          SizedBox(height: scale(4)),
          Text(
            person.roleLabel,
            key: Key('koneksi-connection-role-${person.id}'),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.body,
              fontSize: scale(16),
              height: 24 / 16,
            ),
          ),
          SizedBox(height: scale(12)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: Key('koneksi-end-${person.id}'),
              onPressed: onEnd,
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Akhiri'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.coralText),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.code,
    required this.scale,
    required this.onCopy,
    required this.onRevoke,
  });

  final InviteCode code;
  final double Function(double) scale;
  final VoidCallback onCopy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('koneksi-code-${code.id}'),
      padding: EdgeInsets.all(scale(20)),
      borderRadius: scale(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  code.code,
                  key: Key('koneksi-code-text-${code.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.coralText,
                    fontSize: scale(20),
                    fontWeight: FontWeight.w600,
                    height: 30 / 20,
                  ),
                ),
              ),
              SizedBox(width: scale(8)),
              IconButton(
                key: Key('koneksi-copy-${code.id}'),
                onPressed: onCopy,
                tooltip: 'Salin kode',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: scale(32),
                  height: scale(32),
                ),
                icon: Icon(
                  Icons.copy_rounded,
                  size: scale(20),
                  color: AppTheme.coralText,
                ),
              ),
            ],
          ),
          SizedBox(height: scale(8)),
          Text(
            'Untuk ${code.targetRoleLabel}',
            key: Key('koneksi-target-${code.id}'),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.body,
              fontSize: scale(16),
              height: 24 / 16,
            ),
          ),
          SizedBox(height: scale(4)),
          Text(
            'Berlaku sampai ${formatInviteExpiry(code.expiresAt)}',
            key: Key('koneksi-expiry-${code.id}'),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.muted,
              fontSize: scale(14),
              height: 20 / 14,
            ),
          ),
          SizedBox(height: scale(12)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: Key('koneksi-revoke-${code.id}'),
              onPressed: onRevoke,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Cabut'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.coralText),
            ),
          ),
        ],
      ),
    );
  }
}
