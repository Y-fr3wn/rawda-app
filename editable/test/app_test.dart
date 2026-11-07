import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:rawda/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const userId = '11111111-1111-4111-8111-111111111111';
  final user = {
    'id': userId,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'test@example.invalid',
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': {'provider': 'email'},
    'user_metadata': <String, dynamic>{'display_name': 'يوسف'},
  };
  late SharedPreferences prefs;
  bool delayBootstrap = false;
  Completer<void>? bootstrapRelease;
  List<dynamic> events = [];
  Map<dynamic, dynamic>? nextPayload;
  setUpAll(() async {
    tzdata.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // The Android app-links plugin has no native implementation in widget tests.
    // Accept event stream subscriptions without masking genuine UI failures.
    final testMessenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    testMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.app_links/events'),
      (call) async => null,
    );
    testMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.app_links/messages'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'schedule') {
            events = List<dynamic>.from(
              (call.arguments as Map)['events'] as List,
            );
            return null;
          }
          if (call.method == 'prayerNotifications') {
            nextPayload = Map<dynamic, dynamic>.from(call.arguments as Map);
            return null;
          }
          if (call.method == 'pickImage') {
            return base64Encode(File('assets/logo.png').readAsBytesSync());
          }
          if (call.method == 'status') {
            return {
              'exact': true,
              'notifications': true,
              'count': events.length,
            };
          }
          return null;
        });
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-public-key',
      httpClient: MockClient((r) async {
        dynamic data = {};
        if (r.url.path.endsWith('/user')) data = user;
        if (r.url.path.endsWith('/rawda_bootstrap')) {
          if (delayBootstrap) await bootstrapRelease!.future;
          data = {
            'profile': {
              'id': userId,
              'display_name': 'عضو الروضة',
              'leaderboard_opt_in': false,
            },
            'wallet': {'balance': 10, 'earned': 10},
            'state': <String, dynamic>{},
            'redemptions': [],
            'rewards': [],
          };
        }
        if (r.url.path.endsWith('/rawda_claim_activity')) {
          data = {'awarded': 0, 'balance': 10};
        }
        if (r.url.path.endsWith('/rawda_daily_quiz')) data = [];
        return http.Response(
          jsonEncode(data),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final name in ['RawdaArabic', 'RawdaLatin', 'Quran']) {
      final file = {
        'RawdaArabic': 'NotoSansArabic.ttf',
        'RawdaLatin': 'Inter.ttf',
        'Quran': 'AmiriQuran-Regular.ttf',
      }[name]!;
      final loader = FontLoader(name)..addFont(rootBundle.load('assets/$file'));
      await loader.load();
    }
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
  });
  Future<RawdaState> boot(WidgetTester t) async {
    t.view.reset();
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(Rawda(prefs: prefs));
    await t.pumpAndSettle();
    final a = t.state<RawdaState>(find.byType(Rawda));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 100));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      if (a.chapters.isNotEmpty && (!a.signed || a.ready)) break;
    }
    await t.pumpAndSettle();
    debugPrint(
      'BOOT books=${a.chapters.length} ready=${a.ready} signed=${a.signed} problem=${a.problem}',
    );
    return a;
  }

  Future<void> screenshot(WidgetTester t, String file) async {
    final element = find.byType(Scaffold).last;
    final render = t.renderObject<RenderObject>(element);
    RenderObject? node = render;
    while (node != null && node is! RenderRepaintBoundary) {
      node = node.parent;
    }
    if (node is RenderRepaintBoundary) {
      final boundary = node;
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('test-results').create(recursive: true);
        await File(
          'test-results/$file.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
  }

  test('Corrupt local cache cannot crash parsing', () {
    final parsed = parseQuranIndex('1|1|بِسْمِ اللَّهِ');
    expect(parsed.single['search'], 'بسم الله');
    expect(parsed.single['text'], 'بِسْمِ اللَّهِ');
    expect(safeMap('{broken'), isEmpty);
    expect(safeMap('[1,2]'), isEmpty);
    expect(safeMap('{"clock24":true}')['clock24'], true);
    expect(safeCalendar('{broken'), isEmpty);
    expect(safeCalendar('[1, null, {"timings":{},"date":{}}]').length, 0);
    final row = {
      'timings': {for (final k in prayerKeys) k: '2026-11-06T12:00:00+02:00'},
      'date': {
        'gregorian': {},
        'hijri': {'month': {}},
      },
    };
    expect(safeCalendar(jsonEncode([row])).length, 1);
  });
  testWidgets('Offline Quran, prayer scheduling and signed-in phone UI', (
    t,
  ) async {
    {
      final a = await boot(t);
      a.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(a.clock!.isActive, false);
      a.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(a.clock!.isActive, true);
      expect(a.chapters.length, 114);
      expect(a.verses.length, 6236);
      expect(a.verses.where((v) => v['surah'] == 1).length, 7);
      await t.tap(find.widgetWithText(FilledButton, 'دخول'));
      await t.pump();
      expect(find.textContaining('٨ أحرف'), findsOneWidget);
      await screenshot(t, 'login');
      a.openQuran();
      await t.pumpAndSettle();
      expect(find.text('القرآن الكريم'), findsOneWidget);
      a.openSurah(112);
      await t.pumpAndSettle();
      expect(find.textContaining('قُلْ هُوَ'), findsOneWidget);
      expect(t.takeException(), isNull);
      await screenshot(t, 'quran');
      a.nav.currentState!.popUntil((r) => r.isFirst);
      await t.pumpAndSettle();
      a.openSurah(2, initialAyah: 200);
      await t.pumpAndSettle();
      expect(find.textContaining('﴿200﴾'), findsOneWidget);
      expect(find.textContaining('﴿1﴾'), findsNothing);
      expect(t.takeException(), isNull);
      await screenshot(t, 'quran-deep-reading');
      a.nav.currentState!.pop();
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
    }
    {
      final a = await boot(t);
      final base = DateTime.now().add(const Duration(days: 1));
      a.calendar = [
        {
          'timings': {
            for (var i = 0; i < 5; i++)
              prayerKeys[i]: base.add(Duration(hours: i * 2)).toIso8601String(),
          },
          'date': {
            'hijri': {
              'month': {'number': 1},
            },
          },
        },
      ];
      a.config = {'alerts': true, 'volumeFajr': 0.35};
      await a.schedule();
      expect(events.length, 15);
      final parsed = a.upcoming.first['at'];
      expect(identical(parsed, a.upcoming.first['at']), true);
      expect(
        events
            .where((e) => e['prayer'] == 0 && e['kind'] != 'iqama')
            .every((e) => e['volume'] == 0.35),
        isTrue,
      );
      expect(
        events.where((e) => e['prayer'] == 1).every((e) => e['volume'] == 1.0),
        isTrue,
      );
      expect(events.where((e) => e['audio'] == true).length, 10);
      expect(
        events.every(
          (e) => (e['at'] as int) > DateTime.now().millisecondsSinceEpoch,
        ),
        isTrue,
      );
      expect(events.where((e) => e['kind'] == 'prayer').length, 5);
      final iqamaEvents = events.where((e) => e['kind'] == 'iqama').toList();
      expect(iqamaEvents.length, 5);
      expect(
        iqamaEvents.every(
          (e) =>
              e['sound'] == 'iqama' &&
              e['short'] == false &&
              e['title'].toString().startsWith('قد قامت الصلاة'),
        ),
        isTrue,
      );
      expect(
        iqamaEvents.first['at'] -
            (events.firstWhere(
                  (e) => e['kind'] == 'prayer' && e['prayer'] == 0,
                )['at']
                as int),
        15 * 60 * 1000,
      );
      a.config['iqamaAudio'] = false;
      await a.schedule();
      expect(events.where((e) => e['audio'] == true).length, 5);
      expect(
        events
            .where((e) => e['kind'] == 'iqama')
            .every((e) => e['audio'] == false),
        isTrue,
      );
      a.config['iqamaAudio'] = true;
      a.config['iqamaSound'] = 'silent';
      await a.schedule();
      expect(
        events
            .where((e) => e['kind'] == 'iqama')
            .every((e) => e['audio'] == false),
        isTrue,
      );
      a.config['iqamaSound'] = 'iqama';
      a.config['enabledFajr'] = false;
      await a.schedule();
      expect(events.length, 12);
      a.config['alerts'] = false;
      await a.schedule();
      expect(events, isEmpty);
      expect((nextPayload!['prayers'] as List).length, 5);
      expect((nextPayload!['options'] as Map)['ongoing'], true);
      a.config['ongoingNotification'] = false;
      await a.schedule();
      expect((nextPayload!['options'] as Map)['ongoing'], false);
      await t.pumpWidget(const SizedBox());
    }
    {
      String encode(Map<String, dynamic> value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final token =
          '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': userId, 'role': 'authenticated', 'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000})}.test-signature';
      await Supabase.instance.client.auth.recoverSession(
        jsonEncode({
          'access_token': token,
          'refresh_token': 'test-only',
          'expires_in': 3600,
          'token_type': 'bearer',
          'user': user,
        }),
      );
      debugPrint(
        'SESSION expired=${Supabase.instance.client.auth.currentSession?.isExpired}',
      );
      final a = await boot(t);
      await t.pumpAndSettle();
      expect(find.text('أهلًا بك في الروضة'), findsOneWidget);
      expect(a.account['profile']['display_name'], 'يوسف');
      await screenshot(t, 'home');
      a.push('تدريب', (_) => PracticeScreen(app: a));
      await t.pumpAndSettle();
      expect(find.textContaining('بلا نقاط'), findsOneWidget);
      expect(t.takeException(), isNull);
      await screenshot(t, 'practice');
      a.nav.currentState!.pop();
      await t.pumpAndSettle();
      a.openQuran();
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'الكوثر');
      await t.pumpAndSettle();
      expect(find.text('سورة الكوثر'), findsOneWidget);
      expect(t.takeException(), isNull);
      a.nav.currentState!.popUntil((r) => r.isFirst);
      await t.pumpAndSettle();
      a.mutate(() {
        a.now = DateTime(2026, 11, 6, 10);
        a.config = {'alerts': false, 'city': 'الإسكندرية'};
        a.calendar = [
          {
            'timings': {
              for (var i = 0; i < 5; i++)
                prayerKeys[i]: DateTime(
                  2026,
                  11,
                  6,
                  [5, 12, 15, 17, 19][i],
                ).toIso8601String(),
            },
            'meta': {'timezone': 'Africa/Cairo'},
            'date': {
              'gregorian': {
                'date': '06-11-2026',
                'day': '06',
                'year': '2026',
                'month': {'number': 11},
              },
              'hijri': {
                'day': '26',
                'month': {'number': 5, 'ar': 'جمادى الأولى', 'en': 'Jumada I'},
                'year': '1448',
              },
            },
          },
        ];
      });
      await t.pump();
      await screenshot(t, 'home-with-times');
      // The refreshed UI uses a horizontally scrolling prayer strip.
      expect(find.byKey(const Key('rawda-prayer-strip')), findsOneWidget);
      expect(find.text('مواقيت الصلاة'), findsWidgets);
      expect(a.today!['timings'].containsKey('Isha'), isTrue);
      expect(a.config['alerts'], false);
      expect(t.takeException(), isNull);
      await screenshot(t, 'prayers-disabled');
      a.mutate(() => a.page = 4);
      await t.pumpAndSettle();
      expect(find.text('تعديل بيانات الحساب'), findsOneWidget);
      await screenshot(t, 'profile');
      a.editProfile();
      await t.pumpAndSettle();
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));
      await t.enterText(fields.at(1), '01000000000');
      await t.enterText(fields.at(2), 'عنوان تجريبي');
      await t.ensureVisible(find.text('حفظ البيانات'));
      await t.tap(find.text('حفظ البيانات'));
      await t.pumpAndSettle();
      expect(a.state['phone'], '01000000000');
      expect(a.state['address'], 'عنوان تجريبي');
      await a.pickProfilePhoto();
      await t.pumpAndSettle();
      expect(a.profilePhoto, isA<MemoryImage>());
      a.clearNotice();
      a.toast('رسالة تجريبية');
      await t.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('رسالة تجريبية'), findsOneWidget);
      a.clearNotice();
      a.openPrayerMonth();
      await t.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(t.takeException(), isNull);
      await screenshot(t, 'monthly');
      a.nav.currentState!.pop();
      await t.pumpAndSettle();
      a.openPrayerNotifications();
      await t.pumpAndSettle();
      expect(find.text('إشعار الصلاة القادمة'), findsOneWidget);
      await screenshot(t, 'notification-settings');
      a.nav.currentState!.pop();
      await t.pumpAndSettle();
      a.openAudio();
      await t.pumpAndSettle();
      expect(find.byType(Slider), findsWidgets);
      expect(t.takeException(), isNull);
      await screenshot(t, 'audio');
      a.nav.currentState!.pop();
      await t.pumpAndSettle();
      a.openTracker();
      await t.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsWidgets);
      expect(t.takeException(), isNull);
      await screenshot(t, 'tracker');
      a.nav.currentState!.pop();
      await t.pumpAndSettle();
      a.mutate(() => a.isAdmin = true);
      a.openAdmin();
      await t.pumpAndSettle();
      expect(find.text('لوحة تحكمك'), findsOneWidget);
      expect(t.takeException(), isNull);
      await screenshot(t, 'admin');
      a.nav.currentState!.pop();
      await t.pumpAndSettle();
      a.mutate(() => a.page = 0);
      t.view.physicalSize = const Size(320, 720);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      a.mutate(() => a.dark = true);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await screenshot(t, 'home-dark-small');
      delayBootstrap = true;
      bootstrapRelease = Completer<void>();
      var refreshFinished = false;
      unawaited(a.refreshWallet().whenComplete(() => refreshFinished = true));
      await t.pump();
      await t.runAsync(() => Supabase.instance.client.auth.signOut());
      await t.pumpAndSettle();
      bootstrapRelease!.complete();
      for (var i = 0; i < 10 && !refreshFinished; i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      expect(refreshFinished, true);
      expect(a.signed, false);
      expect(a.account, isEmpty);
      expect(prefs.containsKey('account:'), false);
      delayBootstrap = false;
      await t.pumpWidget(const SizedBox());
    }
  });
}
