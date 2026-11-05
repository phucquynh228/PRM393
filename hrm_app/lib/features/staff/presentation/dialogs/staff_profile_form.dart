import 'package:flutter/material.dart';
import 'package:hrm_app/features/staff/data/repositories/staff_repository.dart';
import 'package:hrm_app/shared/presentation/dialogs/account_profile_form.dart';

class StaffProfileForm extends StatelessWidget {
  final StaffRepository repository;
  final StaffItem profile;
  final bool password;
  const StaffProfileForm({
    super.key,
    required this.repository,
    required this.profile,
    this.password = false,
  });

  static Future<bool?> show(
    BuildContext context,
    StaffRepository repository,
    StaffItem profile, {
    bool password = false,
  }) => AccountProfileForm.show(
    context,
    profile,
    password: password,
    onSave: (data) async {
      await repository.send(
        'PUT',
        password ? '/staff/password' : '/staff/profile',
        data: data,
      );
    },
  );

  @override
  Widget build(BuildContext context) => AccountProfileForm(
    profile: profile,
    password: password,
    onSave: (data) async {
      await repository.send(
        'PUT',
        password ? '/staff/password' : '/staff/profile',
        data: data,
      );
    },
  );
}
