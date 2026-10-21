import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/l10n/app_strings.dart';
import '../domain/page_source.dart';

class EbookSearchSheet extends StatefulWidget {
  const EbookSearchSheet({super.key, required this.search});
  final Future<List<TextSearchResult>> Function(String, CancellationSignal)
  search;
  @override
  State<EbookSearchSheet> createState() => _EbookSearchSheetState();
}

class _EbookSearchSheetState extends State<EbookSearchSheet>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _cancellation?.cancel();
    }
  }

  final _text = TextEditingController();
  CancellationController? _cancellation;
  List<TextSearchResult> _results = [];
  bool _loading = false;
  String? _message;
  Future<void> _search() async {
    final query = _text.text.trim();
    if (query.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final results = await widget.search(
        query,
        _cancellation = CancellationController(),
      );
      if (mounted && !(_cancellation?.isCancelled ?? false)) {
        setState(() {
          _results = results;
          _message = results.isEmpty ? 'No matches found.' : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Search is unavailable for this book.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancellation?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      // The shared sheet already lifts its panel above the keyboard.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom) *
            .65,
        child: Column(
          children: [
            TextField(
              controller: _text,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: context.tr('Search in book'),
                suffixIcon: IconButton(
                  tooltip: context.tr('Search'),
                  icon: const Icon(InkIcons.magnifyingGlass),
                  onPressed: _search,
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: LText(_message!),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final result = _results[i];
                  return ListTile(
                    title: Text(
                      result.chapterTitle ?? result.locator.title ?? '',
                    ),
                    subtitle: Text(
                      result.text?.highlight ?? result.text?.after ?? '',
                    ),
                    onTap: () => Navigator.pop(context, result.locator),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
