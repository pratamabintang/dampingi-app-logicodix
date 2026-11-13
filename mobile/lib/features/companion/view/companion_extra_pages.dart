import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';

class CompanionSupportPage extends StatefulWidget {
  const CompanionSupportPage({
    required this.scale,
    required this.onAction,
    super.key,
  });

  final double scale;
  final ValueChanged<String> onAction;

  @override
  State<CompanionSupportPage> createState() => _CompanionSupportPageState();
}

class _CompanionSupportPageState extends State<CompanionSupportPage> {
  bool _showPrompt = false;

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return ListView(
      key: const Key('companion-support-scroll'),
      padding: EdgeInsets.fromLTRB(
        scale * 24,
        scale * 20,
        scale * 24,
        scale * 24,
      ),
      children: [
        Text(
          'Dampingi',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.coralText,
            fontFamily: AppTheme.fontFamily,
            fontSize: scale * 24,
            fontWeight: FontWeight.w600,
            height: 32 / 24,
          ),
        ),
        SizedBox(height: scale * 48),
        AppCard(
          key: const Key('companion-support-screen'),
          padding: EdgeInsets.all(scale * 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dukungan hari ini',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale * 16,
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: scale * 32),
              InkWell(
                key: const Key('companion-support-prompt'),
                onTap: () => setState(() => _showPrompt = !_showPrompt),
                borderRadius: BorderRadius.circular(scale * 12),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: scale * 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Mulai dari pertanyaan sederhana',
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontFamily: AppTheme.fontFamily,
                                fontSize: scale * 16,
                                fontWeight: FontWeight.w600,
                                height: 24 / 16,
                              ),
                            ),
                          ),
                          SizedBox(width: scale * 12),
                          Icon(
                            _showPrompt
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: AppTheme.coralText,
                            size: scale * 24,
                          ),
                        ],
                      ),
                      SizedBox(height: scale * 12),
                      Text(
                        '“Apa yang paling kamu butuhkan hari ini?”',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: scale * 16,
                          height: 24 / 16,
                        ),
                      ),
                      if (_showPrompt) ...[
                        SizedBox(height: scale * 12),
                        Text(
                          'Tanyakan dengan lembut, lalu beri waktu untuk bercerita.',
                          style: TextStyle(
                            color: AppTheme.body,
                            fontFamily: AppTheme.fontFamily,
                            fontSize: scale * 14,
                            height: 20 / 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: scale * 16),
              Divider(height: scale, color: AppTheme.unselectedSurface),
              SizedBox(height: scale * 16),
              _CompanionSupportSuggestion(
                key: const Key('companion-support-concrete'),
                title: 'Bantu hal yang konkret',
                detail: 'Sepakati pembagian tugas dan...',
                onTap: () => widget.onAction('Bantu hal yang konkret'),
                scale: scale,
              ),
              SizedBox(height: scale * 16),
              Divider(height: scale, color: AppTheme.unselectedSurface),
              SizedBox(height: scale * 16),
              _CompanionSupportSuggestion(
                key: const Key('companion-support-listen'),
                title: 'Hargai ceritanya',
                detail: 'Dengarkan tanpa menghakimi d...',
                onTap: () => widget.onAction('Hargai ceritanya'),
                scale: scale,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompanionSupportSuggestion extends StatelessWidget {
  const _CompanionSupportSuggestion({
    required this.title,
    required this.detail,
    required this.onTap,
    required this.scale,
    super.key,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(scale * 12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: scale * 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontFamily: AppTheme.fontFamily,
                      fontSize: scale * 16,
                      fontWeight: FontWeight.w600,
                      height: 24 / 16,
                    ),
                  ),
                  SizedBox(height: scale * 12),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontFamily: AppTheme.fontFamily,
                      fontSize: scale * 16,
                      height: 24 / 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: scale * 12),
            Icon(
              Icons.chevron_right,
              color: AppTheme.coralText,
              size: scale * 24,
            ),
          ],
        ),
      ),
    );
  }
}

class CompanionProfilePage extends StatefulWidget {
  const CompanionProfilePage({
    required this.scale,
    required this.userName,
    required this.email,
    required this.onEdit,
    required this.onEnterCode,
    required this.onLogout,
    super.key,
  });

