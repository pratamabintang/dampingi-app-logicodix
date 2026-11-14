import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/controller/auth_controller.dart';
import '../../shared/view/app_bottom_navigation_bar.dart';
import 'doctor_guide_page.dart';
import 'doctor_profile_page.dart';
import 'doctor_patient_summary_page.dart';

class DoctorPage extends ConsumerStatefulWidget {
  const DoctorPage({super.key});

  @override
  ConsumerState<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends ConsumerState<DoctorPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  DoctorNavigationTab _selectedTab = DoctorNavigationTab.home;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref
        .watch(authControllerProvider)
        .asData
        ?.value
        .session
        ?.user
        .name
        ?.trim();
    final name = userName == null || userName.isEmpty
        ? 'Maya Estiyanti'
        : userName;
    final greetingName = name.toLowerCase().startsWith('dr.')
        ? name
        : 'dr. $name';
    final query = _searchQuery.trim().toLowerCase();
    final patients = _doctorPatients
        .where(
          (patient) =>
              patient.name.toLowerCase().contains(query) ||
              patient.status.toLowerCase().contains(query),
        )
        .toList();

    if (_selectedTab == DoctorNavigationTab.patients) {
      return DoctorPatientSummaryPage(
        bottomNavigation: DoctorNavigationBar(
          selectedTab: DoctorNavigationTab.patients,
          onHomeTap: () =>
              setState(() => _selectedTab = DoctorNavigationTab.home),
          onPatientsTap: () {},
          onGuideTap: () =>
              setState(() => _selectedTab = DoctorNavigationTab.guide),
          onProfileTap: () =>
              setState(() => _selectedTab = DoctorNavigationTab.profile),
        ),
      );
    }

    if (_selectedTab == DoctorNavigationTab.guide) {
      return DoctorGuidePage(
        bottomNavigation: DoctorNavigationBar(
          selectedTab: DoctorNavigationTab.guide,
          onHomeTap: () =>
              setState(() => _selectedTab = DoctorNavigationTab.home),
          onPatientsTap: () =>
              setState(() => _selectedTab = DoctorNavigationTab.patients),
          onGuideTap: () {},
          onProfileTap: () =>
              setState(() => _selectedTab = DoctorNavigationTab.profile),
        ),
      );
    }

