import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../error_utils.dart';
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
      setState(() => _error = friendlyError(e));
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
    final theme = Theme.of(context);
    final hasResult = _cvHighlights != null && _coverLetter != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _draft,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
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
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Go to Settings > Account to request an upgrade.',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
        if (hasResult) ...[
          const SizedBox(height: 10),
          _resultSection(theme, 'CV highlights for this role', _cvHighlights!),
          const SizedBox(height: 10),
          _resultSection(theme, 'Cover letter', _coverLetter!),
        ],
      ],
    );
  }

  Widget _resultSection(ThemeData theme, String label, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSecondary,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _copy(text),
            style: TextButton.styleFrom(
              foregroundColor: theme.textTheme.bodySmall?.color,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Copy', style: TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }
}
