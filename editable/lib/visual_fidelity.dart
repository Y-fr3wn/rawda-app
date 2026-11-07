part of 'main.dart';

/// A screen-level composition based on Rawda's approved reference mockups.
/// Text, accounts, times and buttons remain real Flutter controls, not a
/// flattened screenshot of the reference.
const _v2Cream = Color(0xFFFFF7E9);
const _v2Paper = Color(0xFFFFF9EF);
const _v2Emerald = Color(0xFF064631);
const _v2Gold = Color(0xFFD8AD64);

class RawdaGoldCorners extends CustomPainter {
  const RawdaGoldCorners({this.strong = false});
  final bool strong;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _v2Gold.withValues(alpha: strong ? .97 : .73)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 2 : 1.2;
    const gap = 7.0;
    const side = 32.0;
    final rect = Rect.fromLTWH(gap, gap, size.width - 2 * gap,
        size.height - 2 * gap);
    canvas.drawRRect(RRect.fromRectAndRadius(rect,
        const Radius.circular(17)), line);
    for (final flipX in [false, true]) {
      for (final flipY in [false, true]) {
        canvas.save();
        canvas.translate(flipX ? size.width : 0,
            flipY ? size.height : 0);
        canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);
        final p = Path()
          ..moveTo(12, side + 7)
          ..quadraticBezierTo(12, 12, side + 7, 12)
          ..moveTo(20, side)
          ..quadraticBezierTo(20, 20, side, 20)
          ..moveTo(25, 15)
          ..quadraticBezierTo(31, 22, 38, 15)
          ..moveTo(15, 26)
          ..quadraticBezierTo(22, 32, 15, 38);
        canvas.drawPath(p, line);
        canvas.drawCircle(const Offset(20, 20), 2.0,
          Paint()..color = _v2Gold);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant RawdaGoldCorners oldDelegate) =>
      oldDelegate.strong != strong;
}

