import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranAudioControls extends StatefulWidget {
  const QuranAudioControls({
    super.key,
    required this.surah,
    required this.arabic,
    required this.preferences,
  });

  final int surah;
  final bool arabic;
  final SharedPreferences preferences;

  @override
  State<QuranAudioControls> createState() => _QuranAudioControlsState();
}

class _QuranAudioControlsState extends State<QuranAudioControls> {
  static const _bridge = MethodChannel('com.rawda/native');
  static const _events = EventChannel('com.rawda/quran');
  static const _preference = 'quran_reciter';
  static const _readers = [
    ('الحصري', 'Al-Hussary', 'mahmoud-husary/r1'),
    ('المنشاوي', 'Al-Minshawi', 'muhammad-minshawi/r1'),
    ('عبدالباسط', 'Abdul Basit', 'abdulbasit-abdulsamad/r3'),
    ('العفاسي', 'Al-Afasy', 'mishary-alafasy/r1'),
    ('نعينع', 'Ahmad Nainaa', 'ahmad-naina/r1'),
  ];

  StreamSubscription<dynamic>? _subscription;
  late int _reader;
  String _status = 'idle';

  String _tr(String ar, String en) => widget.arabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _reader = (widget.preferences.getInt(_preference) ?? 0).clamp(
      0,
      _readers.length - 1,
    );
  }

  Future<void> _control(String method, [Map<String, String>? args]) async {
    try {
      await _bridge.invokeMethod<void>(method, args);
    } catch (_) {
      if (mounted) setState(() => _status = 'error');
    }
  }

  void _play() {
    _subscription ??= _events.receiveBroadcastStream().listen(
      (status) {
        if (mounted && status is String) setState(() => _status = status);
      },
      onError: (Object _) {
        if (mounted) setState(() => _status = 'error');
      },
    );
    final folder = _readers[_reader].$3;
    final surah = widget.surah.toString().padLeft(3, '0');
    unawaited(
      _control('quranPlay', {
        'url': 'https://cdn.mp3quran.net/audio/$folder/$surah.mp3',
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _status == 'playing';
    final loading = _status == 'loading';
    final error = switch (_status) {
      'alarm' => _tr(
        'التلاوة متاحة بعد الأذان',
        'Listen after the prayer alarm',
      ),
      'error' => _tr(
        'تعذر تشغيل التلاوة. تحقق من الإنترنت وحاول تاني.',
        'Audio unavailable. Check your connection and retry.',
      ),
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _reader,
                  items: [
                    for (var i = 0; i < _readers.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(_tr(_readers[i].$1, _readers[i].$2)),
                      ),
                  ],
                  onChanged: (reader) {
                    if (reader == null || reader == _reader) return;
                    if (_subscription != null) unawaited(_control('quranStop'));
                    setState(() => _reader = reader);
                    unawaited(widget.preferences.setInt(_preference, reader));
                  },
                ),
              ),
              if (loading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: playing
                      ? _tr('إيقاف مؤقت', 'Pause')
                      : _status == 'paused'
                      ? _tr('استكمال التلاوة', 'Resume recitation')
                      : _tr('استمع للسورة', 'Listen to surah'),
                  onPressed: playing ? () => _control('quranPause') : _play,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                ),
              IconButton(
                tooltip: _tr('إيقاف التلاوة', 'Stop recitation'),
                onPressed: (playing || loading || _status == 'paused')
                    ? () => _control('quranStop')
                    : null,
                icon: const Icon(Icons.stop),
              ),
            ],
          ),
          Text(
            error ??
                _tr(
                  'التلاوة عبر الإنترنت • MP3Quran',
                  'Online recitation • MP3Quran',
                ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
