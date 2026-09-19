import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../theme.dart';

/// "Draft CV highlights & cover letter" button + inline result panel, shared
/// between JobCard and HistoryCard. Mirrors the desktop app's
/// ApplicationMaterialsPanel.qml.
class ApplicationMaterialsPanel extends StatefulWidget {
  final Map<String, String> job;
  const ApplicationMaterialsPanel({super.key, required this.job});

  @override
  State<ApplicationMaterialsPanel> createState() => _ApplicationMaterialsPanelState();
}

class _ApplicationMaterialsPanelState extends State<ApplicationMaterialsPanel> {
  bool _busy = false;
  String? _error;
  String? _cvHighlights;
  String? _coverLetter;

  Future<void> _draft() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (highlights, letter) = await ApiClient.instance.draftMaterials(widget.job);
      if (!mounted) return;
      setState(() {
        _cvHighlights = highlights;
        _coverLetter = letter;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied.'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _cvHighlights != null && _coverLetter != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _draft,
          style: OutlinedButton.styleFrom(
            foregroundColor: LedgerColors.brass,
            side: const BorderSide(color: LedgerColors.brass),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          ),
          child: Text(
            _busy
                ? 'Drafting…'
                : (hasResult ? 'Regenerate application materials' : 'Draft CV highlights & cover letter'),
            style: const TextStyle(fontSize: 11),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          if (_error!.contains('Daily limit'))
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Go to Settings > Account to request an upgrade.',
                style: TextStyle(color: LedgerColors.slate, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
        ],
        if (hasResult) ...[
          const SizedBox(height: 10),
          _resultSection('CV highlights for this role', _cvHighlights!),
          const SizedBox(height: 10),
          _resultSection('Cover letter', _coverLetter!),
        ],
      ],
    );
  }

  Widget _resultSection(String label, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: LedgerColors.slate, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: LedgerColors.inkBg,
            border: Border.all(color: LedgerColors.hairline),
          ),
          child: Text(text, style: const TextStyle(color: LedgerColors.parchment, fontSize: 12)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _copy(text),
            style: TextButton.styleFrom(
              foregroundColor: LedgerColors.slate,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Copy', style: TextStyle(fontSize: 10)),
          ),
        ),
      ],
    );
  }
}
