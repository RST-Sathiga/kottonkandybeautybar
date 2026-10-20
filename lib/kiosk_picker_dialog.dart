import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class KioskLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  double? distanceInKm;

  KioskLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.distanceInKm,
  });

  /// Plain values, safe to save on the order.
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };
}

/// Lets the customer pick a Pudo locker on a Google Map.
/// If [nearLatitude]/[nearLongitude] are given (e.g. the address they searched),
/// lockers are sorted by distance from there, otherwise from their GPS position.
class KioskPickerDialog extends StatefulWidget {
  final double? nearLatitude;
  final double? nearLongitude;

  const KioskPickerDialog({super.key, this.nearLatitude, this.nearLongitude});

  @override
  State<KioskPickerDialog> createState() => _KioskPickerDialogState();
}

class _KioskPickerDialogState extends State<KioskPickerDialog> {
  static const Color primaryPurple = Color(0xFF6B3A82);

  // TODO: replace with the real Pudo locker list once you have API access.
  final List<KioskLocation> _allKiosks = [
    KioskLocation(id: 'k1', name: 'Pudo Kiosk - Sandton City', address: 'Sandton City Mall, Sandton', latitude: -26.1076, longitude: 28.0567),
    KioskLocation(id: 'k2', name: 'Pudo Kiosk - Rosebank Mall', address: '50 Bath Ave, Rosebank', latitude: -26.1465, longitude: 28.0416),
    KioskLocation(id: 'k3', name: 'Pudo Kiosk - Menlyn Park', address: 'Atterbury Rd, Pretoria', latitude: -25.7828, longitude: 28.2753),
    KioskLocation(id: 'k4', name: 'Pudo Kiosk - Mall of Africa', address: 'Magwa Cres, Midrand', latitude: -25.9982, longitude: 28.1065),
    KioskLocation(id: 'k5', name: 'Pudo Kiosk - Eastgate Mall', address: '43 Bradford Rd, Bedfordview', latitude: -26.1793, longitude: 28.1206),
    KioskLocation(id: 'k6', name: 'Pudo Kiosk - Gateway Theatre', address: '1 Palm Blvd, Umhlanga', latitude: -29.7262, longitude: 31.0658),
    KioskLocation(id: 'k7', name: 'Pudo Kiosk - Canal Walk', address: 'Century City, Cape Town', latitude: -33.8927, longitude: 18.5126),
  ];

  static const LatLng _fallback = LatLng(-26.2041, 28.0473); // Johannesburg

  LatLng _userPosition = _fallback;
  bool _isLoading = true;
  bool _hasGps = false;
  KioskLocation? _selectedKiosk;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final double? lat = widget.nearLatitude;
    final double? lng = widget.nearLongitude;
    if (lat != null && lng != null) {
      _calculateDistancesAndSort(LatLng(lat, lng));
      return;
    }
    await _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _calculateDistancesAndSort(_fallback);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _calculateDistancesAndSort(_fallback);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      _hasGps = true;
      _calculateDistancesAndSort(LatLng(position.latitude, position.longitude));
    } catch (e) {
      _calculateDistancesAndSort(_fallback);
    }
  }

  void _calculateDistancesAndSort(LatLng pos) {
    for (final kiosk in _allKiosks) {
      kiosk.distanceInKm = _distanceKm(
        pos.latitude,
        pos.longitude,
        kiosk.latitude,
        kiosk.longitude,
      );
    }
    _allKiosks.sort((a, b) => (a.distanceInKm ?? 0).compareTo(b.distanceInKm ?? 0));

    if (!mounted) return;
    setState(() {
      _userPosition = pos;
      _isLoading = false;
      _selectedKiosk = _allKiosks.first;
    });
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void _select(KioskLocation kiosk, {bool moveMap = true}) {
    setState(() => _selectedKiosk = kiosk);
    if (moveMap) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(kiosk.latitude, kiosk.longitude), 14),
      );
    }
  }

  Set<Marker> get _markers {
    return _allKiosks.map((kiosk) {
      final bool isSelected = _selectedKiosk?.id == kiosk.id;
      return Marker(
        markerId: MarkerId(kiosk.id),
        position: LatLng(kiosk.latitude, kiosk.longitude),
        infoWindow: InfoWindow(title: kiosk.name, snippet: kiosk.address),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueRed,
        ),
        onTap: () => _select(kiosk, moveMap: false),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final double screenH = MediaQuery.of(context).size.height;
    final double mapH = (screenH * 0.28).clamp(150.0, 240.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Nearby Kiosk',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_isLoading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: primaryPurple)),
              )
            else ...[
              SizedBox(
                height: mapH,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: _userPosition, zoom: 11),
                    onMapCreated: (c) => _mapController = c,
                    markers: _markers,
                    myLocationEnabled: _hasGps,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Nearest Available Kiosks:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  itemCount: _allKiosks.length,
                  itemBuilder: (context, index) {
                    final kiosk = _allKiosks[index];
                    final bool isSelected = _selectedKiosk?.id == kiosk.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryPurple.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? primaryPurple : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(kiosk.name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${kiosk.address}\n${kiosk.distanceInKm?.toStringAsFixed(1)} km away'),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: primaryPurple)
                            : null,
                        onTap: () => _select(kiosk),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedKiosk == null
                      ? null
                      : () => Navigator.pop(context, _selectedKiosk),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('SELECT KIOSK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
