part of 'main.dart';

extension RawdaAdministration on RawdaState {
  void openAdmin() {
    if (!isAdmin) {
      toast(
        tr(
          'لوحة الإدارة لصاحب التطبيق فقط',
          'Administration is restricted to the owner',
        ),
      );
      return;
    }
    push(
      tr('إدارة الروضة', 'Rawda administration'),
      (context) => wrapList([
        sectionHero(
          tr('لوحة تحكمك', 'Your control panel'),
          tr(
            'إدارة المحتوى بحسابك وصلاحيتك الخاصة',
            'Manage content with your own administrator account',
          ),
          Icons.admin_panel_settings_outlined,
        ),
        const SizedBox(height: 16),
        tile(
          tr('أسئلة المسابقة', 'Quiz questions'),
          Icons.quiz_outlined,
          () => openAdminList('questions'),
        ),
        tile(
          tr('الهدايا والمكافآت', 'Gifts & rewards'),
          Icons.card_giftcard_outlined,
          () => openAdminList('rewards'),
        ),
        tile(
          tr('إعلانات داخل التطبيق', 'In-app announcements'),
          Icons.campaign_outlined,
          () => openAdminList('announcements'),
        ),
        tile(
          tr('أصوات الأذان', 'Adhan voices'),
          Icons.library_music_outlined,
          () => openAdminList('voices'),
        ),
        notice(
          tr(
            'الإعلانات تظهر عند فتح التطبيق أو تحديث الحساب. الإشعارات الفورية إلى الهواتف تحتاج خدمة إرسال منفصلة.',
            'Announcements appear on app open or account refresh. Push delivery requires a separate sending service.',
          ),
        ),
      ]),
    );
  }

