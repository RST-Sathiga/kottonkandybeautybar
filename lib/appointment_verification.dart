import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'salon_info.dart';

const Color _purple = Color(0xFF6B3A82);
const Color _lightPurple = Color(0xFFF3EAF6);

// Cloudinary (same account as the chat images).
// TIP: create a separate unsigned preset for face photos and put its name
// below, so they are kept apart from chat/profile pictures.
const String _cloudinaryCloudName = 'nuqsuqyw';
const String _cloudinaryUploadPreset = 'profile_uploads';

/// What the client must do before the appointment. Edit the wording freely.
const List<String> _requirements = [
  'Send a clear photo of your face (looking straight at the camera).',
  'Take it in good light, with no sunglasses, hat or mask.',
  'Only you should be in the photo.',
  'Send it by the day before your appointment.',
  'Arrive at the salon with the same face as in the photo; the owner will compare it when you arrive.',
];

// ---- dates (South Africa, UTC+2) ----
DateTime _sastNow() => DateTime.now().toUtc().add(const Duration(hours: 2));
String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _dayOf(dynamic v) {
  if (v is Timestamp) return _ymd(v.toDate().toUtc().add(const Duration(hours: 2)));
  final s = (v ?? '').toString();
  return s.length >= 10 ? s.substring(0, 10) : s;
}

String _norm(dynamic s) =>
    (s ?? '').toString().toLowerCase().trim().replaceAll(RegExp(r'[\s-]+'), '_');

/// Appointment verification: the client sends a photo of their face
/// so the owner can confirm who they are when they arrive.
class AppointmentVerificationScreen extends StatefulWidget {
  const AppointmentVerificationScreen({super.key});

  @override
  State<AppointmentVerificationScreen> createState() =>
      _AppointmentVerificationScreenState();
}

