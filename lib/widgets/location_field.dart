import 'package:flutter/material.dart';
import '../services/location_autocomplete_service.dart';

/// A text field that shows the human-readable location name to the user
/// but stores the full "Name|lat,lon" value internally.
///
/// Pass a [TextEditingController] — its text will always be the stored
/// "Name|lat,lon" format. The visible input shows only the name part.
class LocationField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;

  const LocationField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText = 'Search location...',
    this.prefixIcon = Icons.location_on,
  });

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  final TextEditingController _displayCtrl = TextEditingController();
  List<LocationSuggestion> _suggestions = [];
  bool _loading = false;
  bool _suppressSearch = false;

  @override
  void initState() {
    super.initState();
    // Show name part of stored value on init
    _displayCtrl.text = _nameFrom(widget.controller.text);
    _displayCtrl.addListener(_onTyped);
  }

  String _nameFrom(String stored) {
    if (stored.isEmpty) return '';
    return stored.contains('|') ? stored.split('|').first.trim() : stored;
  }

  void _onTyped() {
    if (_suppressSearch) return;
    final q = _displayCtrl.text.trim();
    if (q.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _search(q);
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final results =
          await LocationAutocompleteService.instance.searchLocations(q);
      if (mounted) setState(() { _suggestions = results; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pick(LocationSuggestion s) {
    final name = _shortName(s.displayName);
    final coords = '${s.lat},${s.lon}';
    final stored = '$name|$coords';

    _suppressSearch = true;
    _displayCtrl.text = name;
    widget.controller.text = stored;
    _suppressSearch = false;

    setState(() => _suggestions = []);
  }

  String _shortName(String displayName) {
    final parts = displayName.split(',');
    if (parts.length >= 2) return '${parts[0].trim()}, ${parts[1].trim()}';
    return parts[0].trim();
  }

  @override
  void dispose() {
    _displayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _displayCtrl,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(widget.prefixIcon),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _displayCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _displayCtrl.clear();
                          widget.controller.clear();
                          setState(() => _suggestions = []);
                        },
                      )
                    : null,
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length > 5 ? 5 : _suggestions.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                final name = _shortName(s.displayName);
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, size: 18),
                  title: Text(name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    '${s.lat.toStringAsFixed(4)}, ${s.lon.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  onTap: () => _pick(s),
                );
              },
            ),
          ),
      ],
    );
  }
}
