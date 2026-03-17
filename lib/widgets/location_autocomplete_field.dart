import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_autocomplete_service.dart';

class LocationAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Function(LocationSuggestion)? onLocationSelected;
  final String? Function(String?)? validator;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.hint = 'Start typing location...',
    this.icon = Icons.location_on,
    this.onLocationSelected,
    this.validator,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends State<LocationAutocompleteField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<LocationSuggestion> _suggestions = [];
  bool _isLoading = false;
  LocationSuggestion? _selectedLocation;
  bool _overlayInserted = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    // Remove overlay safely on dispose
    _safeRemoveOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) return;

    final query = widget.controller.text;

    if (query.isEmpty) {
      _safeRemoveOverlay();
      if (mounted) {
        setState(() {
          _suggestions = [];
          _selectedLocation = null;
        });
      }
      return;
    }

    if (_selectedLocation != null && query != _selectedLocation!.displayName) {
      if (mounted) setState(() => _selectedLocation = null);
    }

    if (query.length < 3) {
      _safeRemoveOverlay();
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    LocationAutocompleteService.instance.searchWithDebounce(
      query,
      (results) {
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
        if (results.isNotEmpty) {
          _showOverlay();
        } else {
          _safeRemoveOverlay();
        }
      },
    );
  }

  void _showOverlay() {
    if (!mounted) return;
    _safeRemoveOverlay();

    // Use post-frame callback to ensure context is valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final overlayState = Overlay.maybeOf(context);
      if (overlayState == null) return;

      _overlayEntry = OverlayEntry(
        builder: (ctx) => Positioned(
          width: _getTextFieldWidth(),
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, _getTextFieldHeight() + 4),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length + 2, // +2 for current location and manual options
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    // First item: Use Current Location
                    if (index == 0) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.my_location,
                          size: 20,
                          color: Colors.blue,
                        ),
                        title: const Text(
                          'Use Current Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => _useCurrentLocation(),
                      );
                    }
                    
                    // Second item: Enter Manually
                    if (index == 1) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.edit_location_alt,
                          size: 20,
                          color: Colors.orange,
                        ),
                        title: const Text(
                          'Enter Manually',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => _enterManually(),
                      );
                    }
                    
                    // Rest: Location suggestions
                    final suggestion = _suggestions[index - 2];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _getIconForType(suggestion.type),
                        size: 20,
                        color: Colors.blue,
                      ),
                      title: Text(
                        _getShortName(suggestion.displayName),
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        suggestion.displayName,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectLocation(suggestion),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      try {
        overlayState.insert(_overlayEntry!);
        _overlayInserted = true;
      } catch (e) {
        debugPrint('❌ Failed to insert overlay: $e');
        _overlayEntry = null;
        _overlayInserted = false;
      }
    });
  }

  void _safeRemoveOverlay() {
    if (_overlayEntry != null && _overlayInserted) {
      try {
        _overlayEntry!.remove();
      } catch (_) {}
    }
    _overlayEntry = null;
    _overlayInserted = false;
  }

  void _selectLocation(LocationSuggestion suggestion) {
    _safeRemoveOverlay();
    if (!mounted) return;

    setState(() {
      _selectedLocation = suggestion;
      widget.controller.text = _getShortName(suggestion.displayName);
      _suggestions = [];
    });

    widget.onLocationSelected?.call(suggestion);
  }

  void _useCurrentLocation() async {
    _safeRemoveOverlay();
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _suggestions = [];
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      final suggestion = LocationSuggestion(
        displayName: 'Current Location',
        lat: position.latitude,
        lon: position.longitude,
        type: 'current',
      );

      setState(() {
        _selectedLocation = suggestion;
        widget.controller.text = 'Current Location';
        _isLoading = false;
        _suggestions = [];
      });
      widget.onLocationSelected?.call(suggestion);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  void _enterManually() {
    _safeRemoveOverlay();
    if (!mounted) return;

    setState(() {
      _suggestions = [];
    });

    // Just close the dropdown and let user type freely
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Type your location manually'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getShortName(String displayName) {
    final parts = displayName.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return parts[0].trim();
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'city':
      case 'town':
      case 'village':
        return Icons.location_city;
      case 'state':
      case 'region':
        return Icons.map;
      case 'country':
        return Icons.public;
      case 'airport':
        return Icons.flight;
      case 'railway':
      case 'station':
        return Icons.train;
      default:
        return Icons.place;
    }
  }

  double _getTextFieldWidth() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  double _getTextFieldHeight() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.height ?? 56;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: Icon(widget.icon),
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _selectedLocation != null
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
          border: const OutlineInputBorder(),
        ),
        validator: widget.validator,
        onTap: () {
          if (_suggestions.isNotEmpty) _showOverlay();
        },
      ),
    );
  }
}
