part of 'main.dart';

/// Shared, original green/cream/gold presentation for the Rawda screens.
extension RawdaVisualKit on RawdaState {
  Widget rawdaFeatureHero(String title, String subtitle, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: 150,
        child: Stack(children: [
          const Positioned.fill(
              child: CustomPaint(painter: RawdaMedinaPainter())),
          const Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xE610352B), Color(0xA50D4739)],
                  begin: Alignment.bottomLeft, end: Alignment.topRight,
                ),
              ))),
          Positioned(right: 20, top: 32,
            child: Icon(icon, size: 67,
              color: rawdaGold.withValues(alpha: .28))),
          Padding(
            padding: const EdgeInsets.all(21),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  color: Color(0xFFF8E0AD), fontSize: 23,
                  fontWeight: FontWeight.w800,
                )),
                const SizedBox(height: 8),
                SizedBox(width: 240,
                  child: Text(subtitle, style: const TextStyle(
                    color: Colors.white, fontSize: 12, height: 1.6,
                  ))),
                const SizedBox(height: 11),
                Container(height: 2, width: 52, color: rawdaGold),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget rawdaDailyAyah() {
    // Only show verified words from our bundled Quran index.
    const choices = <(int, int)>[(65, 2), (94, 5), (93, 5), (2, 286)];
    final selected = choices[now.day % choices.length];
    dynamic chosen;
    for (final verse in verses) {
      if (verse['surah'] == selected.$1 &&
          verse['ayah'] == selected.$2) {
        chosen = verse;
        break;
      }
    }
    final chapterName = selected.$1 <= chapters.length
        ? chapters[selected.$1 - 1]['name_arabic'].toString()
        : tr('القرآن الكريم', 'Quran');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: chosen == null ? openQuran
            : () => openSurah(selected.$1, initialAyah: selected.$2),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.auto_stories_rounded, color: rawdaGold),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('آية اليوم', 'Verse of the day'),
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,
                  ))),
              const Icon(Icons.chevron_left_rounded, color: rawdaGold),
            ]),
            const SizedBox(height: 12),
            Text(chosen == null
                ? tr('افتح المصحف لقراءة وردك اليومي',
                    'Open the Quran to read today')
                : chosen['text'].toString(),
              maxLines: 5, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: chosen == null ? null : 'Quran',
                fontSize: chosen == null ? 15 : 22,
                height: chosen == null ? 1.7 : 2.0,
                color: dark ? const Color(0xFFF4DFB4) : rawdaGreen,
              )),
            const SizedBox(height: 9),
            Text(chapterName + ' • ' + selected.$2.toString(),
                style: const TextStyle(color: rawdaGold,
                  fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget rawdaDailyHadith() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.format_quote_rounded,
                color: rawdaGold, size: 30),
            const SizedBox(width: 8),
            Text(tr('حديث اليوم', 'Hadith of the day'),
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                )),
          ]),
          const SizedBox(height: 8),
          Text(tr(
            '«مَنْ سَلَكَ طَرِيقًا يَلْتَمِسُ فِيهِ عِلْمًا، سَهَّلَ اللَّهُ لَهُ بِهِ طَرِيقًا إِلَى الْجَنَّةِ»',
            'Whoever follows a path seeking knowledge, Allah makes his path to Paradise easy.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, height: 1.85,
              color: dark ? const Color(0xFFF4DFB4) : rawdaGreen)),
          const SizedBox(height: 7),
          Text(tr('رواه مسلم', 'Sahih Muslim'),
              style: const TextStyle(
                color: rawdaGold, fontSize: 11,
                fontWeight: FontWeight.w700,
              )),
        ]),
      ),
    );
  }

  Widget rawdaTasbihTeaser() {
    final count = (state['tasbih'] as num?)?.toInt() ?? 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: openTasbih,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 15, vertical: 12),
          child: Row(children: [
            const Icon(Icons.blur_circular_rounded,
                size: 37, color: rawdaGold),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('المسبحة الإلكترونية', 'Digital Tasbih'),
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                  )),
                Text(tr('سبحان الله • الحمد لله • الله أكبر',
                      'Subhan Allah • Alhamdulillah • Allahu Akbar'),
                  style: const TextStyle(fontSize: 10),
                  maxLines: 2),
              ],
            )),
            Text('$count', style: const TextStyle(
              fontSize: 20, color: rawdaGold,
              fontFamily: 'RawdaLatin', fontWeight: FontWeight.w800,
            )),
            const Icon(Icons.chevron_left_rounded, color: rawdaGold),
          ]),
        ),
      ),
    );
  }
}

class RawdaTasbihView extends StatefulWidget {
  const RawdaTasbihView({super.key, required this.app});
  final RawdaState app;
  @override
  State<RawdaTasbihView> createState() => _RawdaTasbihViewState();
}

