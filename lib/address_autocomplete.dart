import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const Color _purple = Color(0xFF6B3A82);
const Color _lightPurple = Color(0xFFF3EAF6);

/// An address the customer picked from the address suggestions.
class PickedAddress {
  final String formatted;
  final String street;
  final String city; // suburb, city
  final String postalCode;
  final String placeId;
  final double latitude;
  final double longitude;

  const PickedAddress({
    required this.formatted,
    required this.street,
    required this.city,
    required this.postalCode,
    required this.placeId,
    required this.latitude,
    required this.longitude,
  });

  /// Plain values, safe to save in Firestore.
  Map<String, dynamic> toMap() => {
    'formatted': formatted,
    'street': street,
    'city': city,
    'postalCode': postalCode,
    'placeId': placeId,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;

  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}

class PlacesException implements Exception {
  final String message;
  PlacesException(this.message);

  @override
  String toString() => message;
}

/// Address search using Photon (OpenStreetMap data). Free: no API key, no billing.
/// Photon returns the full address with each suggestion, so picking one needs no
/// second request. Data (c) OpenStreetMap contributors.
class PlacesService {
  static const String _host = 'https://photon.komoot.io/api/';
  // South Africa (min lon, min lat, max lon, max lat). Keeps results local.
  static const String _bbox = '16.3,-35.0,33.0,-22.0';

  // Suggestions from the latest search, so details(placeId) needs no network call.
  final Map<String, PickedAddress> _cache = {};

  static String _s(dynamic v) => (v ?? '').toString().trim();

  Future<List<PlaceSuggestion>> autocomplete(
      String input, {
        double? nearLat,
        double? nearLng,
      }) async {
    final uri = Uri.parse(_host).replace(queryParameters: {
      'q': input,
      'limit': '8',
      'lang': 'en',
      'bbox': _bbox,
      if (nearLat != null && nearLng != null) 'lat': '$nearLat',
      if (nearLat != null && nearLng != null) 'lon': '$nearLng',
    });
    final res = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw PlacesException('The address service returned error ${res.statusCode}.');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final features = (data['features'] as List?) ?? [];
    final out = <PlaceSuggestion>[];
    final seen = <String>{};
    _cache.clear();

    for (final f in features) {
      if (f is! Map) continue;
      final props = f['properties'];
      final coords = f['geometry']?['coordinates'];
      if (props is! Map || coords is! List || coords.length < 2) continue;
      if (_s(props['countrycode']).toUpperCase() != 'ZA') continue;

      final String houseNo = _s(props['housenumber']);
      final String road = _s(props['street']);
      final String name = _s(props['name']);
      final String street = road.isNotEmpty
          ? [houseNo, road].where((x) => x.isNotEmpty).join(' ')
          : name;
      final String suburb = _s(props['locality']).isNotEmpty
          ? _s(props['locality'])
          : _s(props['district']);
      final String town = _s(props['city']).isNotEmpty ? _s(props['city']) : _s(props['county']);
      final String state = _s(props['state']);
      final String postal = _s(props['postcode']);
      final String city = [suburb, town].where((x) => x.isNotEmpty).toSet().join(', ');

      final String secondary = [suburb, town, state, postal]
          .where((x) => x.isNotEmpty)
          .toSet()
          .join(', ');
      final String main = street.isNotEmpty ? street : (secondary.isNotEmpty ? secondary : name);
      if (main.isEmpty) continue;
      final String formatted = [street, suburb, town, state, postal, 'South Africa']
          .where((x) => x.isNotEmpty)
          .toSet()
          .join(', ');
      if (!seen.add(formatted)) continue; // skip duplicates

      final String id = 'osm_${_s(props['osm_type'])}${_s(props['osm_id'])}_${out.length}';
      _cache[id] = PickedAddress(
        formatted: formatted,
        street: street,
        city: city,
        postalCode: postal,
        placeId: id,
        latitude: (coords[1] as num).toDouble(),
        longitude: (coords[0] as num).toDouble(),
      );
      out.add(PlaceSuggestion(placeId: id, mainText: main, secondaryText: secondary));
    }
    return out;
  }

  Future<PickedAddress> details(String placeId) async {
    final a = _cache[placeId];
    if (a == null) throw PlacesException('Please search again and pick your address.');
    return a;
  }
}

/// Opens the address search. Returns the address the customer picked, or null.
Future<PickedAddress?> showAddressSearch(
    BuildContext context, {
      double? nearLat,
      double? nearLng,
    }) {
  return showModalBottomSheet<PickedAddress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddressSearchSheet(nearLat: nearLat, nearLng: nearLng),
  );
}

class _AddressSearchSheet extends StatefulWidget {
  final double? nearLat;
  final double? nearLng;
  const _AddressSearchSheet({this.nearLat, this.nearLng});

  @override
  State<_AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<_AddressSearchSheet> {
  final PlacesService _service = PlacesService();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  int _searchId = 0;

  List<PlaceSuggestion> _results = [];
  bool _searching = false;
  bool _picking = false;
  String? _error;

  /// Turns a raw error into a short reason.
  String _friendly(Object e) {
    final l = e.toString().toLowerCase();
    if (l.contains('socket') || l.contains('timeout') || l.contains('failed host lookup')) {
      return 'No internet connection to the address service.';
    }
    return e.toString();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 3) {
      setState(() {
        _results = [];
        _error = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text.trim()));
  }

  Future<void> _search(String text) async {
    final int id = ++_searchId;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final r = await _service.autocomplete(
        text,
        nearLat: widget.nearLat,
        nearLng: widget.nearLng,
      );
      if (!mounted || id != _searchId) return;
      setState(() {
        _results = r;
        _searching = false;
      });
    } catch (e) {
      if (!mounted || id != _searchId) return;
      setState(() {
        debugPrint('Address search error: $e');
        _error = 'Address search is not available right now. Please type your address in the fields instead.\n(${_friendly(e)})';
        _searching = false;
      });
    }
  }

  Future<void> _pick(PlaceSuggestion s) async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final address = await _service.details(s.placeId);
      if (!mounted) return;
      Navigator.pop(context, address);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        debugPrint('Address search error: $e');
        _error = 'Address search is not available right now. Please type your address in the fields instead.\n(${_friendly(e)})';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: media.size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Find your address',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Start typing your street address...',
                prefixIcon: const Icon(Icons.search, color: _purple),
                suffixIcon: _searching
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
                  ),
                )
                    : (_controller.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _onChanged('');
                  },
                )),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _picking
                  ? const Center(child: CircularProgressIndicator(color: _purple))
                  : (_results.isEmpty
                  ? Center(
                child: Text(
                  _controller.text.trim().length < 3
                      ? 'Type at least 3 characters.'
                      : (_searching ? '' : 'No matching addresses.'),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
                  : ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = _results[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: _lightPurple,
                      child: Icon(Icons.place_outlined, color: _purple),
                    ),
                    title: Text(s.mainText,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: s.secondaryText.isEmpty ? null : Text(s.secondaryText),
                    onTap: () => _pick(s),
                  );
                },
              )),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Text('Address data \u00a9 OpenStreetMap contributors',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}