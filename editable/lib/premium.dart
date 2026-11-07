part of 'main.dart';

const rawdaGreen = Color(0xFF183F33);
const rawdaGold = Color(0xFFC6A76A);

/// Original Rawda illustration: a domed mosque and minarets, with enough
/// contrast for the clock and prayer controls on top. No Nusuk imagery is used.
class MosqueArt extends CustomPainter {
  const MosqueArt();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final area = Offset.zero & size;
    canvas.drawRect(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF265846), Color(0xFF10362D), Color(0xFF0B2925)],
        ).createShader(area),
    );

    final gold = Paint()..color = rawdaGold.withValues(alpha: .10);
    final thin = Paint()
      ..color = rawdaGold.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // A quiet woven geometric border remains legible at different screen sizes.
    for (var x = 16.0; x <= w; x += 43) {
      for (var y = 8.0; y <= h; y += 43) {
        canvas.drawPath(
          Path()
            ..moveTo(x, y - 17)
            ..lineTo(x + 17, y)
            ..lineTo(x, y + 17)
            ..lineTo(x - 17, y)
            ..close(),
          thin,
        );
      }
    }

    // The original mosque silhouette sits low, behind the primary information.
    final building = Paint()..color = const Color(0xFF86AA92).withValues(alpha: .16);
    final detail = Paint()
      ..color = rawdaGold.withValues(alpha: .15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final base = h * .92;
    canvas.drawRect(Rect.fromLTWH(0, base - 55, w, h - base + 55), building);
    canvas.drawPath(
      Path()
        ..moveTo(w * .27, base)
        ..lineTo(w * .27, base - h * .14)
        ..quadraticBezierTo(w * .3, base - h * .29, w * .50, base - h * .32)
        ..quadraticBezierTo(w * .7, base - h * .29, w * .73, base - h * .14)
        ..lineTo(w * .73, base)
        ..close(),
      building,
    );
    canvas.drawLine(
      Offset(w * .5, base - h * .32),
      Offset(w * .5, base - h * .38),
      detail,
    );
    canvas.drawCircle(Offset(w * .5, base - h * .39), 4, gold);
    for (final x in [w * .13, w * .87]) {
      final top = base - h * .47;
      canvas.drawRect(Rect.fromLTWH(x - 7, top + 16, 14, base - top - 16), building);
      canvas.drawRect(Rect.fromLTWH(x - 12, top + 12, 24, 5), building);
      canvas.drawPath(
        Path()
          ..moveTo(x - 9, top + 10)
          ..lineTo(x, top - 10)
          ..lineTo(x + 9, top + 10)
          ..close(),
        building,
      );
      canvas.drawLine(Offset(x, top - 10), Offset(x, top - 19), detail);
      canvas.drawCircle(Offset(x, top - 21), 3, gold);
    }
    for (var i = 0; i < 8; i++) {
      final x = w * (.14 + i * .105);
      final arch = Rect.fromLTWH(x - 11, base - 39, 22, 35);
      canvas.drawArc(arch, math.pi, math.pi, false, detail);
    }
  }

  @override
  bool shouldRepaint(MosqueArt oldDelegate) => false;
}

