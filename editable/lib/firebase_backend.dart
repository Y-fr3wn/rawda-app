import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;

class RawdaFirebaseBackend {
  RawdaFirebaseBackend(this.auth, this.store);
  final FirebaseAuth auth;
  final FirebaseFirestore store;
  static const privacyVersion = '2026-11-06';

  String get uid {
    final user = auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError('EMAIL_VERIFICATION_REQUIRED');
    }
    return user.uid;
  }

  String get day {
    final now = tz.TZDateTime.now(tz.getLocation('Africa/Cairo'));
    return now.toIso8601String().split('T').first;
  }

  DocumentReference<Map<String, dynamic>> user(String owner) =>
      store.collection('users').doc(owner);

  Future<void> sendVerification(User user) {
    const hasReturnPage = bool.fromEnvironment('RAWDA_FIREBASE_EMAIL_RETURN');
    const emulator = String.fromEnvironment('RAWDA_FIREBASE_EMULATOR');
    if (!hasReturnPage || emulator.isNotEmpty) {
      return user.sendEmailVerification();
    }
    return user.sendEmailVerification(
      ActionCodeSettings(
        url: 'https://rawda-7806b.web.app/verified/',
        handleCodeInApp: false,
      ),
    );
  }

  Future<bool> refreshVerification() async {
    final current = auth.currentUser;
    if (current == null) return false;
    await current.reload();
    final updated = auth.currentUser;
    if (updated == null ||
        updated.uid != current.uid ||
        !updated.emailVerified) {
      return false;
    }
    await updated.getIdToken(true);
    return auth.currentUser?.uid == updated.uid;
  }

  Future<Map<String, dynamic>> bootstrap({
    required bool privacyAccepted,
  }) async {
    final owner = uid;
    final profile = user(owner);
    final wallet = profile.collection('private').doc('wallet');
    final rawName = auth.currentUser?.displayName?.trim() ?? '';
    final name = rawName.isEmpty
        ? 'عضو الروضة'
        : String.fromCharCodes(rawName.runes.take(60));
    final account = await store.runTransaction((transaction) async {
      final profileData = (await transaction.get(profile)).data();
      final walletData = (await transaction.get(wallet)).data();
      final initialProfile = <String, dynamic>{
        'display_name': name,
        'avatar': '',
        'leaderboard_opt_in': false,
      };
      final initialWallet = <String, dynamic>{
        'balance': 0,
        'earned': 0,
        'lastEvent': '',
      };
      if (profileData?['privacyVersion'] != privacyVersion) {
        if (!privacyAccepted) throw StateError('PRIVACY_CONSENT_REQUIRED');
        transaction.set(profile, {
          ...(profileData ?? initialProfile),
          'privacyVersion': privacyVersion,
          'consentedAt': FieldValue.serverTimestamp(),
        });
      }
      if (walletData == null) transaction.set(wallet, initialWallet);
      return {
        'profile': {
          ...(profileData ?? initialProfile),
          'privacyVersion': privacyVersion,
        }..remove('consentedAt'),
        'wallet': walletData ?? initialWallet,
      };
    });
    final stateDoc = await profile.collection('private').doc('state').get();
    final payload = stateDoc.data()?['payload'];
    final decoded = payload is String ? jsonDecode(payload) : null;
    final rewards = await store
        .collection('rewards')
        .where('active', isEqualTo: true)
        .get();
    final redemptions = await profile
        .collection('ledger')
        .where('kind', isEqualTo: 'redeem')
        .get();
    return {
      ...account,
      'state': decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{},
      'rewards': rewards.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList(),
      'redemptions': redemptions.docs
          .map(
            (doc) => {
              'reward_id': doc.data()['reward'],
              'cost_paid': -(doc.data()['delta'] as int),
              'created_at': (doc.data()['createdAt'] as Timestamp?)
                  ?.toDate()
                  .toIso8601String(),
            },
          )
          .toList(),
    };
  }

  Future<bool> isAdmin() async {
    final owner = uid;
    return (await store.collection('admins').doc(owner).get())
            .data()?['enabled'] ==
        true;
  }

  Map<String, dynamic> _contentRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return {...doc.data(), 'id': doc.id}..remove('updatedAt');
  }

  Future<Map<String, dynamic>> communityConfig() async {
    final results = await Future.wait([
      store
          .collection('announcements')
          .where('active', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .limit(10)
          .get(),
      store
          .collection('voices')
          .where('active', isEqualTo: true)
          .orderBy('title')
          .get(),
    ]);
    return {
      'is_admin': await isAdmin(),
      'announcements': results[0].docs.map(_contentRow).toList(),
      'voices': results[1].docs.map(_contentRow).toList(),
    };
  }

  static const _collections = {
    'questions': 'questionBank',
    'rewards': 'rewards',
    'announcements': 'announcements',
    'voices': 'voices',
  };

  Future<List<Map<String, dynamic>>> adminList(String kind) async {
    if (!await isAdmin()) throw StateError('ADMIN_REQUIRED');
    final collection = _collections[kind];
    if (collection == null) throw ArgumentError('INVALID_CONTENT');
    final snapshot = await store.collection(collection).get();
    final rows = snapshot.docs.map(_contentRow).toList();
    if (kind == 'questions') {
      rows.sort(
        (a, b) => int.parse(
          b['id'] as String,
        ).compareTo(int.parse(a['id'] as String)),
      );
    } else if (kind == 'rewards') {
      rows.sort((a, b) => (a['cost'] as int).compareTo(b['cost'] as int));
    }
    return rows;
  }

  Future<void> adminSave(String kind, Map<String, dynamic> fields) async {
    if (!await isAdmin()) throw StateError('ADMIN_REQUIRED');
    final collection = _collections[kind];
    final id = fields['id']?.toString().trim() ?? '';
    if (collection == null ||
        id.isEmpty ||
        id.length > 80 ||
        id.contains('/') ||
        id == '.' ||
        id == '..') {
      throw ArgumentError('INVALID_CONTENT');
    }
    if (kind == 'questions' && !RegExp(r'^[1-9][0-9]{0,8}$').hasMatch(id)) {
      throw ArgumentError('INVALID_CONTENT');
    }
    final content = {...fields}..remove('id');
    if (kind == 'announcements' || kind == 'voices') {
      content['updatedAt'] = FieldValue.serverTimestamp();
    }
    final ref = store.collection(collection).doc(id);
    if (kind != 'questions') {
      await ref.set(content);
      return;
    }
    await store.runTransaction((transaction) async {
      final bank = (await transaction.get(ref)).data();
      final published = (await transaction.get(
        store.collection('questions').doc(id),
      )).exists;
      if (published && bank == null) throw StateError('QUESTION_IN_USE');
      if (published) {
        final before = {...bank!}..remove('active');
        final after = {...content}..remove('active');
        if (before.length != after.length ||
            before.entries.any(
              (entry) =>
                  jsonEncode(entry.value) != jsonEncode(after[entry.key]),
            )) {
          throw StateError('QUESTION_IN_USE');
        }
      }
      transaction.set(ref, content);
    });
  }

  Future<bool> isDeletionPending(String owner) async {
    return (await store
            .collection('accountDeletions')
            .doc(owner)
            .get(const GetOptions(source: Source.server)))
        .exists;
  }

  Future<void> deleteAccount(
    String password,
    Future<void> Function() onStarted,
  ) async {
    final account = auth.currentUser;
    final email = account?.email;
    if (account == null || email == null || account.uid != uid) {
      throw StateError('ACCOUNT_CHANGED');
    }
    await account.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    await account.getIdToken(true);
    if (auth.currentUser?.uid != account.uid) {
      throw StateError('ACCOUNT_CHANGED');
    }
    final owner = account.uid;
    final marker = store.collection('accountDeletions').doc(owner);
    final rank = store.collection('rankings').doc(owner);
    await store.runTransaction((transaction) async {
      if (!(await transaction.get(marker)).exists) {
        transaction.set(marker, {'startedAt': FieldValue.serverTimestamp()});
        transaction.delete(rank);
      }
    });
    await onStarted();
    final profile = user(owner);
    for (final name in ['ledger', 'attempts', 'weeks']) {
      while (true) {
        final page = await profile
            .collection(name)
            .limit(20)
            .get(const GetOptions(source: Source.server));
        if (page.docs.isEmpty) break;
        final batch = store.batch();
        for (final document in page.docs) {
          batch.delete(document.reference);
        }
        await batch.commit();
      }
    }
    final batch = store.batch();
    batch.delete(profile.collection('private').doc('state'));
    batch.delete(profile.collection('private').doc('wallet'));
    batch.delete(profile);
    await batch.commit();
    if (auth.currentUser?.uid != owner) throw StateError('ACCOUNT_CHANGED');
    await account.delete();
  }

  Future<void> saveState(Map<String, dynamic> value) async {
    final payload = jsonEncode(value);
    if (utf8.encode(payload).length > 262144) {
      throw ArgumentError('STATE_TOO_LARGE');
    }
    await user(uid).collection('private').doc('state').set({
      'payload': payload,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile(String owner, Map<String, dynamic> fields) async {
    if (owner != uid) throw StateError('ACCOUNT_CHANGED');
    final profile = user(owner);
    final rank = store.collection('rankings').doc(owner);
    await store.runTransaction((transaction) async {
      final previousRank = (await transaction.get(rank)).data();
      transaction.update(profile, fields);
      if (previousRank != null) {
        if (fields['leaderboard_opt_in'] == false) {
          transaction.delete(rank);
        } else if (fields.containsKey('display_name') ||
            fields.containsKey('avatar')) {
          transaction.update(rank, {
            if (fields.containsKey('display_name'))
              'display_name': fields['display_name'],
            if (fields.containsKey('avatar')) 'avatar': fields['avatar'],
          });
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> history() async {
    final result = await user(uid)
        .collection('ledger')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return result.docs
        .map(
          (doc) => <String, dynamic>{
            'event_key': doc.id,
            'delta': doc.data()['delta'],
            'created_at': (doc.data()['createdAt'] as Timestamp?)
                ?.toDate()
                .toIso8601String(),
          },
        )
        .toList();
  }

  Future<Map<String, dynamic>> claimActivity(String activity) {
    const points = {
      'login': 1,
      'prayer_fajr': 1,
      'prayer_dhuhr': 1,
      'prayer_asr': 1,
      'prayer_maghrib': 1,
      'prayer_isha': 1,
      'adhkar_morning': 2,
      'adhkar_evening': 2,
    };
    final delta = points[activity];
    if (delta == null) throw ArgumentError('INVALID_ACTIVITY');
    final date = day;
    return _credit(uid, '${date}_$activity', {
      'kind': 'activity',
      'day': date,
      'activity': activity,
      'delta': delta,
    });
  }

  Future<Map<String, dynamic>> _credit(
    String owner,
    String event,
    Map<String, dynamic> data, {
    String? quizWeek,
  }) {
    final profile = user(owner);
    final wallet = profile.collection('private').doc('wallet');
    final ledger = profile.collection('ledger').doc(event);
    return store.runTransaction((transaction) async {
      final totals = (await transaction.get(wallet)).data();
      final claimed = (await transaction.get(ledger)).exists;
      if (totals == null) throw StateError('ACCOUNT_NOT_INITIALIZED');
      final balance = totals['balance'] as int;
      if (claimed) {
        return {'awarded': 0, 'balance': balance, 'day': data['day']};
      }
      final delta = data['delta'] as int;
      if (balance + delta < 0) throw StateError('INSUFFICIENT_POINTS');
      if (quizWeek != null) {
        final statsRef = profile.collection('weeks').doc(quizWeek);
        final stats = (await transaction.get(statsRef)).data();
        final identity = (await transaction.get(profile)).data();
        if (stats == null || identity == null) {
          throw StateError('QUIZ_NOT_CONFIGURED');
        }
        final score = (stats['score'] as int? ?? 0) + delta;
        transaction.update(statsRef, {'score': score, 'lastScoreEvent': event});
        if (identity['leaderboard_opt_in'] == true) {
          transaction.set(store.collection('rankings').doc(owner), {
            'week': quizWeek,
            'score': score,
            'display_name': identity['display_name'],
            'avatar': identity['avatar'],
          });
        }
      }
      transaction.set(ledger, {
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(wallet, {
        'balance': balance + delta,
        'earned': (totals['earned'] as int) + (delta > 0 ? delta : 0),
        'lastEvent': event,
      });
      return {'awarded': delta, 'balance': balance + delta, 'day': data['day']};
    });
  }

  Future<String> _weekFor(String date) async {
    final assignment = await store.collection('days').doc(date).get();
    final week = assignment.data()?['week'];
    if (week is! String) throw StateError('QUIZ_NOT_CONFIGURED');
    return week;
  }

  Future<List<Map<String, dynamic>>> leaderboard() async {
    final owner = uid;
    final week = await _weekFor(day);
    final profile = user(owner);
    await store.runTransaction((transaction) async {
      final identity = (await transaction.get(profile)).data();
      if (identity?['leaderboard_opt_in'] != true) return;
      final stats = (await transaction.get(
        profile.collection('weeks').doc(week),
      )).data();
      final score = stats?['score'] as int? ?? 0;
      if (score <= 0) return;
      transaction.set(store.collection('rankings').doc(owner), {
        'week': week,
        'score': score,
        'display_name': identity!['display_name'],
        'avatar': identity['avatar'],
      });
    });
    final result = await store
        .collection('rankings')
        .where('week', isEqualTo: week)
        .orderBy('score', descending: true)
        .limit(50)
        .get();
    return result.docs
        .map((doc) => {...doc.data(), 'is_me': doc.id == owner})
        .toList();
  }

  Future<Map<String, dynamic>> weekly() async {
    final owner = uid, date = day;
    final week = await _weekFor(date);
    final profile = user(owner);
    final stats = await profile.collection('weeks').doc(week).get();
    final claim = await profile.collection('ledger').doc('weekly_$week').get();
    return {
      'week': week,
      'day': date,
      'answered': stats.data()?['answered'] ?? 0,
      'target': 20,
      'claimed': claim.exists,
    };
  }

  Future<Map<String, dynamic>> claimWeekly() async {
    final owner = uid;
    final data = await weekly();
    if ((data['answered'] as int) < 20) {
      throw StateError('WEEKLY_TARGET_NOT_REACHED');
    }
    return _credit(owner, "weekly_${data['week']}", {
      'kind': 'weekly',
      'day': data['day'],
      'week': data['week'],
      'delta': 10,
    });
  }

  Future<Map<String, dynamic>> redeem(String id) async {
    final owner = uid;
    final reward = (await store.collection('rewards').doc(id).get()).data();
    if (reward == null || reward['active'] != true || reward['cost'] is! int) {
      throw StateError('REWARD_UNAVAILABLE');
    }
    return _credit(owner, 'redeem_$id', {
      'kind': 'redeem',
      'day': day,
      'reward': id,
      'delta': -(reward['cost'] as int),
    });
  }

  Future<List<Map<String, dynamic>>> quiz() async {
    final owner = uid, date = day;
    final assignment = store.collection('days').doc(date);
    final ids = (await assignment.get()).data()?['questionIds'];
    if (ids is! List || ids.isEmpty) throw StateError('QUIZ_NOT_CONFIGURED');
    return Future.wait(
      ids.map((value) async {
        final id = value as String;
        final question = (await store.collection('questions').doc(id).get())
            .data();
        if (question == null) throw StateError('QUIZ_NOT_CONFIGURED');
        final attempt = (await user(
          owner,
        ).collection('attempts').doc('${date}_$id').get()).data();
        final row = <String, dynamic>{
          ...question,
          'id': id,
          'day': date,
          'answered': attempt != null,
        };
        if (attempt != null) {
          final solution =
              (await assignment.collection('solutions').doc(id).get()).data();
          if (solution == null) throw StateError('QUIZ_NOT_CONFIGURED');
          final correct = attempt['choice'] == solution['correct_index'];
          row.addAll({
            ...solution,
            'selected_index': attempt['choice'],
            'correct': correct,
          });
          if (correct) await _quizCredit(owner, date, id);
        }
        return row;
      }),
    );
  }

  Future<void> answer(String id, int choice, String date) async {
    final owner = uid;
    if (date != day) throw StateError('QUIZ_DAY_CHANGED');
    final attempt = user(owner).collection('attempts').doc('${date}_$id');
    final week = await _weekFor(date);
    final weeklyStats = user(owner).collection('weeks').doc(week);
    final selected = await store.runTransaction((transaction) async {
      final previous = (await transaction.get(attempt)).data();
      if (previous != null) return previous['choice'] as int;
      final stats = (await transaction.get(weeklyStats)).data();
      transaction.set(weeklyStats, {
        'answered': (stats?['answered'] as int? ?? 0) + 1,
        'lastAttempt': '${date}_$id',
      }, SetOptions(merge: true));
      transaction.set(attempt, {
        'day': date,
        'question': id,
        'choice': choice,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return choice;
    });
    final solution =
        (await store
                .collection('days')
                .doc(date)
                .collection('solutions')
                .doc(id)
                .get())
            .data();
    if (solution == null) throw StateError('QUIZ_NOT_CONFIGURED');
    if (selected == solution['correct_index']) {
      await _quizCredit(owner, date, id);
    }
  }

  Future<Map<String, dynamic>> _quizCredit(
    String owner,
    String date,
    String id,
  ) async {
    final week = await _weekFor(date);
    return _credit(owner, '${date}_quiz_$id', {
      'kind': 'quiz',
      'day': date,
      'question': id,
      'delta': 2,
    }, quizWeek: week);
  }
}