class _RawdaTasbihViewState extends State<RawdaTasbihView> {
  static const words = <String>[
    'سبحان الله', 'الحمد لله', 'الله أكبر',
    'لا إله إلا الله', 'أستغفر الله',
  ];
  static const english = <String>[
    'Subhan Allah', 'Alhamdulillah', 'Allahu Akbar',
    'La ilaha illa Allah', 'Astaghfirullah',
  ];
  late int count;
  late int goal;
  late String word;
  Timer? pendingSave;

  @override
  void initState() {
    super.initState();
    final state = widget.app.state;
    count = ((state['tasbih'] as num?)?.toInt() ?? 0).clamp(0, 9999999);
    goal = state['tasbihGoal'] == 100 ? 100 : 33;
    final saved = state['tasbihWord']?.toString();
    word = words.contains(saved) ? saved! : words.first;
  }

  void saveLocally() {
    final app = widget.app;
    app.state['tasbih'] = count;
    app.state['tasbihGoal'] = goal;
    app.state['tasbihWord'] = word;
    if (app.uid.isNotEmpty) {
      unawaited(app.prefs.setString(
          'state:' + app.uid, jsonEncode(app.state)));
    }
  }

  void scheduleSave() {
    pendingSave?.cancel();
    pendingSave = Timer(
        const Duration(milliseconds: 300), saveLocally);
  }

  @override
  void dispose() {
    pendingSave?.cancel();
    saveLocally();
    super.dispose();
  }

  void add() {
    HapticFeedback.selectionClick();
    setState(() => count += 1);
    scheduleSave();
  }

  Future<void> reset() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.app.tr('تصفير السبحة؟', 'Reset tasbih?')),
        content: Text(widget.app.tr(
            'سيعود العداد إلى صفر.', 'The count returns to zero.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.app.tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.app.tr('تصفير', 'Reset')),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      setState(() => count = 0);
      saveLocally();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final progress = count == 0 ? 0.0
        : count % goal == 0 ? 1.0 : (count % goal) / goal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 35),
      children: [
        app.rawdaFeatureHero(
          app.tr('مسبحة الروضة', 'Rawda Tasbih'),
          app.tr('اذكر الله بقلب حاضر واحتفظ بعدّادك.',
              'Remember Allah, one bead at a time.'),
          Icons.spa_outlined,
        ),
        const SizedBox(height: 13),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 15, 11, 15),
            child: Column(children: [
              InputDecorator(
                decoration: InputDecoration(
                  labelText: app.tr('اختر الذكر', 'Choose dhikr'),
                  prefixIcon: const Icon(
                    Icons.spa_outlined, color: rawdaGold),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: word,
                    isExpanded: true,
                    items: [
                      for (var i = 0; i < words.length; i++)
                        DropdownMenuItem(
                          value: words[i],
                          child: Text(app.ar ? words[i] : english[i]),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => word = value);
                      saveLocally();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Semantics(
                label: app.tr('التسبيح $count من $goal',
                              'Tasbih $count of $goal'),
                child: SizedBox(
                  height: 292,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: RawdaBeadPainter(
                      progress: progress, isDark: app.dark),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        Text(app.ar ? word : english[words.indexOf(word)],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800,
                              color: app.dark
                                  ? const Color(0xFFF4DFB4) : rawdaGreen)),
                        const SizedBox(height: 4),
                        Text('$count', style: TextStyle(
                          fontFamily: 'RawdaLatin',
                          fontWeight: FontWeight.w800,
                          fontSize: 59, height: 1.2,
                          color: app.dark
                              ? const Color(0xFFF4DFB4) : rawdaGreen,
                        )),
                        Text(app.tr('من', 'of') + ' $goal',
                            style: const TextStyle(
                              color: rawdaGold, fontSize: 13,
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: 25),
                      ],
                    ),
                  ),
                ),
              ),
              Text(app.tr('الهدف لكل دورة', 'Target for each round'),
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 33,
                    label: Text(app.tr('٣٣ تسبيحة', '33 dhikr'))),
                  ButtonSegment(value: 100,
                    label: Text(app.tr('١٠٠ تسبيحة', '100 dhikr'))),
                ],
                selected: {goal},
                onSelectionChanged: (values) {
                  setState(() => goal = values.first);
                  saveLocally();
                },
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Tooltip(
          message: app.tr('اضغط للتسبيح', 'Tap to count'),
          child: Semantics(
            button: true,
            label: app.tr('تسبيحة جديدة', 'Count one dhikr'),
            child: Material(
              color: rawdaGold,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                onTap: add, customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 89, height: 89,
                  child: Icon(Icons.add_rounded,
                      size: 54, color: rawdaGreen),
                ),
              ),
            ),
          ),
        )),
        const SizedBox(height: 7),
        Center(child: Text(app.tr('اضغط للتسبيح', 'Tap to count'),
          style: const TextStyle(
            color: rawdaGold, fontSize: 12,
            fontWeight: FontWeight.w700,
          ))),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: reset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(app.tr('إعادة العداد', 'Reset')),
          )),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(
            onPressed: () async {
              pendingSave?.cancel();
              saveLocally();
              await app.saveState();
              if (mounted) {
                app.toast(app.tr('تم حفظ التسبيح', 'Tasbih saved'));
              }
            },
            icon: const Icon(Icons.cloud_done_outlined),
            label: Text(app.tr('حفظ ومزامنة', 'Save')),
          )),
        ]),
      ],
    );
  }
}