extension PremiumRawda on RawdaState {
  Future<void> showAdhan(String title) async {
    if (!mounted || nav.currentContext == null) {
      _adhanVisible = false;
      return;
    }
    await showDialog<void>(
      context: nav.currentContext!,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: rawdaGreen,
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mosque_outlined, size: 68, color: rawdaGold),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('حيّ على الصلاة', 'Come to prayer'),
                    style: const TextStyle(color: rawdaGold, fontSize: 20),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: rawdaGold,
                      foregroundColor: rawdaGreen,
                    ),
                    onPressed: () async {
                      await bridge.invokeMethod('stopAudio');
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(tr('إيقاف الصوت', 'Stop audio')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      tr('إغلاق الشاشة', 'Close screen'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    _adhanVisible = false;
  }

  String voiceName(String key) {
    final sound = '${config['sound$key'] ?? 'builtin'}';
    if (sound == 'builtin') return tr('آدم سيناغدا', 'Adam-synagda');
    if (sound == 'silent') return tr('إشعار فقط', 'Notification only');
    return '${config['soundName$key'] ?? tr('تسجيل من جهازي', 'Recording from my device')}';
  }

  Widget sectionHero(String title, String subtitle, IconData icon) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(colors: [rawdaGreen, Color(0xFF2C5845)]),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  color: Color(0xFFE8DCC1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: rawdaGold, size: 42),
      ],
    ),
  );

  Widget inlineStatus(String text, VoidCallback retry) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_outlined, color: rawdaGold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 13, height: 1.8),
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: Text(tr('حاول تاني', 'Retry')),
          ),
        ],
      ),
    ),
  );

  Widget featureGrid() {
    final items = <(String, IconData, VoidCallback)>[
      (tr('القرآن الكريم', 'Quran'), Icons.menu_book_rounded, openQuran),
      (tr('القبلة', 'Qibla'), Icons.explore_outlined, openQibla),
      (tr('المسبحة', 'Tasbih'), Icons.touch_app_outlined, openTasbih),
      (
        tr('أذكار الصباح', 'Morning adhkar'),
        Icons.wb_sunny_outlined,
        () => openAdhkar('morning'),
      ),
      (
        tr('أذكار المساء', 'Evening adhkar'),
        Icons.bedtime_outlined,
        () => openAdhkar('evening'),
      ),
      (
        tr('ورد اليوم', 'Daily reading'),
        Icons.auto_stories_outlined,
        openDaily,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in items)
            SizedBox(
              width: (c.maxWidth - 20) / 3,
              child: Material(
                color: dark ? const Color(0xFF20362B) : const Color(0xFFFFFEF9),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: item.$3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 4,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          item.$2,
                          size: 27,
                          color: dark ? rawdaGold : rawdaGreen,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          item.$1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget premiumHome() {
    final next = upcoming.isEmpty ? null : upcoming.first;
    final row = today;
    final remaining = next == null
        ? Duration.zero
        : (next['at'] as DateTime).difference(now);
    final countdown =
        '${remaining.inHours.toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    final prior = <DateTime>[];
    for (final day in calendar) {
      for (final key in prayerKeys) {
        final d = DateTime.tryParse('${day['timings'][key]}');
        if (d != null && !d.isAfter(now)) prior.add(d);
      }
    }
    prior.sort();
    final total = next == null || prior.isEmpty
        ? 0
        : (next['at'] as DateTime).difference(prior.last).inSeconds;
    final progress = total <= 0
        ? 0.0
        : (1 - remaining.inSeconds / total).clamp(0.0, 1.0);
    final name =
        '${account['profile']?['display_name'] ?? tr('صديق الروضة', 'Rawda friend')}';
    final iqama = activeIqama;
    return wrapList([
      if (prayerConfigChanged)
        inlineStatus(
          tr(
            'الإعدادات اتغيّرت؛ المواقيت المعروضة محفوظة من قبل التعديل. حدّثها لتطبيق الموقع وطريقة الحساب الجديدة.',
            'Settings changed. These are previously saved times; refresh to apply the new location and calculation.',
          ),
          () => run(fetchTimes),
        ),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('السلام عليكم، $name', 'Peace be with you, $name'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr(
                    'لكل يومٍ نصيبٌ من الطمأنينة',
                    'A little peace in every day',
                  ),
                  style: const TextStyle(fontSize: 11, color: rawdaGold),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('مواقيت الشهر', 'Monthly times'),
            onPressed: openPrayerMonth,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: rawdaGreen,
          boxShadow: [
            BoxShadow(
              color: rawdaGreen.withValues(alpha: .18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: MosqueArt())),
            Padding(
              padding: const EdgeInsets.all(23),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: rawdaGold,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          prefs.getString('prayer_location_label') ??
                              tr('المواقيت المحفوظة', 'Saved prayer times'),
                          style: const TextStyle(
                            color: Color(0xFFE7DEC9),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'RawdaLatin',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (prayerClockZone(config, calendar) == 'Africa/Cairo')
                            Text(
                              now.timeZoneOffset == const Duration(hours: 3)
                                  ? tr('مصر • توقيت صيفي', 'Egypt • Summer time')
                                  : tr('مصر • توقيت شتوي', 'Egypt • Winter time'),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFFEBDBB9),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    next == null
                        ? tr('أهلًا بك في الروضة', 'Welcome to Rawda')
                        : tr('الصلاة القادمة', 'Next prayer'),
                    style: const TextStyle(
                      color: Color(0xFFDBD3BF),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    next == null
                        ? tr('رحلتك تبدأ هنا', 'Your journey starts here')
                        : ar
                        ? prayerArabic[next['index'] as int]
                        : prayerKeys[next['index'] as int],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 33,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 174,
                    height: 174,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 3,
                            backgroundColor: Colors.white12,
                            color: rawdaGold,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              next == null ? '—' : timeLabel('${next['raw']}'),
                              style: const TextStyle(
                                fontSize: 26,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              tr('متبقي على الأذان', 'Until adhan'),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white60,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              next == null ? '--:--:--' : countdown,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontFamily: 'RawdaLatin',
                                color: rawdaGold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    row == null
                        ? dayKey(now)
                        : '${row['date']['hijri']['day']} ${row['date']['hijri']['month'][ar ? 'ar' : 'en']} ${row['date']['hijri']['year']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  if (next == null)
                    TextButton(
                      onPressed: prayerSettings,
                      child: Text(
                        tr(
                          'حدد موقعك لعرض المواقيت',
                          'Choose location to load times',
                        ),
                        style: const TextStyle(color: rawdaGold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (iqama != null)
        Card(
          child: ListTile(
            leading: const Icon(Icons.timelapse, color: rawdaGold),
            title: Text(
              tr(
                'الإقامة • ${prayerArabic[iqama['index'] as int]}',
                'Iqama • ${prayerKeys[iqama['index'] as int]}',
              ),
            ),
            subtitle: Text(
              tr('حسب المدة التي اخترتها', 'Based on your selected interval'),
            ),
            trailing: Text(
              '${iqama['minutes']}:${(iqama['seconds'] as int).toString().padLeft(2, '0')}',
              style: const TextStyle(fontFamily: 'RawdaLatin', fontSize: 22),
            ),
          ),
        ),
      const SizedBox(height: 12),
      featureGrid(),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: openQuran,
              icon: const Icon(Icons.auto_stories_outlined),
              label: Text(tr('أكمل قراءتك', 'Continue reading')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => openAdhkar('morning'),
              icon: const Icon(Icons.spa_outlined),
              label: Text(tr('ورد الأذكار', 'Daily adhkar')),
            ),
          ),
        ],
      ),
      for (final message in announcements)
        Card(
          child: ListTile(
            leading: const Icon(Icons.campaign_outlined, color: rawdaGold),
            title: Text('${message['title']}'),
            subtitle: Text('${message['body']}'),
          ),
        ),
      Row(
        children: [
          Expanded(
            child: heading(tr('فروضك الخمسة', 'Your five daily prayers')),
          ),
          TextButton(
            onPressed: openAudio,
            child: Text(tr('ضبط الأذان', 'Adhan settings')),
          ),
        ],
      ),
      for (var i = 0; i < 5; i++) prayerRow(i, row, next?['index'] == i),
      const SizedBox(height: 12),
      tile(
        tr('متابعة الصلاة والصيام', 'Prayer & fasting tracker'),
        Icons.fact_check_outlined,
        openTracker,
      ),
      tile(
        tr('جدول مواقيت الشهر', 'Monthly timetable'),
        Icons.date_range_outlined,
        openPrayerMonth,
      ),
      tile(
        tr('مكتبة أصوات الأذان', 'Adhan voice library'),
        Icons.library_music_outlined,
        openVoiceLibrary,
      ),
      notice(
        tr(
          'راجع مواقيت منطقتك واضبط فرق الدقائق عند الحاجة. تسجيل العبادات اختياري وشخصي.',
          'Check times against your local authority. Worship records are optional and private.',
        ),
      ),
    ]);
  }

  Map<String, dynamic>? get activeIqama {
    final row = today;
    if (row == null) return null;
    for (var i = 4; i >= 0; i--) {
      final at = DateTime.tryParse('${row['timings'][prayerKeys[i]]}');
      final minutes = (config['iqama${prayerKeys[i]}'] as num?)?.toInt() ?? 15;
      if (at == null || minutes == 0) continue;
      final end = at.add(Duration(minutes: minutes));
      if (!now.isBefore(at) && now.isBefore(end)) {
        final d = end.difference(now);
        return {
          'index': i,
          'minutes': d.inMinutes,
          'seconds': d.inSeconds % 60,
        };
      }
    }
    return null;
  }

  Widget prayerRow(int i, Map<String, dynamic>? row, bool next) {
    final enabled =
        config['alerts'] == true && config['enabled${prayerKeys[i]}'] != false;
    final done = state['prayer:${dayKey(now)}:$i'] == true;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (next ? rawdaGold : rawdaGreen).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            [
              Icons.wb_twilight,
              Icons.light_mode_outlined,
              Icons.wb_sunny_outlined,
              Icons.wb_twilight,
              Icons.nightlight_outlined,
            ][i],
            color: next ? rawdaGold : null,
          ),
        ),
        title: Row(
          children: [
            Text(
              ar ? prayerArabic[i] : prayerKeys[i],
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Text(
              tr('فرض', 'Obligatory'),
              style: const TextStyle(fontSize: 10, color: rawdaGold),
            ),
          ],
        ),
        subtitle: Text(
          row == null
              ? tr('حدد موقعك لتحميل الموعد', 'Choose your location')
              : timeLabel('${row['timings'][prayerKeys[i]]}'),
          style: const TextStyle(fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: enabled
                  ? tr('تنبيه مفعّل', 'Alert enabled')
                  : tr('تنبيه متوقف', 'Alert off'),
              onPressed: openAudio,
              icon: Icon(
                enabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                size: 20,
                color: enabled ? rawdaGold : null,
              ),
            ),
            IconButton(
              tooltip: done
                  ? tr('تم تسجيل الصلاة', 'Prayer recorded')
                  : tr('سجّل أداء الصلاة', 'Record prayer'),
              onPressed: () => recordPrayer(i),
              icon: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? rawdaGold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> recordPrayer(int index) async {
    await run(() async {
      final key = 'prayer:${dayKey(now)}:$index';
      if (state[key] == true) {
        state.remove(key);
        await saveState();
        return;
      }
      state[key] = true;
      await saveState();
      try {
        await claim(
          'prayer_${['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'][index]}',
          quiet: true,
        );
      } catch (_) {
        toast(
          tr(
            'تم حفظ الصلاة؛ تعذّر تحديث النقاط حاليًا.',
            'Prayer saved; points could not refresh.',
          ),
        );
      }
    });
  }

  void openPrayerMonth() {
    push(
      tr('مواقيت الشهر', 'Monthly prayer times'),
      (context) => StatefulBuilder(
        builder: (context, update) {
          final months = calendar
              .map((r) {
                final d = r['date']['gregorian'];
                return '${d['year']}-${d['month']['number']}';
              })
              .toSet()
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(
                          'الفروض الخمسة • كل أيام الشهر',
                          'Five prayers • every day',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('تحديث المواقيت', 'Refresh times'),
                      onPressed: () => run(() async {
                        await fetchTimes();
                        update(() {});
                      }),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              if (calendar.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 52,
                        color: rawdaGold,
                      ),
                      Text(
                        tr(
                          'حدد موقعك أولًا لتحميل جدولك',
                          'Choose your location to load your timetable',
                        ),
                      ),
                      TextButton(
                        onPressed: prayerSettings,
                        child: Text(tr('تحديد الموقع', 'Choose location')),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView(
                  children: [
                    for (final month in months) ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          month,
                          style: const TextStyle(
                            color: rawdaGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowColor: WidgetStateProperty.all(
                            rawdaGold.withValues(alpha: .12),
                          ),
                          columns: [
                            DataColumn(label: Text(tr('اليوم', 'Day'))),
                            for (var i = 0; i < 5; i++)
                              DataColumn(
                                label: Text(
                                  ar ? prayerArabic[i] : prayerKeys[i],
                                ),
                              ),
                          ],
                          rows: [
                            for (final r in calendar.where(
                              (r) =>
                                  '${r['date']['gregorian']['year']}-${r['date']['gregorian']['month']['number']}' ==
                                  month,
                            ))
                              DataRow(
                                selected:
                                    r['date']['gregorian']['date'] ==
                                    today?['date']?['gregorian']?['date'],
                                cells: [
                                  DataCell(
                                    Text('${r['date']['gregorian']['day']}'),
                                  ),
                                  for (final k in prayerKeys)
                                    DataCell(
                                      Text(
                                        timeLabel('${r['timings'][k]}'),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget profileLine(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, size: 19, color: rawdaGold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: rawdaGold),
              ),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
  );

  ImageProvider? get profilePhoto {
    final photo = state['photo'];
    if (photo is String && photo.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(photo));
      } catch (_) {}
    }
    return null;
  }

  Future<void> pickProfilePhoto() async {
    await run(() async {
      final photo = await bridge.invokeMethod<String>('pickImage');
      if (photo == null) return;
      state['photo'] = photo;
      await saveState();
    });
  }

  Widget profileHeader() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: rawdaGreen,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF476554),
              backgroundImage: profilePhoto,
              child: profilePhoto == null
                  ? const Icon(
                      Icons.person_outline,
                      size: 42,
                      color: Color(0xFFEADCC0),
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Material(
                color: rawdaGold,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: pickProfilePhoto,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      size: 16,
                      color: rawdaGreen,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${account['profile']?['display_name'] ?? tr('عضو الروضة', 'Rawda member')}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        TextButton(
          onPressed: pickProfilePhoto,
          child: Text(
            tr('إضافة أو تغيير الصورة', 'Add or change photo'),
            style: const TextStyle(color: rawdaGold, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            stat('$balance', tr('نقطة', 'Points')),
            stat('${earned ~/ 50 + 1}', tr('المستوى', 'Level')),
            stat(
              '${(state['bookmarks'] as List? ?? []).length}',
              tr('علامة قراءة', 'Bookmarks'),
            ),
          ],
        ),
      ],
    ),
  );
  Widget stat(String value, String label) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          color: rawdaGold,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ],
  );

  void editProfile() {
    final name = TextEditingController(
      text: '${account['profile']?['display_name'] ?? ''}',
    );
    final phone = TextEditingController(text: '${state['phone'] ?? ''}');
    final address = TextEditingController(text: '${state['address'] ?? ''}');
    String? error;
    bool saving = false;
    push(
      tr('تعديل بياناتي', 'Edit my details'),
      (context) => StatefulBuilder(
        builder: (context, update) => wrapList([
          sectionHero(
            tr('حسابك في الروضة', 'Your Rawda profile'),
            tr(
              'بياناتك الخاصة تظهر لك وحدك',
              'Your private details are visible to you',
            ),
            Icons.person_outline,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              await pickProfilePhoto();
              update(() {});
            },
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(tr('إضافة أو تغيير الصورة', 'Add or change photo')),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: name,
            maxLength: 60,
            decoration: InputDecoration(labelText: tr('الاسم', 'Name')),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: phone,
            maxLength: 25,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: tr('رقم الهاتف — اختياري', 'Phone — optional'),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: address,
            maxLength: 250,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: tr('العنوان — اختياري', 'Address — optional'),
            ),
          ),
          notice(
            tr(
              'إضافة رقم الهاتف لا تفعّل تسجيل الدخول بالهاتف. يمكنك حذف الرقم والعنوان في أي وقت.',
              'Adding a phone number does not enable phone sign-in. You can clear these details at any time.',
            ),
          ),
          if (error != null)
            inlineStatus(error!, () => update(() => error = null)),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (name.text.trim().isEmpty) {
                      update(
                        () => error = tr(
                          'اكتب اسمك أولًا',
                          'Enter your name first',
                        ),
                      );
                      return;
                    }
                    if (phone.text.trim().isNotEmpty &&
                        !RegExp(
                          r'^\+?[0-9 ()-]{6,25}$',
                        ).hasMatch(phone.text.trim())) {
                      update(
                        () => error = tr(
                          'راجع رقم الهاتف',
                          'Check the phone number',
                        ),
                      );
                      return;
                    }
                    update(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await updateProfile({
                        'display_name': name.text.trim(),
                      }, uid);
                      account['profile']['display_name'] = name.text.trim();
                      for (final entry in {
                        'phone': phone.text.trim(),
                        'address': address.text.trim(),
                      }.entries) {
                        if (entry.value.isEmpty) {
                          state.remove(entry.key);
                        } else {
                          state[entry.key] = entry.value;
                        }
                      }
                      await saveState();
                      await prefs.setString(
                        'account:$uid',
                        jsonEncode(account),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        toast(tr('تم حفظ بياناتك', 'Profile saved'));
                      }
                    } catch (e) {
                      if (context.mounted) update(() => error = err(e));
                    } finally {
                      if (context.mounted) update(() => saving = false);
                    }
                  },
            child: Text(
              saving
                  ? tr('جاري الحفظ…', 'Saving…')
                  : tr('حفظ البيانات', 'Save profile'),
            ),
          ),
        ]),
      ),
    );
  }

  void openTracker() {
    push(
      tr('متابعة الصلاة والصيام', 'Prayer & fasting tracker'),
      (context) => StatefulBuilder(
        builder: (context, update) => wrapList([
          sectionHero(
            tr('خطواتك الطيبة', 'Your daily progress'),
            tr(
              'متابعة شخصية تساعدك على الاستمرار',
              'A private record to help you stay consistent',
            ),
            Icons.fact_check_outlined,
          ),
          heading(tr('صلوات اليوم', 'Today’s prayers')),
          for (var i = 0; i < 5; i++)
            CheckboxListTile(
              title: Text(ar ? prayerArabic[i] : prayerKeys[i]),
              subtitle: Text(tr('فرض', 'Obligatory')),
              value: state['prayer:${dayKey(now)}:$i'] == true,
              onChanged: (v) async {
                await recordPrayer(i);
                update(() {});
              },
            ),
          heading(tr('الصيام', 'Fasting')),
          SwitchListTile(
            title: Text(tr('سجّلت صيام اليوم', 'Record fasting today')),
            subtitle: Text(
              tr('تسجيل شخصي اختياري', 'Optional personal record'),
            ),
            value: state['fasting:${dayKey(now)}'] == true,
            onChanged: (v) async {
              state['fasting:${dayKey(now)}'] = v;
              await saveState();
              update(() {});
            },
          ),
          heading(tr('آخر ٧ أيام', 'Last 7 days')),
          for (var d = 0; d < 7; d++)
            Builder(
              builder: (context) {
                final day = now.subtract(Duration(days: d));
                final key = dayKey(day);
                final count = List.generate(
                  5,
                  (i) => state['prayer:$key:$i'] == true,
                ).where((v) => v).length;
                return Card(
                  child: ListTile(
                    title: Text(key),
                    subtitle: LinearProgressIndicator(
                      value: count / 5,
                      minHeight: 4,
                      color: rawdaGold,
                    ),
                    trailing: Text('$count / 5'),
                  ),
                );
              },
            ),
        ]),
      ),
    );
  }

  Future<void> loadCommunityConfig() async {
    final owner = uid;
    try {
      final data = obj(await rpc('rawda_public_config'));
      if (uid != owner) return;
      if (mounted) {
        mutate(() {
          isAdmin = data['is_admin'] == true;
          announcements = data['announcements'] as List? ?? [];
          voices = data['voices'] as List? ?? [];
        });
      }
    } catch (_) {
      if (mounted && uid == owner) mutate(() => isAdmin = false);
    }
  }

  void openVoiceLibrary() {
    push(
      tr('مكتبة أصوات الأذان', 'Adhan voice library'),
      (context) => StatefulBuilder(
        builder: (context, update) => wrapList([
          sectionHero(
            tr('صوت يرافق صلاتك', 'A voice for your prayer'),
            tr(
              'عاين التسجيل ثم خصصه لصلواتك',
              'Preview a recording and assign it to your prayers',
            ),
            Icons.graphic_eq,
          ),
          tile(
            tr('آدم سيناغدا • مدمج', 'Adam-synagda • built in'),
            Icons.play_circle_outline,
            () => run(
              () => bridge.invokeMethod('preview', {
                'sound': 'builtin',
                'short': false,
                'volume': 1.0,
              }),
            ),
            subtitle: 'CC0',
          ),
          tile(
            tr('اختيار ملف من جهازي', 'Choose a local recording'),
            Icons.audio_file_outlined,
            () async {
              await run(() async {
                final path = await bridge.invokeMethod<String>('pickAudio');
                if (path != null) {
                  config['librarySound'] = path;
                  config['librarySoundName'] = tr(
                    'تسجيل من جهازي',
                    'Recording from my device',
                  );
                  await persistConfig();
                }
              });
              if (context.mounted) update(() {});
            },
          ),
          for (final voice in voices)
            tile(
              '${voice['title']}',
              Icons.download_outlined,
              () async {
                await run(() async {
                  final path = await bridge.invokeMethod<String>(
                    'downloadAudio',
                    {'url': voice['url']},
                  );
                  if (path != null) {
                    config['librarySound'] = path;
                    config['librarySoundName'] = '${voice['title']}';
                    await persistConfig();
                  }
                });
                if (context.mounted) update(() {});
              },
              subtitle: '${voice['license']}',
            ),
          if (config['librarySound'] != null) ...[
            heading(
              '${config['librarySoundName'] ?? tr('التسجيل المختار جاهز', 'Selected recording is ready')}',
            ),
            OutlinedButton.icon(
              onPressed: () => run(
                () => bridge.invokeMethod('preview', {
                  'sound': config['librarySound'],
                  'short': false,
                  'volume': 1.0,
                }),
              ),
              icon: const Icon(Icons.play_arrow),
              label: Text(tr('معاينة التسجيل', 'Preview recording')),
            ),
            for (var i = 0; i < 5; i++)
              OutlinedButton(
                onPressed: () => run(() async {
                  config['sound${prayerKeys[i]}'] = config['librarySound'];
                  config['soundName${prayerKeys[i]}'] =
                      config['librarySoundName'];
                  await persistConfig();
                  await schedule();
                  toast(
                    tr(
                      'تم تعيين التسجيل لصلاة ${prayerArabic[i]}',
                      'Recording assigned to ${prayerKeys[i]}',
                    ),
                  );
                }),
                child: Text(
                  tr(
                    'استخدام للفجر'.replaceFirst('الفجر', prayerArabic[i]),
                    'Use for ${prayerKeys[i]}',
                  ),
                ),
              ),
          ],
          TextButton(
            onPressed: () => bridge.invokeMethod('stopAudio'),
            child: Text(tr('إيقاف المعاينة', 'Stop preview')),
          ),
          tile(
            tr('تخصيص التنبيه لكل صلاة', 'Customize each prayer'),
            Icons.tune,
            openAudio,
          ),
        ]),
      ),
    );
  }
}

extension _PremiumAuth on _AuthScreenState {
  Widget authPremium() {
    final a = widget.app;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: rawdaGreen,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: MosqueArt()),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 27,
                        ),
                        child: Column(
                          children: [
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: 82,
                                  height: 82,
                                ),
                              ),
                            ),
                            const SizedBox(height: 13),
                            Text(
                              a.tr('الروضة', 'Rawda'),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE5D1A1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              a.tr(
                                'رفيق يومك إلى الطمأنينة',
                                'Your daily companion to peace',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 27),
                Text(
                  signup
                      ? a.tr('أهلًا بك في الروضة', 'Welcome to Rawda')
                      : a.tr('نورت الروضة', 'Welcome back'),
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  signup
                      ? a.tr(
                          'ابدأ رحلتك بحسابك الخاص',
                          'Begin your journey with a personal account',
                        )
                      : a.tr(
                          'سجّل دخولك وكمل رحلتك',
                          'Sign in and continue your journey',
                        ),
                  style: const TextStyle(fontSize: 12, color: rawdaGold),
                ),
                const SizedBox(height: 24),
                if (signup) ...[
                  TextField(
                    controller: name,
                    maxLength: 60,
                    autofillHints: const [AutofillHints.name],
                    decoration: InputDecoration(
                      labelText: a.tr('اسمك', 'Your name'),
                      errorText: nameError,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: a.tr('الإيميل', 'Email'),
                    errorText: emailError,
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: !reveal,
                  autofillHints: const [AutofillHints.password],
                  textDirection: TextDirection.ltr,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: a.tr('كلمة المرور', 'Password'),
                    errorText: passwordError,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: a.tr(
                        'إظهار أو إخفاء كلمة المرور',
                        'Show or hide password',
                      ),
                      onPressed: () => mutate(() => reveal = !reveal),
                      icon: Icon(
                        reveal
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: loading ? null : () => submit(reset: true),
                    child: Text(a.tr('نسيت كلمة المرور؟', 'Forgot password?')),
                  ),
                ),
                if (a.firebase != null) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: privacyAccepted,
                    onChanged: loading
                        ? null
                        : (value) =>
                              mutate(() => privacyAccepted = value == true),
                    title: Text(
                      a.tr(
                        'قرأت ووافقت على سياسة الخصوصية',
                        'I read and accept the privacy policy',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: showFirebasePrivacy,
                    child: Text(
                      a.tr('اقرأ سياسة الخصوصية', 'Read the privacy policy'),
                    ),
                  ),
                  if (a.firebase!.auth.currentUser != null) ...[
                    OutlinedButton(
                      onPressed: loading ? null : () => verifyFirebase(),
                      child: Text(a.tr('أكدت بريدي', 'I verified my email')),
                    ),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => verifyFirebase(resend: true),
                      child: Text(
                        a.tr(
                          'إرسال رابط تأكيد جديد',
                          'Resend verification link',
                        ),
                      ),
                    ),
                  ],
                ],
                if (message != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          (messageOk
                                  ? rawdaGreen
                                  : Theme.of(context).colorScheme.error)
                              .withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          messageOk
                              ? Icons.mark_email_read_outlined
                              : Icons.info_outline,
                          color: messageOk
                              ? rawdaGold
                              : Theme.of(context).colorScheme.error,
                          size: 21,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message!,
                            style: const TextStyle(fontSize: 12, height: 1.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                FilledButton(
                  onPressed: loading ? null : () => submit(),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          signup
                              ? a.tr('إنشاء حساب', 'Create account')
                              : a.tr('دخول', 'Sign in'),
                        ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => mutate(() {
                          signup = !signup;
                          message = null;
                          emailError = null;
                          passwordError = null;
                          nameError = null;
                        }),
                  child: Text(
                    signup
                        ? a.tr('عندي حساب بالفعل', 'I already have an account')
                        : a.tr('إنشاء حساب جديد', 'Create a new account'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: a.tr('المظهر', 'Appearance'),
                      onPressed: () => a.setDark(!a.dark),
                      icon: Icon(
                        a.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                    ),
                    TextButton(
                      onPressed: () => a.setArabic(!a.ar),
                      child: Text(a.ar ? 'EN' : 'عربي'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