  final double scale;
  final String userName;
  final String email;
  final VoidCallback onEdit;
  final VoidCallback onEnterCode;
  final VoidCallback onLogout;

  @override
  State<CompanionProfilePage> createState() => _CompanionProfilePageState();
}

class _CompanionProfilePageState extends State<CompanionProfilePage> {
  bool _weeklySummary = true;

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return ListView(
      key: const Key('companion-profile-scroll'),
      padding: EdgeInsets.fromLTRB(
        scale * 24,
        scale * 20,
        scale * 24,
        scale * 24,
      ),
      children: [
        Text(
          'Dampingi',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.coralText,
            fontFamily: AppTheme.fontFamily,
            fontSize: scale * 24,
            fontWeight: FontWeight.w600,
            height: 32 / 24,
          ),
        ),
        SizedBox(height: scale * 48),
        AppCard(
          key: const Key('companion-profile-card'),
          padding: EdgeInsets.all(scale * 24),
          child: Column(
            children: [
              SvgPicture.asset(
                'assets/images/role_picker/companion.svg',
                width: scale * 96,
                height: scale * 96,
                semanticsLabel: 'Foto profil ${widget.userName}',
              ),
              SizedBox(height: scale * 24),
              Text(
                widget.userName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.ink,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale * 20,
                  fontWeight: FontWeight.w600,
                  height: 30 / 20,
                ),
              ),
              SizedBox(height: scale * 4),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.muted,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale * 16,
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: scale * 24),
              Text(
                'Kode pendampingan : OPD324',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.muted,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale * 16,
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: scale * 20),
              _CompanionProfileButton(
                key: const Key('companion-profile-edit'),
                label: 'Ubah Profil',
                scale: scale,
                onPressed: widget.onEdit,
              ),
              SizedBox(height: scale * 10),
              _CompanionProfileButton(
                key: const Key('companion-profile-enter-code'),
                label: 'Masukan Kode Pendampingan',
                scale: scale,
                onPressed: widget.onEnterCode,
                secondary: true,
              ),
            ],
          ),
        ),
        SizedBox(height: scale * 24),
        AppCard(
          key: const Key('companion-profile-permissions'),
          padding: EdgeInsets.all(scale * 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih data yang boleh dilihat orang yang terhubung',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: scale * 16,
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: scale * 24),
              Container(
                padding: EdgeInsets.all(scale * 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAF9),
                  borderRadius: BorderRadius.circular(scale * 32),
                ),
                child: Row(
                  children: [
                    ClipOval(
                      child: Image.asset(
                        'assets/images/mother_profile/man-1.png',
                        width: scale * 56,
                        height: scale * 56,
                        fit: BoxFit.cover,
                        semanticLabel: 'Foto Tn. Enzokulin',
                      ),
                    ),
                    SizedBox(width: scale * 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tn. Enzokulin',
                            style: TextStyle(
                              color: AppTheme.coralText,
                              fontFamily: AppTheme.fontFamily,
                              fontSize: scale * 16,
                              fontWeight: FontWeight.w600,
                              height: 24 / 16,
                            ),
                          ),
                          Text(
                            'enzo***@gmail.com',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontFamily: AppTheme.fontFamily,
                              fontSize: scale * 16,
                              height: 24 / 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: scale * 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ringkasan mingguan',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: scale * 14,
                        height: 20 / 14,
                      ),
                    ),
                  ),
                  Switch(
                    key: const Key('companion-profile-weekly-toggle'),
                    value: _weeklySummary,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF039855),
                    onChanged: (value) =>
                        setState(() => _weeklySummary = value),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: scale * 32),
        _CompanionProfileButton(
          key: const Key('companion-profile-logout'),
          label: 'Keluar',
          scale: scale,
          onPressed: widget.onLogout,
        ),
      ],
    );
  }
}

class _CompanionProfileButton extends StatelessWidget {
  const _CompanionProfileButton({
    required this.label,
    required this.scale,
    required this.onPressed,
    this.secondary = false,
    super.key,
  });

  final String label;
  final double scale;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: scale * 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: secondary ? AppTheme.pink2 : AppTheme.coral,
          foregroundColor: secondary ? AppTheme.coralText : Colors.white,
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(scale * 8),
          ),
          textStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: scale * 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
