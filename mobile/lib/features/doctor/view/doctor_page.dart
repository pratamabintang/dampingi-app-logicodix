import 'package:flutter/material.dart';

import '../../../core/widgets/role_page_scaffold.dart';
import '../../../models/app_role.dart';

class DoctorPage extends StatelessWidget {
  const DoctorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RolePageScaffold(role: AppRole.professional);
  }
}