  void openAdminList(String kind) {
    final title = {
      'questions': tr('أسئلة المسابقة', 'Quiz questions'),
      'rewards': tr('الهدايا', 'Rewards'),
      'announcements': tr('إعلانات التطبيق', 'Announcements'),
      'voices': tr('أصوات الأذان', 'Adhan voices'),
    }[kind]!;
    push(title, (context) => AdminContentScreen(app: this, kind: kind));
  }
}

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key, required this.app, required this.kind});
  final RawdaState app;
  final String kind;
  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  List<dynamic> rows = [];
  bool loading = true;
  String? error;
  RawdaState get a => widget.app;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await a.rpc(
        'rawda_admin_list',
        params: {'p_kind': widget.kind},
      );
      if (mounted) setState(() => rows = data as List);
    } catch (e) {
      if (mounted) setState(() => error = a.err(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggle(Map<String, dynamic> row) async {
    try {
      await a.rpc(
        'rawda_admin_save',
        params: {
          'p_kind': widget.kind,
          'p_data': {...row, 'active': row['active'] != true},
        },
      );
      await load();
      await a.loadCommunityConfig();
    } catch (e) {
      if (mounted) setState(() => error = a.err(e));
    }
  }

  @override
  Widget build(BuildContext context) => a.wrapList([
    FilledButton.icon(
      onPressed: () => edit(),
      icon: const Icon(Icons.add),
      label: Text(a.tr('إضافة جديد', 'Add new')),
    ),
    if (loading)
      const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator()),
      ),
    if (error != null) a.inlineStatus(error!, load),
    if (!loading && error == null && rows.isEmpty)
      Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          a.tr(
            'لا يوجد محتوى هنا بعد. أضف أول عنصر.',
            'No content yet. Add the first item.',
          ),
        ),
      ),
    for (final raw in rows)
      Builder(
        builder: (context) {
          final row = obj(raw);
          return Card(
            child: ListTile(
              title: Text(
                '${row['question_ar'] ?? row['title_ar'] ?? row['title'] ?? row['id']}',
              ),
              subtitle: Text(
                row['active'] == true
                    ? a.tr('ظاهر للمستخدمين', 'Active')
                    : a.tr('متوقف', 'Inactive'),
              ),
              onTap: () => edit(row),
              trailing: Switch(
                value: row['active'] == true,
                onChanged: (_) => toggle(row),
              ),
            ),
          );
        },
      ),
  ]);

  Future<void> edit([Map<String, dynamic>? existing]) async {
    final kind = widget.kind;
    final keys = switch (kind) {
      'questions' => [
        'id',
        'question_ar',
        'question_en',
        'option0_ar',
        'option1_ar',
        'option2_ar',
        'option3_ar',
        'option0_en',
        'option1_en',
        'option2_en',
        'option3_en',
        'correct_index',
        'category',
        'difficulty',
        'reference',
      ],
      'rewards' => ['id', 'title_ar', 'title_en', 'cost', 'kind', 'asset_key'],
      'voices' => ['id', 'title', 'url', 'license'],
      _ => ['id', 'title', 'body'],
    };
    const labels = {
      'id': 'الرقم أو المعرّف',
      'question_ar': 'السؤال بالعربية',
      'question_en': 'السؤال بالإنجليزية',
      'correct_index': 'رقم الإجابة الصحيحة من ٠ إلى ٣',
      'category': 'التصنيف',
      'difficulty': 'الصعوبة من ١ إلى ٣',
      'reference': 'المصدر',
      'title_ar': 'الاسم بالعربية',
      'title_en': 'الاسم بالإنجليزية',
      'cost': 'تكلفة النقاط',
      'kind': 'النوع: theme أو badge أو title',
      'asset_key': 'المحتوى: olive / sand / midnight أو learner أو explorer',
      'title': 'العنوان',
      'url': 'رابط ملف الصوت HTTPS',
      'license': 'الترخيص أو إذن الاستخدام',
      'body': 'نص الإعلان',
    };
    final values = <String, TextEditingController>{};
    for (final key in keys) {
      dynamic value = existing?[key];
      final m = RegExp(r'^option([0-3])_(ar|en)$').firstMatch(key);
      if (m != null) {
        value = (existing?['options_${m[2]}'] as List?)?[int.parse(m[1]!)];
      }
      values[key] = TextEditingController(
        text:
            '${value ?? (key == 'difficulty'
                    ? 1
                    : key == 'correct_index'
                    ? 0
                    : key == 'category'
                    ? 'general'
                    : '')}',
      );
    }
    String? issue;
    bool saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .9,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  a.tr('تحرير المحتوى', 'Edit content'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 23,
                  ),
                ),
                const SizedBox(height: 16),
                for (final key in keys) ...[
                  TextField(
                    controller: values[key],
                    enabled: !(existing != null && key == 'id'),
                    maxLines: key == 'body' ? 4 : 1,
                    decoration: InputDecoration(
                      labelText: a.ar
                          ? (labels[key] ??
                                (key.startsWith('option')
                                    ? 'الاختيار ${int.parse(key[6]) + 1} — ${key.endsWith('ar') ? 'عربي' : 'إنجليزي'}'
                                    : key))
                          : key,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (issue != null)
                  Text(
                    issue!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          update(() {
                            saving = true;
                            issue = null;
                          });
                          try {
                            final data = <String, dynamic>{
                              'active': existing?['active'] ?? true,
                            };
                            for (final e in values.entries) {
                              data[e.key] = e.value.text.trim();
                            }
                            if (kind == 'questions') {
                              for (final lang in ['ar', 'en']) {
                                data['options_$lang'] = [
                                  for (var i = 0; i < 4; i++)
                                    data.remove('option${i}_$lang'),
                                ];
                              }
                              for (final key in [
                                'id',
                                'correct_index',
                                'difficulty',
                              ]) {
                                data[key] = int.tryParse('${data[key]}');
                              }
                            }
                            if (kind == 'rewards') {
                              data['cost'] = int.tryParse('${data['cost']}');
                            }
                            await a.rpc(
                              'rawda_admin_save',
                              params: {'p_kind': kind, 'p_data': data},
                            );
                            if (context.mounted) Navigator.pop(context);
                            await a.loadCommunityConfig();
                            await a.refreshWallet();
                            await load();
                          } catch (e) {
                            if (context.mounted) update(() => issue = a.err(e));
                          } finally {
                            if (context.mounted) update(() => saving = false);
                          }
                        },
                  child: Text(
                    saving
                        ? a.tr('جاري الحفظ…', 'Saving…')
                        : a.tr('حفظ', 'Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final c in values.values) {
      c.dispose();
    }
  }
}
