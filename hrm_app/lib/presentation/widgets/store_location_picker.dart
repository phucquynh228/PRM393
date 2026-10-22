import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../screens/employee/request_form.dart' show requestError;
import 'content_widgets.dart';

/// A controlled picker: moving the map never silently changes the store point.
class StoreLocationPicker extends StatefulWidget {
  final LatLng? value;
  final ValueChanged<LatLng> onChanged;
  final LocationService locationService;
  final ValueChanged<bool> onLocatingChanged;
  final double radius;
  final bool enabled;
  final TileProvider? tileProvider;

  const StoreLocationPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.locationService,
    required this.onLocatingChanged,
    this.radius = 200,
    this.enabled = true,
    this.tileProvider,
  });

  @override
  State<StoreLocationPicker> createState() => _StoreLocationPickerState();
}

class _StoreLocationPickerState extends State<StoreLocationPicker> {
  static const _defaultCenter = LatLng(10.7769, 106.7009);
  final _map = MapController();
  final _tileReset = StreamController<void>.broadcast();
  late final TileProvider _tiles;
  late final TextEditingController _lat, _lng;
  bool _locating = false, _tileError = false, _tileErrorQueued = false;
  String? _error;
  LatLng? _dragPoint;
  Offset? _dragStartGlobal, _dragStartScreen;

  bool get _enabled => widget.enabled && !_locating;

  @override
  void initState() {
    super.initState();
    _tiles = widget.tileProvider ?? NetworkTileProvider();
    _lat = TextEditingController();
    _lng = TextEditingController();
    _syncCoordinates();
  }

  @override
  void didUpdateWidget(StoreLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _syncCoordinates();
  }

  void _syncCoordinates() {
    _lat.text = widget.value?.latitude.toStringAsFixed(7) ?? '';
    _lng.text = widget.value?.longitude.toStringAsFixed(7) ?? '';
  }

  @override
  void dispose() {
    _map.dispose();
    _tileReset.close();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _select(LatLng point, {bool recenter = false}) {
    if (!_enabled) return;
    // Normalize longitudes when the user pans past the international date line.
    final normalized = LatLng(
      point.latitude.clamp(-90.0, 90.0),
      (point.longitude + 180) % 360 - 180,
    );
    setState(() => _error = null);
    widget.onChanged(normalized);
    if (recenter) _map.move(normalized, 18);
  }

  Future<void> _getCurrentLocation() async {
    if (!_enabled) return;
    setState(() {
      _locating = true;
      _error = null;
    });
    widget.onLocatingChanged(true);
    try {
      // A store coordinate is editable anyway. Attendance still rejects mock
      // positions through LocationService's default rejectMocked: true.
      final position = await widget.locationService.getCurrentPosition(
        rejectMocked: false,
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude.abs() > 90 ||
          point.longitude.abs() > 180) {
        throw Exception('Tọa độ GPS không hợp lệ. Vui lòng thử lại.');
      }
      widget.onChanged(point);
      _map.move(point, 18);
    } catch (e) {
      if (mounted) setState(() => _error = requestError(e));
    } finally {
      if (mounted) {
        setState(() => _locating = false);
        widget.onLocatingChanged(false);
      }
    }
  }

  void _applyCoordinates() {
    final lat = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(_lng.text.trim().replaceAll(',', '.'));
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      setState(
        () => _error = 'Nhập vĩ độ từ −90 đến 90 và kinh độ từ −180 đến 180.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    _select(LatLng(lat, lng), recenter: true);
  }

  void _showTileError() {
    if (!mounted || _tileError || _tileErrorQueued) return;
    _tileErrorQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tileErrorQueued = false;
      if (mounted) setState(() => _tileError = true);
    });
  }

  void _zoom(double delta) => _map.move(
    _map.camera.center,
    (_map.camera.zoom + delta).clamp(3.0, 20.0),
  );

  void _startPinDrag(DragStartDetails details) {
    _dragStartGlobal = details.globalPosition;
    _dragStartScreen = _map.camera.latLngToScreenOffset(
      widget.value ?? _defaultCenter,
    );
  }

  void _updatePinDrag(DragUpdateDetails details) {
    if (_dragStartGlobal == null || _dragStartScreen == null) return;
    _dragPoint = _map.camera.screenOffsetToLatLng(
      _dragStartScreen! + details.globalPosition - _dragStartGlobal!,
    );
    _select(_dragPoint!);
  }

