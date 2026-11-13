import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';

class DoctorPatientPicker extends StatelessWidget {
  const DoctorPatientPicker({
    required this.value,
    required this.onChanged,
    required this.keyPrefix,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final scale = _scaleFor(context);
    return AppCard(
      key: Key('$keyPrefix-picker'),
      padding: EdgeInsets.all(20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih pasien',
            style: TextStyle(
              color: AppTheme.body,
              fontFamily: AppTheme.fontFamily,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
          SizedBox(height: 16 * scale),
          Container(
            key: Key('$keyPrefix-picker-value'),
            height: 76 * scale,
            padding: EdgeInsets.symmetric(horizontal: 8 * scale),
            decoration: BoxDecoration(
              color: AppTheme.selectedSurface,
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: Key('$keyPrefix-dropdown'),
                value: value,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.coralText,
                  size: 28 * scale,
                ),
                borderRadius: BorderRadius.circular(20 * scale),
                items: const [
                  DropdownMenuItem(
                    value: 'Ny. Shopia Mudj.',
                    child: _PatientPickerLabel(),
                  ),
                ],
                onChanged: (selected) {
                  if (selected != null) onChanged(selected);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientPickerLabel extends StatelessWidget {
  const _PatientPickerLabel();

  @override
  Widget build(BuildContext context) {
    final scale = _scaleFor(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: const Key('doctor-patient-picker-name'),
          'Ny. Shopia Mudj.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.coralText,
            fontFamily: AppTheme.fontFamily,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w600,
            height: 24 / 16,
          ),
        ),
        Text(
          'Ringkasan Belum ditinjau',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.muted,
            fontFamily: AppTheme.fontFamily,
            fontSize: 16 * scale,
            height: 24 / 16,
          ),
        ),
      ],
    );
  }
}

double _scaleFor(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width / 390).clamp(0.7, 1.15).toDouble();
}
