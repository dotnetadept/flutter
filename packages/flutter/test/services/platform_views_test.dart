// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_platform_views.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android', () {
    late FakeAndroidPlatformViewsController viewsController;
    setUp(() {
      viewsController = FakeAndroidPlatformViewsController();
    });

    test('create Android view of unregistered type', () async {
      expect(
        () {
          return PlatformViewsService.initAndroidView(
            id: 0,
            viewType: 'web',
            layoutDirection: TextDirection.ltr,
          ).setSize(const Size(100.0, 100.0));
        },
        throwsA(isA<PlatformException>()),
      );

      expect(
        () {
          return PlatformViewsService.initSurfaceAndroidView(
            id: 0,
            viewType: 'web',
            layoutDirection: TextDirection.ltr,
          ).create();
        },
        throwsA(isA<PlatformException>()),
      );
    });

    test('create Android views', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initAndroidView(id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr)
          .setSize(const Size(100.0, 100.0));
      await PlatformViewsService.initAndroidView( id: 1, viewType: 'webview', layoutDirection: TextDirection.rtl)
          .setSize(const Size(200.0, 300.0));
      await PlatformViewsService.initSurfaceAndroidView(id: 2, viewType: 'webview', layoutDirection: TextDirection.rtl).create();
      expect(
        viewsController.views,
        unorderedEquals(<FakeAndroidPlatformView>[
          const FakeAndroidPlatformView(0, 'webview', Size(100.0, 100.0), AndroidViewController.kAndroidLayoutDirectionLtr, null),
          const FakeAndroidPlatformView(1, 'webview', Size(200.0, 300.0), AndroidViewController.kAndroidLayoutDirectionRtl, null),
          const FakeAndroidPlatformView(2, 'webview', null, AndroidViewController.kAndroidLayoutDirectionRtl, true),
        ]),
      );
    });

    test('reuse Android view id', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      ).setSize(const Size(100.0, 100.0));
      expect(
        () => PlatformViewsService.initAndroidView(
          id: 0,
          viewType: 'web',
          layoutDirection: TextDirection.ltr,
        ).setSize(const Size(100.0, 100.0)),
        throwsA(isA<PlatformException>()),
      );

      await PlatformViewsService.initSurfaceAndroidView(
        id: 1,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      ).create();
      expect(
        () => PlatformViewsService.initSurfaceAndroidView(
          id: 1,
          viewType: 'web',
          layoutDirection: TextDirection.ltr,
        ).create(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('dispose Android view', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      ).setSize(const Size(100.0, 100.0));
      final AndroidViewController viewController =
          PlatformViewsService.initAndroidView(id: 1, viewType: 'webview', layoutDirection: TextDirection.ltr);
      await viewController.setSize(const Size(200.0, 300.0));
      await viewController.dispose();

      final AndroidViewController surfaceViewController = PlatformViewsService.initSurfaceAndroidView(id: 1, viewType: 'webview', layoutDirection: TextDirection.ltr);
      await surfaceViewController.create();
      await surfaceViewController.dispose();

      expect(
        viewsController.views,
        unorderedEquals(<FakeAndroidPlatformView>[
          const FakeAndroidPlatformView(0, 'webview', Size(100.0, 100.0), AndroidViewController.kAndroidLayoutDirectionLtr, null),
        ]),
      );
    });

    test('dispose inexisting Android view', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      ).setSize(const Size(100.0, 100.0));
      final AndroidViewController viewController =
          PlatformViewsService.initAndroidView(id: 1, viewType: 'webview', layoutDirection: TextDirection.ltr);
      await viewController.setSize(const Size(200.0, 300.0));
      await viewController.dispose();
      await viewController.dispose();
    });

    test('dispose clears focusCallbacks', () async {
      bool didFocus = false;
      viewsController.registerViewType('webview');
      final AndroidViewController viewController = PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
        onFocus: () { didFocus = true; },
      );
      await viewController.setSize(const Size(100.0, 100.0));
      await viewController.dispose();
      final ByteData message =
          SystemChannels.platform_views.codec.encodeMethodCall(const MethodCall('viewFocused', 0));
      await SystemChannels.platform_views.binaryMessenger.handlePlatformMessage(SystemChannels.platform_views.name, message, (_) { });
      expect(didFocus, isFalse);
    });

    test('resize Android view', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      ).setSize(const Size(100.0, 100.0));
      final AndroidViewController viewController =
          PlatformViewsService.initAndroidView(id: 1, viewType: 'webview', layoutDirection: TextDirection.ltr);
      await viewController.setSize(const Size(200.0, 300.0));
      await viewController.setSize(const Size(500.0, 500.0));
      expect(
        viewsController.views,
        unorderedEquals(<FakeAndroidPlatformView>[
          const FakeAndroidPlatformView(0, 'webview', Size(100.0, 100.0), AndroidViewController.kAndroidLayoutDirectionLtr, null),
          const FakeAndroidPlatformView(1, 'webview', Size(500.0, 500.0), AndroidViewController.kAndroidLayoutDirectionLtr, null),
        ]),
      );
    });

    test('OnPlatformViewCreated callback', () async {
      viewsController.registerViewType('webview');
      final List<int> createdViews = <int>[];
      void callback(int id) { createdViews.add(id); }

      final AndroidViewController controller1 = PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..addOnPlatformViewCreatedListener(callback);
      expect(createdViews, isEmpty);

      await controller1.setSize(const Size(100.0, 100.0));
      expect(createdViews, orderedEquals(<int>[0]));

      final AndroidViewController controller2 = PlatformViewsService.initAndroidView(
        id: 5,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..addOnPlatformViewCreatedListener(callback);
      expect(createdViews, orderedEquals(<int>[0]));

      await controller2.setSize(const Size(100.0, 200.0));
      expect(createdViews, orderedEquals(<int>[0, 5]));

    });

    test("change Android view's directionality before creation", () async {
      viewsController.registerViewType('webview');
      final AndroidViewController viewController =
      PlatformViewsService.initAndroidView(id: 0, viewType: 'webview', layoutDirection: TextDirection.rtl);
      await viewController.setLayoutDirection(TextDirection.ltr);
      await viewController.setSize(const Size(100.0, 100.0));
      expect(
        viewsController.views,
        unorderedEquals(<FakeAndroidPlatformView>[
          const FakeAndroidPlatformView(0, 'webview', Size(100.0, 100.0), AndroidViewController.kAndroidLayoutDirectionLtr, null),
        ]),
      );
    });

    test("change Android view's directionality after creation", () async {
      viewsController.registerViewType('webview');
      final AndroidViewController viewController =
      PlatformViewsService.initAndroidView(id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr);
      await viewController.setSize(const Size(100.0, 100.0));
      await viewController.setLayoutDirection(TextDirection.rtl);
      expect(
        viewsController.views,
        unorderedEquals(<FakeAndroidPlatformView>[
          const FakeAndroidPlatformView(0, 'webview', Size(100.0, 100.0), AndroidViewController.kAndroidLayoutDirectionRtl, null),
        ]),
      );
    });

    test('synchronizeToNativeViewHierarchy', () async {
      await PlatformViewsService.synchronizeToNativeViewHierarchy(false);
      expect(viewsController.synchronizeToNativeViewHierarchy, false);
    });
  });

  group('iOS', () {
    late FakeIosPlatformViewsController viewsController;
    setUp(() {
      viewsController = FakeIosPlatformViewsController();
    });

    test('create iOS view of unregistered type', () async {
      expect(
        () {
          return PlatformViewsService.initUiKitView(
            id: 0,
            viewType: 'web',
            layoutDirection: TextDirection.ltr,
          );
        },
        throwsA(isA<PlatformException>()),
      );
    });

    test('create iOS views', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initUiKitView(id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr);
      await PlatformViewsService.initUiKitView(id: 1, viewType: 'webview', layoutDirection: TextDirection.rtl);
      expect(
        viewsController.views,
        unorderedEquals(<FakeUiKitView>[
          const FakeUiKitView(0, 'webview'),
          const FakeUiKitView(1, 'webview'),
        ]),
      );
    });

    test('reuse iOS view id', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initUiKitView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      );
      expect(
        () => PlatformViewsService.initUiKitView(id: 0, viewType: 'web', layoutDirection: TextDirection.ltr),
        throwsA(isA<PlatformException>()),
      );
    });

    test('dispose iOS view', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initUiKitView(id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr);
      final UiKitViewController viewController = await PlatformViewsService.initUiKitView(
        id: 1,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      );

      viewController.dispose();
      expect(
        viewsController.views,
        unorderedEquals(<FakeUiKitView>[
          const FakeUiKitView(0, 'webview'),
        ]),
      );
    });

    test('dispose inexisting iOS view', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initUiKitView(id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr);
      final UiKitViewController viewController = await PlatformViewsService.initUiKitView(
        id: 1,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      );
      await viewController.dispose();
      expect(
        () async {
          await viewController.dispose();
        },
        throwsA(isA<PlatformException>()),
      );
    });
  });

  test('toString works as intended', () async {
    const AndroidPointerProperties androidPointerProperties = AndroidPointerProperties(id: 0, toolType: 0);
    expect(androidPointerProperties.toString(), 'AndroidPointerProperties(id: 0, toolType: 0)');

    const double zero = 0.0;
    const AndroidPointerCoords androidPointerCoords = AndroidPointerCoords(
      orientation: zero,
      pressure: zero,
      size: zero,
      toolMajor: zero,
      toolMinor: zero,
      touchMajor: zero,
      touchMinor: zero,
      x: zero,
      y: zero
    );
    expect(androidPointerCoords.toString(), 'AndroidPointerCoords(orientation: $zero, '
      'pressure: $zero, '
      'size: $zero, '
      'toolMajor: $zero, '
      'toolMinor: $zero, '
      'touchMajor: $zero, '
      'touchMinor: $zero, '
      'x: $zero, '
      'y: $zero)',
    );

    final AndroidMotionEvent androidMotionEvent = AndroidMotionEvent(
      downTime: 0,
      eventTime: 0,
      action: 0,
      pointerCount: 0,
      pointerProperties: <AndroidPointerProperties>[],
      pointerCoords: <AndroidPointerCoords>[],
      metaState: 0,
      buttonState: 0,
      xPrecision: zero,
      yPrecision: zero,
      deviceId: 0,
      edgeFlags: 0,
      source: 0,
      flags: 0,
      motionEventId: 0
    );
    expect(androidMotionEvent.toString(), 'AndroidPointerEvent(downTime: 0, '
      'eventTime: 0, '
      'action: 0, '
      'pointerCount: 0, '
      'pointerProperties: [], '
      'pointerCoords: [], '
      'metaState: 0, '
      'buttonState: 0, '
      'xPrecision: $zero, '
      'yPrecision: $zero, '
      'deviceId: 0, '
      'edgeFlags: 0, '
      'source: 0, '
      'flags: 0, '
      'motionEventId: 0)',
    );
  });

  group('Gtk', () {
    late FakeGtkPlatformViewsController viewsController;
    setUp(() {
      viewsController = FakeGtkPlatformViewsController();
    });

    test('create Gtk view of unregistered type', () async {
      expect(
        () {
          return PlatformViewsService.initGtkView(
            id: 0,
            viewType: 'unregistered_view_type',
            layoutDirection: TextDirection.ltr,
          );
        },
        throwsA(isA<PlatformException>()),
      );
    });

    test('create Gtk views', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initGtkView(
          id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr);
      await PlatformViewsService.initGtkView(
          id: 1, viewType: 'webview', layoutDirection: TextDirection.rtl);
      expect(
        viewsController.views,
        unorderedEquals(<FakeGtkView>[
          const FakeGtkView(0, 'webview', GtkViewController.kGtkTextDirectionLtr),
          const FakeGtkView(1, 'webview', GtkViewController.kGtkTextDirectionRtl),
        ]),
      );
    });

    test('reuse Gtk view id', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initGtkView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      );
      expect(
            () => PlatformViewsService.initGtkView(
            id: 0, viewType: 'web', layoutDirection: TextDirection.ltr),
        throwsA(isA<PlatformException>()),
      );
    });

    test('dispose Gtk view', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initGtkView(
          id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr);
      final GtkViewController viewController = await PlatformViewsService.initGtkView(
          id: 1, viewType: 'webview', layoutDirection: TextDirection.ltr);

      viewController.dispose();
      expect(
          viewsController.views,
          unorderedEquals(<FakeGtkView>[
            const FakeGtkView(0, 'webview', GtkViewController.kGtkTextDirectionLtr),
          ]));
    });

    test('dispose inexisting Gtk view', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initGtkView(id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr);
      final GtkViewController viewController = await PlatformViewsService.initGtkView(
          id: 1, viewType: 'webview', layoutDirection: TextDirection.ltr);
      await viewController.dispose();
      expect(
          () async {
            await viewController.dispose();
          },
          throwsA(isA<PlatformException>()),
      );
    });

    test("change Gtk GtkWidget's directionality", () async {
      viewsController.registerViewType('webview');
      final GtkViewController viewController = await PlatformViewsService.initGtkView(
          id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr);
      await viewController.setLayoutDirection(TextDirection.rtl);
      expect(
          viewsController.views,
          unorderedEquals(<FakeGtkView>[
            const FakeGtkView(0, 'webview', GtkViewController.kGtkTextDirectionRtl, null),
          ]));
    });
  });
}
