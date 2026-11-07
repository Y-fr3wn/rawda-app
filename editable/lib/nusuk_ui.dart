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
      (tr('أوقات الصلاة', 'Prayer times'),
        Icons.access_time_filled_rounded, openPrayerToday,
        const Color(0xFF97713A)),
      (tr('القرآن الكريم', 'Holy Quran'),
        Icons.menu_book_rounded, openQuran, rawdaGreen),
      (tr('القبلة', 'Qibla'), Icons.explore_rounded,
        openQibla, const Color(0xFF9B7842)),
      (tr('الأذكار', 'Adhkar'), Icons.spa_outlined,
        () => openAdhkar('morning'), const Color(0xFF6F8B54)),
      (tr('المسابقة', 'Quiz'), Icons.emoji_events_outlined,
        () => showMainTab(1), const Color(0xFFAF8849)),
      (tr('اليوم', 'Today'), Icons.today_outlined,
        () => showMainTab(3), const Color(0xFF90734B)),
      (tr('السبحة', 'Tasbih'), Icons.blur_circular_rounded,
        openTasbih, const Color(0xFF288060)),
      (tr('الورد اليومي', 'Daily reading'),
        Icons.auto_stories_outlined, openDaily,
        const Color(0xFF95784C)),
      (tr('الإعدادات', 'Settings'),
        Icons.tune_rounded, settings, const Color(0xFF5C7B72)),
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

  Widget nusukInspiredHome() => referenceHome();

  Widget nusukInspiredQuran() => referenceQuran();

  Widget nusukInspiredToday() => referenceToday();
}
