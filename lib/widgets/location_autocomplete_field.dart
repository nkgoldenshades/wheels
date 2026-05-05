import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_autocomplete_service.dart';
import 'map_location_picker.dart';

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
  final FocusNode _focusNode = FocusNode();
  bool _overlayInserted = false;
  bool _tapInOverlayInProgress = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Only show overlay if no location is selected
      if (_selectedLocation == null || widget.controller.text.isEmpty) {
        _showOverlay();
      }
    } else {
      if (_tapInOverlayInProgress) return;
      _safeRemoveOverlay();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    // Remove overlay safely on dispose
    _safeRemoveOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) return;

    final query = widget.controller.text;
    debugPrint('📍 LocationAutocompleteField text changed: "$query"');

    // If a location is already selected and text hasn't changed, hide overlay
    if (_selectedLocation != null && query == _getShortName(_selectedLocation!.displayName)) {
      _safeRemoveOverlay();
      return;
    }

    // If user is typing after selecting "Enter Manually", allow free typing without searching
    if (_selectedLocation != null && _selectedLocation!.type == 'manual') {
      // User is manually entering, don't search and don't show overlay
      _safeRemoveOverlay();
      return;
    }

    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _selectedLocation = null;
        });
        if (_focusNode.hasFocus) {
          _refreshOverlay(); // Show Current Location and Enter Manually options
        }
      }
      return;
    }

    if (_selectedLocation != null && query != _getShortName(_selectedLocation!.displayName)) {
      if (mounted) setState(() => _selectedLocation = null);
    }

    if (_selectedLocation != null) {
      // User hasn't changed the text since selection
      _safeRemoveOverlay();
      return;
    }

    // Always show overlay when typing
    if (_focusNode.hasFocus && !_overlayInserted) {
      _showOverlay();
    }

    // Start searching after 3 characters
    if (query.length >= 3) {
      if (mounted) setState(() => _isLoading = true);

      debugPrint('📍 LocationAutocompleteField searching for: "$query"');

      LocationAutocompleteService.instance.searchWithDebounce(
        query,
        (results) {
          if (!mounted) return;
          debugPrint(
            '📍 LocationAutocompleteField got ${results.length} suggestions for: "$query"',
          );
          setState(() {
            _suggestions = results;
            _isLoading = false;
          });
          if (mounted && _focusNode.hasFocus) {
            _refreshOverlay(); // Rebuild overlay with new suggestions
          } else {
            _safeRemoveOverlay();
          }
        },
      );
    } else {
      // Less than 3 characters, just show Current Location and Enter Manually
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
        if (_focusNode.hasFocus) {
          _refreshOverlay();
        }
      }
    }
  }

  void _refreshOverlay() {
    if (!mounted || !_focusNode.hasFocus) return;
    if (_overlayInserted && _overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }
    _showOverlay();
  }

  void _showOverlay() {
    if (!mounted) return;
    if (!_focusNode.hasFocus) return;
    if (_selectedLocation != null &&
        widget.controller.text == _getShortName(_selectedLocation!.displayName)) {
      return;
    }
    _safeRemoveOverlay();

    // Use post-frame callback to ensure context is valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_focusNode.hasFocus) return;
      if (_selectedLocation != null &&
          widget.controller.text ==
              _getShortName(_selectedLocation!.displayName)) {
        return;
      }

      final overlayState = Overlay.maybeOf(context);
      if (overlayState == null) return;

      _overlayEntry = OverlayEntry(
        builder: (ctx) => Stack(
          children: [
            Positioned(
              width: _getTextFieldWidth(),
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, _getTextFieldHeight() + 4),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: _suggestions.isEmpty ? 120 : 300,
                      minHeight: 0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _suggestions.length + 3, // +3 for current location, map picker, and manual options
                          separatorBuilder: (_, _) => const Divider(height: 1, thickness: 0.5),
                          itemBuilder: (context, index) {
                    // First item: Use Current Location
                    if (index == 0) {
                      return InkWell(
                        onTapDown: (_) => _tapInOverlayInProgress = true,
                        onTap: () => _useCurrentLocation(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.my_location,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Use Current Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    // Second item: Pick on Map
                    if (index == 1) {
                      return InkWell(
                        onTapDown: (_) => _tapInOverlayInProgress = true,
                        onTap: () => _pickOnMap(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.map,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Pick on Map',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    // Third item: Enter Manually
                    if (index == 2) {
                      return InkWell(
                        onTapDown: (_) => _tapInOverlayInProgress = true,
                        onTap: () => _enterManually(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_location_alt,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Enter Manually',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    // Rest: Location suggestions
                    final suggestion = _suggestions[index - 3];
                    final geo = suggestion.geo;
                    final flag = geo != null ? _flagEmoji(geo.countryCode) : '';
                    final district = geo?.district ?? geo?.stateDistrict;
                    final geoParts = <String>[
                      ?district,
                      if (geo?.state != null) geo!.state!,
                      if (geo?.postcode != null) geo!.postcode!,
                      if (geo?.country != null)
                        geo!.countryCode != null
                            ? '${geo.country!} (${geo.countryCode!.toUpperCase()})'
                            : geo.country!,
                    ];
                    final geoLine = '${flag.isNotEmpty ? '$flag ' : ''}${geoParts.join(' · ')}';

                    return InkWell(
                      onTapDown: (_) => _tapInOverlayInProgress = true,
                      onTap: () => _selectLocation(suggestion),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                _getIconForType(suggestion.type),
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getShortName(suggestion.displayName),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (geoLine.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      geoLine,
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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

  void _handleFieldSubmit() {
    _tapInOverlayInProgress = false;
    _focusNode.unfocus();
    _safeRemoveOverlay();
  }

  void _selectLocation(LocationSuggestion suggestion) {
    if (!mounted) return;
    _tapInOverlayInProgress = false;
    _focusNode.unfocus();
    _safeRemoveOverlay();

    setState(() {
      _selectedLocation = suggestion;
      widget.controller.text = _getShortName(suggestion.displayName);
      _suggestions = [];
    });

    widget.onLocationSelected?.call(suggestion);
  }

  void _useCurrentLocation() async {
    if (!mounted) return;
    _tapInOverlayInProgress = false;
    _focusNode.unfocus();
    _safeRemoveOverlay();

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

      final address = await LocationAutocompleteService.instance.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      final displayName = address?.displayName ?? 'Current Location';

      if (!mounted) return;
      final suggestion = LocationSuggestion(
        displayName: displayName,
        lat: position.latitude,
        lon: position.longitude,
        type: 'current',
      );

      setState(() {
        _selectedLocation = suggestion;
        widget.controller.text = _getShortName(displayName);
        _isLoading = false;
        _suggestions = [];
      });
      
      // Ensure overlay is removed and field is unfocused
      _safeRemoveOverlay();
      
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

  void _pickOnMap() async {
    if (!mounted) return;
    _tapInOverlayInProgress = false;
    _safeRemoveOverlay();

    // Get initial location for map
    LatLng? initialLocation;
    if (_selectedLocation != null && 
        _selectedLocation!.lat != 0 && 
        _selectedLocation!.lon != 0) {
      initialLocation = LatLng(_selectedLocation!.lat, _selectedLocation!.lon);
    }

    // Show map picker
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPicker(
          initialLocation: initialLocation,
          initialAddress: _selectedLocation?.displayName,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final lat = result['lat'] as double;
    final lon = result['lon'] as double;
    final address = result['address'] as String;

    // Create map-picked suggestion
    final mapSuggestion = LocationSuggestion(
      displayName: address,
      lat: lat,
      lon: lon,
      type: 'map',
    );

    setState(() {
      _suggestions = [];
      _selectedLocation = mapSuggestion;
      widget.controller.text = _getShortName(address);
    });

    // Remove focus to close dropdown
    _focusNode.unfocus();
    _safeRemoveOverlay();

    // Notify parent
    widget.onLocationSelected?.call(mapSuggestion);

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Location selected from map'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _enterManually() async {
    if (!mounted) return;
    _tapInOverlayInProgress = false;
    _safeRemoveOverlay();

    // Show dialog to enter location manually with optional coordinates
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ManualLocationDialog(
        initialLocation: widget.controller.text,
      ),
    );

    if (result == null || !mounted) return;

    final locationText = result['location'] as String;
    final lat = result['lat'] as double?;
    final lon = result['lon'] as double?;

    // Create manual entry suggestion
    final manualSuggestion = LocationSuggestion(
      displayName: locationText,
      lat: lat ?? 0, // Use provided coordinates or 0
      lon: lon ?? 0, // Use provided coordinates or 0
      type: 'manual',
    );

    setState(() {
      _suggestions = [];
      _selectedLocation = manualSuggestion;
      widget.controller.text = locationText;
    });

    // Remove focus to close dropdown
    _focusNode.unfocus();
    _safeRemoveOverlay();

    // Notify parent
    widget.onLocationSelected?.call(manualSuggestion);

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lat != null && lon != null
                ? '✅ Location saved with coordinates'
                : '⚠️ Location saved without coordinates',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _flagEmoji(String? code) {
    if (code == null || code.length != 2) return '';
    final base = 0x1F1E6 - 0x41;
    final chars = code.toUpperCase().codeUnits;
    return String.fromCharCode(base + chars[0]) +
        String.fromCharCode(base + chars[1]);
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
    if (!mounted) return 300.0; // Return default if unmounted
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  double _getTextFieldHeight() {
    if (!mounted) return 56.0; // Return default if unmounted
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.height ?? 56;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.done,
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
              : widget.controller.text.isNotEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedLocation != null && _selectedLocation!.type != 'manual' && _selectedLocation!.type != 'map')
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        if (_selectedLocation != null && _selectedLocation!.type == 'map')
                          const Icon(Icons.map, color: Colors.green, size: 20),
                        if (_selectedLocation != null && _selectedLocation!.type == 'manual')
                          const Icon(Icons.edit, color: Colors.orange, size: 20),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            widget.controller.clear();
                            setState(() {
                              _selectedLocation = null;
                              _suggestions = [];
                            });
                            _focusNode.requestFocus();
                          },
                        ),
                      ],
                    )
                  : null,
          border: const OutlineInputBorder(),
        ),
        validator: widget.validator,
        onTap: () {
          final hasStableSelection = _selectedLocation != null &&
              widget.controller.text ==
                  _getShortName(_selectedLocation!.displayName);
          if (!_overlayInserted && !hasStableSelection) {
             _showOverlay();
          }
        },
        onFieldSubmitted: (_) => _handleFieldSubmit(),
      ),
    );
  }
}


// Manual Location Entry Dialog
class _ManualLocationDialog extends StatefulWidget {
  final String initialLocation;

  const _ManualLocationDialog({
    required this.initialLocation,
  });

  @override
  State<_ManualLocationDialog> createState() => _ManualLocationDialogState();
}

class _ManualLocationDialogState extends State<_ManualLocationDialog> {
  late final TextEditingController _locationController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.initialLocation);
    _latController = TextEditingController();
    _lonController = TextEditingController();
    
    // Automatically get current location
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _loadingLocation = true;
    });

    try {
      // Request location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied || 
            requested == LocationPermission.deniedForever) {
          if (mounted) {
            setState(() {
              _loadingLocation = false;
            });
          }
          return; // User denied permission
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update text fields with current location
      if (mounted) {
        setState(() {
          _latController.text = position.latitude.toStringAsFixed(6);
          _lonController.text = position.longitude.toStringAsFixed(6);
          _loadingLocation = false;
        });
      }
    } catch (e) {
      // Silently fail if location is not available
      debugPrint('Failed to get current location: $e');
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Location Manually'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS coordinates are required for navigation and distance calculation',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location Name *',
                hintText: 'e.g., Near City Mall, Chennai',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'GPS Coordinates (Required)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_loadingLocation)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text('Use Current', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _latController,
              decoration: const InputDecoration(
                labelText: 'Latitude *',
                hintText: 'e.g., 13.0827 (between -90 and 90)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_searching),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lonController,
              decoration: const InputDecoration(
                labelText: 'Longitude *',
                hintText: 'e.g., 80.2707 (between -180 and 180)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_searching),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.help_outline, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'How to get coordinates?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Open Google Maps\n'
                    '2. Long press on your location\n'
                    '3. Copy the coordinates shown\n'
                    '4. Paste them here',
                    style: TextStyle(fontSize: 11, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final location = _locationController.text.trim();
            if (location.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a location name')),
              );
              return;
            }

            final lat = double.tryParse(_latController.text.trim());
            final lon = double.tryParse(_lonController.text.trim());

            if (lat == null || lon == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('GPS coordinates are required. Please enter valid numbers.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Validate coordinate ranges
            if (lat < -90 || lat > 90) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Latitude must be between -90 and 90'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (lon < -180 || lon > 180) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Longitude must be between -180 and 180'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            Navigator.pop(context, {
              'location': location,
              'lat': lat,
              'lon': lon,
            });
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

