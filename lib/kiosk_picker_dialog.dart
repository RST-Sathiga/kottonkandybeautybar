import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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
}

class KioskPickerDialog extends StatefulWidget {
  const KioskPickerDialog({super.key});

  @override
  State<KioskPickerDialog> createState() => _KioskPickerDialogState();
}

class _KioskPickerDialogState extends State<KioskPickerDialog> {
  static const Color primaryPurple = Color(0xFF6B3A82);

  final List<KioskLocation> _allKiosks = [
    KioskLocation(id: 'k1', name: 'Pudo Kiosk - Sandton City', address: 'Sandton City Mall, Sandton', latitude: -26.1076, longitude: 28.0567),
    KioskLocation(id: 'k2', name: 'Pudo Kiosk - Rosebank Mall', address: '50 Bath Ave, Rosebank', latitude: -26.1465, longitude: 28.0416),
    KioskLocation(id: 'k3', name: 'Pudo Kiosk - Menlyn Park', address: 'Atterbury Rd, Pretoria', latitude: -25.7828, longitude: 28.2753),
    KioskLocation(id: 'k4', name: 'Pudo Kiosk - Mall of Africa', address: 'Magwa Cres, Midrand', latitude: -25.9982, longitude: 28.1065),
    KioskLocation(id: 'k5', name: 'Pudo Kiosk - Eastgate Mall', address: '43 Bradford Rd, Bedfordview', latitude: -26.1793, longitude: 28.1206),
    KioskLocation(id: 'k6', name: 'Pudo Kiosk - Gateway Theatre', address: '1 Palm Blvd, Umhlanga', latitude: -29.7262, longitude: 31.0658),
    KioskLocation(id: 'k7', name: 'Pudo Kiosk - Canal Walk', address: 'Century City, Cape Town', latitude: -33.8927, longitude: 18.5126),
  ];

  LatLng _userPosition = const LatLng(-26.2041, 28.0473); // Fallback JHB
  bool _isLoading = true;
  KioskLocation? _selectedKiosk;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _useDefaultLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _useDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _useDefaultLocation();
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      _calculateDistancesAndSort(LatLng(position.latitude, position.longitude));
    } catch (e) {
      _useDefaultLocation();
    }
  }

  void _useDefaultLocation() {
    _calculateDistancesAndSort(const LatLng(-26.2041, 28.0473));
  }

  void _calculateDistancesAndSort(LatLng pos) {
    for (var kiosk in _allKiosks) {
      kiosk.distanceInKm = _calculateDistanceInKm(
        pos.latitude,
        pos.longitude,
        kiosk.latitude,
        kiosk.longitude,
      );
    }

    _allKiosks.sort((a, b) => (a.distanceInKm ?? 0).compareTo(b.distanceInKm ?? 0));

    setState(() {
      _userPosition = pos;
      _isLoading = false;
      _selectedKiosk = _allKiosks.first;
    });
  }

  double _calculateDistanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Nearby Kiosk'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const SizedBox(
          height: 200,
          child: Center(
            child: CircularProgressIndicator(color: primaryPurple),
          ),
        )
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userPosition,
                    initialZoom: 11.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kottonkandy.app',
                    ),
                    MarkerLayer(
                      markers: _allKiosks.map((kiosk) {
                        final isSelected = _selectedKiosk?.id == kiosk.id;
                        return Marker(
                          point: LatLng(kiosk.latitude, kiosk.longitude),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedKiosk = kiosk);
                            },
                            child: Icon(
                              Icons.location_on,
                              color: isSelected ? primaryPurple : Colors.red,
                              size: isSelected ? 40 : 30,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nearest Available Kiosks:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _allKiosks.length,
                itemBuilder: (context, index) {
                  final kiosk = _allKiosks[index];
                  final isSelected = _selectedKiosk?.id == kiosk.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryPurple.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? primaryPurple : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        kiosk.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${kiosk.address}\n${kiosk.distanceInKm?.toStringAsFixed(1)} km away'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: primaryPurple)
                          : null,
                      onTap: () {
                        setState(() => _selectedKiosk = kiosk);
                        _mapController.move(
                          LatLng(kiosk.latitude, kiosk.longitude),
                          13.0,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('CANCEL'),
        ),
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
    );
  }
}