    if (_selectedTab == DoctorNavigationTab.profile) {
      return DoctorProfilePage(
        bottomNavigation: DoctorNavigationBar(
          selectedTab: DoctorNavigationTab.profile,
          onHomeTap: () =>
              setState(() => _selectedTab = DoctorNavigationTab.home),
          onPatientsTap: () =>
              setState(() => _selectedTab = DoctorNavigationTab.patients),
          onGuideTap: () =>
              setState(() => _selectedTab = DoctorNavigationTab.guide),
          onProfileTap: () {},
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 390)
                .clamp(0.7, 1.15)
                .toDouble();
            final contentWidth = constraints.maxWidth < 390 * scale
                ? constraints.maxWidth
                : 390 * scale;

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        key: const Key('doctor-home-scroll'),
                        padding: EdgeInsets.fromLTRB(
                          24 * scale,
                          20 * scale,
                          24 * scale,
                          24 * scale,
                        ),
                        children: [
                          _DoctorHeader(
                            scale: scale,
                            doctorName: greetingName,
                            onNotificationsTap: () => _showNotice(
                              context,
                              'Belum ada notifikasi baru.',
                            ),
                          ),
                          SizedBox(height: 36 * scale),
                          Text(
                            'Halo, $greetingName',
                            key: const Key('doctor-home-greeting'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.ink,
                              fontSize: 24 * scale,
                              fontWeight: FontWeight.w600,
                              height: 32 / 24,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            'Senin, 28 Oktober 2026',
                            key: const Key('doctor-home-date'),
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.muted,
                              fontSize: 16 * scale,
                              height: 24 / 16,
                            ),
                          ),
                          SizedBox(height: 36 * scale),
                          _ConnectionCard(
                            scale: scale,
                            onOpenConnections: () =>
                                context.push('/doctor/connections'),
                          ),
                          SizedBox(height: 36 * scale),
                          _PatientsCard(
                            scale: scale,
                            searchController: _searchController,
                            searchFocusNode: _searchFocusNode,
                            patients: patients,
                            onSearch: _searchPatients,
                            onSearchChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    DoctorNavigationBar(
                      selectedTab: _selectedTab,
                      onHomeTap: () => setState(
                        () => _selectedTab = DoctorNavigationTab.home,
                      ),
                      onPatientsTap: () => setState(
                        () => _selectedTab = DoctorNavigationTab.patients,
                      ),
                      onGuideTap: () => setState(
                        () => _selectedTab = DoctorNavigationTab.guide,
                      ),
                      onProfileTap: () => setState(
                        () => _selectedTab = DoctorNavigationTab.profile,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _searchPatients() {
    _searchFocusNode.unfocus();
    setState(() => _searchQuery = _searchController.text);
  }
}

class _DoctorHeader extends StatelessWidget {
  const _DoctorHeader({
    required this.scale,
    required this.doctorName,
    required this.onNotificationsTap,
  });

  final double scale;
  final String doctorName;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/doctor/doctor-avatar.png',
            key: const Key('doctor-home-avatar'),
            width: 56 * scale,
            height: 56 * scale,
            fit: BoxFit.cover,
            semanticLabel: 'Foto profil $doctorName',
          ),
        ),
        IconButton(
          key: const Key('doctor-home-notifications'),
          tooltip: 'Notifikasi',
          onPressed: onNotificationsTap,
          padding: EdgeInsets.all(8 * scale),
          constraints: BoxConstraints(
            minWidth: 48 * scale,
            minHeight: 48 * scale,
          ),
          icon: SvgPicture.asset(
            'assets/images/mother_home/notification.svg',
            width: 19.478 * scale,
            height: 22 * scale,
          ),
        ),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.scale, required this.onOpenConnections});

  final double scale;
  final VoidCallback onOpenConnections;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('doctor-connections-card'),
      padding: EdgeInsets.all(20 * scale),
      borderRadius: 32 * scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Koneksi',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.coralText,
              fontSize: 16 * scale,
              height: 24 / 16,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            'Tukar Kode Undangan dari Ibu',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.coralText,
              fontSize: 20 * scale,
              fontWeight: FontWeight.w600,
              height: 30 / 20,
            ),
          ),
          SizedBox(height: 16 * scale),
          SizedBox(
            height: 48 * scale,
            child: FilledButton(
              key: const Key('doctor-connections-open'),
              onPressed: onOpenConnections,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coral,
                foregroundColor: Colors.white,
                minimumSize: Size.fromHeight(48 * scale),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                textStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
              child: const Text('Masukkan Kode'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientsCard extends StatelessWidget {
  const _PatientsCard({
    required this.scale,
    required this.searchController,
    required this.searchFocusNode,
    required this.patients,
    required this.onSearch,
    required this.onSearchChanged,
  });

  final double scale;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<_DoctorPatient> patients;
  final VoidCallback onSearch;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('doctor-patients-card'),
      padding: EdgeInsets.all(20 * scale),
      borderRadius: 32 * scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pasien anda',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.body,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
          SizedBox(height: 16 * scale),
          SizedBox(
            key: const Key('doctor-patient-search-composer'),
            height: 53 * scale,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(8 * scale),
                boxShadow: AppTheme.inputShadow,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 14 * scale,
                vertical: 7.5 * scale,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36 * scale,
                      child: Center(
                        child: TextField(
                          key: const Key('doctor-patient-search'),
                          controller: searchController,
                          focusNode: searchFocusNode,
                          onChanged: onSearchChanged,
                          onSubmitted: (_) => onSearch(),
                          maxLines: 1,
                          textAlignVertical: TextAlignVertical.center,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.body,
                            fontSize: 16 * scale,
                            height: 24 / 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Cari nama pasien',
                            hintStyle: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.secondary,
                              fontSize: 16 * scale,
                              height: 24 / 16,
                            ),
                            isCollapsed: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Semantics(
                    button: true,
                    label: 'Cari pasien',
                    child: Material(
                      color: AppTheme.coral,
                      borderRadius: BorderRadius.circular(8 * scale),
                      child: InkWell(
                        key: const Key('doctor-patient-search-button'),
                        onTap: onSearch,
                        borderRadius: BorderRadius.circular(8 * scale),
                        child: SizedBox(
                          width: 36 * scale,
                          height: 36 * scale,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/images/doctor/search.svg',
                              key: const Key('doctor-patient-search-icon'),
                              width: 20 * scale,
                              height: 20 * scale,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16 * scale),
          if (patients.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16 * scale),
              child: Text(
                'Tidak ada pasien yang cocok.',
                key: const Key('doctor-patients-empty'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.muted,
                  fontSize: 14 * scale,
                  height: 20 / 14,
                ),
              ),
            )
          else
            for (var index = 0; index < patients.length; index++) ...[
              _DoctorPatientRow(
                key: Key('doctor-patient-row-$index'),
                scale: scale,
                patient: patients[index],
              ),
              if (index < patients.length - 1) SizedBox(height: 16 * scale),
            ],
        ],
      ),
    );
  }
}

class _DoctorPatientRow extends StatelessWidget {
  const _DoctorPatientRow({
    required this.scale,
    required this.patient,
    super.key,
  });

  final double scale;
  final _DoctorPatient patient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: AppTheme.selectedSurface,
        borderRadius: BorderRadius.circular(32 * scale),
      ),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/doctor/patient-avatar.png',
              width: 56 * scale,
              height: 56 * scale,
              fit: BoxFit.cover,
              semanticLabel: 'Foto pasien ${patient.name}',
            ),
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.coralText,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                ),
                Text(
                  patient.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.muted,
                    fontSize: 16 * scale,
                    height: 24 / 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum DoctorNavigationTab { home, patients, guide, profile }

class DoctorNavigationBar extends StatelessWidget {
  const DoctorNavigationBar({
    required this.selectedTab,
    this.onHomeTap,
    this.onPatientsTap,
    this.onGuideTap,
    this.onProfileTap,
    super.key,
  });

  final DoctorNavigationTab selectedTab;
  final VoidCallback? onHomeTap;
  final VoidCallback? onPatientsTap;
  final VoidCallback? onGuideTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return AppBottomNavigationBar(
      key: key,
      navigationKey: const Key('doctor-bottom-navigation'),
      selectedId: selectedTab.name,
      items: [
        AppNavigationItem(
          id: DoctorNavigationTab.home.name,
          label: 'Beranda',
          inactiveAsset: 'home.svg',
          activeAsset: 'home-active.svg',
          onTap: onHomeTap,
          tapKey: const Key('doctor-nav-home'),
          tileKey: const Key('doctor-nav-item-home'),
        ),
        AppNavigationItem(
          id: DoctorNavigationTab.patients.name,
          label: 'Pasien',
          inactiveAsset: 'observation.svg',
          activeAsset: 'observation-active.svg',
          onTap: onPatientsTap,
          tapKey: const Key('doctor-nav-patients'),
          tileKey: const Key('doctor-nav-item-patients'),
        ),
        AppNavigationItem(
          id: DoctorNavigationTab.guide.name,
          label: 'Panduan',
          inactiveAsset: 'doctor-book.svg',
          activeAsset: 'doctor-book-active.svg',
          onTap: onGuideTap,
          tapKey: const Key('doctor-nav-guide'),
          tileKey: const Key('doctor-nav-item-guide'),
        ),
        AppNavigationItem(
          id: DoctorNavigationTab.profile.name,
          label: 'Profil',
          inactiveAsset: 'profile.svg',
          activeAsset: 'profile-active.svg',
          onTap: onProfileTap,
          tapKey: const Key('doctor-nav-profile'),
          tileKey: const Key('doctor-nav-item-profile'),
        ),
      ],
    );
  }
}

class _DoctorPatient {
  const _DoctorPatient({required this.name, required this.status});

  final String name;
  final String status;
}

const _doctorPatients = [
  _DoctorPatient(name: 'Ny. Shopia Mudj.', status: 'Ringkasan Belum ditinjau'),
  _DoctorPatient(name: 'Ny. Shopia Mudj.', status: 'Arahan telah diberikan'),
  _DoctorPatient(name: 'Ny. Shopia Mudj.', status: 'Ringkasan Belum ditinjau'),
  _DoctorPatient(name: 'Ny. Shopia Mudj.', status: 'Menunggu persetujuan'),
];