/// 33 painted beads and a gold tassel, no external graphics or frame timer.
class RawdaBeadPainter extends CustomPainter {
  const RawdaBeadPainter({required this.progress, required this.isDark});
  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 7);
    final r = math.min(size.width * .36, size.height * .36);
    final track = Paint()
      ..color = isDark ? const Color(0xFF294737)
          : const Color(0xFFF3E4C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, r, track);
    const gold = Color(0xFFD6AB57);
    for (var i = 0; i < 33; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 33;
      final pos = Offset(center.dx + math.cos(angle) * r,
          center.dy + math.sin(angle) * r);
      final selected = i < (progress * 33).round();
      canvas.drawCircle(pos + const Offset(0, 1.3), 8.9,
          Paint()..color = const Color(0x52000000));
      canvas.drawCircle(pos, 8.0,
          Paint()..shader = RadialGradient(
            center: const Alignment(-.5, -.5),
            radius: .95,
            colors: selected
                ? [const Color(0xFFFAE3AB), gold,
                    const Color(0xFF9C6F30)]
                : [const Color(0xFF4D876A),
                    const Color(0xFF176449),
                    const Color(0xFF093C32)],
          ).createShader(Rect.fromCircle(center: pos, radius: 9)));
      canvas.drawCircle(pos, 8.0,
          Paint()..style = PaintingStyle.stroke
            ..strokeWidth = .8
            ..color = gold.withValues(alpha: .75));
    }
    final tip = center.dy + r + 5;
    canvas.drawLine(Offset(center.dx, tip),
        Offset(center.dx, tip + 21),
        Paint()..color = gold
          ..strokeWidth = 2.3);
    canvas.drawCircle(Offset(center.dx, tip + 7), 4,
        Paint()..color = gold);
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(Offset(center.dx, tip + 20),
          Offset(center.dx + i * 3, tip + 35),
          Paint()..color = gold
            ..strokeWidth = 1.6);
    }
  }

  @override
  bool shouldRepaint(covariant RawdaBeadPainter oldDelegate) =>
      progress != oldDelegate.progress || isDark != oldDelegate.isDark;
}


/// Sensor-aware Qibla dial (rotation is applied only with a live heading).
class RawdaCompassFace extends StatelessWidget {
  const RawdaCompassFace({super.key, required this.bearing,
      required this.heading, required this.dark});
  final double bearing;
  final double? heading;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Qibla bearing ' + bearing.toStringAsFixed(1),
      child: SizedBox(
        width: 285, height: 285,
        child: CustomPaint(painter: RawdaCompassPainter(
          rotation: heading == null ? null
              : (bearing - heading!) * math.pi / 180,
          dark: dark,
        )),
      ),
    );
  }
}