class _AppointmentVerificationScreenState
    extends State<AppointmentVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _busyId;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- photo flow ----------------

  Future<void> _start(QueryDocumentSnapshot<Map<String, dynamic>> appt) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GuideSheet(),
    );
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final file = File(picked.path);
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => _FacePreviewScreen(file: file)),
      );
      if (ok != true) return;
      await _upload(appt, file);
    } catch (e) {
      _toast('Could not get the photo: $e');
    }
  }

  /// Uploads the photo to Cloudinary and returns its https URL.
  Future<String> _uploadToCloudinary(File file) async {
    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response =
    await request.send().timeout(const Duration(seconds: 60));
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Cloudinary ${response.statusCode}: $body');
    }
    final secureUrl = jsonDecode(body)['secure_url'];
    if (secureUrl is! String || secureUrl.isEmpty) {
      throw Exception('Cloudinary returned no secure_url: $body');
    }
    return secureUrl;
  }

  Future<void> _upload(
      QueryDocumentSnapshot<Map<String, dynamic>> appt, File file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _busyId = appt.id);
    try {
      final url = await _uploadToCloudinary(file);

      // The link is saved in its own collection (NOT on the appointment),
      // because every signed-in user can read appointments. Only the owner
      // and the admin can read verification/{appointmentId}.
      await FirebaseFirestore.instance
          .collection('verification')
          .doc(appt.id)
          .set({
        'userId': uid,
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _toast('Photo sent. See you soon!');
    } catch (e) {
      _toast('Could not send the photo: $e');
      debugPrint('Face photo upload failed: $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  // ---------------- UI ----------------

  Widget _card({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _requirementsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_user_outlined, color: _purple),
              SizedBox(width: 10),
              Expanded(
                child: Text('Before your appointment',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'For everyone\'s safety, the owner confirms who you are when you arrive.',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const SizedBox(height: 10),
          ..._requirements.map(
                (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle, size: 16, color: _purple),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r, style: const TextStyle(fontSize: 13.5))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your photo is only used by the salon to confirm your identity at your appointment.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _appointmentCard(QueryDocumentSnapshot<Map<String, dynamic>> doc,
      String tomorrow, Map<String, String> photos) {
    final a = doc.data();
    final day = _dayOf(a['date']);
    final name = (a['serviceName'] ?? a['title'] ?? a['name'] ?? 'Appointment').toString();
    final time = (a['timeSlot'] ?? a['time'] ?? '').toString();
    // New photos live in verification/{id}; fall back to the old field so
    // photos sent before this change still show as sent.
    final url = (photos[doc.id] ?? a['facePhotoUrl'] ?? '').toString();
    final sent = url.isNotEmpty;
    final urgent = !sent && day.compareTo(tomorrow) <= 0;
    final busy = _busyId == doc.id;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _lightPurple,
                    borderRadius: BorderRadius.circular(14),
                    image: sent
                        ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                        : null,
                  ),
                  child: sent
                      ? null
                      : const Icon(Icons.face_outlined, color: _purple, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text('$day${time.isEmpty ? '' : '  ·  $time'}',
                          style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: sent
                              ? Colors.green.shade50
                              : (urgent ? Colors.red.shade50 : Colors.orange.shade50),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          sent ? 'Photo sent' : (urgent ? 'Action needed' : 'Photo needed'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: sent
                                ? Colors.green.shade800
                                : (urgent ? Colors.red.shade700 : Colors.orange.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => _start(doc),
                icon: busy
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Icon(sent ? Icons.refresh : Icons.camera_alt_outlined),
                label: Text(
                  busy ? 'SENDING...' : (sent ? 'SEND A NEW PHOTO' : 'SEND MY PHOTO'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final today = _ymd(_sastNow());
    final tomorrow = _ymd(_sastNow().add(const Duration(days: 1)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Appointment verification',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: user == null
          ? const Center(child: Text('Please log in.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load your appointments.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _purple));
          }

          final upcoming = snap.data!.docs.where((d) {
            final a = d.data();
            final st = _norm(a['status']);
            if (['cancelled', 'canceled', 'failed', 'completed'].contains(st)) {
              return false;
            }
            if (_norm(a['paymentStatus']) != 'paid') return false;
            return _dayOf(a['date']).compareTo(today) >= 0;
          }).toList()
            ..sort((a, b) {
              final c = _dayOf(a.data()['date']).compareTo(_dayOf(b.data()['date']));
              return c != 0
                  ? c
                  : (a.data()['timeSlot'] ?? '')
                  .toString()
                  .compareTo((b.data()['timeSlot'] ?? '').toString());
            });

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('verification')
                .where('userId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, photoSnap) {
              final photos = <String, String>{};
              for (final d in photoSnap.data?.docs ?? []) {
                final u = (d.data()['photoUrl'] ?? '').toString();
                if (u.isNotEmpty) photos[d.id] = u;
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _requirementsCard(),
                  const SizedBox(height: 22),
                  const Text('Your upcoming appointments',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (upcoming.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _card(
                        color: _lightPurple,
                        child: Column(
                          children: [
                            const Icon(Icons.event_available_outlined,
                                color: _purple, size: 40),
                            const SizedBox(height: 8),
                            const Text('No upcoming paid appointments',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              'Once you book and pay, you can send your photo here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...upcoming.map((d) => _appointmentCard(d, tomorrow, photos)),
                  const SizedBox(height: 22),
                  _card(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _lightPurple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on_outlined, color: _purple),
                      ),
                      title: const Text('Find the salon',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Address, phone and directions'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SalonLocationScreen()),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// Bottom sheet: shows the client what the photo should look like
// ============================================================

class _GuideSheet extends StatelessWidget {
  const _GuideSheet();

  Widget _tip(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: _purple),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Take a clear photo of your face',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            SizedBox(
              width: 120,
              height: 150,
              child: CustomPaint(
                painter: _OvalOutlinePainter(),
                child: const Center(
                  child: Icon(Icons.person_outline, size: 64, color: _purple),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _tip(Icons.center_focus_strong_outlined, 'Fit your whole face inside the oval'),
            _tip(Icons.wb_sunny_outlined, 'Face the light so your face is clearly visible'),
            _tip(Icons.no_photography_outlined, 'No sunglasses, hat or mask'),
            _tip(Icons.person_outline, 'Only you in the photo'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('TAKE A PHOTO',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('CHOOSE FROM GALLERY',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _purple,
                  side: const BorderSide(color: _purple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OvalOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _purple,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// Preview: the picture with an oval, so the client can check
// that their face fits before sending
// ============================================================

class _FacePreviewScreen extends StatelessWidget {
  const _FacePreviewScreen({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Check your photo'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(file, fit: BoxFit.cover),
                        CustomPaint(painter: _OvalMaskPainter()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Is your whole face clearly inside the oval, with nothing covering it?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('RETAKE'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('USE THIS PHOTO',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OvalMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.47),
      width: size.width * 0.62,
      height: size.height * 0.62,
    );
    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(oval),
    );
    canvas.drawPath(dim, Paint()..color = Colors.black.withOpacity(0.55));
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}