import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'maps_config.dart';

const Color _purple = Color(0xFF6B3A82);
const Color _lightPurple = Color(0xFFF3EAF6);

/// An address the customer picked from Google's suggestions.
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

/// Talks to Google Places API (New): autocomplete + place details.
/// One session token covers the typing and the final pick, which keeps billing low.
class PlacesService {
  static const String _host = 'https://places.googleapis.com/v1';
  String _session = _newSession();

  static String _newSession() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  Map<String, String> _headers({String? fieldMask}) => {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': MapsConfig.apiKey,
        if (fieldMask != null) 'X-Goog-FieldMask': fieldMask,
        ...MapsConfig.restrictionHeaders,
      };

  String _errorText(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      final msg = j['error']?['message'];
      if (msg != null) return msg.toString();
    } catch (_) {}
    return 'Google returned error ${r.statusCode}.';
  }

  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    double? nearLat,
    double? nearLng,
  }) async {
    if (!MapsConfig.hasKey) {
      throw PlacesException('Add your Google Maps API key in maps_config.dart.');
    }
    final res = await http
        .post(
          Uri.parse('$_host/places:autocomplete'),
          headers: _headers(),
          body: jsonEncode({
            'input': input,
            'sessionToken': _session,
            'languageCode': 'en',
            'includedRegionCodes': ['za'],
            if (nearLat != null && nearLng != null)
              'locationBias': {
                'circle': {
                  'center': {'latitude': nearLat, 'longitude': nearLng},
                  'radius': 50000.0,
                },
              },
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw PlacesException(_errorText(res));

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['suggestions'] as List?) ?? [];
    final out = <PlaceSuggestion>[];
    for (final s in list) {
      final p = s is Map ? s['placePrediction'] : null;
      if (p is! Map) continue;
      final id = (p['placeId'] ?? '').toString();
      if (id.isEmpty) continue;
      final String main =
          (p['structuredFormat']?['mainText']?['text'] ?? p['text']?['text'] ?? '').toString();
      final String secondary =
          (p['structuredFormat']?['secondaryText']?['text'] ?? '').toString();
      out.add(PlaceSuggestion(placeId: id, mainText: main, secondaryText: secondary));
    }
    return out;
  }

  Future<PickedAddress> details(String placeId) async {
    final uri = Uri.parse('$_host/places/$placeId').replace(
      queryParameters: {'sessionToken': _session, 'languageCode': 'en'},
    );
    final res = await http
        .get(uri, headers: _headers(fieldMask: 'formattedAddress,location,addressComponents'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw PlacesException(_errorText(res));
    _session = _newSession(); // the session ends when details are fetched

    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final comps = (j['addressComponents'] as List?) ?? [];

    String comp(List<String> types) {
      for (final type in types) {
        for (final c in comps) {
          if (c is! Map) continue;
          final t = (c['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
          if (t.contains(type)) return (c['longText'] ?? '').toString();
        }
      }
      return '';
    }

    final street = [comp(['street_number']), comp(['route'])]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final suburb = comp(['sublocality_level_1', 'sublocality', 'neighborhood']);
    final town = comp(['locality', 'administrative_area_level_2']);
    final city = [suburb, town].where((s) => s.isNotEmpty).toSet().join(', ');
    final loc = j['location'];

    return PickedAddress(
      formatted: (j['formattedAddress'] ?? '').toString(),
      street: street,
      city: city,
      postalCode: comp(['postal_code']),
      placeId: placeId,
      latitude: ((loc?['latitude'] ?? 0) as num).toDouble(),
      longitude: ((loc?['longitude'] ?? 0) as num).toDouble(),
    );
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
        _error = 'Address search is not available right now. Please type your address in the fields instead.';
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
        _error = 'Address search is not available right now. Please type your address in the fields instead.';
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
                child: Text('Powered by Google',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