class RawdaCompassPainter extends CustomPainter {
  const RawdaCompassPainter({required this.rotation, required this.dark});
  final double? rotation;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * .46;
    canvas.drawCircle(center, r, Paint()
      ..shader = const RadialGradient(colors: [
        Color(0xFF326B54), Color(0xFF0C4A3A), Color(0xFF092C26),
      ]).createShader(Rect.fromCircle(center: center, radius: r)));
    canvas.drawCircle(center, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFFD2AA65));
    canvas.drawCircle(center, r - 16, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x75E0BB79));
    for (var i = 0; i < 72; i++) {
      final a = i * math.pi / 36 - math.pi / 2;
      final inner = r - (i % 9 == 0 ? 26 : 17);
      final p1 = center + Offset(math.cos(a) * inner, math.sin(a) * inner);
      final p2 = center + Offset(math.cos(a) * (r - 9),
          math.sin(a) * (r - 9));
      canvas.drawLine(p1, p2, Paint()
        ..color = const Color(0xFFE7C58B).withValues(
          alpha: i % 9 == 0 ? .95 : .48)
        ..strokeWidth = i % 9 == 0 ? 2.0 : .9);
    }
    const labels = <String>['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 - math.pi / 2;
      final p = center + Offset(
          math.cos(angle) * (r - 42), math.sin(angle) * (r - 42));
      final tp = TextPainter(
        text: TextSpan(text: labels[i],
          style: const TextStyle(color: Color(0xFFF5E2B9),
              fontSize: 15, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    if (rotation != null) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation!);
      final needle = Path()
        ..moveTo(0, -r * .59)
        ..lineTo(-17, 11)
        ..lineTo(0, -4)
        ..lineTo(17, 11)
        ..close();
      canvas.drawPath(needle, Paint()
        ..color = const Color(0xFFF5D293));
      canvas.drawPath(Path()
        ..moveTo(-17, 11)..lineTo(0, r * .56)
        ..lineTo(17, 11)..lineTo(0, -4)..close(),
        Paint()..color = const Color(0xFF77AB8C));
      canvas.restore();
    }
    canvas.drawCircle(center, 16,
        Paint()..color = const Color(0xFFE7BC73));
    canvas.drawCircle(center, 9,
        Paint()..color = const Color(0xFF184C3D));
    final mosque = TextPainter(
      text: const TextSpan(text: '🕋',
        style: TextStyle(fontSize: 21)),
      textDirection: TextDirection.ltr,
    )..layout();
    mosque.paint(canvas, center -
      Offset(mosque.width / 2, mosque.height / 2));
  }
  @override
  bool shouldRepaint(covariant RawdaCompassPainter oldDelegate) =>
      rotation != oldDelegate.rotation || dark != oldDelegate.dark;
}


/// Daily five-prayer screen matching the light Rawda design. The authoritative
/// timings come from the existing Cairo-aware prayer calendar.
extension RawdaPrayerToday on RawdaState {
  void openPrayerToday() {
    push(tr('أوقات الصلاة', 'Prayer times'),
      (context) => rawdaPrayerToday());
  }

  Widget rawdaPrayerToday() {
    final current = today;
    final next = upcoming.isNotEmpty ? upcoming.first : null;
    final label = prefs.getString('prayer_location_label') ??
        tr('الموقع المحدد', 'Selected location');
    final icons = <IconData>[
      Icons.wb_twilight_outlined,
      Icons.wb_sunny_outlined,
      Icons.wb_sunny_rounded,
      Icons.wb_twilight_rounded,
      Icons.nightlight_round,
    ];
    return RefreshIndicator(
      onRefresh: fetchTimes,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 35),
        children: [
          rawdaFeatureHero(tr('أوقات الصلاة', 'Prayer times'),
              tr('صلاتك في وقتها، أينما كنت',
                 'Keep your prayer times at hand'),
              Icons.mosque_outlined),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined,
                  color: rawdaGold),
              title: Text(label, style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14,
              )),
              subtitle: Text(tr(
                'المواقيت وفق الموقع المختار والتوقيت المحلي',
                'Local times for your selected location')),
              trailing: IconButton(
                tooltip: tr('الموقع والتوقيت', 'Location & time zone'),
                onPressed: prayerSettings,
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < prayerKeys.length; i++)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                color: next != null && next['index'] == i
                    ? (dark ? const Color(0xFF1C5440) : rawdaGreen)
                    : null,
                child: ListTile(
                  leading: Icon(icons[i], size: 29,
                      color: next != null && next['index'] == i
                        ? const Color(0xFFF2D6A0)
                        : rawdaGold),
                  title: Text(ar ? prayerArabic[i] : prayerKeys[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: next != null && next['index'] == i
                        ? Colors.white : null,
                    )),
                  subtitle: next != null && next['index'] == i
                    ? Text(tr('الصلاة القادمة', 'Next prayer'),
                      style: const TextStyle(
                        color: Color(0xFFEBD4A5), fontSize: 11))
                    : null,
                  trailing: Text(current == null ? '--:--'
                      : timeLabel(current['timings'][prayerKeys[i]]
                          .toString()),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 19, fontFamily: 'RawdaLatin',
                      fontWeight: FontWeight.w800,
                      color: next != null && next['index'] == i
                        ? const Color(0xFFF8E6BC)
                        : (dark ? const Color(0xFFF5DCA6) : rawdaGreen),
                    )),
                ),
              ),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: openPrayerMonth,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(tr('جدول مواقيت الشهر',
                          'Monthly prayer timetable')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: openPrayerNotifications,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(tr('تنبيهات الأذان',
                          'Adhan notifications')),
          ),
          if (current == null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(tr(
                'لا توجد مواقيت محمّلة. حدّد موقعك أو اسحب للتحديث.',
                'No prayer times loaded. Choose a location or pull to refresh.'),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