  void _endPinDrag() {
    _dragPoint = null;
    _dragStartGlobal = _dragStartScreen = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = widget.value ?? _defaultCenter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Chạm lên bản đồ hoặc kéo ghim đến đúng vị trí của quán.'),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 280,
            child: Stack(
              children: [
                FlutterMap(
                  key: const Key('store-location-map'),
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: widget.value == null ? 13 : 18,
                    minZoom: 3,
                    maxZoom: 20,
                    backgroundColor: AppColors.surfaceVariant,
                    interactionOptions: InteractionOptions(
                      flags: _enabled
                          ? InteractiveFlag.all & ~InteractiveFlag.rotate
                          : InteractiveFlag.none,
                    ),
                    onTap: _enabled ? (_, p) => _select(p) : null,
                  ),
                  children: [
                    TileLayer(
                      reset: _tileReset.stream,
                      urlTemplate: const String.fromEnvironment(
                        'MAP_TILE_URL',
                        defaultValue:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      userAgentPackageName: 'com.example.hrm_app',
                      maxNativeZoom: 19,
                      tileProvider: _tiles,
                      errorTileCallback: (_, __, ___) => _showTileError(),
                    ),
                    if (widget.value != null &&
                        widget.radius.isFinite &&
                        widget.radius > 0)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: point,
                            radius: widget.radius,
                            useRadiusInMeter: true,
                            color: AppColors.primary.withValues(alpha: .12),
                            borderColor: AppColors.primary.withValues(
                              alpha: .65,
                            ),
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 56,
                          height: 56,
                          alignment: Alignment.topCenter,
                          child: Semantics(
                            label: 'Ghim vị trí chi nhánh, kéo để thay đổi',
                            child: GestureDetector(
                              key: const Key('store-location-pin'),
                              behavior: HitTestBehavior.opaque,
                              dragStartBehavior: DragStartBehavior.down,
                              // Axis recognizers win against the map's own drag
                              // recognizers; use global pointer positions to retain
                              // both dimensions when dragging diagonally.
                              onHorizontalDragStart: _enabled
                                  ? _startPinDrag
                                  : null,
                              onHorizontalDragUpdate: _enabled
                                  ? _updatePinDrag
                                  : null,
                              onHorizontalDragEnd: _enabled
                                  ? (_) => _endPinDrag()
                                  : null,
                              onHorizontalDragCancel: _endPinDrag,
                              onVerticalDragStart: _enabled
                                  ? _startPinDrag
                                  : null,
                              onVerticalDragUpdate: _enabled
                                  ? _updatePinDrag
                                  : null,
                              onVerticalDragEnd: _enabled
                                  ? (_) => _endPinDrag()
                                  : null,
                              onVerticalDragCancel: _endPinDrag,
                              child: Icon(
                                Icons.location_on,
                                size: 56,
                                color: widget.value == null
                                    ? AppColors.textSecondary
                                    : AppColors.primary,
                                shadows: const [
                                  Shadow(color: Colors.white, blurRadius: 5),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: theme.colorScheme.surface,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Phóng to bản đồ',
                          onPressed: _enabled ? () => _zoom(1) : null,
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          tooltip: 'Thu nhỏ bản đồ',
                          onPressed: _enabled ? () => _zoom(-1) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip: 'Về ghim đã chọn',
                          onPressed: _enabled && widget.value != null
                              ? () => _map.move(widget.value!, 18)
                              : null,
                          icon: const Icon(Icons.location_searching),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Material(
                      color: theme.colorScheme.surface.withValues(alpha: .95),
                      child: InkWell(
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            '© OpenStreetMap contributors',
                            style: theme.textTheme.bodySmall,
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
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            widget.value == null
                ? 'Chưa chọn vị trí chi nhánh'
                : 'Đã chọn: ${point.latitude.toStringAsFixed(7)}, ${point.longitude.toStringAsFixed(7)}',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _enabled ? _getCurrentLocation : null,
          icon: _locating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          label: Text(_locating ? 'Đang lấy vị trí…' : 'Lấy vị trí hiện tại'),
        ),
        const SizedBox(height: 6),
        Text(
          'Đang ở quán? Lấy GPS rồi kéo ghim để căn lại vị trí.',
          style: theme.textTheme.bodySmall,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          InlineNotice(_error!, error: true),
        ],
        if (_tileError) ...[
          const SizedBox(height: 12),
          const InlineNotice(
            'Chưa tải được bản đồ. Kiểm tra kết nối mạng hoặc nhập tọa độ thủ công.',
          ),
          TextButton.icon(
            onPressed: () {
              setState(() => _tileError = false);
              _tileReset.add(null);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại bản đồ'),
          ),
        ],
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Nhập tọa độ thủ công'),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            TextField(
              controller: _lat,
              enabled: _enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Vĩ độ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lng,
              enabled: _enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Kinh độ'),
              onSubmitted: (_) {
                if (_enabled) _applyCoordinates();
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Bấm Áp dụng tọa độ để cập nhật ghim trước khi lưu.',
              style: theme.textTheme.bodySmall,
            ),
            OutlinedButton(
              onPressed: _enabled ? _applyCoordinates : null,
              child: const Text('Áp dụng tọa độ'),
            ),
          ],
        ),
      ],
    );
  }
}
