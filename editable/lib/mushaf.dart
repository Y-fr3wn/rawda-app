import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MushafReader extends StatefulWidget {
  const MushafReader({
    super.key,
    required this.arabic,
    required this.preferences,
  });

  final bool arabic;
  final SharedPreferences preferences;

  @override
  State<MushafReader> createState() => _MushafReaderState();
}

class _MushafReaderState extends State<MushafReader> {
  static const _pages = 604;
  static const _positionKey = 'mushaf_page';
  static const _source =
      'https://raw.githubusercontent.com/Miftah-Fentaw/Quran-Images/cca352724b9f29e326e077ce142172ddd9006368/png';

  late int _page;
  late final PageController _controller;

  String _tr(String ar, String en) => widget.arabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _page = (widget.preferences.getInt(_positionKey) ?? 1).clamp(1, _pages);
    _controller = PageController(initialPage: _page - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) {
    if (page >= 1 && page <= _pages && _controller.hasClients) {
      _controller.jumpToPage(page - 1);
    }
  }

  Future<void> _choosePage() async {
    var input = '';
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('انتقل لصفحة', 'Go to page')),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '1–604'),
          onChanged: (value) => input = value.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              const digits = '٠١٢٣٤٥٦٧٨٩';
              final normalized = input.split('').map((character) {
                final index = digits.indexOf(character);
                return index < 0 ? character : '$index';
              }).join();
              final page = int.tryParse(normalized);
              if (page != null && page >= 1 && page <= _pages) {
                Navigator.pop(context, page);
              }
            },
            child: Text(_tr('اذهب', 'Go')),
          ),
        ],
      ),
    );
    if (mounted && target != null) _go(target);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: _tr('الصفحة السابقة', 'Previous page'),
              onPressed: _page > 1 ? () => _go(_page - 1) : null,
              icon: const Icon(Icons.arrow_forward),
            ),
            TextButton(
              onPressed: _choosePage,
              child: Text(
                _tr('صفحة $_page من $_pages', 'Page $_page of $_pages'),
              ),
            ),
            IconButton(
              tooltip: _tr('الصفحة التالية', 'Next page'),
              onPressed: _page < _pages ? () => _go(_page + 1) : null,
              icon: const Icon(Icons.arrow_back),
            ),
          ],
        ),
      ),
      Expanded(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: PageView.builder(
            controller: _controller,
            itemCount: _pages,
            onPageChanged: (index) {
              setState(() => _page = index + 1);
              unawaited(widget.preferences.setInt(_positionKey, index + 1));
            },
            itemBuilder: (context, index) => _MushafPage(
              url: '$_source/${index + 1}.png',
              arabic: widget.arabic,
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          _tr(
            'مصحف المدينة • حفص عن عاصم • مجمع الملك فهد • صور Quran-Images',
            'Madani Mushaf · Hafs · King Fahd Complex · Quran-Images',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}

class _MushafPage extends StatefulWidget {
  const _MushafPage({required this.url, required this.arabic});

  final String url;
  final bool arabic;

  @override
  State<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage> {
  var _attempt = 0;
  bool _zoomed = false;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xfffbf6e9),
    child: InteractiveViewer(
      maxScale: 3,
      panEnabled: _zoomed,
      onInteractionUpdate: (event) {
        if (event.pointerCount > 1 && !_zoomed) setState(() => _zoomed = true);
      },
      child: Center(
        child: Image.network(
          widget.url,
          key: ValueKey(_attempt),
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : const CircularProgressIndicator(),
          errorBuilder: (context, error, stackTrace) => TextButton(
            onPressed: () => setState(() => _attempt++),
            child: Text(
              widget.arabic
                  ? 'تعذّر تحميل الصفحة. اتصل بالإنترنت واضغط لإعادة المحاولة.'
                  : 'Could not load this page. Connect to the internet and tap to retry.',
            ),
          ),
        ),
      ),
    ),
  );
}