class RawdaArchEmblem extends CustomPainter {
  const RawdaArchEmblem();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _v2Gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    final center = size.width / 2;
    final arch = Path()
      ..moveTo(7, size.height - 4)
      ..lineTo(7, size.height * .36)
      ..quadraticBezierTo(12, size.height * .17,
          center, size.height * .035)
      ..quadraticBezierTo(size.width - 12, size.height * .17,
          size.width - 7, size.height * .36)
      ..lineTo(size.width - 7, size.height - 4);
    canvas.drawPath(arch, paint);
    canvas.drawPath(Path()
      ..moveTo(14, size.height - 4)
      ..lineTo(14, size.height * .40)
      ..quadraticBezierTo(18, size.height * .26,
          center, size.height * .12)
      ..quadraticBezierTo(size.width - 18, size.height * .26,
          size.width - 14, size.height * .40)
      ..lineTo(size.width - 14, size.height - 4),
      Paint()..color = _v2Gold.withValues(alpha: .55)
        ..style = PaintingStyle.stroke..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(covariant RawdaArchEmblem oldDelegate) => false;
}

extension RawdaReferenceFidelity on RawdaState {
  Widget framedCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(15),
    bool darkInterior = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: darkInterior ? _v2Emerald
            : (dark ? const Color(0xFF243C31) : _v2Paper),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _v2Gold.withValues(alpha: .65)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF99754B).withValues(alpha: .10),
            blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(children: [
        const Positioned.fill(
            child: CustomPaint(painter: RawdaGoldCorners())),
        Padding(padding: padding, child: child),
      ]),
    );
  }

  Widget referenceCover({double height = 225}) {
    final date = today;
    String hijri = '';
    if (date != null) {
      final h = date['date']['hijri'];
      hijri = "${h['day']} ${h['month'][ar ? 'ar' : 'en']} ${h['year']}";
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(23),
      child: SizedBox(
        height: height,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/madinah_hero.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
              const CustomPaint(painter: RawdaMedinaPainter())),
          const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x90062420), Color(0x180F332B), Color(0xD5053026),
              ],
              stops: [0, .48, 1],
            ),
          )),
          const CustomPaint(painter: RawdaGoldCorners()),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Column(children: [
              Text(tr('الروضة', 'Rawda'),
                style: const TextStyle(color: Color(0xFFF7DDA9),
                  fontSize: 28, fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Color(0xA0000000), blurRadius: 7),
                  ])),
              const Spacer(),
              Text(hijri,
                style: const TextStyle(
                  color: Color(0xFFF4E0B3), fontSize: 11,
                  fontWeight: FontWeight.w700)),
              Text(prefs.getString('prayer_location_label') ??
                  tr('مواقيت الصلاة بحسب موقعك', 'Prayer times by location'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _nextPrayerPanel() {
    final next = upcoming.isEmpty ? null : upcoming.first;
    final index = next?['index'] as int?;
    return Container(
      height: 113,
      decoration: BoxDecoration(
        color: _v2Emerald,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _v2Gold, width: 1.3),
        boxShadow: [BoxShadow(
          color: _v2Emerald.withValues(alpha: .20),
          blurRadius: 11, offset: const Offset(0, 5),
        )],
      ),
      child: Stack(children: [
        const Positioned.fill(child:
          CustomPaint(painter: RawdaGoldCorners(strong: true))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 12),
          child: Row(children: [
            const Icon(Icons.mosque_rounded, size: 42, color: _v2Gold),
            const SizedBox(width: 13),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('الصلاة القادمة', 'Next prayer'),
                  style: const TextStyle(
                    color: _v2Gold, fontSize: 12,
                    fontWeight: FontWeight.w800)),
                Text(index == null
                    ? tr('حدّد موقعك', 'Choose location')
                    : (ar ? prayerArabic[index] : prayerKeys[index]),
                  style: const TextStyle(
                    color: Colors.white, fontSize: 25,
                    fontWeight: FontWeight.w900,
                  )),
                if (next != null)
                  Text("${tr('الأذان', 'Adhan')}: ${timeLabel(next['raw'].toString())}",
                    style: const TextStyle(
                      fontSize: 11, color: Color(0xFFFFE8BD))),
              ],
            )),
            ValueListenableBuilder<DateTime>(
              valueListenable: clockTick,
              builder: (context, tick, child) {
                if (next == null) {
                  return const SizedBox.shrink();
                }
                final delta = (next['at'] as DateTime).difference(tick);
                final left = delta.isNegative ? Duration.zero : delta;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(tr('المتبقي', 'Remaining'),
                      style: const TextStyle(
                        color: _v2Gold, fontSize: 10)),
                    Text(
                      "${left.inHours.toString().padLeft(2, '0')}:${(left.inMinutes % 60).toString().padLeft(2, '0')}:${(left.inSeconds % 60).toString().padLeft(2, '0')}",
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: 'RawdaLatin', color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _referenceShortcut(
    IconData icon, String label, VoidCallback onTap,
  ) {
    return Material(
      color: dark ? const Color(0xFF254034) : _v2Paper,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(17),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _v2Gold.withValues(alpha: .7)),
          ),
          child: Stack(children: [
            const Positioned.fill(
              child: CustomPaint(painter: RawdaGoldCorners())),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 29,
                  color: dark ? const Color(0xFFE8C48D) : _v2Emerald),
                const SizedBox(height: 4),
                Text(label, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget referenceHome() {
    final shortcuts = <(IconData, String, VoidCallback)>[
      (Icons.access_time_rounded,
        tr('أوقات الصلاة', 'Prayer times'), openPrayerToday),
      (Icons.menu_book_rounded,
        tr('القرآن الكريم', 'Quran'), () => showMainTab(0)),
      (Icons.spa_rounded,
        tr('الأذكار', 'Adhkar'), () => openAdhkar('morning')),
      (Icons.emoji_events_rounded,
        tr('المسابقة', 'Quiz'), () => showMainTab(1)),
      (Icons.auto_stories_rounded,
        tr('ركن اليوم', 'Today'), () => showMainTab(3)),
      (Icons.blur_circular_rounded,
        tr('السبحة', 'Tasbih'), openTasbih),
    ];
    return RefreshIndicator(
      onRefresh: loadAccount,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(13, 8, 13, 30),
        children: [
          if (prayerConfigChanged)
            inlineStatus(
              tr('حدّث مواقيت الصلاة بعد تغيير الموقع.',
                'Refresh prayer times after changing location.'),
              () => run(fetchTimes)),
          referenceCover(height: 202),
          const SizedBox(height: 11),
          InkWell(onTap: openPrayerToday,
            child: _nextPrayerPanel()),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shortcuts.length,
            gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: 1.22,
              ),
            itemBuilder: (context, i) => _referenceShortcut(
              shortcuts[i].$1, shortcuts[i].$2,
              shortcuts[i].$3),
          ),
          const SizedBox(height: 13),
          rawdaTasbihTeaser(),
          if (activeIqama != null)
            framedCard(child: Text(
              tr('تذكير الإقامة', 'Iqama reminder'),
              style: const TextStyle(fontWeight: FontWeight.w700))),
          for (final item in announcements)
            Card(child: ListTile(
              title: Text(item['title'].toString()),
              subtitle: Text(item['body'].toString()))),
        ],
      ),
    );
  }

  Widget _pill(String label, bool chosen, VoidCallback onTap) {
    return Material(
      color: chosen ? _v2Emerald
        : (dark ? const Color(0xFF294839) : _v2Paper),
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: _v2Gold.withValues(alpha: .5)),
          ),
          child: Text(label, style: TextStyle(
            color: chosen ? Colors.white : null,
            fontSize: 12, fontWeight: FontWeight.w800,
          )),
        ),
      ),
    );
  }

  Widget referenceQuran() {
    final query = plain(quranTabQuery.trim()).toLowerCase();
    final matched = chapters.where((chapter) =>
      query.isEmpty ||
      plain(chapter['name_arabic'].toString())
          .toLowerCase().contains(query) ||
      chapter['name_simple'].toString().toLowerCase()
          .contains(query) ||
      chapter['id'].toString() == query).toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      itemCount: 3 + matched.length,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _pill(tr('السور', 'Surahs'), true, openQuran),
                const SizedBox(width: 7),
                _pill(tr('الأجزاء', 'Juz'), false, openJuz),
                const SizedBox(width: 7),
                _pill(tr('علاماتي', 'Bookmarks'), false, openBookmarks),
              ]),
            ),
          );
        }
        if (index == 1) {
          return TextField(
            onChanged: (value) {
              quranTabQuery = value;
              refreshSettings();
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: tr('ابحث عن سورة...', 'Search for a surah...'),
              prefixIcon: const Icon(Icons.search, color: _v2Gold),
            ),
          );
        }
        if (index == 2) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(7, 15, 7, 5),
            child: Row(children: [
              Expanded(child: Text(
                tr('سور القرآن الكريم', 'Surahs of the Quran'),
                style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800))),
              Text(matched.length.toString(),
                style: const TextStyle(
                  color: _v2Gold, fontWeight: FontWeight.w800)),
            ]),
          );
        }
        final chapter = matched[index - 3];
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: framedCard(
            padding: const EdgeInsets.all(6),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 3),
              onTap: () => openSurah(chapter['id'] as int),
              leading: const Icon(Icons.auto_stories_rounded,
                  color: _v2Gold, size: 31),
              title: Text(ar
                ? "سورة ${chapter['name_arabic']}"
                : "Surah ${chapter['name_simple']}",
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
              subtitle: Text("${chapter['verses_count']} ${tr('آية', 'verses')}",
                style: const TextStyle(fontSize: 11)),
              trailing: CircleAvatar(
                backgroundColor: const Color(0xFFFFE3AE),
                foregroundColor: _v2Emerald,
                radius: 17,
                child: Text(chapter['id'].toString(),
                  style: const TextStyle(
                    fontFamily: 'RawdaLatin',
                    fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget referenceToday() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 30),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _pill(tr('آية اليوم', 'Verse'), true, openDaily),
            const SizedBox(width: 8),
            _pill(tr('حديث اليوم', 'Hadith'), false, openDaily),
            const SizedBox(width: 8),
            _pill(tr('ذكر اليوم', 'Dhikr'), false,
              () => openAdhkar('morning')),
          ]),
        ),
        const SizedBox(height: 13),
        rawdaDailyAyah(),
        const SizedBox(height: 7),
        rawdaDailyHadith(),
        const SizedBox(height: 7),
        rawdaTasbihTeaser(),
        rawdaSectionTitle(tr('أذكار اليوم', 'Daily adhkar')),
        framedCard(
          padding: const EdgeInsets.symmetric(
            horizontal: 5, vertical: 4),
          child: Column(children: [
            tile(tr('أذكار الصباح', 'Morning adhkar'),
              Icons.wb_sunny_outlined, () => openAdhkar('morning')),
            tile(tr('أذكار المساء', 'Evening adhkar'),
              Icons.nights_stay_outlined, () => openAdhkar('evening')),
            tile(tr('أذكار الصلاة', 'Prayer adhkar'),
              Icons.mosque_outlined, () => openAdhkar('prayer')),
          ]),
        ),
        rawdaSectionTitle(tr('عباداتك', 'Your worship')),
        tile(tr('الورد وخطة الختمة', 'Daily reading'),
            Icons.menu_book, openDaily),
        tile(tr('الصلاة والصيام', 'Prayer and fasting'),
            Icons.checklist_rounded, openTracker),
      ],
    );
  }

  Widget referenceQuizBanner() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: _v2Emerald,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _v2Gold),
      ),
      child: Stack(children: [
        const Positioned.fill(child:
          CustomPaint(painter: RawdaGoldCorners(strong: true))),
        Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded,
              color: Color(0xFFFFD27C), size: 75),
            Text(tr('اختبر معلوماتك الإسلامية',
              'Test your Islamic knowledge'),
              style: const TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(tr('خمس أسئلة كل يوم • نقطتان لكل إجابة',
                'Five questions a day • two points per answer'),
              style: const TextStyle(
                color: Color(0xFFF1D3A0), fontSize: 11)),
          ],
        )),
      ]),
    );
  }

  Widget referenceProfileHeader() {
    final name = account['profile']?['display_name']?.toString()
        ?? tr('عضو الروضة', 'Rawda member');
    return framedCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(children: [
        SizedBox(
          width: 88, height: 94,
          child: Stack(children: [
            const Positioned.fill(
              child: CustomPaint(painter: RawdaArchEmblem())),
            Center(child: CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF38634A),
              backgroundImage: profilePhoto,
              child: profilePhoto == null
                ? const Icon(Icons.mosque_rounded,
                    color: Color(0xFFF0CF91), size: 37)
                : null)),
          ]),
        ),
        const SizedBox(height: 5),
        Text(name, textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21, fontWeight: FontWeight.w900,
            color: dark ? const Color(0xFFF1D3A0) : _v2Emerald)),
        const SizedBox(height: 3),
        Text(accountEmail ?? '',
          style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 9),
        TextButton.icon(
          onPressed: pickProfilePhoto,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(tr('تعديل الصورة', 'Edit photo')),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _profileMetric(
            Icons.stars_rounded, '$balance',
            tr('نقطة', 'Points'))),
          const SizedBox(width: 10),
          Expanded(child: _profileMetric(
            Icons.card_giftcard_rounded, '$earned',
            tr('إجمالي النقاط', 'Earned'))),
        ]),
      ]),
    );
  }

  Widget _profileMetric(IconData icon, String value, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF335345)
          : const Color(0xFFFFEED1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _v2Gold.withValues(alpha: .7)),
      ),
      child: Column(children: [
        Icon(icon, color: _v2Gold, size: 26),
        Text(value, style: const TextStyle(
          fontFamily: 'RawdaLatin', fontWeight: FontWeight.w900,
          fontSize: 20)),
        Text(name, style: const TextStyle(fontSize: 10)),
      ]),
    );
  }

  Widget referencePrayerToday() {
    final current = today;
    final next = upcoming.isEmpty ? null : upcoming.first;
    const icons = <IconData>[
      Icons.wb_twilight, Icons.wb_sunny_rounded,
      Icons.sunny, Icons.wb_twilight_rounded,
      Icons.nights_stay_rounded,
    ];
    return RefreshIndicator(
      onRefresh: fetchTimes,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 30),
        children: [
          framedCard(
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              const Icon(Icons.location_on_rounded,
                color: _v2Gold, size: 25),
              const SizedBox(width: 10),
              Expanded(child: Text(
                prefs.getString('prayer_location_label') ??
                tr('حدّد موقعك أولًا', 'Choose your location'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800))),
              IconButton(
                onPressed: prayerSettings,
                icon: const Icon(Icons.tune_rounded)),
            ]),
          ),
          const SizedBox(height: 8),
          referenceCover(height: 139),
          const SizedBox(height: 12),
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: next?['index'] == i ? _v2Emerald
                  : (dark ? const Color(0xFF243C31)
                      : _v2Paper),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: openPrayerNotifications,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _v2Gold.withValues(alpha: .55)),
                    ),
                    child: Row(children: [
                      Icon(icons[i], size: 25,
                        color: next?['index'] == i
                          ? const Color(0xFFFFD881) : _v2Gold),
                      const SizedBox(width: 14),
                      Expanded(child: Text(
                        ar ? prayerArabic[i] : prayerKeys[i],
                        style: TextStyle(
                          color: next?['index'] == i ? Colors.white : null,
                          fontWeight: FontWeight.w800))),
                      Text(current == null ? '--:--'
                          : timeLabel(
                              current['timings'][prayerKeys[i]].toString()),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: next?['index'] == i
                            ? const Color(0xFFF8D98D) : null,
                          fontSize: 16, fontFamily: 'RawdaLatin',
                          fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: openPrayerMonth,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(tr('مواقيت الشهر', 'Monthly timetable'))),
        ],
      ),
    );
  }
}
