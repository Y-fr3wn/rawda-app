part of 'main.dart';

/// Light, structured settings with the same visual identity as the home page.
/// All controls use existing persistence and Android notification actions.
extension RefinedRawdaSettings on RawdaState {
  Widget _settingsSection(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 21, color: dark ? rawdaGold : rawdaGreen),
          const SizedBox(width: 9),
          Expanded(child: Text(title, style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800,
          ))),
        ],
      ),
    );
  }

  Widget _settingsTile(
    String title, IconData icon, VoidCallback onTap, {
    String? subtitle,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF345144) : const Color(0xFFF3E8D4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: dark ? rawdaGold : rawdaGreen, size: 22),
      ),
      title: Text(title, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
      )),
      subtitle: subtitle == null ? null :
          Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: Icon(ar ? Icons.chevron_left_rounded :
          Icons.chevron_right_rounded, size: 19, color: rawdaGold),
    );
  }

  Widget _settingsSwitch(
    String title, String subtitle, IconData icon,
    bool value, ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      secondary: Icon(icon, color: dark ? rawdaGold : rawdaGreen),
      title: Text(title, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      value: value,
      activeColor: rawdaGreen,
      onChanged: onChanged,
    );
  }

  Widget _settingsGroup(List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1,
                color: rawdaGold.withValues(alpha: .15)),
            ),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget refinedSettingsPage(BuildContext context, StateSetter update) {
    final fontSize = ((state['quranSize'] as num?)?.toDouble() ?? 30)
        .clamp(20.0, 48.0).toDouble();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: SizedBox(
            height: 104,
            child: Stack(
              children: [
                const Positioned.fill(child:
                    CustomPaint(painter: RawdaMedinaPainter())),
                Positioned.fill(child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        rawdaGreen.withValues(alpha: .20),
                        const Color(0xFF092D24).withValues(alpha: .79),
                      ],
                    ),
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.all(21),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.tune_rounded,
                          color: Color(0xFFEBD4A5), size: 22),
                      const SizedBox(height: 7),
                      Text(tr('الروضة على ذوقك', 'Make Rawda yours'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w800,
                          )),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _settingsSection(tr('المظهر والقراءة', 'Appearance & reading'),
            Icons.palette_outlined),
        _settingsGroup([
          _settingsSwitch(
            tr('الوضع الليلي', 'Dark mode'),
            tr('اختر إضاءة مريحة لعينيك', 'Comfortable display at night'),
            Icons.dark_mode_outlined, dark,
            (v) {
              dark = v;
              refreshSettings();
              update(() {});
              prefs.setBool('dark', v);
            },
          ),
          _settingsSwitch(
            tr('اللغة العربية', 'Arabic language'),
            tr('غيّر لغة التطبيق', 'Change app language'),
            Icons.language_rounded, ar,
            (v) {
              ar = v;
              refreshSettings();
              update(() {});
              prefs.setBool('arabic', v);
              schedule();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.format_size_rounded,
                      color: dark ? rawdaGold : rawdaGreen),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    tr('حجم خط القرآن الكريم', 'Quran text size'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  )),
                  Text(fontSize.round().toString(),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                Slider(
                  value: fontSize,
                  min: 20, max: 48, divisions: 14,
                  label: fontSize.round().toString(),
                  onChanged: (value) {
                    state['quranSize'] = value;
                    update(() {});
                  },
                  onChangeEnd: (value) {
                    state['quranSize'] = value;
                    unawaited(saveState());
                  },
                ),
                Text(
                  tr('ينطبق على قراءة السور داخل المصحف',
                     'Applies when reading Quran surahs'),
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          _settingsSwitch(
            tr('نظام ٢٤ ساعة', '24-hour time'),
            tr('طريقة عرض مواقيت الصلاة', 'Prayer time display'),
            Icons.schedule_rounded,
            config['clock24'] == true,
            (v) {
              config['clock24'] = v;
              unawaited(persistConfig());
              update(() {});
            },
          ),
        ]),
        _settingsSection(tr('الصلاة والأذان', 'Prayer & adhan'),
            Icons.mosque_outlined),
        _settingsGroup([
          _settingsTile(
            tr('إعدادات الأذان', 'Adhan settings'),
            Icons.notifications_active_outlined, openPrayerNotifications,
            subtitle: tr('إشعارات الصلاة والإقامة',
                         'Prayer and iqama notifications'),
          ),
          _settingsTile(
            tr('أصوات الأذان', 'Adhan voices'),
            Icons.volume_up_outlined, openAudio,
            subtitle: tr('تخصيص صوت كل صلاة', 'Choose each prayer sound'),
          ),
          _settingsTile(
            tr('الموقع والتوقيت', 'Location & time zone'),
            Icons.location_on_outlined, prayerSettings,
            subtitle: tr('توقيت مصر الصيفي والشتوي',
                         'Egypt summer and winter time'),
          ),
          _settingsTile(
            tr('التذكيرات', 'Reminders'),
            Icons.alarm_outlined, openReminders,
          ),
          _settingsTile(
            tr('صلاحيات الأذان والاختبار', 'Permissions & adhan test'),
            Icons.verified_user_outlined, openPermissions,
          ),
        ]),
        _settingsSection(tr('التطبيق والحساب', 'App & account'),
            Icons.settings_suggest_outlined),
        _settingsGroup([
          _settingsTile(
            tr('حسابي', 'My account'),
            Icons.account_circle_outlined,
            () {
              Navigator.of(context).pop();
              page = 4;
              refreshSettings();
            },
          ),
          if (isAdmin) _settingsTile(
            tr('لوحة إدارة الروضة', 'Administration'),
            Icons.admin_panel_settings_outlined, openAdmin,
          ),
          _settingsTile(
            tr('عن الروضة والمصادر', 'About Rawda & sources'),
            Icons.info_outline_rounded, about,
          ),
        ]),
        const SizedBox(height: 24),
        Center(child: Text(
          tr('الروضة • رفيقك للقرآن والصلاة والذكر',
             'Rawda • Your companion for prayer and Quran'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: dark ? const Color(0xFFCCBD9E) : const Color(0xFF86795F),
            fontSize: 11,
          ),
        )),
      ],
    );
  }
}
