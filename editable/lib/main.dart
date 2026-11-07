import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_backend.dart';
import 'firebase_options.dart';
import 'quran_audio.dart';
import 'prayer_time_zone.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
part 'premium.dart';
part 'admin.dart';
part 'nusuk_ui.dart';
part 'refined_settings.dart';

const bridge = MethodChannel('com.rawda/native');
const sensors = EventChannel('com.rawda/compass');
const prayerKeys = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
const prayerArabic = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
Map<String, dynamic> obj(dynamic v) => Map<String, dynamic>.from(v as Map);
Map<String, dynamic> safeMap(String? raw) {
  try {
    final value = jsonDecode(raw ?? '{}');
    return value is Map ? obj(value) : {};
  } catch (_) {
    return {};
  }
}

List<dynamic> safeCalendar(String? raw) {
  try {
    final value = jsonDecode(raw ?? '[]');
    return value is List
        ? value
              .where(
                (r) =>
                    r is Map &&
                    r['timings'] is Map &&
                    r['date'] is Map &&
                    r['date']['gregorian'] is Map &&
                    r['date']['hijri'] is Map &&
                    r['date']['hijri']['month'] is Map &&
                    prayerKeys.every(
                      (k) => DateTime.tryParse('${r['timings'][k]}') != null,
                    ),
              )
              .toList()
        : [];
  } catch (_) {
    return [];
  }
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String plain(String s) => s
    .replaceAll(RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي');
List<Map<String, dynamic>> parseQuranIndex(String text) {
  final all = <Map<String, dynamic>>[];
  for (final line in const LineSplitter().convert(text)) {
    final parts = line.split('|');
    if (parts.length >= 3 && int.tryParse(parts[0]) != null) {
      all.add({
        'surah': int.parse(parts[0]),
        'ayah': int.parse(parts[1]),
        'text': parts.sublist(2).join('|'),
        'search': plain(parts.sublist(2).join('|')),
      });
    }
  }
  return all;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  LicenseRegistry.addLicense(() async* {
    for (final name in ['Noto', 'Inter', 'Amiri']) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/$name-OFL.txt'));
    }
  });
  final prefs = await SharedPreferences.getInstance();
  String? error;
  RawdaFirebaseBackend? firebase;
  const useFirebase = bool.fromEnvironment('RAWDA_USE_FIREBASE');
  try {
    if (useFirebase) {
      const emulatorHost = String.fromEnvironment('RAWDA_FIREBASE_EMULATOR');
      await Firebase.initializeApp(
        options: emulatorHost.isEmpty
            ? rawdaFirebaseOptions
            : const FirebaseOptions(
                apiKey: 'demo-key',
                appId: '1:1234567890:android:1234567890123456789012',
                messagingSenderId: '1234567890',
                projectId: 'demo-rawda',
              ),
      );
      final auth = firebase_auth.FirebaseAuth.instance;
      final store = FirebaseFirestore.instance;
      if (emulatorHost.isNotEmpty) {
        await auth.useAuthEmulator(emulatorHost, 9099);
        store.useFirestoreEmulator(emulatorHost, 8080);
      }
      firebase = RawdaFirebaseBackend(auth, store);
    } else {
      await Supabase.initialize(
        url: 'https://fqnactwixpfmgnulkbvt.supabase.co',
        anonKey: 'sb_publishable_JNm98zhJvVLTOAYuwBUsCQ_6hwXV75c',
      );
    }
  } catch (_) {
    error = 'تعذّر بدء الاتصال. افتح التطبيق مجددًا.';
  }
  runApp(Rawda(prefs: prefs, startError: error, firebase: firebase));
}

class Rawda extends StatefulWidget {
  const Rawda({super.key, required this.prefs, this.startError, this.firebase});
  final RawdaFirebaseBackend? firebase;
  final SharedPreferences prefs;
  final String? startError;
  @override
  State<Rawda> createState() => RawdaState();
}

class RawdaState extends State<Rawda> with WidgetsBindingObserver {
  final nav = GlobalKey<NavigatorState>();
  final messenger = GlobalKey<ScaffoldMessengerState>();
  late final SharedPreferences prefs = widget.prefs;
  SupabaseClient get db => Supabase.instance.client;
  bool ar = true, dark = false, ready = false, busy = false;
  int page = 2;
  String? problem;
  OverlayEntry? _noticeEntry;
  Timer? _noticeTimer;
  bool isAdmin = false;
  bool _adhanVisible = false;
  String? _lastAdhanTitle;
  List<dynamic> announcements = [], voices = [];
  String? quizProblem;
  bool quizLoading = false;
  Map<String, dynamic> account = {}, state = {}, config = {};
  List<dynamic> chapters = [], verses = [], calendar = [], quiz = [];
  String search = '';
  StreamSubscription<dynamic>? auth;
  RawdaFirebaseBackend? get firebase => widget.firebase;
  Timer? clock;
  final clockTick = ValueNotifier<DateTime>(DateTime.now());
  DateTime now = DateTime.now();
  DateTime clockNow() {
    // The location (not the phone's current UTC offset) owns prayer dates.
    // Africa/Cairo changes between UTC+2 and UTC+3 automatically.
    final zone = prayerClockZone(config, calendar);
    if (zone != null) {
      try {
        return tz.TZDateTime.now(tz.getLocation(zone));
      } catch (_) {
        // Invalid custom zone: keep the device clock usable.
      }
    }
    return DateTime.now();
  }

  bool _loadingAccount = false;
  bool _refreshingVerification = false;
  bool _deletionPending = false;
  int scheduled = 0;
  bool exact = false, notifications = false;
  String tr(String a, String e) => ar ? a : e;
  bool get signed {
    if (widget.startError != null) return false;
    final backend = firebase;
    if (backend == null) return db.auth.currentSession != null;
    final user = backend.auth.currentUser;
    return user != null && user.emailVerified && hasFirebaseConsent(user.uid);
  }

  bool hasFirebaseConsent(String owner) =>
      prefs.getBool(
        'firebase-consent:${RawdaFirebaseBackend.privacyVersion}:$owner',
      ) ==
      true;
  Future<void> saveFirebaseConsent(String owner) async {
    await prefs.setBool(
      'firebase-consent:${RawdaFirebaseBackend.privacyVersion}:$owner',
      true,
    );
  }

  Future<dynamic> rpc(String operation, {Map<String, dynamic>? params}) async {
    final backend = firebase;
    if (backend == null) return db.rpc(operation, params: params);
    final data = params ?? const <String, dynamic>{};
    switch (operation) {
      case 'rawda_bootstrap':
        return backend.bootstrap(privacyAccepted: hasFirebaseConsent(uid));
      case 'rawda_save_state':
        return backend.saveState(obj(data['p_data']));
      case 'rawda_claim_activity':
        return backend.claimActivity(data['p_activity'] as String);
      case 'rawda_daily_quiz':
        return backend.quiz();
      case 'rawda_answer_quiz':
        return backend.answer(
          '${data['p_question_id']}',
          data['p_selected_index'] as int,
          '${data['p_day']}',
        );
      case 'rawda_leaderboard':
        return backend.leaderboard();
      case 'rawda_weekly_challenge':
        return backend.weekly();
      case 'rawda_claim_weekly':
        return backend.claimWeekly();
      case 'rawda_redeem':
        return backend.redeem(data['p_reward_id'] as String);
      case 'rawda_public_config':
        return backend.communityConfig();
      case 'rawda_admin_list':
        return backend.adminList(data['p_kind'] as String);
      case 'rawda_admin_save':
        return backend.adminSave(data['p_kind'] as String, obj(data['p_data']));
      default:
        throw StateError('FIREBASE_PREVIEW_FEATURE_UNAVAILABLE');
    }
  }

  Future<void> updateProfile(Map<String, dynamic> fields, String owner) async {
    final backend = firebase;
    if (backend != null) {
      await backend.updateProfile(owner, fields);
    } else {
      await db.from('rawda_profiles').update(fields).eq('id', owner);
    }
  }

  Future<dynamic> pointHistory() async {
    final backend = firebase;
    if (backend != null) return backend.history();
    return db
        .from('rawda_ledger')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
  }

  Future<void> signOut() async {
    final backend = firebase;
    if (backend == null) {
      await db.auth.signOut();
    } else {
      await backend.auth.signOut();
    }
  }

  void clearAccountSession() {
    if (!mounted) return;
    setState(() {
      ready = false;
      _deletionPending = false;
      account = {};
      state = {};
      quiz = [];
      page = 2;
      isAdmin = false;
      announcements = [];
      voices = [];
    });
    nav.currentState?.popUntil((r) => r.isFirst);
  }

  int get balance => (account['wallet']?['balance'] as num?)?.toInt() ?? 0;
  int get earned => (account['wallet']?['earned'] as num?)?.toInt() ?? 0;
  void mutate(VoidCallback action) => setState(action);
  void setArabic(bool value) {
    setState(() => ar = value);
    prefs.setBool('arabic', value);
  }

  void setDark(bool value) {
    setState(() => dark = value);
    prefs.setBool('dark', value);
  }

  String get uid => firebase == null
      ? (db.auth.currentUser?.id ?? '')
      : (firebase!.auth.currentUser?.uid ?? '');
  String? get accountEmail => firebase == null
      ? db.auth.currentUser?.email
      : firebase!.auth.currentUser?.email;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ar = prefs.getBool('arabic') ?? true;
    dark = prefs.getBool('dark') ?? false;
    config = safeMap(prefs.getString('prayer_config'));
    final cache = prefs.getString('prayer_calendar');
    if (cache != null) {
      calendar = safeCalendar(cache);
    }
    now = clockNow();
    loadBooks();
    startClock();
    if (widget.startError == null) {
      final backend = firebase;
      if (backend != null) {
        String? previousOwner;
        auth = backend.auth.authStateChanges().listen(
          (user) {
            if (!mounted) return;
            if (user == null ||
                (previousOwner != null && previousOwner != user.uid)) {
              clearAccountSession();
            }
            previousOwner = user?.uid;
            if (signed) {
              unawaited(loadAccount());
            } else {
              unawaited(refreshFirebaseOnReturn());
            }
          },
          onError: (Object error, StackTrace stack) {
            if (mounted) toast(err(error));
          },
        );
      } else {
        auth = db.auth.onAuthStateChange.listen(
          (event) {
            if (event.event == AuthChangeEvent.passwordRecovery) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => changePassword(),
              );
            }
            if (event.event == AuthChangeEvent.signedIn ||
                event.event == AuthChangeEvent.initialSession) {
              loadAccount();
            }
            if (event.event == AuthChangeEvent.signedOut) clearAccountSession();
          },
          onError: (Object error, StackTrace stack) {
            if (mounted) toast(err(error));
          },
        );
      }
      if (signed) {
        loadAccount();
      }
    }
    status();
  }

  void startClock() {
    clock?.cancel();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      now = clockNow();
      if (signed &&
          ready &&
          page == 2 &&
          (nav.currentState?.canPop() != true)) {
        clockTick.value = now;
      }
      if (signed && ready && page == 2 && now.second == 0 &&
          (nav.currentState?.canPop() != true)) {
        setState(() {});
      }
      if (signed && now.second % 5 == 0) status();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    auth?.cancel();
    clock?.cancel();
    clockTick.dispose();
    _noticeTimer?.cancel();
    _noticeEntry?.remove();
    _noticeEntry = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      clock?.cancel();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      startClock();
      now = clockNow();
      status();
      unawaited(refreshFirebaseOnReturn());
      if (signed && calendar.isNotEmpty) {
        schedule();
        unawaited(refreshCalendarIfNeeded());
      }
    }
  }

  Future<void> refreshFirebaseOnReturn() async {
    final backend = firebase;
    final user = backend?.auth.currentUser;
    if (backend == null ||
        user == null ||
        user.emailVerified ||
        !hasFirebaseConsent(user.uid) ||
        _refreshingVerification) {
      return;
    }
    _refreshingVerification = true;
    try {
      if (await backend.refreshVerification() && mounted && uid == user.uid) {
        await loadAccount();
      }
    } catch (error) {
      // Manual confirmation remains available if the device is offline.
      if (kDebugMode) debugPrint('Verification refresh: $error');
    } finally {
      _refreshingVerification = false;
    }
  }

  Future<void> loadBooks() async {
    final data = await rootBundle.loadString('assets/chapters.json');
    final text = await rootBundle.loadString('assets/quran-uthmani.txt');
    final all = await compute(parseQuranIndex, text);
    if (mounted) {
      setState(() {
        chapters = jsonDecode(data)['chapters'] as List;
        verses = all;
      });
    }
  }

  void toast(String s) {
    _noticeTimer?.cancel();
    _noticeEntry?.remove();
    final overlay = nav.currentState?.overlay;
    if (overlay == null) return;
    _noticeEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 16,
        right: 16,
        child: SafeArea(
          bottom: false,
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                elevation: 12,
                shadowColor: Colors.black26,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: rawdaGold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s,
                          style: const TextStyle(fontSize: 13, height: 1.6),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('إغلاق', 'Close'),
                        onPressed: clearNotice,
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_noticeEntry!);
    _noticeTimer = Timer(const Duration(seconds: 5), clearNotice);
  }

  void clearNotice() {
    _noticeTimer?.cancel();
    _noticeEntry?.remove();
    _noticeEntry = null;
  }

  String err(dynamic e) {
    final s = e.toString();
    if (s.contains('FIREBASE_PREVIEW_FEATURE_UNAVAILABLE')) {
      return tr(
        'الميزة دي لسه تحت الاختبار في نسخة Firebase.',
        'This feature is pending in the Firebase preview.',
      );
    }
    if (s.contains('WEEKLY_TARGET_NOT_REACHED')) {
      return tr(
        'كمّل ٢٠ إجابة في الأسبوع الأول.',
        'Answer 20 questions this week first.',
      );
    }
    if (s.contains('REWARD_UNAVAILABLE')) {
      return tr(
        'الهدية دي غير متاحة دلوقتي.',
        'This reward is currently unavailable.',
      );
    }
    if (s.contains('QUIZ_NOT_CONFIGURED')) {
      return tr(
        'أسئلة اليوم لسه ما اترفعتش.',
        'Today’s questions haven’t been uploaded.',
      );
    }
    if (s.contains('QUIZ_DAY_CHANGED')) {
      return tr(
        'بدأ يوم جديد. حدّث أسئلة المسابقة.',
        'A new quiz day has started. Reload the questions.',
      );
    }
    if (e is firebase_auth.FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return tr(
            'الإيميل مسجل بالفعل. جرّب تسجيل الدخول.',
            'This email is already registered. Try signing in.',
          );
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return tr(
            'راجع الإيميل وكلمة المرور.',
            'Check your email and password.',
          );
        case 'requires-recent-login':
          return tr(
            'سجّل خروج وادخل مرة تانية قبل تغيير كلمة المرور.',
            'Sign in again before changing the password.',
          );
        case 'too-many-requests':
          return tr(
            'انتظر شوية قبل المحاولة مرة تانية.',
            'Wait a little before retrying.',
          );
      }
    }
    if (s.contains('QUESTION_IN_USE')) {
      return tr(
        'السؤال مستخدم بالفعل في مسابقة؛ أضف نسخة برقم جديد للحفاظ على النتائج.',
        'This question has already been assigned. Add a new ID to preserve results.',
      );
    }
    if (s.contains('INVALID_CONTENT') ||
        s.contains('violates check constraint') ||
        s.contains('invalid input syntax')) {
      return tr(
        'راجع الحقول المطلوبة والقيم قبل الحفظ.',
        'Check the required fields and values before saving.',
      );
    }
    if (s.contains('ADMIN_REQUIRED')) {
      return tr(
        'الإدارة متاحة لصاحب التطبيق فقط.',
        'Administration is restricted to the owner.',
      );
    }
    if (s.contains('rate_limit') ||
        s.contains('429') ||
        s.contains('Too many')) {
      return tr(
        'طلبات كتير في وقت قصير. انتظر قليلًا ثم حاول مجددًا.',
        'Too many requests. Please wait and retry.',
      );
    }
    if (s.contains('User already registered')) {
      return tr(
        'الإيميل مسجّل بالفعل. جرّب تسجيل الدخول أو استعادة كلمة المرور.',
        'Email already registered. Sign in or reset your password.',
      );
    }
    if (s.contains('signup_disabled')) {
      return tr(
        'إنشاء الحسابات متوقف مؤقتًا.',
        'New registrations are temporarily disabled.',
      );
    }
    if (s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('TimeoutException')) {
      return tr(
        'الاتصال بالخدمة غير متاح حاليًا. جرّب تاني بعد التأكد من الإنترنت.',
        'Service connection unavailable. Check internet and retry.',
      );
    }
    if (s.contains('LOCATION')) {
      return tr(
        'تعذّر تحديد الموقع. فعّل إذن الموقع أو اكتب مدينتك يدويًا.',
        'Location unavailable. Grant permission or enter your city.',
      );
    }
    if (s.contains('PERMISSION')) {
      return tr(
        'التنبيه يحتاج إذن من إعدادات الهاتف. افتح قسم صلاحيات الأذان.',
        'Alarm permission required. Open alarm permissions.',
      );
    }
    if (s.contains('TIMES')) {
      return tr(
        'تعذّر تحميل المواقيت. راجع المدينة وطريقة الحساب ثم حاول تاني.',
        'Could not load times. Check city and calculation settings.',
      );
    }

    if (s.contains('INSUFFICIENT_POINTS')) {
      return tr('رصيد النقاط غير كافٍ.', 'Not enough points.');
    }
    if (s.contains('CHALLENGE_INCOMPLETE')) {
      return tr(
        'أكمل ٢٠ إجابة هذا الأسبوع أولًا.',
        'Answer 20 questions this week first.',
      );
    }
    if (s.contains('Invalid login credentials')) {
      return tr('راجع الإيميل وكلمة المرور.', 'Check email and password.');
    }
    if (s.contains('Email not confirmed')) {
      return tr('افتح رسالة تأكيد الإيميل أولًا.', 'Confirm your email first.');
    }
    return tr(
      'تعذّر إتمام العملية. حاول مجددًا؛ لو استمرت المشكلة أعد فتح التطبيق.',
      'Could not complete the request. Check your connection and retry.',
    );
  }

  Future<void> run(Future<void> Function() f) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await f();
    } catch (e) {
      toast(err(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadAccount() async {
    if (_loadingAccount) return;
    _loadingAccount = true;
    final owner = uid;
    try {
      await _loadAccount();
    } finally {
      _loadingAccount = false;
      if (mounted && signed && uid != owner) unawaited(loadAccount());
    }
  }

  Future<void> _loadAccount() async {
    if (!signed) return;
    final user = uid;
    final local = prefs.getString('state:$user');
    if (local != null && mounted) {
      setState(() => state = safeMap(local));
    }
    try {
      final backend = firebase;
      if (backend != null &&
          (prefs.getBool('firebase-deleting:$user') == true ||
              await backend.isDeletionPending(user))) {
        if (uid == user) await markDeletionPending(user);
        return;
      }
      final data = obj(await rpc('rawda_bootstrap'));
      if (uid != user) return;
      final cloud = obj(data['state']);
      final localAt = num.tryParse('${state['_updatedAt'] ?? 0}') ?? 0,
          cloudAt = num.tryParse('${cloud['_updatedAt'] ?? 0}') ?? 0;
      if (cloudAt >= localAt) {
        state = cloud;
      } else {
        await rpc('rawda_save_state', params: {'p_data': state});
      }
      if (state['_profileInitialized'] != true) {
        final metaName = firebase == null
            ? (db.auth.currentUser?.userMetadata?['display_name'])
            : null;
        if (data['profile']['display_name'] == 'عضو الروضة' &&
            metaName is String &&
            metaName.trim().isNotEmpty) {
          final displayName = String.fromCharCodes(
            metaName.trim().runes.take(60),
          );
          await updateProfile({'display_name': displayName}, user);
          data['profile']['display_name'] = displayName;
        }
        state['_profileInitialized'] = true;
        state['_updatedAt'] = DateTime.now().millisecondsSinceEpoch;
        await rpc('rawda_save_state', params: {'p_data': state});
      }
      if (uid != user || prefs.getBool('firebase-deleting:$user') == true) {
        return;
      }
      if (mounted) {
        setState(() {
          account = data;
          ready = true;
          problem = null;
        });
      }
      await prefs.setString('account:$user', jsonEncode(data));
      await prefs.setString('state:$user', jsonEncode(state));
      try {
        await claim('login', quiet: true);
      } catch (error) {
        if (firebase == null) rethrow;
        if (kDebugMode) debugPrint('Firebase daily credit pending: $error');
      }
      await loadCommunityConfig();
      await status();
      unawaited(refreshCalendarIfNeeded());
    } catch (e) {
      if (kDebugMode) debugPrint('Rawda account initialization: $e');
      if (uid != user || prefs.getBool('firebase-deleting:$user') == true) {
        return;
      }
      final cached = prefs.getString('account:$user');
      if (mounted) {
        setState(() {
          if (cached != null) {
            account = safeMap(cached);
            ready = true;
          }
          problem = tr(
            'الاتصال بالحساب غير متاح؛ المحفوظ على الجهاز متاح.',
            'Account offline; locally saved content remains available.',
          );
        });
      }
    }
  }

  Future<void> _stateSync = Future<void>.value();
  Future<void> saveState() async {
    final owner = uid;
    if (owner.isEmpty) return;
    state['_updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    final encoded = jsonEncode(state);
    await prefs.setString('state:$owner', encoded);
    if (!mounted || uid != owner) return;
    setState(() {});
    try {
      final task = _stateSync.then((_) async {
        if (!mounted ||
            uid != owner ||
            prefs.getString('state:$owner') != encoded) {
          return;
        }
        await rpc('rawda_save_state', params: {'p_data': jsonDecode(encoded)});
      });
      _stateSync = task.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {},
      );
      await task;
    } catch (_) {
      if (mounted && uid == owner) {
        toast(
          tr(
            'اتحفظ على الجهاز؛ المزامنة هتتكرر عند فتح التطبيق.',
            'Saved locally; sync retries on reopening.',
          ),
        );
      }
    }
  }

  Future<void> claim(String activity, {bool quiet = false}) async {
    final owner = uid;
    final result = obj(
      await rpc('rawda_claim_activity', params: {'p_activity': activity}),
    );
    if (uid != owner) return;
    if (mounted) {
      setState(() {
        account['wallet'] ??= {};
        account['wallet']['balance'] = result['balance'];
        account['wallet']['earned'] =
            earned + ((result['awarded'] as num?)?.toInt() ?? 0);
      });
    }
    if (!quiet) {
      toast(
        tr(
          'تم التسجيل • +${result['awarded']} نقطة',
          'Recorded • +${result['awarded']} points',
        ),
      );
    }
  }

  Future<void> status() async {
    try {
      final s = obj(await bridge.invokeMethod('status'));
      final title = '${s['playingTitle'] ?? ''}';
      final needsPopup =
          s['playing'] == true &&
          config['fullScreenAlarm'] != false &&
          !_adhanVisible &&
          _lastAdhanTitle != title &&
          !title.contains('Preview');
      final changed =
          exact != (s['exact'] == true) ||
          notifications != (s['notifications'] == true) ||
          scheduled != ((s['count'] as num?)?.toInt() ?? 0) ||
          (s['nextDismissed'] == true &&
              config['ongoingNotification'] != false);
      if (!changed && !needsPopup) {
        if (s['playing'] != true) _lastAdhanTitle = null;
        return;
      }
      if (mounted) {
        setState(() {
          exact = s['exact'] == true;
          notifications = s['notifications'] == true;
          scheduled = (s['count'] as num?)?.toInt() ?? 0;
          if (s['nextDismissed'] == true) {
            config['ongoingNotification'] = false;
            prefs.setString('prayer_config', jsonEncode(config));
          }
          if (s['playing'] != true) _lastAdhanTitle = null;
          final title = '${s['playingTitle'] ?? ''}';
          if (s['playing'] == true &&
              config['fullScreenAlarm'] != false &&
              !_adhanVisible &&
              _lastAdhanTitle != title &&
              !title.contains('Preview')) {
            _lastAdhanTitle = title;
            _adhanVisible = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => showAdhan('${s['playingTitle'] ?? ''}'),
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> persistConfig() async {
    await prefs.setString('prayer_config', jsonEncode(config));
    if (mounted) setState(() {});
  }

  Map<String, dynamic>? get today {
    for (final x in calendar) {
      if (x['date']['gregorian']['date'] ==
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}') {
        return obj(x);
      }
    }
    return null;
  }

  String timeLabel(String raw) {
    final dt = DateTime.tryParse(raw);
    final match = RegExp(r'T(\d\d):(\d\d)').firstMatch(raw);
    if (dt == null || match == null) return '—';
    final h = int.parse(match[1]!), m = match[2]!;
    return config['clock24'] == true
        ? '${match[1]}:$m'
        : '${h % 12 == 0 ? 12 : h % 12}:$m ${h < 12 ? tr('ص', 'AM') : tr('م', 'PM')}';
  }

  List<dynamic>? _timelineCalendar;
  List<Map<String, dynamic>> _timeline = [];
  List<Map<String, dynamic>> get upcoming {
    if (!identical(_timelineCalendar, calendar)) {
      _timelineCalendar = calendar;
      _timeline = [];
      for (final row in calendar) {
        for (var i = 0; i < 5; i++) {
          final raw = '${row['timings'][prayerKeys[i]]}';
          final at = DateTime.tryParse(raw);
          if (at != null) _timeline.add({'index': i, 'at': at, 'raw': raw});
        }
      }
      _timeline.sort(
        (a, b) => (a['at'] as DateTime).compareTo(b['at'] as DateTime),
      );
    }
    return _timeline.where((r) => (r['at'] as DateTime).isAfter(now)).toList();
  }

  String get prayerSourceSignature => jsonEncode({
    for (final key in [
      'lat',
      'lon',
      'city',
      'country',
      'method',
      'school',
      'timezone',
      'tuneFajr',
      'tuneDhuhr',
      'tuneAsr',
      'tuneMaghrib',
      'tuneIsha',
    ])
      key: config[key],
  });
  bool get prayerConfigChanged =>
      calendar.isNotEmpty &&
      prefs.getString('prayer_source_signature') != null &&
      prefs.getString('prayer_source_signature') != prayerSourceSignature;
  bool _refreshingCalendar = false;
  Future<void> refreshCalendarIfNeeded() async {
    if (_refreshingCalendar ||
        !signed ||
        (config['lat'] == null && '${config['city'] ?? ''}'.trim().isEmpty)) {
      return;
    }
    final expires = calendar.isEmpty
        ? null
        : DateTime.tryParse('${calendar.last['timings']['Isha']}');
    if (expires != null &&
        expires.isAfter(DateTime.now().add(const Duration(days: 7))) &&
        !prayerConfigChanged) {
      return;
    }
    _refreshingCalendar = true;
    try {
      await fetchTimes();
    } catch (_) {
      /* Keep the last valid offline calendar. */
    } finally {
      _refreshingCalendar = false;
    }
  }

  Future<void> fetchTimes() async {
    if (config['lat'] == null &&
        (config['city'] ?? '').toString().trim().isEmpty) {
      toast(
        tr(
          'حدد موقعك أو اكتب المدينة أولًا.',
          'Choose a location or enter a city first.',
        ),
      );
      return;
    }
    final request = Map<String, dynamic>.from(config);
    final signature = prayerSourceSignature;
    final requestedMonth = clockNow();
    final rows = <dynamic>[];
    final errors = <String>[];
    for (var offset = 0; offset < 2; offset++) {
      final month = DateTime(
        requestedMonth.year,
        requestedMonth.month + offset,
        1,
      );
      final byGps = request['lat'] != null;
      final endpoint = byGps ? 'calendar' : 'calendarByCity';
      final query = <String, String>{
        'method': '${request['method'] ?? 5}',
        'school': '${request['school'] ?? 0}',
        'iso8601': 'true',
        'latitudeAdjustmentMethod': '3',
        if (byGps) 'latitude': '${request['lat']}',
        if (byGps) 'longitude': '${request['lon']}',
        if (!byGps) 'city': '${request['city']}',
        if (!byGps) 'country': '${request['country'] ?? 'Egypt'}',
        // An IANA identifier handles Egypt's daylight-saving transitions;
        // a fixed GMT+2/GMT+3 offset would be wrong for half the year.
        if (prayerZoneHint(request) != null)
          'timezonestring': prayerZoneHint(request)!,
        'tune':
            '0,${request['tuneFajr'] ?? 0},0,${request['tuneDhuhr'] ?? 0},${request['tuneAsr'] ?? 0},${request['tuneMaghrib'] ?? 0},0,${request['tuneIsha'] ?? 0},0',
      };
      try {
        final response = await http
            .get(
              Uri.https(
                'api.aladhan.com',
                '/v1/$endpoint/${month.year}/${month.month}',
                query,
              ),
            )
            .timeout(const Duration(seconds: 25));
        final json = obj(jsonDecode(response.body));
        if (response.statusCode != 200 || json['code'] != 200) {
          throw Exception('TIMES');
        }
        rows.addAll(json['data'] as List);
      } catch (_) {
        errors.add('$offset');
      }
    }
    if (rows.isEmpty) throw Exception('TIMES');
    if (signature != prayerSourceSignature) {
      throw Exception('TIMES_CONFIG_CHANGED');
    }
    await prefs.setString('prayer_source_signature', signature);
    await prefs.setString(
      'prayer_location_label',
      request['lat'] != null
          ? tr('حسب موقعك', 'Your location')
          : '${request['city']}, ${request['country'] ?? 'Egypt'}',
    );
    calendar = rows;
    now = clockNow();
    await prefs.setString('prayer_calendar', jsonEncode(rows));
    config['fetchedAt'] = now.toIso8601String();
    await persistConfig();
    await schedule();
    if (errors.isNotEmpty) {
      toast(
        tr(
          'اتحملت مواقيت شهر واحد؛ حدّثها لاحقًا للشهر التالي.',
          'One month loaded; refresh later for the next month.',
        ),
      );
    }
  }

  Future<void> schedule() async {
    try {
      await syncPrayerNotification();
    } catch (_) {
      /* A presentation error must not stop exact prayer alarms. */
    }
    if (config['alerts'] != true) {
      await bridge.invokeMethod('schedule', {'events': <dynamic>[]});
      await status();
      return;
    }
    final events = <Map<String, dynamic>>[];
    var id = 100;
    for (final row in calendar) {
      for (var i = 0; i < 5; i++) {
        final dt = DateTime.tryParse('${row['timings'][prayerKeys[i]]}');
        if (dt == null) continue;
        final key = prayerKeys[i];
        final enabled = config['enabled$key'] != false;
        final pre = (config['pre$key'] as num?)?.toInt() ?? 10,
            iqama = (config['iqama$key'] as num?)?.toInt() ?? 15;
        final sound = config['sound$key'] ?? 'builtin';
        void event(
          DateTime at,
          String title,
          String body,
          bool audio, {
          String kind = 'reminder',
          String? audioOverride,
        }) {
          if (at.isAfter(DateTime.now())) {
            events.add({
              'id': id++,
              'at': at.millisecondsSinceEpoch,
              'title': title,
              'body': body,
              'audio': audio,
              'sound': audioOverride ?? sound,
              'short': kind == 'iqama' ? false : config['short$key'] == true,
              'volume':
                  ((config[kind == 'iqama' ? 'iqamaVolume' : 'volume$key']
                                  as num?)
                              ?.toDouble() ??
                          1.0)
                      .clamp(0.0, 1.0),
              'prayer': i,
              'kind': kind,
              'ar': ar,
            });
          }
        }

        if (enabled) {
          event(
            dt,
            tr('حان وقت ${prayerArabic[i]}', 'Time for ${prayerKeys[i]}'),
            tr('حيّ على الصلاة', 'Come to prayer'),
            sound != 'silent',
            kind: 'prayer',
          );
          if (pre > 0) {
            event(
              dt.subtract(Duration(minutes: pre)),
              tr(
                'اقتربت صلاة ${prayerArabic[i]}',
                '${prayerKeys[i]} is approaching',
              ),
              tr('متبقي $pre دقائق', 'In $pre minutes'),
              false,
            );
          }
          if (iqama > 0) {
            event(
              dt.add(Duration(minutes: iqama)),
              tr(
                'قد قامت الصلاة • ${prayerArabic[i]}',
                'Iqama reminder • ${prayerKeys[i]}',
              ),
              tr(
                'حان وقت الإقامة حسب المدة التي حددتها',
                'Reminder based on your chosen interval',
              ),
              config['iqamaAudio'] != false && config['iqamaSound'] != 'silent',
              kind: 'iqama',
              audioOverride: (config['iqamaSound'] ?? 'iqama').toString(),
            );
          }
        }
      }
      final fajr = DateTime.tryParse('${row['timings']['Fajr']}'),
          sunrise = DateTime.tryParse('${row['timings']['Sunrise']}'),
          maghrib = DateTime.tryParse('${row['timings']['Maghrib']}');
      void reminder(DateTime? at, String arTitle, String enTitle) {
        if (at != null && at.isAfter(DateTime.now())) {
          events.add({
            'id': id++,
            'at': at.millisecondsSinceEpoch,
            'title': tr(arTitle, enTitle),
            'body': tr('لحظة طيبة مع الروضة', 'A peaceful moment with Rawda'),
            'audio': false,
          });
        }
      }

      if (config['reminderMorning'] == true) {
        reminder(
          fajr?.add(const Duration(minutes: 30)),
          'أذكار الصباح',
          'Morning adhkar',
        );
      }
      if (config['reminderEvening'] == true) {
        reminder(
          maghrib?.subtract(const Duration(minutes: 30)),
          'أذكار المساء',
          'Evening adhkar',
        );
      }
      if (config['reminderSunrise'] == true) {
        reminder(
          sunrise?.subtract(const Duration(minutes: 10)),
          'اقترب الشروق',
          'Sunrise is approaching',
        );
      }
      if (config['reminderDuha'] == true) {
        reminder(
          sunrise?.add(
            Duration(minutes: (config['duhaMinutes'] as num?)?.toInt() ?? 30),
          ),
          'تذكير الضحى',
          'Duha reminder',
        );
      }
      if (config['reminderQiyam'] == true) {
        reminder(
          fajr?.subtract(
            Duration(minutes: (config['qiyamMinutes'] as num?)?.toInt() ?? 60),
          ),
          'تذكير القيام',
          'Night prayer reminder',
        );
      }
      if (config['reminderQuran'] == true) {
        reminder(
          maghrib?.add(const Duration(minutes: 30)),
          'ورد القرآن',
          'Daily Quran reading',
        );
      }
      if (config['reminderKahf'] == true &&
          maghrib?.weekday == DateTime.friday) {
        reminder(
          maghrib?.subtract(const Duration(hours: 3)),
          'قراءة سورة الكهف',
          'Surah Al-Kahf',
        );
      }
      if (config['reminderFasting'] == true &&
          (fajr?.weekday == DateTime.monday ||
              fajr?.weekday == DateTime.thursday)) {
        reminder(
          fajr?.subtract(const Duration(minutes: 60)),
          'تذكير صيام الاثنين والخميس',
          'Monday / Thursday fasting reminder',
        );
      }
    }
    await bridge.invokeMethod('schedule', {'events': events});
    await status();
  }

  Future<void> push(String title, Widget Function(BuildContext) body) async {
    await nav.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: body(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget tile(
    String title,
    IconData icon,
    VoidCallback onTap, {
    String? subtitle,
  }) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: rawdaGold.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: dark ? rawdaGold : rawdaGreen),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: const TextStyle(fontSize: 11, height: 1.8)),
      trailing: Icon(ar ? Icons.chevron_left : Icons.chevron_right, size: 20),
      onTap: onTap,
    ),
  );
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
    ),
  );
  Widget notice(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(text, style: const TextStyle(fontSize: 12, height: 1.8)),
  );
  Widget wrapList(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(20), children: children);
  @override
  Widget build(BuildContext context) {
    final themeKey = state['theme'] ?? 'olive';
    final owned = (account['redemptions'] as List? ?? []).any(
      (r) =>
          r['reward_id'] == 'theme_$themeKey' ||
          (account['rewards'] as List? ?? []).any(
            (item) =>
                item['id'] == r['reward_id'] &&
                item['kind'] == 'theme' &&
                item['asset_key'] == themeKey,
          ),
    );
    final seed = owned && themeKey == 'sand'
        ? const Color(0xFF987540)
        : owned && themeKey == 'midnight'
        ? const Color(0xFF435F80)
        : rawdaGreen;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return MaterialApp(
      navigatorKey: nav,
      scaffoldMessengerKey: messenger,
      debugShowCheckedModeBanner: false,
      title: 'الروضة | Rawda',
      locale: Locale(ar ? 'ar' : 'en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme.copyWith(
          primary: seed,
          secondary: rawdaGold,
          surface: dark ? const Color(0xFF1B3028) : const Color(0xFFFFFBF2),
          onSurface: dark ? const Color(0xFFF5EEE0) : const Color(0xFF193C32),
        ),
        fontFamily: ar ? 'RawdaArabic' : 'RawdaLatin',
        fontFamilyFallback: const ['RawdaArabic', 'RawdaLatin'],
        scaffoldBackgroundColor: dark
            ? const Color(0xFF161D18)
            : const Color(0xFFF7F4EC),
        appBarTheme: AppBarTheme(
          backgroundColor: dark ? const Color(0xFF162D26) : const Color(0xFFFFFBF2),
          foregroundColor: dark ? const Color(0xFFF2DBAD) : rawdaGreen,
          centerTitle: true,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: ar ? 'RawdaArabic' : 'RawdaLatin',
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: dark ? const Color(0xFFF2DBAD) : rawdaGreen,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: dark
              ? const Color(0xFF14271F)
              : const Color(0xFFFFFCF4),
          indicatorColor: rawdaGold.withValues(alpha: .22),
          height: 74,
          labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          iconTheme: WidgetStatePropertyAll(
            IconThemeData(color: dark ? const Color(0xFFEBD9B7) : rawdaGreen),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: rawdaGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(64, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        dividerTheme: DividerThemeData(color: rawdaGold.withValues(alpha: .15)),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: dark ? const Color(0xFF20362B) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: rawdaGold.withValues(alpha: .2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: rawdaGold, width: 1.6),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: dark ? const Color(0xFF1D3026) : const Color(0xFFFFFEFA),
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: rawdaGold.withValues(alpha: .13)),
          ),
        ),
      ),
      home: widget.startError != null
          ? Scaffold(body: Center(child: Text(widget.startError!)))
          : !signed
          ? AuthScreen(app: this)
          : !ready
          ? Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (problem == null) const CircularProgressIndicator(),
                    if (problem != null) Text(problem!),
                    if (_deletionPending)
                      TextButton(
                        onPressed: busy ? null : deleteAccount,
                        child: Text(
                          tr('كمّل حذف الحساب', 'Finish deleting account'),
                        ),
                      ),
                    if (!_deletionPending)
                      TextButton(
                        onPressed: loadAccount,
                        child: Text(tr('إعادة المحاولة', 'Retry')),
                      ),
                    TextButton(
                      onPressed: signOut,
                      child: Text(tr('خروج', 'Sign out')),
                    ),
                  ],
                ),
              ),
            )
          : Scaffold(
              appBar: AppBar(
                toolbarHeight: 76,
                title: Row(
                  children: [
                    Image.asset('assets/logo.png', width: 40, height: 40),
                    const SizedBox(width: 10),
                    Text(
                      tr('الروضة', 'Rawda'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: settings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => ar = !ar);
                      prefs.setBool('arabic', ar);
                      schedule();
                    },
                    child: Text(ar ? 'EN' : 'عربي'),
                  ),
                ],
              ),
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Column(
                      children: [
                        if (busy) const LinearProgressIndicator(minHeight: 2),
                        if (problem != null)
                          MaterialBanner(
                            content: Text(
                              problem!,
                              style: const TextStyle(fontSize: 12),
                            ),
                            actions: [
                              TextButton(
                                onPressed: loadAccount,
                                child: Text(tr('اتصال', 'Retry')),
                              ),
                            ],
                          ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey(page),
                              child: page == 2
                                  ? home()
                                  : [
                                      nusukInspiredQuran,
                                      quizBody,
                                      home,
                                      nusukInspiredToday,
                                      profile,
                                    ][page](),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: page,
                onDestinationSelected: (i) {
                  setState(() => page = i);
                  if (i == 1) loadQuiz();
                  if (i == 0 && chapters.isEmpty) unawaited(loadBooks());
                },
                destinations: [
                  for (final item in [
                    (Icons.menu_book_outlined, tr('القرآن', 'Quran')),
                     (Icons.auto_awesome_outlined, tr('المسابقة', 'Quiz')),
                     (Icons.home_rounded, tr('الرئيسية', 'Home')),
                     (Icons.wb_sunny_outlined, tr('اليوم', 'Today')),
                     (Icons.person_outline, tr('الحساب', 'Account')),
                  ])
                    NavigationDestination(icon: Icon(item.$1), label: item.$2),
                ],
              ),
            ),
    );
  }

  Widget home() =>
       RefreshIndicator(onRefresh: loadAccount, child: nusukInspiredHome());

  Widget worship() => wrapList([
    heading(tr('لحظات من الطمأنينة', 'Moments of peace')),
    featureGrid(),
    tile(
      tr('جدول مواقيت الشهر', 'Monthly prayer timetable'),
      Icons.date_range_outlined,
      openPrayerMonth,
    ),
    tile(
      tr('متابعة الصلاة والصيام', 'Prayer & fasting tracker'),
      Icons.fact_check_outlined,
      openTracker,
    ),
    tile(tr('القرآن الكريم', 'Quran'), Icons.menu_book_outlined, openQuran),
    tile(tr('اتجاه القبلة', 'Qibla'), Icons.explore_outlined, openQibla),
    tile(
      tr('أذكار الصباح', 'Morning adhkar'),
      Icons.wb_sunny_outlined,
      () => openAdhkar('morning'),
    ),
    tile(
      tr('أذكار المساء', 'Evening adhkar'),
      Icons.nightlight_outlined,
      () => openAdhkar('evening'),
    ),
    tile(
      tr('أذكار بعد الصلاة', 'After-prayer adhkar'),
      Icons.mosque_outlined,
      () => openAdhkar('prayer'),
    ),
    tile(
      tr('أذكار النوم', 'Bedtime adhkar'),
      Icons.bedtime_outlined,
      () => openAdhkar('sleep'),
    ),
    tile(tr('المسبحة', 'Tasbih'), Icons.touch_app_outlined, openTasbih),
    tile(
      tr('التقويم الهجري', 'Hijri calendar'),
      Icons.calendar_month_outlined,
      openCalendar,
    ),
    tile(
      tr('ورد اليوم وخطة الختمة', 'Daily reading & khatma'),
      Icons.bookmark_outline,
      openDaily,
    ),
  ]);
  Future<void> loadQuiz() async {
    if (quizLoading || !signed || !mounted) return;
    final owner = uid;
    setState(() {
      quizLoading = true;
      quizProblem = null;
    });
    try {
      final data = await rpc('rawda_daily_quiz');
      if (mounted && uid == owner) setState(() => quiz = data as List);
    } catch (e) {
      if (mounted && uid == owner) setState(() => quizProblem = err(e));
    } finally {
      if (mounted) setState(() => quizLoading = false);
    }
  }

  Widget quizBody() => wrapList([
    sectionHero(
      tr('مسابقتك اليومية', 'Your daily quiz'),
      tr('كل يوم فرصة جديدة للمعرفة', 'A new chance to learn every day'),
      Icons.auto_awesome_outlined,
    ),
    if (quizLoading) const LinearProgressIndicator(),
    if (quizProblem != null) inlineStatus(quizProblem!, loadQuiz),
    tile(
      tr('تدريب حسب الموضوع والمستوى', 'Practice by topic and level'),
      Icons.school_outlined,
      () => push(
        tr('تدريب المعرفة', 'Knowledge practice'),
        (_) => PracticeScreen(app: this),
      ),
    ),
    Text(
      tr(
        'كل إجابة صحيحة بنقطتين. الأسئلة تتجدد يوميًا بتوقيت القاهرة.',
        'Each correct answer earns 2 points. New daily sets follow Cairo time.',
      ),
    ),
    if (quiz.isNotEmpty && quiz.first['is_review'] == true)
      notice(
        tr(
          'دورة مراجعة: أكملت بنك الأسئلة في الدورة السابقة.',
          'Review cycle: you completed the previous question-bank cycle.',
        ),
      ),
    Row(
      children: [
        TextButton.icon(
          onPressed: loadQuiz,
          icon: const Icon(Icons.refresh),
          label: Text(tr('تحديث', 'Refresh')),
        ),
        TextButton(
          onPressed: openWeekly,
          child: Text(tr('تحدي الأسبوع', 'Weekly challenge')),
        ),
      ],
    ),
    if (quiz.isEmpty)
      notice(
        tr(
          'اتصل بالإنترنت ثم اضغط تحديث لتحميل الأسئلة.',
          'Connect to the internet and tap Refresh to load questions.',
        ),
      ),
    for (var i = 0; i < quiz.length; i++) quizCard(obj(quiz[i]), i),
    tile(
      tr('ترتيب الأسبوع', 'Weekly leaderboard'),
      Icons.leaderboard_outlined,
      openLeaderboard,
    ),
    notice(
      tr(
        'لن تتكرر الأسئلة خلال الدورة. قد يكون عدد الأسئلة أقل من خمسة في آخر يوم منها.',
        'Questions do not repeat within your cycle. Its final day may contain fewer than five questions.',
      ),
    ),
  ]);
  Widget quizCard(Map<String, dynamic> q, int index) {
    final answered = q['answered'] == true;
    final options = q[ar ? 'options_ar' : 'options_en'] as List;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${index + 1} • ${tr('المستوى', 'Level')} ${q['difficulty']}'),
            const SizedBox(height: 10),
            Text(
              q[ar ? 'question_ar' : 'question_en'].toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (var j = 0; j < 4; j++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton.styleFrom().letButton(
                  options[j].toString(),
                  answered || busy
                      ? null
                      : () => run(() async {
                          await rpc(
                            'rawda_answer_quiz',
                            params: {
                              'p_question_id': q['id'],
                              'p_selected_index': j,
                              if (firebase != null) 'p_day': q['day'],
                            },
                          );
                          await loadQuiz();
                          await refreshWallet();
                        }),
                  answered && q['correct_index'] == j
                      ? Icons.check_circle
                      : answered && q['selected_index'] == j
                      ? Icons.cancel_outlined
                      : null,
                ),
              ),
            if (answered)
              Text(
                q['correct'] == true
                    ? tr('إجابة صحيحة • نقطتان', 'Correct • 2 points')
                    : tr(
                        'تعلمنا معلومة جديدة؛ الصحيح معلّم بالأخضر.',
                        'A new fact learned; the correct answer is marked.',
                      ),
              ),
            if (answered) notice('${q['reference']}'),
          ],
        ),
      ),
    );
  }

  Future<void> refreshWallet() async {
    final owner = uid;
    if (owner.isEmpty) return;
    final data = obj(await rpc('rawda_bootstrap'));
    if (!mounted || uid != owner) return;
    setState(() => account = data);
    await prefs.setString('account:$owner', jsonEncode(data));
  }

  void openWeekly() {
    push(
      tr('تحدي الأسبوع', 'Weekly challenge'),
      (context) => FutureBuilder<dynamic>(
        future: rpc('rawda_weekly_challenge'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Text(tr('تعذر الاتصال', 'Could not connect'))
                  : const CircularProgressIndicator(),
            );
          }
          final w = obj(snapshot.data);
          return wrapList([
            heading(tr('٢٠ إجابة خلال الأسبوع', '20 answers this week')),
            Text('${w['answered']} / ${w['target']}'),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: ((w['answered'] as num) / 20).clamp(0, 1).toDouble(),
            ),
            notice(
              tr(
                'الأسبوع من الاثنين إلى الأحد بتوقيت القاهرة. المكافأة ١٠ نقاط مرة واحدة.',
                'Weeks run Monday–Sunday, Cairo time. Earn a one-time 10-point bonus.',
              ),
            ),
            FilledButton(
              onPressed: w['claimed'] == true
                  ? null
                  : () => run(() async {
                      await rpc('rawda_claim_weekly');
                      await refreshWallet();
                      toast(
                        tr('تم استلام مكافأة الأسبوع', 'Weekly bonus received'),
                      );
                      nav.currentState?.pop();
                    }),
              child: Text(
                w['claimed'] == true
                    ? tr('تم الاستلام', 'Claimed')
                    : tr('استلم المكافأة', 'Claim bonus'),
              ),
            ),
          ]);
        },
      ),
    );
  }

  void openLeaderboard() {
    push(
      tr('ترتيب الأسبوع', 'Weekly leaderboard'),
      (context) => FutureBuilder<dynamic>(
        future: rpc('rawda_leaderboard'),
        builder: (context, s) {
          if (!s.hasData) {
            return Center(
              child: Text(
                s.hasError
                    ? tr('تعذر الاتصال', 'Could not connect')
                    : tr('جارٍ التحميل…', 'Loading…'),
              ),
            );
          }
          final rows = s.data as List;
          return wrapList([
            notice(
              tr(
                'يعتمد الترتيب على إجابات المسابقة فقط. المشاركة اختيارية من حسابك.',
                'Rankings use quiz answers only. Participation is opt-in from your profile.',
              ),
            ),
            if (rows.isEmpty)
              Text(tr('لا توجد مشاركات معلنة بعد.', 'No public entries yet.')),
            for (var i = 0; i < rows.length; i++)
              ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text('${rows[i]['display_name']}'),
                trailing: Text('${rows[i]['score']}'),
              ),
          ]);
        },
      ),
    );
  }

  Widget gifts() {
    final rewards = account['rewards'] as List? ?? [];
    final owned = account['redemptions'] as List? ?? [];
    return wrapList([
      sectionHero(
        tr('هدايا الروضة', 'Rawda gifts'),
        tr('إنجازات صغيرة تستحق التقدير', 'Celebrate each small achievement'),
        Icons.card_giftcard_outlined,
      ),
      const SizedBox(height: 16),
      Text(tr('رصيدك: $balance نقطة', 'Your balance: $balance points')),
      notice(
        tr(
          'هذه هدايا رقمية داخل التطبيق؛ النقاط ليس لها مقابل نقدي.',
          'These are digital in-app rewards; points have no cash value.',
        ),
      ),
      for (final item in rewards)
        Card(
          child: ListTile(
            leading: Icon(
              item['kind'] == 'theme'
                  ? Icons.palette_outlined
                  : item['kind'] == 'badge'
                  ? Icons.workspace_premium_outlined
                  : Icons.badge_outlined,
            ),
            title: Text('${item[ar ? 'title_ar' : 'title_en']}'),
            subtitle: Text('${item['cost']} ${tr('نقطة', 'points')}'),
            trailing: TextButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      final has = owned.any(
                        (r) => r['reward_id'] == item['id'],
                      );
                      if (!has) {
                        await rpc(
                          'rawda_redeem',
                          params: {'p_reward_id': item['id']},
                        );
                        await refreshWallet();
                      }
                      state[item['kind']] = item['asset_key'];
                      await saveState();
                      toast(tr('تم تفعيل الهدية', 'Reward applied'));
                    }),
              child: Text(
                owned.any((r) => r['reward_id'] == item['id'])
                    ? tr('تفعيل', 'Apply')
                    : tr('استبدال', 'Redeem'),
              ),
            ),
          ),
        ),
      if (owned.isNotEmpty) heading(tr('سجل الاستبدال', 'Redemption history')),
      for (final r in owned)
        ListTile(
          title: Text('${r['reward_id']}'),
          subtitle: Text('${r['created_at']}'.split('T').first),
          trailing: Text('-${r['cost_paid']}'),
        ),
    ]);
  }

  Widget profile() {
    final p = account['profile'] ?? {};
    final bookmarks = state['bookmarks'] as List? ?? [];
    return wrapList([
      profileHeader(),
      tile(
        tr('تعديل بيانات الحساب', 'Edit profile details'),
        Icons.manage_accounts_outlined,
        editProfile,
        subtitle: tr(
          'الصورة والاسم ورقم الهاتف والعنوان',
          'Photo, name, phone and address',
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              profileLine(
                Icons.email_outlined,
                tr('الإيميل', 'Email'),
                accountEmail ?? '—',
              ),
              profileLine(
                Icons.phone_outlined,
                tr('رقم الهاتف', 'Phone'),
                '${state['phone'] ?? tr('اختياري — لم يُضف', 'Optional — not added')}',
              ),
              profileLine(
                Icons.location_on_outlined,
                tr('العنوان', 'Address'),
                '${state['address'] ?? tr('اختياري — لم يُضف', 'Optional — not added')}',
              ),
            ],
          ),
        ),
      ),
      if (isAdmin)
        tile(
          tr('لوحة إدارة الروضة', 'Rawda administration'),
          Icons.admin_panel_settings_outlined,
          openAdmin,
        ),
      heading(tr('إنجازاتك', 'Your achievements')),
      Text(
        tr(
          'صلوات مسجلة: ${state.keys.where((k) => k.startsWith('prayer:')).length} • أذكار مسجلة: ${state.keys.where((k) => k.startsWith('adhkar:')).length}',
          'Recorded prayers: ${state.keys.where((k) => k.startsWith('prayer:')).length} • Recorded adhkar: ${state.keys.where((k) => k.startsWith('adhkar:')).length}',
        ),
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          Chip(label: Text(tr('النقاط: $balance', 'Points: $balance'))),
          Chip(
            label: Text(
              tr('المستوى: ${earned ~/ 50 + 1}', 'Level: ${earned ~/ 50 + 1}'),
            ),
          ),
          Chip(
            label: Text(tr('إجمالي المكتسب: $earned', 'Total earned: $earned')),
          ),
          Chip(
            label: Text(
              tr(
                'العلامات: ${bookmarks.length}',
                'Bookmarks: ${bookmarks.length}',
              ),
            ),
          ),
        ],
      ),
      tile(
        tr('تعديل الاسم', 'Edit display name'),
        Icons.edit_outlined,
        () => editName(),
      ),
      SwitchListTile(
        title: Text(
          tr('المشاركة في ترتيب الأسبوع', 'Join the weekly leaderboard'),
        ),
        subtitle: Text(
          tr(
            'يظهر اسمك ونتيجة المسابقة فقط.',
            'Only your display name and quiz score are shown.',
          ),
        ),
        value: p['leaderboard_opt_in'] == true,
        onChanged: (v) => run(() async {
          await updateProfile({'leaderboard_opt_in': v}, uid);
          await refreshWallet();
        }),
      ),
      tile(
        tr('سجل النقاط والإنجازات', 'Points & achievement history'),
        Icons.history,
        openHistory,
      ),
      tile(tr('الإعدادات', 'Settings'), Icons.settings_outlined, settings),
      tile(
        tr('تغيير كلمة المرور', 'Change password'),
        Icons.lock_outline,
        changePassword,
      ),
      tile(
        tr('عن الروضة والمصادر', 'About & sources'),
        Icons.info_outline,
        about,
      ),
      TextButton(
        onPressed: signOut,
        child: Text(tr('تسجيل الخروج', 'Sign out')),
      ),
      TextButton(
        onPressed: deleteAccount,
        child: Text(tr('حذف الحساب وبياناته', 'Delete account and its data')),
      ),
    ]);
  }

  Future<void> editName() async {
    final c = TextEditingController(
      text: account['profile']?['display_name']?.toString() ?? '',
    );
    final value = await showDialog<String>(
      context: nav.currentContext!,
      builder: (context) => AlertDialog(
        title: Text(tr('الاسم', 'Name')),
        content: TextField(controller: c, maxLength: 60),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: Text(tr('حفظ', 'Save')),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      await run(() async {
        await updateProfile({'display_name': value}, uid);
        await refreshWallet();
      });
    }
  }

  void openHistory() {
    push(
      tr('سجل النقاط', 'Points history'),
      (context) => FutureBuilder<dynamic>(
        future: pointHistory(),
        builder: (context, s) {
          if (!s.hasData) {
            return Center(
              child: Text(
                s.hasError
                    ? tr('تعذر الاتصال', 'Could not connect')
                    : tr('جارٍ التحميل…', 'Loading…'),
              ),
            );
          }
          return wrapList([
            for (final row in s.data as List)
              ListTile(
                title: Text('${row['event_key']}'),
                subtitle: Text('${row['created_at']}'.split('T').first),
                trailing: Text('${row['delta']}'),
              ),
          ]);
        },
      ),
    );
  }

  Future<void> changePassword() async {
    if (!signed) return;
    final c = TextEditingController();
    final value = await showDialog<String>(
      context: nav.currentContext!,
      builder: (context) => AlertDialog(
        title: Text(tr('كلمة مرور جديدة', 'New password')),
        content: TextField(
          controller: c,
          obscureText: true,
          decoration: InputDecoration(
            helperText: tr('٨ أحرف على الأقل', 'At least 8 characters'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () {
              if (c.text.length >= 8) Navigator.pop(context, c.text);
            },
            child: Text(tr('حفظ', 'Save')),
          ),
        ],
      ),
    );
    if (value != null) {
      await run(() async {
        final backend = firebase;
        if (backend == null) {
          await db.auth.updateUser(UserAttributes(password: value));
        } else {
          await backend.auth.currentUser!.updatePassword(value);
        }
        toast(tr('تم تغيير كلمة المرور', 'Password changed'));
      });
    }
  }

  Future<void> markDeletionPending(String owner) async {
    await prefs.setBool('firebase-deleting:$owner', true);
    await prefs.remove('state:$owner');
    await prefs.remove('account:$owner');
    if (!mounted || uid != owner) return;
    setState(() {
      _deletionPending = true;
      ready = false;
      account = {};
      state = {};
      quiz = [];
      problem = tr(
        'حذف الحساب بدأ. كمّل الحذف لو العملية وقفت.',
        'Account deletion has started. You can finish it if interrupted.',
      );
    });
    nav.currentState?.popUntil((route) => route.isFirst);
  }

  Future<String?> deletionPassword() async {
    String password = '';
    return showDialog<String>(
      context: nav.currentContext!,
      builder: (context) => AlertDialog(
        title: Text(tr('أكّد كلمة المرور', 'Confirm your password')),
        content: TextField(
          obscureText: true,
          onChanged: (value) => password = value,
          decoration: InputDecoration(labelText: tr('كلمة المرور', 'Password')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (password.isNotEmpty) Navigator.pop(context, password);
            },
            child: Text(tr('حذف نهائي', 'Delete permanently')),
          ),
        ],
      ),
    );
  }

  Future<void> deleteAccount() async {
    final ok = await showDialog<bool>(
      context: nav.currentContext!,
      builder: (context) => AlertDialog(
        title: Text(tr('حذف الحساب نهائيًا؟', 'Delete account permanently?')),
        content: Text(
          tr(
            'سيُحذف رصيدك وسجلّك وبياناتك المحفوظة. لا يمكن التراجع.',
            'Your points, history and saved data will be deleted. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('حذف نهائي', 'Delete permanently')),
          ),
        ],
      ),
    );
    if (ok == true) {
      final backend = firebase;
      final id = uid;
      final password = backend == null ? null : await deletionPassword();
      if (backend != null && password == null) return;
      await run(() async {
        if (uid != id) throw StateError('ACCOUNT_CHANGED');
        if (backend == null) {
          await rpc('rawda_delete_account');
        } else {
          await backend.deleteAccount(password!, () => markDeletionPending(id));
          await prefs.remove('firebase-deleting:$id');
          await prefs.remove(
            'firebase-consent:${RawdaFirebaseBackend.privacyVersion}:$id',
          );
        }
        await prefs.remove('state:$id');
        await prefs.remove('account:$id');
        try {
          await bridge.invokeMethod('clearUserFiles');
        } catch (_) {
          /* Continue clearing the session after server-side deletion. */
        }
        await prefs.remove('prayer_config');
        await prefs.remove('prayer_calendar');
        await prefs.remove('prayer_source_signature');
        await prefs.remove('prayer_location_label');
        config = {};
        calendar = [];
        await signOut();
      });
    }
  }

  void settings() {
    push(
      tr('الإعدادات', 'Settings'),
      (context) => StatefulBuilder(
        builder: (context, update) => refinedSettingsPage(context, update),
      ),
    );
  }

  void prayerSettings() {
    final city = TextEditingController(text: '${config['city'] ?? ''}'),
        country = TextEditingController(
          text: '${config['country'] ?? 'Egypt'}',
        ),
        zone = TextEditingController(text: '${config['timezone'] ?? ''}');
    push(
      tr('الموقع والمواقيت', 'Location & prayer times'),
      (context) => StatefulBuilder(
        builder: (context, update) => wrapList([
          notice(
            tr(
              'اختر GPS أو اكتب المدينة والدولة. الدقة تعتمد على الموقع وطريقة الحساب والضبط المحلي.',
              'Choose GPS or enter a city and country. Accuracy depends on location, calculation method and local adjustments.',
            ),
          ),
          FilledButton.icon(
            onPressed: () => run(() async {
              final p = obj(await bridge.invokeMethod('locate'));
              config['lat'] = p['lat'];
              config['lon'] = p['lon'];
              await persistConfig();
              update(() {});
              await fetchTimes();
              toast(
                tr(
                  'تم تحديث المواقيت حسب موقعك',
                  'Prayer times updated for your location',
                ),
              );
            }),
            icon: const Icon(Icons.my_location),
            label: Text(tr('استخدم موقعي الحالي', 'Use current location')),
          ),
          if (config['lat'] != null)
            notice('${config['lat']}, ${config['lon']}'),
          const SizedBox(height: 15),
          TextField(
            controller: city,
            decoration: InputDecoration(
              labelText: tr(
                'المدينة، مثال Alexandria',
                'City, e.g. Alexandria',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: country,
            decoration: InputDecoration(
              labelText: tr('الدولة، مثال Egypt', 'Country, e.g. Egypt'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: zone,
            decoration: InputDecoration(
              labelText: tr(
                'منطقة زمنية اختيارية، مثال Africa/Cairo',
                'Optional time zone, e.g. Africa/Cairo',
              ),
              helperText: tr(
                'فارغ = المنطقة التي يحددها مصدر المواقيت',
                'Empty = time zone provided by the prayer service',
              ),
            ),
          ),
          TextButton(
            onPressed: () => run(() async {
              if (city.text.trim().isEmpty || country.text.trim().isEmpty) {
                toast(tr('اكتب المدينة والدولة', 'Enter city and country'));
                return;
              }
              config.remove('lat');
              config.remove('lon');
              config['city'] = city.text.trim();
              config['country'] = country.text.trim();
              config['timezone'] = zone.text.trim();
              await persistConfig();
              await fetchTimes();
              update(() {});
            }),
            child: Text(
              tr('حفظ المدينة وتحديث المواقيت', 'Save city & update times'),
            ),
          ),
          heading(tr('طريقة الحساب', 'Calculation method')),
          DropdownButtonFormField<int>(
            value: (config['method'] as num?)?.toInt() ?? 5,
            isExpanded: true,
            items: [
              for (final entry in {
                5: tr('الهيئة المصرية للمساحة', 'Egyptian Survey Authority'),
                4: tr('أم القرى — مكة', 'Umm al-Qura, Makkah'),
                3: tr('رابطة العالم الإسلامي', 'Muslim World League'),
                2: tr('أمريكا الشمالية ISNA', 'ISNA, North America'),
                1: tr('كراتشي', 'Karachi'),
                8: tr('الخليج', 'Gulf region'),
              }.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              config['method'] = v;
              persistConfig();
              update(() {});
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            value: (config['school'] as num?)?.toInt() ?? 0,
            decoration: InputDecoration(
              labelText: tr('حساب العصر', 'Asr calculation'),
            ),
            items: [
              DropdownMenuItem(
                value: 0,
                child: Text(tr('الجمهور', 'Standard')),
              ),
              DropdownMenuItem(value: 1, child: Text(tr('الحنفي', 'Hanafi'))),
            ],
            onChanged: (v) {
              config['school'] = v;
              persistConfig();
              update(() {});
            },
          ),
          heading(tr('ضبط الدقائق لكل صلاة', 'Minute adjustments')),
          for (final key in prayerKeys)
            Row(
              children: [
                Expanded(
                  child: Text(ar ? prayerArabic[prayerKeys.indexOf(key)] : key),
                ),
                IconButton(
                  onPressed: () {
                    config['tune$key'] =
                        ((config['tune$key'] as num?)?.toInt() ?? 0) - 1;
                    persistConfig();
                    update(() {});
                  },
                  icon: const Icon(Icons.remove),
                ),
                Text('${config['tune$key'] ?? 0}'),
                IconButton(
                  onPressed: () {
                    config['tune$key'] =
                        ((config['tune$key'] as num?)?.toInt() ?? 0) + 1;
                    persistConfig();
                    update(() {});
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          FilledButton(
            onPressed: () => run(() async {
              config['timezone'] = zone.text.trim();
              await persistConfig();
              await fetchTimes();
              update(() {});
              toast(
                tr(
                  'تم تحديث المواقيت وجدولة التنبيهات',
                  'Times and alarms updated',
                ),
              );
            }),
            child: Text(tr('تطبيق وتحديث المواقيت', 'Apply & refresh times')),
          ),
          notice(
            tr(
              'المصدر AlAdhan. المواقيت محملة للشهر الحالي والتالي؛ افتح التطبيق وحدّثها قبل انتهاء المدة. المنطقة: ${today?['meta']?['timezone'] ?? '—'}',
              'Source: AlAdhan. Times cover this month and next; refresh before they expire. Zone: ${today?['meta']?['timezone'] ?? '—'}',
            ),
          ),
          tile(
            tr('أصوات الأذان والتنبيهات', 'Adhan voices & alerts'),
            Icons.volume_up_outlined,
            openAudio,
          ),
        ]),
      ),
    );
  }

  Future<void> syncPrayerNotification() async {
    final prayers = <Map<String, dynamic>>[];
    for (final row in calendar) {
      final hijri = row['date']?['hijri'];
      for (var i = 0; i < 5; i++) {
        final at = DateTime.tryParse('${row['timings'][prayerKeys[i]]}');
        if (at == null) continue;
        prayers.add({
          'at': at.millisecondsSinceEpoch,
          'name_ar': prayerArabic[i],
          'name_en': prayerKeys[i],
          'zone': prayerZoneForRow(row, config) ?? '',
          'hijri_ar': hijri == null
              ? ''
              : '${hijri['day'] ?? ''} ${hijri['month']?['ar'] ?? ''} ${hijri['year'] ?? ''} هـ',
          'hijri_en': hijri == null
              ? ''
              : '${hijri['day'] ?? ''} ${hijri['month']?['en'] ?? ''} ${hijri['year'] ?? ''} AH',
        });
      }
    }
    await bridge.invokeMethod('prayerNotifications', {
      'prayers': prayers,
      'options': {
        'ongoing': config['ongoingNotification'] != false,
        'picture': config['pictureNotification'] != false,
        'fullScreenAlarm': config['fullScreenAlarm'] != false,
        'ar': ar,
        'clock24': config['clock24'] == true,
      },
    });
  }

  void openPrayerNotifications() {
    push(
      tr('إشعارات الصلاة والإقامة', 'Prayer notifications & iqama'),
      (context) => StatefulBuilder(
        builder: (context, update) => wrapList([
          heading(tr('صلاتك، أقرب إليك', 'Your prayer at a glance')),
          notice(
            tr(
              'الصلاة القادمة ومواعيدها، وإقامة بصوت تختاره.',
              'Your next prayer at a glance, and an iqama voice you choose.',
            ),
          ),
          SwitchListTile(
            title: Text(tr('إشعار الصلاة القادمة', 'Next-prayer notification')),
            subtitle: Text(
              tr(
                'اسم الصلاة وموعدها وعدّ تنازلي في شريط الإشعارات',
                'Prayer name, time and live countdown',
              ),
            ),
            value: config['ongoingNotification'] != false,
            onChanged: (v) => run(() async {
              config['ongoingNotification'] = v;
              await bridge.invokeMethod('clearNextDismissal');
              await persistConfig();
              await syncPrayerNotification();
              update(() {});
              if (v && !notifications) {
                toast(
                  tr(
                    'اسمح بإشعارات الروضة من إعدادات الهاتف لعرض البطاقة.',
                    'Allow Rawda notifications in phone settings to show this card.',
                  ),
                );
              }
            }),
          ),
          SwitchListTile(
            title: Text(
              tr('بطاقة مصوّرة عند الصلاة', 'Illustrated prayer alert'),
            ),
            subtitle: Text(
              tr(
                'رسمة مسجد وألوان الروضة عند توسيع الإشعار',
                'Rawda’s mosque artwork in the expanded notification',
              ),
            ),
            value: config['pictureNotification'] != false,
            onChanged: (v) => run(() async {
              config['pictureNotification'] = v;
              await persistConfig();
              await syncPrayerNotification();
              update(() {});
            }),
          ),
          OutlinedButton.icon(
            onPressed: () => run(() async {
              await bridge.invokeMethod('previewPrayerCard', {
                'title': tr('حان وقت الصلاة', 'Time for prayer'),
                'ar': ar,
                'prayer': 1,
              });
              toast(
                tr(
                  'افتح شريط الإشعارات ووسّع بطاقة المعاينة.',
                  'Open the notification shade and expand the preview.',
                ),
              );
            }),
            icon: const Icon(Icons.image_outlined),
            label: Text(
              tr('جرّب الإشعار المصوّر', 'Preview illustrated notification'),
            ),
          ),
          notice(
            tr(
              'إخفاء البطاقة لا يوقف الأذان. لإعادتها، فعّلها من هنا.',
              'Hiding this card keeps prayer alerts enabled. Switch it on here to show it again.',
            ),
          ),
          SwitchListTile(
            title: Text(
              tr('شاشة كاملة للأذان والإقامة', 'Full-screen prayer alarms'),
            ),
            subtitle: Text(
              tr(
                'تظهر فوق القفل إذا سمح نظام الهاتف.',
                'Shown over the lock screen when Android allows it.',
              ),
            ),
            value: config['fullScreenAlarm'] != false,
            onChanged: (value) async {
              config['fullScreenAlarm'] = value;
              await persistConfig();
              await syncPrayerNotification();
              if (context.mounted) update(() {});
            },
          ),
          if (defaultTargetPlatform == TargetPlatform.android)
            tile(
              tr('إذن شاشة التنبيه الكاملة', 'Full-screen alarm permission'),
              Icons.fullscreen,
              () => run(() async {
                final opened = await bridge.invokeMethod<bool>(
                  'fullScreenAlarmPermission',
                );
                if (opened != true) {
                  toast(
                    tr(
                      'الإذن المنفصل متاح بدءًا من Android 14.',
                      'Separate permission is available from Android 14.',
                    ),
                  );
                }
              }),
            ),
          heading(tr('قد قامت الصلاة', 'Time for iqama')),
          SwitchListTile(
            title: Text(tr('تشغيل صوت الإقامة', 'Play iqama audio')),
            subtitle: Text(
              tr(
                'عند موعد الإقامة الذي تحدده لكل صلاة',
                'At the delay you choose for each prayer',
              ),
            ),
            value: config['iqamaAudio'] != false,
            onChanged: (v) => run(() async {
              config['iqamaAudio'] = v;
              await persistConfig();
              await schedule();
              update(() {});
            }),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: (config['iqamaSound'] ?? 'iqama').toString().startsWith('/')
                ? 'local'
                : (config['iqamaSound'] ?? 'iqama').toString(),
            decoration: InputDecoration(
              labelText: tr(
                'تسجيل الإقامة • لكل الصلوات',
                'Iqama recording • all prayers',
              ),
            ),
            items: [
              DropdownMenuItem(
                value: 'iqama',
                child: Text(
                  tr(
                    'إقامة كاملة • تسجيل مدمج',
                    'Full iqama • built-in recording',
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'local',
                child: Text(
                  tr('تسجيل إقامة من هاتفي', 'Iqama recording from my phone'),
                ),
              ),
              DropdownMenuItem(
                value: 'silent',
                child: Text(
                  tr(
                    'إشعار «قد قامت الصلاة» فقط',
                    '“Time for iqama” notification only',
                  ),
                ),
              ),
            ],
            onChanged: (v) => run(() async {
              if (v == 'local') {
                final file = await bridge.invokeMethod<String>('pickAudio');
                if (file == null) return;
                config['iqamaSound'] = file;
              } else {
                config['iqamaSound'] = v;
              }
              await persistConfig();
              await schedule();
              update(() {});
            }),
          ),
          const SizedBox(height: 16),
          Text(tr('مستوى صوت الإقامة', 'Iqama volume')),
          Slider(
            value: ((config['iqamaVolume'] as num?)?.toDouble() ?? 1).clamp(
              0,
              1,
            ),
            label:
                '${(((config['iqamaVolume'] as num?)?.toDouble() ?? 1) * 100).round()}%',
            divisions: 20,
            onChanged: (v) => update(() => config['iqamaVolume'] = v),
            onChangeEnd: (_) => run(() async {
              await persistConfig();
              await schedule();
            }),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => run(() async {
                    await bridge.invokeMethod('preview', {
                      'sound': config['iqamaSound'] ?? 'iqama',
                      'short': false,
                      'volume': config['iqamaVolume'] ?? 1.0,
                      'kind': 'iqama',
                      'ar': ar,
                    });
                  }),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(tr('اسمع الإقامة', 'Listen to iqama')),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => bridge.invokeMethod('stopAudio'),
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: tr('إيقاف الصوت', 'Stop audio'),
              ),
            ],
          ),
          tile(
            tr('ضبط مدة الإقامة لكل صلاة', 'Set iqama delay for each prayer'),
            Icons.timer_outlined,
            openAudio,
            subtitle: tr('من ٥ إلى ٣٠ دقيقة، أو إيقاف', '5–30 minutes, or off'),
          ),
          notice(
            tr(
              'مدة الإقامة تذكير شخصي حسب اختيارك، وليست موعد مسجدك الفعلي. إيقاف تنبيهات صلاة يوقف أذانها وتذكير إقامتها. مستوى الصوت يتأثر أيضًا بإعدادات المنبّه وعدم الإزعاج في الهاتف.',
              'Iqama delay is a personal reminder, not your mosque’s confirmed iqama time. Disabling a prayer’s alerts stops its adhan and iqama. Phone alarm volume and Do Not Disturb also affect sound.',
            ),
          ),
          FilledButton.icon(
            onPressed: () => run(() async {
              await status();
              if (!exact || !notifications) {
                openPermissions();
                return;
              }
              await bridge.invokeMethod('testAlarm', {
                'kind': 'iqama',
                'sound': config['iqamaSound'] == 'silent'
                    ? 'iqama'
                    : config['iqamaSound'] ?? 'iqama',
                'volume': config['iqamaVolume'] ?? 1.0,
                'ar': ar,
              });
              toast(
                tr(
                  'تم ضبط اختبار الإقامة بعد دقيقة. اقفل الشاشة لاختباره.',
                  'Iqama test scheduled in one minute. Lock your screen to test it.',
                ),
              );
            }),
            icon: const Icon(Icons.alarm_on_outlined),
            label: Text(
              tr('اختبار الإقامة بعد دقيقة', 'Test iqama in one minute'),
            ),
          ),
          tile(
            tr('الصلاحيات وإعدادات الهاتف', 'Phone permissions & settings'),
            Icons.settings_outlined,
            openPermissions,
          ),
          notice(
            tr(
              'تسجيل الإقامة: Iqamah.ogg للمساهم Aishatu98، منشور بترخيص CC0. يعمل التسجيل المدمج دون إنترنت.',
              'Iqama recording: Iqamah.ogg by Aishatu98, CC0. The bundled recording plays offline.',
            ),
          ),
        ]),
      ),
    );
  }

  void openAudio() {
    push(
      tr('الأذان لكل صلاة', 'Adhan for each prayer'),
      (context) => StatefulBuilder(
        builder: (context, update) => wrapList([
          tile(
            tr(
              'إشعارات الصلاة وصوت الإقامة',
              'Prayer notifications & iqama voice',
            ),
            Icons.notifications_active_outlined,
            openPrayerNotifications,
          ),
          SwitchListTile(
            title: Text(tr('تفعيل تنبيهات الصلاة', 'Enable prayer alerts')),
            value: config['alerts'] == true,
            onChanged: (v) async {
              config['alerts'] = v;
              await persistConfig();
              await schedule();
              update(() {});
              if (v && (!exact || !notifications)) openPermissions();
            },
          ),
          tile(
            tr('مكتبة أصوات الأذان', 'Adhan voice library'),
            Icons.library_music_outlined,
            openVoiceLibrary,
          ),
          notice(
            tr(
              'التسجيل المدمج: آدم سيناغدا • CC0. يمكنك اختيار تسجيل آخر من جهازك. الملفات المحلية لا تنتقل لجهاز آخر مع الحساب.',
              'Built-in: Adam-synagda • CC0. You can choose a recording from your device. Local audio files do not sync to other devices.',
            ),
          ),
          for (var i = 0; i < 5; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(ar ? prayerArabic[i] : prayerKeys[i]),
                      subtitle: Text(
                        tr(
                          'صلاة مفروضة • المفتاح يتحكم في التنبيه فقط',
                          'Obligatory prayer • switch controls alerts only',
                        ),
                      ),
                      value: config['enabled${prayerKeys[i]}'] != false,
                      onChanged: (v) async {
                        config['enabled${prayerKeys[i]}'] = v;
                        await persistConfig();
                        await schedule();
                        update(() {});
                      },
                    ),
                    Slider(
                      value:
                          ((config['volume${prayerKeys[i]}'] as num?)
                                      ?.toDouble() ??
                                  1.0)
                              .clamp(0.0, 1.0),
                      divisions: 10,
                      label:
                          '${(((config['volume${prayerKeys[i]}'] as num?)?.toDouble() ?? 1.0) * 100).round()}%',
                      onChanged: (v) {
                        config['volume${prayerKeys[i]}'] = v;
                        update(() {});
                      },
                      onChangeEnd: (v) async {
                        await persistConfig();
                        await schedule();
                      },
                    ),
                    Text(tr('مستوى صوت الأذان', 'Adhan volume')),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value:
                          (config['sound${prayerKeys[i]}'] ?? 'builtin')
                              .toString()
                              .startsWith('/')
                          ? 'local'
                          : (config['sound${prayerKeys[i]}'] ?? 'builtin')
                                .toString(),
                      items: [
                        DropdownMenuItem(
                          value: 'builtin',
                          child: Text(
                            tr('أذان آدم — مدمج', 'Adam adhan — built-in'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'local',
                          child: Text(
                            (config['sound${prayerKeys[i]}'] ?? '')
                                    .toString()
                                    .startsWith('/')
                                ? voiceName(prayerKeys[i])
                                : tr('ملف من جهازي', 'Audio from my device'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'silent',
                          child: Text(tr('إشعار فقط', 'Notification only')),
                        ),
                      ],
                      onChanged: (v) async {
                        if (v == 'local') {
                          final file = await bridge.invokeMethod<String>(
                            'pickAudio',
                          );
                          if (file == null) return;
                          config['sound${prayerKeys[i]}'] = file;
                          config['soundName${prayerKeys[i]}'] = tr(
                            'تسجيل من جهازي',
                            'Recording from my device',
                          );
                        } else {
                          config['sound${prayerKeys[i]}'] = v;
                        }
                        await persistConfig();
                        await schedule();
                        update(() {});
                      },
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => bridge.invokeMethod('preview', {
                            'sound':
                                config['sound${prayerKeys[i]}'] ?? 'builtin',
                            'short': config['short${prayerKeys[i]}'] == true,
                            'volume': config['volume${prayerKeys[i]}'] ?? 1.0,
                          }),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(tr('معاينة', 'Preview')),
                        ),
                        TextButton(
                          onPressed: () => bridge.invokeMethod('stopAudio'),
                          child: Text(tr('إيقاف', 'Stop')),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: Text(
                        tr(
                          'تشغيل أول ٢٠ ثانية فقط',
                          'Play first 20 seconds only',
                        ),
                      ),
                      value: config['short${prayerKeys[i]}'] == true,
                      onChanged: (v) async {
                        config['short${prayerKeys[i]}'] = v;
                        await persistConfig();
                        await schedule();
                        update(() {});
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr('تنبيه قبل الصلاة', 'Minutes before prayer'),
                          ),
                        ),
                        DropdownButton<int>(
                          value:
                              (config['pre${prayerKeys[i]}'] as num?)
                                  ?.toInt() ??
                              10,
                          items: [
                            for (final n in [0, 5, 10, 15, 20, 30])
                              DropdownMenuItem(value: n, child: Text('$n')),
                          ],
                          onChanged: (v) async {
                            config['pre${prayerKeys[i]}'] = v;
                            await persistConfig();
                            await schedule();
                            update(() {});
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr(
                              'تذكير الإقامة بعد الصلاة',
                              'Iqama reminder after prayer',
                            ),
                          ),
                        ),
                        DropdownButton<int>(
                          value:
                              (config['iqama${prayerKeys[i]}'] as num?)
                                  ?.toInt() ??
                              15,
                          items: [
                            for (final n in [0, 5, 10, 15, 20, 25, 30])
                              DropdownMenuItem(value: n, child: Text('$n')),
                          ],
                          onChanged: (v) async {
                            config['iqama${prayerKeys[i]}'] = v;
                            await persistConfig();
                            await schedule();
                            update(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          tile(
            tr(
              'الصلاحيات واختبار الشاشة المقفولة',
              'Permissions & locked-screen test',
            ),
            Icons.alarm_outlined,
            openPermissions,
          ),
        ]),
      ),
    );
  }

  void openReminders() {
    push(
      tr('التذكيرات', 'Reminders'),
      (context) => StatefulBuilder(
        builder: (context, update) => wrapList([
          notice(
            tr(
              'تحتاج مواقيت محمّلة وتفعيل التنبيهات وأذونات أندرويد. مواعيد التذكير تقريبية حسب اختيارك وليست أحكامًا على وقت العبادة.',
              'Requires loaded times, enabled alerts and Android permissions. These are reminder choices, not religious rulings on worship times.',
            ),
          ),
          for (final e in {
            'Sunrise': tr(
              'الشروق — قبله بعشر دقائق',
              'Sunrise — 10 min before',
            ),
            'Morning': tr(
              'الصباح — بعد الفجر بنصف ساعة',
              'Morning — 30 min after Fajr',
            ),
            'Evening': tr(
              'المساء — قبل المغرب بنصف ساعة',
              'Evening — 30 min before Maghrib',
            ),
            'Duha': tr('تذكير صلاة الضحى', 'Duha reminder'),
            'Qiyam': tr('تذكير قيام الليل', 'Night prayer reminder'),
            'Quran': tr(
              'ورد القرآن — بعد المغرب بنصف ساعة',
              'Quran — 30 min after Maghrib',
            ),
            'Kahf': tr(
              'الكهف — الجمعة قبل المغرب بثلاث ساعات',
              'Al-Kahf — Friday, 3 hours before Maghrib',
            ),
            'Fasting': tr(
              'صيام الاثنين والخميس — قبل الفجر بساعة',
              'Mon/Thu fasting — 1 hour before Fajr',
            ),
          }.entries)
            SwitchListTile(
              title: Text(e.value),
              value: config['reminder${e.key}'] == true,
              onChanged: (v) async {
                config['reminder${e.key}'] = v;
                await persistConfig();
                await schedule();
                update(() {});
              },
            ),
          heading(tr('تخصيص وقت التذكير', 'Reminder timing')),
          DropdownButtonFormField<int>(
            value: (config['duhaMinutes'] as num?)?.toInt() ?? 30,
            decoration: InputDecoration(
              labelText: tr(
                'الضحى — دقائق بعد الشروق',
                'Duha — minutes after sunrise',
              ),
            ),
            items: [
              for (final n in [15, 30, 45, 60])
                DropdownMenuItem(value: n, child: Text('$n')),
            ],
            onChanged: (v) async {
              config['duhaMinutes'] = v;
              await persistConfig();
              await schedule();
              update(() {});
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: (config['qiyamMinutes'] as num?)?.toInt() ?? 60,
            decoration: InputDecoration(
              labelText: tr(
                'القيام — دقائق قبل الفجر',
                'Night prayer — minutes before Fajr',
              ),
            ),
            items: [
              for (final n in [30, 60, 90, 120])
                DropdownMenuItem(value: n, child: Text('$n')),
            ],
            onChanged: (v) async {
              config['qiyamMinutes'] = v;
              await persistConfig();
              await schedule();
              update(() {});
            },
          ),
        ]),
      ),
    );
  }

  void openPermissions() {
    push(
      tr('صلاحيات الأذان', 'Adhan permissions'),
      (context) => StatefulBuilder(
        builder: (context, update) => wrapList([
          heading(
            tr(
              'اختبر قبل الاعتماد على التنبيه',
              'Test before relying on alerts',
            ),
          ),
          Text(
            tr(
              'إشعارات: ${notifications ? 'مفعّلة' : 'تحتاج إذنًا'} • تنبيه دقيق: ${exact ? 'مفعّل' : 'يحتاج إذنًا'}',
              'Notifications: $notifications • Exact alarms: $exact',
            ),
          ),
          Text(
            tr(
              'عدد التنبيهات المستقبلية: $scheduled',
              'Future scheduled alerts: $scheduled',
            ),
          ),
          tile(
            tr('١. السماح بالإشعارات', '1. Allow notifications'),
            Icons.notifications_outlined,
            () => bridge.invokeMethod('notificationPermission'),
          ),
          tile(
            tr('٢. السماح بالتنبيهات الدقيقة', '2. Allow exact alarms'),
            Icons.alarm,
            () => bridge.invokeMethod('alarmPermission'),
          ),
          tile(
            tr('٣. إعدادات التطبيق والبطارية', '3. App & battery settings'),
            Icons.battery_saver_outlined,
            () => bridge.invokeMethod('appSettings'),
          ),
          FilledButton(
            onPressed: () => run(() async {
              await status();
              await schedule();
              update(() {});
              if (!exact || !notifications) {
                toast(
                  tr('فعّل الإذنين أولًا', 'Enable both permissions first'),
                );
                return;
              }
              await bridge.invokeMethod('testAlarm');
              toast(
                tr(
                  'اقفل الشاشة؛ الاختبار بعد دقيقة.',
                  'Lock your screen; the test starts in one minute.',
                ),
              );
            }),
            child: Text(
              tr('اختبار الأذان بعد دقيقة', 'Test adhan in one minute'),
            ),
          ),
          TextButton(
            onPressed: () => bridge.invokeMethod('stopAudio'),
            child: Text(tr('إيقاف الأذان', 'Stop adhan')),
          ),
          notice(
            tr(
              'على OPPO اسمح للتطبيق بالعمل في الخلفية من إعدادات البطارية إن منع النظام التنبيه. الإيقاف الإجباري للتطبيق يعطّل المنبهات حتى تفتحه مجددًا. احفظ التحديثات وجرّب إعادة تشغيل الهاتف.',
              'If OPPO battery management blocks alerts, allow background activity in system settings. Force-stopping the app disables alarms until you reopen it. Test after restarting your phone.',
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> openQuran() async {
    if (chapters.isEmpty) {
      await loadBooks();
    }
    if (!mounted) return;
    final c = TextEditingController();
    String query = '';
    push(
      tr('القرآن الكريم', 'The Holy Quran'),
      (context) => StatefulBuilder(
        builder: (context, update) {
          final needle = plain(query);
          final hits = needle.isEmpty
              ? <dynamic>[]
              : verses
                    .where(
                      (v) => (v['search'] ?? plain(v['text'].toString()))
                          .toString()
                          .contains(needle),
                    )
                    .take(100)
                    .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: c,
                  onChanged: (v) => update(() => query = v.trim()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: tr(
                      'ابحث باسم سورة أو كلمات آية',
                      'Search surah name or verse text',
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (query.isEmpty) ...[
                      ListTile(
                        title: Text(tr('آخر قراءة', 'Last reading')),
                        subtitle: Text(
                          state['lastSurah'] == null
                              ? tr('ابدأ رحلتك', 'Begin your journey')
                              : '${chapters[(state['lastSurah'] as int) - 1]['name_arabic']} • ${state['lastAyah'] ?? 1}',
                        ),
                        onTap: state['lastSurah'] == null
                            ? null
                            : () => openSurah(
                                state['lastSurah'] as int,
                                initialAyah: (state['lastAyah'] as int?) ?? 1,
                              ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text(tr('علاماتي', 'My bookmarks')),
                        onTap: openBookmarks,
                      ),
                      ListTile(
                        leading: const Icon(Icons.format_list_numbered),
                        title: Text(tr('الأجزاء الثلاثون', 'The 30 juz')),
                        onTap: openJuz,
                      ),
                    ],
                    for (final chapter in chapters.where(
                      (v) =>
                          query.isEmpty ||
                          plain(v['name_arabic'].toString()).contains(needle) ||
                          v['name_simple'].toString().toLowerCase().contains(
                            query.toLowerCase(),
                          ) ||
                          '${v['id']}' == query,
                    ))
                      ListTile(
                        onTap: () => openSurah(chapter['id'] as int),
                        leading: CircleAvatar(child: Text('${chapter['id']}')),
                        title: Text(
                          ar
                              ? 'سورة ${chapter['name_arabic']}'
                              : 'Surah ${chapter['name_simple']}',
                        ),
                        subtitle: Text(
                          '${chapter['verses_count']} ${tr('آية', 'verses')}',
                        ),
                        trailing: TextButton(
                          onPressed: () => openSurah(chapter['id'] as int),
                          child: Text(tr('قراءة', 'Read')),
                        ),
                      ),
                    if (query.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          tr(
                            'نتائج الآيات — أول ١٠٠ نتيجة',
                            'Verse results — first 100 matches',
                          ),
                        ),
                      ),
                      for (final v in hits)
                        ListTile(
                          title: Text(
                            v['text'].toString(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontFamily: 'Quran',
                              fontSize: 23,
                            ),
                          ),
                          subtitle: Text(
                            '${chapters[(v['surah'] as int) - 1]['name_arabic']} • ${v['ayah']}',
                          ),
                          onTap: () => openSurah(
                            v['surah'] as int,
                            initialAyah: v['ayah'] as int,
                          ),
                        ),
                    ],
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        tr(
                          'النص العثماني كما هو من مشروع تنزيل • tanzil.net',
                          'Unmodified Uthmani Quran text • Tanzil Project • tanzil.net',
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void openSurah(int id, {int initialAyah = 1}) {
    final chapter = chapters[id - 1];
    final lines = verses.where((v) => v['surah'] == id).toList();
    final basmala = verses.first['text'].toString();
    final separateBasmala =
        id != 1 &&
        id != 9 &&
        lines.first['text'].toString().startsWith('$basmala ');
    final scroll = ScrollController();
    var start = (initialAyah - 1).clamp(0, lines.length - 1);
    double size = (state['quranSize'] as num?)?.toDouble() ?? 30;
    final centerKey = UniqueKey();
    VoidCallback? refreshReader;
    final keys = List.generate(lines.length, (_) => GlobalKey());
    Widget basmalaHeader() => Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        basmala,
        textDirection: TextDirection.rtl,
        style: TextStyle(fontFamily: 'Quran', fontSize: size, height: 2),
      ),
    );
    Widget verseAt(BuildContext verseContext, int i) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        key: keys[i],
        onTap: () async {
          state['lastSurah'] = id;
          state['lastAyah'] = lines[i]['ayah'];
          await saveState();
          if (verseContext.mounted) refreshReader?.call();
          toast(tr('تم حفظ موضع القراءة', 'Reading position saved'));
        },
        onLongPress: () async {
          final marks = List<dynamic>.from(state['bookmarks'] as List? ?? []);
          if (!marks.any(
            (b) => b['surah'] == id && b['ayah'] == lines[i]['ayah'],
          )) {
            marks.add({'surah': id, 'ayah': lines[i]['ayah']});
          }
          state['bookmarks'] = marks;
          await saveState();
          toast(tr('تمت إضافة علامة', 'Bookmark added'));
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
          decoration: BoxDecoration(
            color:
                state['lastSurah'] == id &&
                    state['lastAyah'] == lines[i]['ayah']
                ? const Color(0x22536B4F)
                : null,
            border: const Border(bottom: BorderSide(color: Color(0x18536B4F))),
          ),
          child: Text(
            '${separateBasmala && i == 0 ? lines[i]['text'].toString().substring(basmala.length + 1) : lines[i]['text']} ﴿${lines[i]['ayah']}﴾',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Quran', fontSize: size, height: 2.0),
          ),
        ),
      ),
    );
    unawaited(
      push(
        ar
            ? 'سورة ${chapter['name_arabic']}'
            : 'Surah ${chapter['name_simple']}',
        (context) => StatefulBuilder(
          builder: (context, update) {
            refreshReader = () => update(() {});
            return Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        size = (size - 2).clamp(20, 48);
                        state['quranSize'] = size;
                        saveState();
                        update(() {});
                      },
                      icon: const Icon(Icons.text_decrease),
                    ),
                    IconButton(
                      onPressed: () {
                        size = (size + 2).clamp(20, 48);
                        state['quranSize'] = size;
                        saveState();
                        update(() {});
                      },
                      icon: const Icon(Icons.text_increase),
                    ),
                    Expanded(
                      child: Text(
                        tr(
                          'اضغط الآية لحفظ موضعك',
                          'Tap a verse to save your place',
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: CustomScrollView(
                    controller: scroll,
                    center: centerKey,
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            if (i == start) return basmalaHeader();
                            return verseAt(context, start - 1 - i);
                          },
                          childCount: start > 0
                              ? start + (separateBasmala ? 1 : 0)
                              : 0,
                        ),
                      ),
                      SliverList(
                        key: centerKey,
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            if (start == 0 && separateBasmala && i == 0) {
                              return basmalaHeader();
                            }
                            return verseAt(
                              context,
                              start +
                                  i -
                                  (start == 0 && separateBasmala ? 1 : 0),
                            );
                          },
                          childCount:
                              lines.length -
                              start +
                              (start == 0 && separateBasmala ? 1 : 0),
                        ),
                      ),
                    ],
                  ),
                ),
                if (defaultTargetPlatform == TargetPlatform.android)
                  QuranAudioControls(surah: id, arabic: ar, preferences: prefs),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    tr(
                      'ضغطة مطولة لإضافة علامة • مصدر النص tanzil.net',
                      'Long-press to bookmark • Quran source: tanzil.net',
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            );
          },
        ),
      ).whenComplete(scroll.dispose),
    );
  }

  void openBookmarks() {
    push(
      tr('علاماتي', 'My bookmarks'),
      (context) => StatefulBuilder(
        builder: (context, update) => wrapList([
          for (final b in List<dynamic>.from(state['bookmarks'] as List? ?? []))
            ListTile(
              title: Text(
                '${chapters[(b['surah'] as int) - 1]['name_arabic']} • ${b['ayah']}',
              ),
              onTap: () =>
                  openSurah(b['surah'] as int, initialAyah: b['ayah'] as int),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  (state['bookmarks'] as List).remove(b);
                  saveState();
                  update(() {});
                },
              ),
            ),
          if ((state['bookmarks'] as List? ?? []).isEmpty)
            Text(
              tr(
                'اضغط مطولًا على آية لإضافة علامة.',
                'Long-press a verse to add a bookmark.',
              ),
            ),
        ]),
      ),
    );
  }

  void openJuz() {
    const starts = [
      (1, 1),
      (2, 142),
      (2, 253),
      (3, 93),
      (4, 24),
      (4, 148),
      (5, 82),
      (6, 111),
      (7, 88),
      (8, 41),
      (9, 93),
      (11, 6),
      (12, 53),
      (15, 1),
      (17, 1),
      (18, 75),
      (21, 1),
      (23, 1),
      (25, 21),
      (27, 56),
      (29, 46),
      (33, 31),
      (36, 28),
      (39, 32),
      (41, 47),
      (46, 1),
      (51, 31),
      (58, 1),
      (67, 1),
      (78, 1),
    ];
    push(
      tr('الأجزاء', 'Juz'),
      (context) => wrapList([
        for (var i = 0; i < 30; i++)
          ListTile(
            title: Text(tr('الجزء ${i + 1}', 'Juz ${i + 1}')),
            subtitle: Text(
              '${chapters[starts[i].$1 - 1]['name_arabic']} • ${starts[i].$2}',
            ),
            onTap: () => openSurah(starts[i].$1, initialAyah: starts[i].$2),
          ),
      ]),
    );
  }

  Future<void> openDaily() async {
    if (verses.isEmpty) {
      await loadBooks();
    }
    if (!mounted) return;
    push(
      tr('وردك وختمتك', 'Daily reading & khatma'),
      (context) => StatefulBuilder(
        builder: (context, update) {
          final started = DateTime.tryParse('${state['khatmaStart']}');
          final days = (state['khatmaDays'] as num?)?.toInt() ?? 30;
          final elapsed = started == null
              ? 0
              : now.difference(started).inDays + 1;
          final dailyVerse =
              verses[now.difference(DateTime(2026)).inDays.abs() %
                  verses.length];
          const sayings = [
            (
              'إنما الأعمال بالنيات',
              'Actions are judged by intentions.',
              'البخاري 1 • sunnah.com/bukhari:1',
            ),
            (
              'خيركم من تعلم القرآن وعلمه',
              'Learn the Quran and share its teaching.',
              'البخاري 5027 • sunnah.com/bukhari:5027',
            ),
            (
              'ومن سلك طريقًا يلتمس فيه علمًا، سهّل الله له به طريقًا إلى الجنة',
              'Seeking knowledge is a path toward Paradise.',
              'مسلم 2699a • sunnah.com/muslim:2699a',
            ),
          ];
          final saying =
              sayings[now.difference(DateTime(2026)).inDays.abs() %
                  sayings.length];
          return wrapList([
            heading(tr('آية اليوم', 'Verse of the day')),
            if (verses.isNotEmpty)
              Text(
                '${verses[now.difference(DateTime(2026)).inDays.abs() % verses.length]['text']}',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'Quran',
                  fontSize: 28,
                  height: 2,
                ),
              ),
            notice(
              '${chapters[(dailyVerse['surah'] as int) - 1]['name_arabic']} • ${dailyVerse['ayah']} • Tanzil Quran Text • tanzil.net',
            ),
            heading(tr('من هدي النبي ﷺ', 'Prophetic guidance')),
            Text(
              saying.$1,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 22, height: 1.8),
            ),
            if (!ar) Text(saying.$2),
            notice(saying.$3),
            heading(tr('خطة ختمة', 'Khatma plan')),
            DropdownButton<int>(
              value: days,
              items: [
                for (final d in [15, 30, 60, 90])
                  DropdownMenuItem(
                    value: d,
                    child: Text(tr('$d يومًا', '$d days')),
                  ),
              ],
              onChanged: (v) {
                state['khatmaDays'] = v;
                saveState();
                update(() {});
              },
            ),
            Text(
              tr(
                'هدف تقريبي: ${(604 / days).ceil()} صفحة يوميًا من مصحف ٦٠٤ صفحات.',
                'Approximate goal: ${(604 / days).ceil()} pages a day in a 604-page mushaf.',
              ),
            ),
            if (started != null)
              Text(tr('اليوم $elapsed من $days', 'Day $elapsed of $days')),
            FilledButton(
              onPressed: () {
                state['khatmaStart'] = DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).toIso8601String();
                saveState();
                update(() {});
              },
              child: Text(tr('ابدأ خطة جديدة', 'Start a new plan')),
            ),
            tile(
              tr('متابعة آخر قراءة', 'Resume reading'),
              Icons.menu_book,
              () => openSurah(
                (state['lastSurah'] as int?) ?? 1,
                initialAyah: (state['lastAyah'] as int?) ?? 1,
              ),
            ),
            notice(
              tr(
                'سجّل موضعك بالضغط على الآية؛ الخطة مساعدة للتنظيم وليست تحققًا تلقائيًا من القراءة.',
                'Tap a verse to save your position. This plan helps organize reading; it does not verify it automatically.',
              ),
            ),
          ]);
        },
      ),
    );
  }

  void openTasbih() {
    int count = (state['tasbih'] as num?)?.toInt() ?? 0;
    String word = 'سبحان الله';
    push(
      tr('المسبحة', 'Tasbih'),
      (context) => StatefulBuilder(
        builder: (context, update) => wrapList([
          DropdownButton<String>(
            value: word,
            isExpanded: true,
            items: [
              for (final s in [
                'سبحان الله',
                'الحمد لله',
                'الله أكبر',
                'لا إله إلا الله',
                'أستغفر الله',
              ])
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => update(() => word = v!),
          ),
          const SizedBox(height: 35),
          Center(
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 72, fontFamily: 'RawdaLatin'),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 150,
            child: FilledButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                update(() => count++);
                state['tasbih'] = count;
                prefs.setString('state:$uid', jsonEncode(state));
              },
              style: FilledButton.styleFrom(shape: const CircleBorder()),
              child: Text(word, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              update(() => count = 0);
              state['tasbih'] = 0;
              saveState();
            },
            child: Text(tr('تصفير العداد', 'Reset counter')),
          ),
          TextButton(
            onPressed: () => saveState(),
            child: Text(tr('حفظ ومزامنة', 'Save & sync')),
          ),
        ]),
      ),
    );
  }

  void openCalendar() {
    push(
      tr('التقويم الهجري', 'Hijri calendar'),
      (context) => wrapList([
        notice(
          tr(
            'التاريخ الهجري حسابي من AlAdhan وقد يختلف يومًا عن رؤية الهلال المحلية.',
            'Hijri dates are calculated by AlAdhan and may differ from local moon sighting.',
          ),
        ),
        if (calendar.isEmpty)
          Text(
            tr(
              'حدّث مواقيت الصلاة لعرض التقويم.',
              'Refresh prayer times to load the calendar.',
            ),
          ),
        for (final r in calendar)
          ListTile(
            title: Text(
              '${r['date']['hijri']['day']} ${r['date']['hijri']['month'][ar ? 'ar' : 'en']} ${r['date']['hijri']['year']}',
            ),
            subtitle: Text('${r['date']['gregorian']['date']}'),
            trailing: r['date']['hijri']['month']['number'] == 9
                ? const Icon(Icons.nightlight_round)
                : null,
          ),
      ]),
    );
  }

  void openQibla() {
    push(tr('القبلة', 'Qibla'), (context) => QiblaScreen(app: this));
  }

  void openAdhkar(String type) {
    push(
      tr('الأذكار', 'Adhkar'),
      (context) => AdhkarScreen(app: this, type: type),
    );
  }

  void about() {
    push(
      tr('عن الروضة', 'About Rawda'),
      (context) => wrapList([
        Center(child: Image.asset('assets/logo.png', width: 110)),
        heading('الروضة • Rawda 1.3'),
        Text(tr('رفيق يومك، بخطوة مطمئنة', 'A little more peace in every day')),
        heading(tr('المصادر والتراخيص', 'Sources & licenses')),
        TextButton(
          onPressed: () => showLicensePage(
            context: nav.currentContext!,
            applicationName: 'Rawda',
            applicationVersion: '1.3',
          ),
          child: Text(tr('عرض التراخيص', 'View licenses')),
        ),
        notice(
          'Quran: Tanzil Quran Text, Uthmani v1.1. Copyright © 2007–2026 Tanzil Project. CC BY 3.0. Text used unchanged. https://tanzil.net • https://tanzil.net/docs/Text_License',
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://tanzil.net'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Tanzil.net'),
        ),
        notice(
          'Surah metadata: Quran Foundation, api.quran.com. Prayer times & Hijri dates: AlAdhan, aladhan.com. Adhan: Beautiful adhan by Adam-synagda, CC0 1.0. Iqama: Iqamah.ogg by Aishatu98, CC0 1.0, Wikimedia Commons, https://commons.wikimedia.org/wiki/File:Iqamah.ogg. Local audio is selected by the user. Fonts: Noto Sans Arabic, Inter, Amiri Quran — SIL Open Font License. Rawda app icon: created for this app.',
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse(
              'https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg',
            ),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(tr('مصدر تسجيل الأذان', 'Adhan recording source')),
        ),
        notice(
          tr(
            'الأسئلة الأولية لها مراجع ظاهرة بعد الإجابة. الأذكار مجموعة مختارة وليست حصرًا لكل الأذكار. الحسابات والنقاط تحتاج إنترنت؛ القرآن والأذكار والمواقيت المحملة تعمل محليًا.',
            'Quiz references are shown after answering. Adhkar are a selection, not a complete collection. Accounts and points need internet; Quran, adhkar and downloaded times work locally.',
          ),
        ),
      ]),
    );
  }
}

extension RawdaButton on ButtonStyle {
  Widget letButton(String label, VoidCallback? action, IconData? icon) =>
      OutlinedButton(
        onPressed: action,
        child: Row(
          children: [
            if (icon != null)
              Icon(
                icon,
                color: icon == Icons.check_circle ? Colors.green : Colors.red,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(label),
              ),
            ),
          ],
        ),
      );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.app});
  final RawdaState app;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  void mutate(VoidCallback action) => setState(action);
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool signup = false, loading = false, reveal = false, messageOk = false;
  bool privacyAccepted = false;
  String? emailError, passwordError, nameError;
  String? message;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit({bool reset = false}) async {
    if (loading) return;
    final a = widget.app;
    final validEmail = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(email.text.trim());
    setState(() {
      emailError = validEmail
          ? null
          : a.tr('اكتب إيميلًا صحيحًا.', 'Enter a valid email.');
      passwordError = reset || password.text.length >= 8
          ? null
          : a.tr(
              'كلمة المرور ٨ أحرف على الأقل.',
              'At least 8 password characters.',
            );
      nameError = !signup || reset || name.text.trim().isNotEmpty
          ? null
          : a.tr('اكتب اسمك.', 'Enter your name.');
      message = null;
      messageOk = false;
    });
    if (emailError != null || passwordError != null || nameError != null) {
      return;
    }
    setState(() {
      loading = true;
      message = null;
    });
    try {
      if (a.firebase != null) {
        await submitFirebase(reset: reset);
        return;
      }
      if (reset) {
        await a.db.auth.resetPasswordForEmail(
          email.text.trim(),
          redirectTo: 'rawda://auth-callback',
        );
        if (mounted) {
          setState(() {
            messageOk = true;
            message = a.tr(
              'راجع إيميلك لرسالة استعادة الحساب.',
              'Check your email for the recovery link.',
            );
          });
        }
      } else if (signup) {
        final r = await a.db.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          emailRedirectTo: 'rawda://auth-callback',
          data: {'display_name': name.text.trim()},
        );
        if (r.session == null && mounted) {
          setState(() {
            messageOk = true;
            message = a.tr(
              'افتح رسالة التأكيد في إيميلك، ثم ارجع لتسجيل الدخول.',
              'Confirm your email, then return to sign in.',
            );
          });
        }
      } else {
        await a.db.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      if (!reset && a.signed) {
        if (signup && name.text.trim().isNotEmpty) {
          await a.rpc('rawda_bootstrap');
          await a.db
              .from('rawda_profiles')
              .update({
                'display_name': name.text.trim().substring(
                  0,
                  math.min(60, name.text.trim().length),
                ),
              })
              .eq('id', a.uid);
        }
        await a.loadAccount();
      }
    } catch (e) {
      if (mounted) setState(() => message = a.err(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showFirebasePrivacy() {
    final a = widget.app;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(a.tr('خصوصية الروضة', 'Rawda privacy')),
        scrollable: true,
        content: Text(
          a.tr(
            'يدير الروضة يوسف حامد. تستخدم نسخة Firebase التجريبية بريدك لتسجيل الدخول والتأكيد واستعادة الحساب. يحفظ Firestore اسم العرض، وموافقتك، وتقدمك، وإجابات المسابقة ونقاطك. رقم الهاتف والعنوان اختياريان داخل الحساب. بعض الإعدادات وبيانات التقدم تُحفظ أيضًا على جهازك. تُستخدم المدينة أو الإحداثيات التي تختارها لطلب مواقيت الصلاة. لطلب الوصول إلى بياناتك أو حذفها تواصل معنا على elrawdasupport@gmail.com.',
            'Rawda is operated by Youssef Hamed. The Firebase preview uses your email for sign-in, verification and account recovery. Firestore stores your display name, consent, progress, quiz answers and points. Phone number and address are optional profile fields. Some settings and progress are also stored on your device. The city or coordinates you choose are used to request prayer times. For data access or deletion requests, contact elrawdasupport@gmail.com.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(a.tr('رجوع', 'Back')),
          ),
        ],
      ),
    );
  }

  Future<void> submitFirebase({required bool reset}) async {
    final a = widget.app;
    final backend = a.firebase!;
    final auth = backend.auth;
    await auth.setLanguageCode(a.ar ? 'ar' : 'en');
    if (reset) {
      await auth.sendPasswordResetEmail(email: email.text.trim());
      if (mounted) {
        setState(() {
          messageOk = true;
          message = a.tr(
            'راجع إيميلك لرابط تغيير كلمة المرور.',
            'Check your email for the reset link.',
          );
        });
      }
      return;
    }
    if (signup && !privacyAccepted) {
      if (mounted) {
        setState(
          () => message = a.tr(
            'وافق على سياسة الخصوصية قبل إنشاء الحساب.',
            'Accept the privacy policy before creating an account.',
          ),
        );
      }
      return;
    }
    if (signup) {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
      final user = credential.user!;
      await a.saveFirebaseConsent(user.uid);
      await user.updateDisplayName(name.text.trim());
      await backend.sendVerification(user);
    } else {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
      final user = credential.user!;
      if (privacyAccepted) await a.saveFirebaseConsent(user.uid);
      if (!a.hasFirebaseConsent(user.uid)) {
        if (mounted) {
          setState(
            () => message = a.tr(
              'اقرأ سياسة الخصوصية ووافق عليها عشان تكمل.',
              'Read and accept the privacy policy to continue.',
            ),
          );
        }
        return;
      }
      if (await backend.refreshVerification()) {
        await a.loadAccount();
        return;
      }
    }
    if (mounted) {
      setState(() {
        messageOk = true;
        message = a.tr(
          'افتح رابط التأكيد في إيميلك، وبعدها دوس «أكدت بريدي».',
          'Open the verification link in your email, then tap “I verified my email”.',
        );
      });
    }
  }

  Future<void> verifyFirebase({bool resend = false}) async {
    if (loading) return;
    final a = widget.app;
    final backend = a.firebase!;
    final user = backend.auth.currentUser;
    if (user == null) return;
    setState(() {
      loading = true;
      message = null;
      messageOk = false;
    });
    try {
      if (privacyAccepted) await a.saveFirebaseConsent(user.uid);
      if (!a.hasFirebaseConsent(user.uid)) {
        setState(
          () => message = a.tr(
            'وافق على سياسة الخصوصية عشان تكمل.',
            'Accept the privacy policy to continue.',
          ),
        );
        return;
      }
      if (await backend.refreshVerification()) {
        await a.loadAccount();
      } else if (resend) {
        await backend.sendVerification(user);
        if (mounted) {
          setState(() {
            messageOk = true;
            message = a.tr(
              'بعتنا رابط تأكيد جديد على إيميلك.',
              'A new verification link was sent.',
            );
          });
        }
      } else if (mounted) {
        setState(
          () => message = a.tr(
            'البريد لسه مش مؤكد. افتح الرابط من رسالة التأكيد.',
            'Your email is not verified yet. Open the link in the verification email.',
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => message = a.err(error));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => authPremium();
}

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key, required this.app});
  final RawdaState app;
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<dynamic>? sub;
  double? heading;
  int accuracy = 0;
  bool available = true;
  double? lat, lon;
  @override
  void initState() {
    super.initState();
    lat = (widget.app.config['lat'] as num?)?.toDouble();
    lon = (widget.app.config['lon'] as num?)?.toDouble();
    start();
  }

  void start() {
    sub = sensors.receiveBroadcastStream().listen(
      (v) {
        if (mounted) {
          setState(() {
            final m = obj(v);
            available = m['available'] != false;
            heading = (m['heading'] as num?)?.toDouble();
            accuracy = (m['accuracy'] as num?)?.toInt() ?? 0;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => available = false);
      },
    );
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    double bearing = 0;
    if (lat != null && lon != null) {
      final x = lat! * math.pi / 180;
      final delta = (39.826206 - lon!) * math.pi / 180;
      final kaaba = 21.422487 * math.pi / 180;
      bearing =
          (math.atan2(
                    math.sin(delta) * math.cos(kaaba),
                    math.cos(x) * math.sin(kaaba) -
                        math.sin(x) * math.cos(kaaba) * math.cos(delta),
                  ) *
                  180 /
                  math.pi +
              360) %
          360;
    }
    return a.wrapList([
      a.notice(
        a.tr(
          'ضع الهاتف أفقيًا، بعيدًا عن المعادن، وحرّكه على شكل ٨ للمعايرة. الاتجاه يتأثر بدقة حساس هاتفك.',
          'Hold your phone flat, away from metal. Move it in a figure-eight to calibrate. Sensor accuracy affects direction.',
        ),
      ),
      FilledButton.icon(
        onPressed: () async {
          try {
            final p = obj(await bridge.invokeMethod('locate'));
            if (mounted) {
              setState(() {
                lat = (p['lat'] as num).toDouble();
                lon = (p['lon'] as num).toDouble();
              });
            }
          } catch (_) {
            a.toast(
              a.tr(
                'تعذّر تحديد الموقع؛ فعّل GPS والصلاحية.',
                'Could not locate you; enable GPS and location permission.',
              ),
            );
          }
        },
        icon: const Icon(Icons.my_location),
        label: Text(a.tr('حدد موقعي للقبلة', 'Locate me for Qibla')),
      ),
      const SizedBox(height: 30),
      if (lat != null && lon != null) ...[
        Center(
          child: Text(
            '${bearing.toStringAsFixed(1)}°',
            style: const TextStyle(fontSize: 36),
          ),
        ),
        const SizedBox(height: 20),
        if (available && heading != null)
          Center(
            child: Transform.rotate(
              angle: (bearing - heading!) * math.pi / 180,
              child: const Icon(
                Icons.navigation,
                size: 150,
                color: Color(0xFFB49A60),
              ),
            ),
          )
        else
          a.notice(
            a.tr(
              'الحساس غير متاح؛ استخدم زاوية القبلة مع بوصلة خارجية.',
              'Compass unavailable; use this bearing with an external compass.',
            ),
          ),
        a.notice(
          a.tr(
            'دقة الحساس: $accuracy / 3 • الاتجاه نحو الشمال الحقيقي',
            'Sensor accuracy: $accuracy / 3 • True north reference',
          ),
        ),
      ] else
        a.notice(
          a.tr(
            'حدد موقعك الحالي أولًا.',
            'Choose your current location first.',
          ),
        ),
    ]);
  }
}

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key, required this.app, required this.type});
  final RawdaState app;
  final String type;
  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  List<dynamic> data = [];
  final Map<int, int> counts = {};
  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/adhkar.json').then((s) {
      if (mounted) {
        setState(
          () => data = (jsonDecode(s) as List)
              .where((v) => (v['types'] as List).contains(widget.type))
              .toList(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    return a.wrapList([
      a.notice(
        a.tr(
          'مجموعة مختارة من الأذكار مع مصادرها. اضغط العداد لكل تكرار.',
          'A selected collection with references. Tap the counter for each repetition.',
        ),
      ),
      for (var i = 0; i < data.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${data[i]['ar']}',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 23, height: 1.9),
                ),
                if (!a.ar)
                  Text('${data[i]['en']}', style: const TextStyle(height: 1.7)),
                a.notice('${data[i]['source']}'),
                FilledButton.tonal(
                  onPressed: () {
                    if ((counts[i] ?? 0) < (data[i]['count'] as int)) {
                      HapticFeedback.lightImpact();
                      setState(() => counts[i] = (counts[i] ?? 0) + 1);
                    }
                  },
                  child: Text('${counts[i] ?? 0} / ${data[i]['count']}'),
                ),
              ],
            ),
          ),
        ),
      if (widget.type == 'morning' || widget.type == 'evening')
        FilledButton(
          onPressed: () => a.run(() async {
            await a.claim('adhkar_${widget.type}');
            a.state['adhkar:${dayKey(a.now)}:${widget.type}'] = true;
            await a.saveState();
          }),
          child: Text(a.tr('سجّل إتمام أذكاري', 'Record my adhkar completion')),
        ),
    ]);
  }
}

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.app});
  final RawdaState app;
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  List<dynamic> bank = [];
  String category = 'all';
  int level = 0;
  final Map<int, int> answers = {};
  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/practice.json').then((s) {
      if (mounted) setState(() => bank = jsonDecode(s) as List);
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    final list = bank.where(
      (q) =>
          (category == 'all' || q['category'] == category) &&
          (level == 0 || q['difficulty'] == level),
    );
    return a.wrapList([
      a.notice(
        a.tr(
          'تدريب مفتوح بلا نقاط، يعمل دون إنترنت. نقاط التنافس تخص المسابقة اليومية فقط.',
          'Offline practice without points. Competitive points come only from the daily quiz.',
        ),
      ),
      DropdownButton<String>(
        value: category,
        isExpanded: true,
        items: [
          for (final e in {
            'all': a.tr('كل الموضوعات', 'All topics'),
            'fiqh': a.tr('العبادات', 'Worship'),
            'sirah': a.tr('السيرة', 'Sirah'),
            'names': a.tr('أسماء الله الحسنى', 'Names of Allah'),
          }.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => setState(() => category = v!),
      ),
      DropdownButton<int>(
        value: level,
        isExpanded: true,
        items: [
          for (final e in {
            0: a.tr('كل المستويات', 'All levels'),
            1: a.tr('سهل', 'Easy'),
            2: a.tr('متوسط', 'Medium'),
            3: a.tr('متقدم', 'Advanced'),
          }.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => setState(() => level = v!),
      ),
      for (final q in list)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  q[a.ar ? 'question_ar' : 'question_en'].toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                for (var i = 0; i < 4; i++)
                  OutlinedButton(
                    onPressed: answers.containsKey(q['id'])
                        ? null
                        : () => setState(() => answers[q['id'] as int] = i),
                    child: Row(
                      children: [
                        if (answers.containsKey(q['id']) &&
                            i == q['correct_index'])
                          const Icon(Icons.check_circle, color: Colors.green),
                        Expanded(
                          child: Text(
                            q[a.ar ? 'options_ar' : 'options_en'][i].toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (answers.containsKey(q['id']))
                  a.notice(q['reference'].toString()),
              ],
            ),
          ),
        ),
    ]);
  }
}
