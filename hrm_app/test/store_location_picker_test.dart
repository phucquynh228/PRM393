import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hrm_app/core/services/location_service.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/presentation/screens/admin/dialogs/store_form_dialog.dart';
import 'package:hrm_app/presentation/widgets/store_location_picker.dart';
import 'package:latlong2/latlong.dart';

import 'visual_smoke_test.dart' show preview;

class MemoryTiles extends TileProvider {
  final image = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      image;
}

class PickerLocationService extends LocationService {
  Object? error;
  Completer<Position>? pending;
  int calls = 0;
  bool? rejectedMock;
  @override
  Future<Position> getCurrentPosition({bool rejectMocked = true}) async {
    calls++;
    rejectedMock = rejectMocked;
    if (error != null) throw error!;
    return pending?.future ??
        Position(
          latitude: 10.8412345,
          longitude: 106.8098765,
          timestamp: DateTime(2026, 10, 22),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
  }
}

const originalPoint = LatLng(10.7769123, 106.7009456);

Widget picker(
  PickerLocationService location, {
  LatLng? initial = originalPoint,
  ValueChanged<LatLng>? onChanged,
  ValueChanged<bool>? onLocatingChanged,
}) {
  LatLng? selected = initial;
  final tiles = MemoryTiles();
  return Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setState) => StoreLocationPicker(
            value: selected,
            onChanged: (p) {
              setState(() => selected = p);
              onChanged?.call(p);
            },
            locationService: location,
            onLocatingChanged: onLocatingChanged ?? (_) {},
            tileProvider: tiles,
          ),
        ),
      ),
    ),
  );
}

Future<void> mount(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: child));

Map<String, dynamic> store({bool withLocation = true}) => {
  'code': 'CN-01',
  'name': 'Cafe Thủ Đức',
  'allowedRadius': 200,
  'maxStaff': 15,
  'status': 'ACTIVE',
  if (withLocation) 'latitude': originalPoint.latitude,
  if (withLocation) 'longitude': originalPoint.longitude,
};

Widget form(
  PickerLocationService location, {
  required Future<void> Function(Map<String, dynamic>) save,
  bool withLocation = true,
}) => Scaffold(
  body: Builder(
    builder: (context) => TextButton(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => StoreFormDialog(
          store: store(withLocation: withLocation),
          users: const [],
          locationService: location,
          mapTileProvider: MemoryTiles(),
          onSubmit: save,
          showSnackBar: (_, {isError = false}) {},
        ),
      ),
      child: const Text('Mở form'),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await (FontLoader(
      'HRMSans',
    )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'dragging the pin changes the store point without panning the map',
    (tester) async {
      LatLng? selected;
      await mount(
        tester,
        picker(PickerLocationService(), onChanged: (p) => selected = p),
      );
      await tester.pumpAndSettle();
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final center = map.camera.center;
      await tester.drag(
        find.byKey(const Key('store-location-pin')),
        const Offset(60, 30),
      );
      await tester.pumpAndSettle();
      expect(selected, isNotNull);
      expect(selected!.longitude, greaterThan(originalPoint.longitude));
      expect(selected!.latitude, lessThan(originalPoint.latitude));
      expect(map.camera.center, center);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'panning keeps selected coordinates; tapping selects a new point',
    (tester) async {
      LatLng? selected;
      await mount(
        tester,
        picker(PickerLocationService(), onChanged: (p) => selected = p),
      );
      await tester.pumpAndSettle();
      final map = find.byKey(const Key('store-location-map'));
      final origin = tester.getTopLeft(map);
      await tester.dragFrom(
        origin + const Offset(45, 65),
        const Offset(55, 20),
      );
      await tester.pumpAndSettle();
      expect(selected, isNull);
      await tester.tapAt(origin + const Offset(65, 200));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(selected, isNotNull);
    },
  );

  testWidgets('GPS centers the map and preserves full precision for saving', (
    tester,
  ) async {
    final service = PickerLocationService();
    LatLng? selected;
    final busy = <bool>[];
    await mount(
      tester,
      picker(
        service,
        onChanged: (p) => selected = p,
        onLocatingChanged: busy.add,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lấy vị trí hiện tại'));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(service.rejectedMock, false);
    expect(busy, [true, false]);
    expect(selected, const LatLng(10.8412345, 106.8098765));
    final map = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    expect(map.camera.center, selected);
    expect(map.camera.zoom, 18);
  });

  testWidgets(
    'GPS permission failure keeps the selected location and permits retry',
    (tester) async {
      final service = PickerLocationService()
        ..error = Exception('Chưa có quyền vị trí');
      LatLng? selected;
      await mount(tester, picker(service, onChanged: (p) => selected = p));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lấy vị trí hiện tại'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.text('Chưa có quyền vị trí'), findsOneWidget);
      expect(find.textContaining('10.7769123'), findsOneWidget);
      service.error = null;
      await tester.tap(find.text('Lấy vị trí hiện tại'));
      await tester.pumpAndSettle();
      expect(service.calls, 2);
      expect(selected, isNotNull);
    },
  );

  testWidgets(
    'manual coordinates reject non-finite values and can move the pin',
    (tester) async {
      LatLng? selected;
      await mount(
        tester,
        picker(PickerLocationService(), onChanged: (p) => selected = p),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhập tọa độ thủ công'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextField, 'Vĩ độ'));
      await tester.enterText(find.widgetWithText(TextField, 'Vĩ độ'), 'NaN');
      await tester.ensureVisible(find.text('Áp dụng tọa độ'));
      await tester.tap(find.text('Áp dụng tọa độ'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.textContaining('Nhập vĩ độ từ'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(TextField, 'Vĩ độ'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Vĩ độ'),
        '21,028511',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Kinh độ'),
        '105.804817',
      );
      await tester.ensureVisible(find.text('Áp dụng tọa độ'));
      await tester.tap(find.text('Áp dụng tọa độ'));
      await tester.pumpAndSettle();
      expect(selected!.latitude, closeTo(21.028511, 1e-9));
      expect(selected!.longitude, closeTo(105.804817, 1e-9));
    },
  );

  testWidgets(
    'edit form saves dragged coordinates and never saves a map preview center',
    (tester) async {
      Map<String, dynamic>? saved;
      await mount(
        tester,
        form(PickerLocationService(), save: (data) async => saved = data),
      );
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('store-location-map')));
      await tester.drag(
        find.byKey(const Key('store-location-pin')),
        const Offset(40, 20),
      );
      await tester.pumpAndSettle();
      final selected = tester
          .widget<StoreLocationPicker>(find.byType(StoreLocationPicker))
          .value!;
      await tester.tap(find.text('Lưu chi nhánh'));
      await tester.pumpAndSettle();
      expect(saved?['latitude'], selected.latitude);
      expect(saved?['longitude'], selected.longitude);
      expect(saved?['allowedRadius'], 200);

      saved = null;
      await mount(
        tester,
        form(
          PickerLocationService(),
          withLocation: false,
          save: (data) async => saved = data,
        ),
      );
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu chi nhánh'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('Vui lòng chọn vị trí quán'), findsOneWidget);
    },
  );

  testWidgets('store-location-phone-large-text', (tester) async {
    await preview(
      tester,
      picker(PickerLocationService()),
      const Size(320, 740),
      'store-location-phone-large-text',
      scale: 1.6,
    );
    expect(tester.takeException(), isNull);
  });
}
