import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/doctor/view/doctor_page.dart';

void main() {
  testWidgets('doctor navigation matches the shared bar in all four states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final selectedTab in DoctorNavigationTab.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox()),
                DoctorNavigationBar(
                  selectedTab: selectedTab,
                  onHomeTap: () {},
                  onPatientsTap: () {},
                  onGuideTap: () {},
                  onProfileTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.byKey(const Key('doctor-bottom-navigation')))
            .height,
        107,
      );
      for (final tab in DoctorNavigationTab.values) {
        final item = tester.widget<Container>(
          find.byKey(Key('doctor-nav-item-${tab.name}')),
        );
        final decoration = item.decoration! as BoxDecoration;
        expect(
          decoration.color,
          tab == selectedTab ? AppTheme.coral : const Color(0xFFFDFDFD),
        );
        expect(
          tester.getSize(find.byKey(Key('doctor-nav-item-${tab.name}'))),
          const Size(56, 56),
        );
      }
    }
  });
}
