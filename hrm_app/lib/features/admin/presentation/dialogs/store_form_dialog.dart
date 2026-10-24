import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:hrm_app/core/services/location_service.dart';
import 'package:hrm_app/shared/presentation/widgets/adaptive_form.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/features/branch/presentation/widgets/store_location_picker.dart';
import 'package:hrm_app/features/staff/presentation/dialogs/request_form.dart';

class StoreFormDialog extends StatefulWidget {
  final Map<String, dynamic>? store;
  final List<dynamic> users;
  final LocationService locationService;
  final TileProvider? mapTileProvider;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(String, {bool isError}) showSnackBar;
  const StoreFormDialog({
    super.key,
    this.store,
    required this.users,
    required this.locationService,
    this.mapTileProvider,
    required this.onSubmit,
    required this.showSnackBar,
  });
  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? store,
    required List<dynamic> users,
    required LocationService locationService,
    required Future<void> Function(Map<String, dynamic>) onSubmit,
    required void Function(String, {bool isError}) showSnackBar,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StoreFormDialog(
      store: store,
      users: users,
      locationService: locationService,
      onSubmit: onSubmit,
      showSnackBar: showSnackBar,
    ),
  );
  @override
  State<StoreFormDialog> createState() => _StoreFormDialogState();
}

class _StoreFormDialogState extends State<StoreFormDialog> {
  final _form = GlobalKey<FormState>();
  final _locationField = GlobalKey<FormFieldState<LatLng>>();
  late final TextEditingController _code, _name, _radius, _capacity;
  LatLng? _initialLocation;
  String _status = 'ACTIVE';
  int? _manager;
  bool _saving = false, _gps = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final s = widget.store;
    _code = TextEditingController(text: s?['code']?.toString() ?? '');
    _name = TextEditingController(text: s?['name']?.toString() ?? '');
    final lat = double.tryParse(s?['latitude']?.toString() ?? '');
    final lng = double.tryParse(s?['longitude']?.toString() ?? '');
    if (lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180) {
      _initialLocation = LatLng(lat, lng);
    }
    _radius = TextEditingController(
      text: s?['allowedRadius']?.toString() ?? '200',
    );
    _capacity = TextEditingController(text: s?['maxStaff']?.toString() ?? '15');
    _status = s?['status']?.toString() ?? 'ACTIVE';
    _manager = s?['managerId'] as int?;
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _radius, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? s) =>
      s == null || s.trim().isEmpty ? 'Vui lòng nhập thông tin' : null;

  Future<void> _save() async {
    if (_saving || _gps || !_form.currentState!.validate()) return;
    if (widget.store?['managerId'] != null &&
        _manager != widget.store?['managerId']) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Thay đổi quản lý?'),
          content: const Text(
            'Xác nhận cập nhật người quản lý của chi nhánh này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit({
        'code': _code.text.trim().toUpperCase(),
        'name': _name.text.trim(),
        'latitude': _locationField.currentState!.value!.latitude,
        'longitude': _locationField.currentState!.value!.longitude,
        'allowedRadius': int.parse(_radius.text.trim()),
        'maxStaff': int.parse(_capacity.text.trim()),
        'status': _status,
        'managerId': _manager,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = requestError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveForm(
    title: widget.store == null ? 'Thêm chi nhánh' : 'Chỉnh sửa chi nhánh',
    saving: _saving || _gps,
    actions: [
      OutlinedButton(
        onPressed: _saving || _gps ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _saving || _gps ? null : _save,
        child: Text(_saving ? 'Đang lưu…' : 'Lưu chi nhánh'),
      ),
    ],
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            InlineNotice(_error!, error: true),
            const SizedBox(height: 16),
          ],
          Text(
            'Thông tin chung',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _code,
            enabled: !_saving,
            validator: _required,
            decoration: const InputDecoration(
              labelText: 'Mã chi nhánh',
              hintText: 'VD: CAFE-HCM01',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            enabled: !_saving,
            validator: _required,
            decoration: const InputDecoration(labelText: 'Tên chi nhánh'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _capacity,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            validator: (s) =>
                int.tryParse(s?.trim() ?? '') == null ||
                    int.parse(s!.trim()) < 1
                ? 'Nhập số nguyên lớn hơn 0'
                : null,
            decoration: const InputDecoration(labelText: 'Số nhân viên tối đa'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Trạng thái'),
            items: const [
              DropdownMenuItem(value: 'ACTIVE', child: Text('Hoạt động')),
              DropdownMenuItem(value: 'MAINTENANCE', child: Text('Bảo trì')),
              DropdownMenuItem(value: 'CLOSED', child: Text('Ngừng hoạt động')),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _status = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _manager,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Người quản lý'),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('Chưa bổ nhiệm'),
              ),
              ...widget.users
                  .where((u) => u['role'] == 'MANAGER' || u['id'] == _manager)
                  .map(
                    (u) => DropdownMenuItem<int>(
                      value: u['id'],
                      child: Text(
                        u['name'] ?? '—',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _manager = value),
          ),
          const SizedBox(height: 28),
          Text(
            'Vị trí chấm công',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FormField<LatLng>(
            key: _locationField,
            initialValue: _initialLocation,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (point) => point == null
                ? 'Vui lòng chọn vị trí quán trên bản đồ hoặc lấy vị trí hiện tại.'
                : null,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StoreLocationPicker(
                  value: field.value,
                  onChanged: field.didChange,
                  locationService: widget.locationService,
                  onLocatingChanged: (value) => setState(() => _gps = value),
                  radius: double.tryParse(_radius.text.trim()) ?? 0,
                  enabled: !_saving,
                  tileProvider: widget.mapTileProvider,
                ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      field.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _radius,
            enabled: !_saving,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            validator: (s) =>
                int.tryParse(s?.trim() ?? '') == null ||
                    int.parse(s!.trim()) < 1
                ? 'Nhập bán kính nguyên lớn hơn 0'
                : null,
            decoration: const InputDecoration(
              labelText: 'Bán kính cho phép (m)',
            ),
          ),
        ],
      ),
    ),
  );
}
