part of 'main.dart';

/// Rawda's own warm, mosque-inspired visual system.
/// The panorama is drawn locally, so the home screen works offline and
/// does not depend on third-party imagery or branding.
class RawdaMedinaPainter extends CustomPainter {
  const RawdaMedinaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final area = Offset.zero & size;
    canvas.drawRect(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF426C58), Color(0xFF194739), Color(0xFF0F2F29)],
        ).createShader(area),
    );

    final halo = Paint()
      ..color = const Color(0xFFFFE4A9).withValues(alpha: .10);
    canvas.drawCircle(Offset(w * .23, h * .22), h * .35, halo);
    canvas.drawCircle(
      Offset(w * .77, h * .15),
      h * .20,
      Paint()..color = const Color(0xFFE8C88D).withValues(alpha: .07),
    );

    final silhouette = Paint()
      ..color = const Color(0xFFD9C79B).withValues(alpha: .17);
    final accent = Paint()
      ..color = const Color(0xFFDFCFAB).withValues(alpha: .25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final base = h * .95;
    canvas.drawRect(Rect.fromLTWH(0, base - h * .13, w, h * .15), silhouette);
    for (final x in [w * .14, w * .82]) {
      final towerHeight = x < w * .5 ? .52 : .64;
      final towerTop = base - h * towerHeight;
      canvas.drawRect(
        Rect.fromLTWH(x - 9, towerTop + 30, 18, base - towerTop - 30),
        silhouette,
      );
      canvas.drawRect(Rect.fromLTWH(x - 15, towerTop + 27, 30, 7), silhouette);
      canvas.drawRect(Rect.fromLTWH(x - 12, towerTop + 14, 24, 6), silhouette);
      canvas.drawPath(
        Path()
          ..moveTo(x - 10, towerTop + 14)
          ..lineTo(x, towerTop - 7)
          ..lineTo(x + 10, towerTop + 14)
          ..close(),
        silhouette,
      );
      canvas.drawLine(
        Offset(x, towerTop - 7),
        Offset(x, towerTop - 19),
        accent,
      );
      canvas.drawCircle(Offset(x, towerTop - 21), 2.5, accent);
    }
    for (final dome in [(w * .45, .27), (w * .61, .21), (w * .30, .19)]) {
      final x = dome.$1;
      final rise = h * dome.$2;
      canvas.drawPath(
        Path()
          ..moveTo(x - rise * .76, base)
          ..lineTo(x - rise * .76, base - rise * .25)
          ..quadraticBezierTo(x - rise * .60, base - rise * .90, x, base - rise)
          ..quadraticBezierTo(x + rise * .60, base - rise * .90,
              x + rise * .76, base - rise * .25)
          ..lineTo(x + rise * .76, base)
          ..close(),
        silhouette,
      );
      canvas.drawLine(
        Offset(x, base - rise),
        Offset(x, base - rise - 11),
        accent,
      );
    }
    for (var i = 0; i < 9; i++) {
      final x = w * (.08 + i * .108);
      canvas.drawArc(
        Rect.fromLTWH(x - 9, base - 23, 18, 26),
        math.pi,
        math.pi,
        false,
        accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RawdaMedinaPainter oldDelegate) => false;
}

extension NusukInspiredRawda on RawdaState {
  Widget rawdaSectionTitle(String title, {VoidCallback? onTap, String? action}) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              child: Text(action ?? tr('عرض الكل', 'See all'),
                  style: const TextStyle(color: rawdaGreen)),
            ),
        ],
      ),
    );
  }

  Widget rawdaShortcut(
      String title, IconData icon, VoidCallback action, Color tint) {
    return Material(
      color: dark ? const Color(0xFF20362B) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 102,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: rawdaGold.withValues(alpha: dark ? .20 : .13),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: dark ? .22 : .11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: dark ? rawdaGold : tint, size: 25),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget rawdaShortcutGrid() {
    final tiles = <(String, IconData, VoidCallback, Color)>[
      (tr('القرآن الكريم', 'Quran'), Icons.menu_book_rounded, openQuran,
          rawdaGreen),
      (tr('اتجاه القبلة', 'Qibla'), Icons.explore_outlined, openQibla,
          const Color(0xFF936B42)),
      (tr('أذكار الصباح', 'Morning adhkar'), Icons.wb_sunny_outlined,
          () => openAdhkar('morning'), const Color(0xFFAD8551)),
      (tr('أذكار المساء', 'Evening adhkar'), Icons.nights_stay_outlined,
          () => openAdhkar('evening'), const Color(0xFF586D87)),
      (tr('المسبحة', 'Tasbih'), Icons.fingerprint_outlined, openTasbih,
          const Color(0xFF537C70)),
      (tr('الورد اليومي', 'Daily reading'), Icons.auto_stories_outlined,
          openDaily, const Color(0xFF95784C)),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 20) / 3;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final tile in tiles)
            SizedBox(
              width: width,
              child: rawdaShortcut(tile.$1, tile.$2, tile.$3, tile.$4),
            ),
        ],
      );
    });
  }

  Widget nusukInspiredHome() {
    final next = upcoming.isEmpty ? null : upcoming.first;
    final remaining = next == null
        ? Duration.zero
        : (next['at'] as DateTime).difference(now);
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final countdown =
        "${safe.inHours.toString().padLeft(2, '0')}:${(safe.inMinutes % 60).toString().padLeft(2, '0')}:${(safe.inSeconds % 60).toString().padLeft(2, '0')}";
    final displayName = (account['profile']?['display_name'] ??
            tr('صديق الروضة', 'Rawda friend'))
        .toString();
    final current = today;
    final hijri = current == null
        ? dayKey(now)
        : "${current['date']['hijri']['day']} ${current['date']['hijri']['month'][ar ? 'ar' : 'en']} ${current['date']['hijri']['year']}";

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        if (prayerConfigChanged)
          inlineStatus(
            tr('حدّث مواقيت الصلاة لتطبيق إعدادات موقعك الجديدة.',
                'Refresh prayer times to apply your new location settings.'),
            () => run(fetchTimes),
          ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('السلام عليكم ورحمة الله', 'Peace be upon you'),
                      style: TextStyle(
                          color: dark ? rawdaGold : const Color(0xFF88765D),
                          fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: openPrayerMonth,
              tooltip: tr('التقويم', 'Calendar'),
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              onPressed: openPrayerNotifications,
              tooltip: tr('تنبيهات الأذان', 'Adhan alerts'),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(29),
          child: SizedBox(
            height: 350,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: RawdaMedinaPainter()),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0F3029).withValues(alpha: .05),
                          const Color(0xFF092C24).withValues(alpha: .32),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(21),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: Color(0xFFEED8A7), size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              prefs.getString('prayer_location_label') ??
                                  tr('مواقيت الصلاة', 'Prayer times'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                          Text(
                            hijri,
                            style: const TextStyle(
                                color: Color(0xFFF4DDB5), fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Text(tr('الصلاة القادمة', 'Next prayer'),
                          style: const TextStyle(
                              color: Color(0xFFF3E1C9), fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        next == null
                            ? tr('أهلًا بك في الروضة', 'Welcome to Rawda')
                            : (ar
                                ? prayerArabic[next['index'] as int]
                                : prayerKeys[next['index'] as int]),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        next == null
                            ? tr('حدّد موقعك لعرض المواقيت',
                                'Choose your location to see prayer times')
                            : "${tr('الأذان الساعة ', 'Adhan at ')}${timeLabel(next['raw'].toString())}",
                        style: const TextStyle(
                            color: Color(0xFFEAD5AC),
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr('المتبقي على الأذان', 'Time until adhan'),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 10)),
                                Text(next == null ? '--:--:--' : countdown,
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                        fontFamily: 'RawdaLatin',
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed:
                                next == null ? prayerSettings : openPrayerMonth,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                  color: Color(0xFFEBD3A6), width: .8),
                              backgroundColor:
                                  const Color(0xFF0D3B30).withValues(alpha: .45),
                            ),
                            child: Text(tr('المواقيت', 'Times')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        rawdaSectionTitle(
          tr('مواقيت الصلاة', 'Prayer times'),
          onTap: openPrayerMonth,
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            key: const Key('rawda-prayer-strip'),
            scrollDirection: Axis.horizontal,
            itemCount: prayerKeys.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final isNext = next != null && next['index'] == i;
              final hour = current == null
                  ? '--:--'
                  : timeLabel(
                      current['timings'][prayerKeys[i]].toString());
              return Container(
                width: 95,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: isNext
                      ? rawdaGreen
                      : (dark ? const Color(0xFF20362B) : Colors.white),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: rawdaGold.withValues(alpha: isNext ? .7 : .16)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(ar ? prayerArabic[i] : prayerKeys[i],
                        style: TextStyle(
                            color: isNext ? Colors.white : null,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(hour,
                        style: TextStyle(
                            color: isNext ? const Color(0xFFF0DDB8) : null,
                            fontFamily: 'RawdaLatin',
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              );
            },
          ),
        ),
        rawdaSectionTitle(tr('اكتشف الروضة', 'Explore Rawda')),
        rawdaShortcutGrid(),
        rawdaSectionTitle(
          tr('وردك اليومي', 'Your daily reading'),
          onTap: openDaily,
          action: tr('افتح الورد', 'Open'),
        ),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: openDaily,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories_rounded,
                      color: rawdaGold, size: 38),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('رحلة الختمة والذكر', 'Quran & remembrance'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(
                          tr('كل يوم خطوة جديدة إلى الطمأنينة',
                              'One peaceful step every day'),
                          style:
                              const TextStyle(fontSize: 11, height: 1.7),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, color: rawdaGold),
                ],
              ),
            ),
          ),
        ),
        if (activeIqama != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.timelapse, color: rawdaGold),
              title: Text(tr('تذكير الإقامة', 'Iqama reminder')),
              subtitle: Text(
                "${activeIqama!['minutes']}:${(activeIqama!['seconds'] as int).toString().padLeft(2, '0')}",
              ),
            ),
          ),
        for (final message in announcements)
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.campaign_outlined, color: rawdaGold),
              title: Text(message['title'].toString()),
              subtitle: Text(message['body'].toString()),
            ),
          ),
      ],
    );
  }

  Widget nusukInspiredQuran() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        sectionHero(
          tr('القرآن الكريم', 'The Holy Quran'),
          tr('اقرأ واستمع إلى تلاوة السور', 'Read and listen to recitations'),
          Icons.menu_book_rounded,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.headphones_rounded, color: rawdaGreen),
            title: Text(tr('التلاوات القرآنية', 'Quran recitations')),
            subtitle: Text(tr(
                'افتح أي سورة واختر القارئ ثم اضغط تشغيل',
                'Open a surah, select a reciter and tap Play')),
            onTap: openQuran,
          ),
        ),
        rawdaSectionTitle(
          tr('سور القرآن الكريم', 'Surahs of the Quran'),
          onTap: openQuran,
          action: tr('البحث', 'Search'),
        ),
        if (chapters.isEmpty)
          FilledButton.icon(
            onPressed: openQuran,
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(tr('افتح المصحف', 'Open Quran')),
          ),
        for (final chapter in chapters)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: rawdaGold.withValues(alpha: .16),
                foregroundColor: dark ? rawdaGold : rawdaGreen,
                child: Text(chapter['id'].toString()),
              ),
              title: Text(ar
                  ? "سورة ${chapter['name_arabic']}"
                  : "Surah ${chapter['name_simple']}"),
              subtitle: Text("${chapter['verses_count']} ${tr('آية', 'verses')}"),
              trailing: const Icon(Icons.play_circle_outline_rounded,
                  color: rawdaGold),
              onTap: () => openSurah(chapter['id'] as int),
            ),
          ),
      ],
    );
  }

  Widget nusukInspiredToday() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        sectionHero(
          tr('يومك مع الروضة', 'Your day with Rawda'),
          tr('أذكار وورد وعبادات في مكان واحد',
              'Daily reading, remembrance and worship'),
          Icons.spa_outlined,
        ),
        rawdaSectionTitle(tr('أذكار اليوم', 'Daily remembrance')),
        tile(tr('أذكار الصباح', 'Morning adhkar'),
            Icons.wb_sunny_outlined, () => openAdhkar('morning')),
        tile(tr('أذكار المساء', 'Evening adhkar'),
            Icons.nights_stay_outlined, () => openAdhkar('evening')),
        tile(tr('أذكار بعد الصلاة', 'After-prayer adhkar'),
            Icons.mosque_outlined, () => openAdhkar('prayer')),
        tile(tr('أذكار النوم', 'Bedtime adhkar'),
            Icons.bedtime_outlined, () => openAdhkar('sleep')),
        rawdaSectionTitle(tr('عباداتك', 'Your worship')),
        tile(tr('وردك وختمتك', 'Daily reading & khatma'),
            Icons.auto_stories_rounded, openDaily),
        tile(tr('متابعة الصلاة والصيام', 'Prayer & fasting tracker'),
            Icons.fact_check_outlined, openTracker),
        tile(tr('مواقيت الصلاة', 'Prayer timetable'),
            Icons.calendar_month_outlined, openPrayerMonth),
        tile(tr('إعدادات الأذان', 'Adhan settings'),
            Icons.notifications_active_outlined, openPrayerNotifications),
      ],
    );
  }
}
