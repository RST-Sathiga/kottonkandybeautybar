import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// ---------------------------------------------------------------------------
// Report an issue: clients report a problem with a product, booking, delivery
// or payment. The salon replies, may ask for photo evidence, and finally
// resolves or declines the report. Data lives in:
//   issues/{id}            (the report)
//   issues/{id}/messages   (the conversation and extra evidence)
// ---------------------------------------------------------------------------

const Color _purple = Color(0xFF6B3A82);
const Color _lightPurple = Color(0xFFF3EAF6);

const String _cloudName = 'nuqsuqyw'; // same Cloudinary account as the chat
const String _uploadPreset = 'profile_uploads';

class _Category {
  final String key, label;
  final IconData icon;
  const _Category(this.key, this.label, this.icon);
}

const _categories = <_Category>[
  _Category('product', 'Problem with a product', Icons.shopping_bag_outlined),
  _Category('delivery', 'Delivery problem', Icons.local_shipping_outlined),
  _Category('booking', 'Problem with a booking', Icons.calendar_month_outlined),
  _Category('payment', 'Payment or refund problem', Icons.payments_outlined),
  _Category('other', 'Something else', Icons.help_outline),
];

String _categoryLabel(String key) =>
    _categories.firstWhere((c) => c.key == key, orElse: () => _categories.last).label;

String _statusLabel(String s) {
  switch (s) {
    case 'in_review':
      return 'In review';
    case 'awaiting_client':
      return 'Evidence needed';
    case 'resolved':
      return 'Resolved';
    case 'rejected':
      return 'Closed';
    default:
      return 'Received';
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'in_review':
      return Colors.blue.shade100;
    case 'awaiting_client':
      return Colors.orange.shade200;
    case 'resolved':
      return Colors.green.shade100;
    case 'rejected':
      return Colors.red.shade100;
    default:
      return Colors.purple.shade100;
  }
}

bool _isClosed(String s) => s == 'resolved' || s == 'rejected';

String _date(dynamic t) {
  if (t is! Timestamp) return '';
  final d = t.toDate();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

Future<String?> _uploadEvidence(XFile file) async {
  try {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) return jsonDecode(body)['secure_url'] as String?;
    debugPrint('Evidence upload error: $body');
  } catch (e) {
    debugPrint('Evidence upload failed: $e');
  }
  return null;
}

void _showImage(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _thumbs(BuildContext context, List<dynamic> urls) {
  if (urls.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: urls
          .map((u) => GestureDetector(
        onTap: () => _showImage(context, u.toString()),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(u.toString(),
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  width: 90,
                  height: 90,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image))),
        ),
      ))
          .toList(),
    ),
  );
}

// ===========================================================================
// 1. List of my reports
// ===========================================================================

class ReportIssueScreen extends StatelessWidget {
  const ReportIssueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Report an issue',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: uid == null
          ? null
          : FloatingActionButton.extended(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New report'),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const NewIssueScreen())),
      ),
      body: uid == null
          ? const Center(child: Text('Please log in to report an issue.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('issues')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Could not load your reports.\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _purple));
          }
          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final ta = (a.data()['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final tb = (b.data()['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return tb.compareTo(ta);
            });
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.report_gmailerrorred_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Text('No reports yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      'Had a problem with a product, a booking or a delivery? Tap "New report" and tell us.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final status = (d['status'] ?? 'open').toString();
              final unread = ((d['unreadForClient'] as num?) ?? 0) > 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _lightPurple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text((d['subject'] ?? 'Issue').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (unread)
                        const Icon(Icons.circle, size: 10, color: Colors.pink),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        '${_categoryLabel((d['category'] ?? 'other').toString())}\n${_date(d['createdAt'])}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  isThreeLine: true,
                  trailing: Chip(
                    label: Text(_statusLabel(status), style: const TextStyle(fontSize: 11)),
                    backgroundColor: _statusColor(status),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => IssueDetailScreen(issueId: docs[i].id)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ===========================================================================
// 2. New report
// ===========================================================================

class _Related {
  final String type, id, label;
  const _Related(this.type, this.id, this.label);
}

class NewIssueScreen extends StatefulWidget {
  const NewIssueScreen({super.key});

  @override
  State<NewIssueScreen> createState() => _NewIssueScreenState();
}

class _NewIssueScreenState extends State<NewIssueScreen> {
  String _category = 'product';
  _Related? _related;
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final List<XFile> _photos = [];
  bool _sending = false;
  late final Future<List<_Related>> _relatedFuture = _loadRelated();

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<List<_Related>> _loadRelated() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final db = FirebaseFirestore.instance;
    final out = <_Related>[];
    try {
      final orders = await db.collection('orders').where('userId', isEqualTo: uid).get();
      for (final d in orders.docs) {
        final m = d.data();
        final total = (m['amountPaid'] ?? m['totalAmount'] ?? m['price'] ?? 0).toString();
        final id = d.id;
        out.add(_Related('order', id, 'Order #${id.substring(0, id.length > 8 ? 8 : id.length)} · R$total'));
      }
    } catch (_) {}
    try {
      final appts = await db.collection('appointments').where('userId', isEqualTo: uid).get();
      for (final d in appts.docs) {
        final m = d.data();
        final name = (m['serviceName'] ?? 'Booking').toString();
        var when = '';
        final dt = m['date'];
        if (dt is Timestamp) {
          final x = dt.toDate();
          when = ' · ${x.day}/${x.month}/${x.year}';
        } else if (dt != null) {
          when = ' · $dt';
        }
        out.add(_Related('booking', d.id, '$name$when'));
      }
    } catch (_) {}
    return out;
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 4) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _photos.add(picked));
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_subject.text.trim().isEmpty || _description.text.trim().length < 10) {
      _snack('Please add a short title and describe the problem (at least 10 characters).');
      return;
    }
    setState(() => _sending = true);
    try {
      final urls = <String>[];
      for (final p in _photos) {
        final u = await _uploadEvidence(p);
        if (u == null) {
          _snack('A photo could not be uploaded. Please try again.');
          setState(() => _sending = false);
          return;
        }
        urls.add(u);
      }

      final name = (user.displayName ?? '').trim().isNotEmpty
          ? user.displayName!.trim()
          : (user.email ?? '').split('@').first;

      await FirebaseFirestore.instance.collection('issues').add({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'userName': name,
        'category': _category,
        'relatedType': _related?.type ?? '',
        'relatedId': _related?.id ?? '',
        'relatedLabel': _related?.label ?? '',
        'subject': _subject.text.trim(),
        'description': _description.text.trim(),
        'evidence': urls,
        'status': 'open',
        'resolution': '',
        'lastMessage': _description.text.trim(),
        'unreadForAdmin': 1,
        'unreadForClient': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Your report was sent. The salon will reply here.')));
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      _snack('Could not send your report. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('New report',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('What is the problem about?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories
                .map((c) => ChoiceChip(
              avatar: Icon(c.icon, size: 18, color: _category == c.key ? Colors.white : _purple),
              label: Text(c.label),
              selected: _category == c.key,
              selectedColor: _purple,
              labelStyle: TextStyle(color: _category == c.key ? Colors.white : Colors.black87),
              onSelected: _sending
                  ? null
                  : (_) => setState(() {
                _category = c.key;
                _related = null;
              }),
            ))
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text('Which order or booking? (optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          FutureBuilder<List<_Related>>(
            future: _relatedFuture,
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator(color: _purple);
              final wanted = _category == 'product' || _category == 'delivery'
                  ? ['order']
                  : _category == 'booking'
                  ? ['booking']
                  : ['order', 'booking'];
              final items = snap.data!.where((r) => wanted.contains(r.type)).toList();
              return DropdownButtonFormField<String>(
                isExpanded: true,
                value: _related?.id,
                decoration: InputDecoration(
                  hintText: items.isEmpty ? 'Nothing to choose from' : 'Not about a specific one',
                  filled: true,
                  fillColor: _lightPurple,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                items: items
                    .map((r) => DropdownMenuItem(
                    value: r.id, child: Text(r.label, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: _sending
                    ? null
                    : (v) => setState(() => _related = items.where((r) => r.id == v).firstOrNull),
              );
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _subject,
            enabled: !_sending,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: 'Short title',
              filled: true,
              fillColor: _lightPurple,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            enabled: !_sending,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: 'Describe what happened',
              alignLabelWithHint: true,
              filled: true,
              fillColor: _lightPurple,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Photos (optional, up to 4)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Photos help us sort this out faster, e.g. a damaged item.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _photos.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(_photos[i].path), width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: _sending ? null : () => setState(() => _photos.removeAt(i)),
                        child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 12, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              if (_photos.length < 4)
                InkWell(
                  onTap: _sending ? null : _pickPhoto,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _lightPurple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: _purple),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send report'),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 3. One report: conversation, evidence, outcome
// ===========================================================================

class IssueDetailScreen extends StatefulWidget {
  final String issueId;
  const IssueDetailScreen({super.key, required this.issueId});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  final _text = TextEditingController();
  final List<XFile> _photos = [];
  bool _sending = false;
  bool _markedRead = false;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('issues').doc(widget.issueId);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickPhoto() async {
    if (_photos.length >= 4) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _photos.add(picked));
  }

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _text.text.trim();
    if (user == null || _sending || (text.isEmpty && _photos.isEmpty)) return;

    setState(() => _sending = true);
    try {
      final urls = <String>[];
      for (final p in _photos) {
        final u = await _uploadEvidence(p);
        if (u == null) {
          _snack('A photo could not be uploaded. Please try again.');
          setState(() => _sending = false);
          return;
        }
        urls.add(u);
      }

      final batch = FirebaseFirestore.instance.batch();
      batch.set(_ref.collection('messages').doc(), {
        'senderId': user.uid,
        'senderType': 'client',
        'text': text,
        'evidence': urls,
        'timestamp': FieldValue.serverTimestamp(),
      });
      batch.update(_ref, {
        'status': 'open', // back in the salon's "needs reply" list
        'lastMessage': text.isEmpty ? '📷 Photos' : text,
        'unreadForAdmin': FieldValue.increment(1),
        'unreadForClient': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      _text.clear();
      setState(() {
        _photos.clear();
        _sending = false;
      });
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      _snack('Could not send. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Your report',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Could not load: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _purple));
          final d = snap.data!.data();
          if (d == null) return const Center(child: Text('This report no longer exists.'));

          final status = (d['status'] ?? 'open').toString();
          final closed = _isClosed(status);

          // Tell the salon-side counter that the client has read the reply.
          if (!_markedRead && ((d['unreadForClient'] as num?) ?? 0) > 0) {
            _markedRead = true;
            _ref.update({'unreadForClient': 0}).catchError((_) {});
          }

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _ref.collection('messages').orderBy('timestamp').snapshots(),
                  builder: (context, msgSnap) {
                    final msgs = msgSnap.data?.docs ?? [];
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // The original report
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text((d['subject'] ?? '').toString(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                  Chip(
                                    label: Text(_statusLabel(status),
                                        style: const TextStyle(fontSize: 11)),
                                    backgroundColor: _statusColor(status),
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              Text(
                                '${_categoryLabel((d['category'] ?? 'other').toString())} · ${_date(d['createdAt'])}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              if ((d['relatedLabel'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('About: ${d['relatedLabel']}',
                                      style: const TextStyle(fontSize: 12)),
                                ),
                              const SizedBox(height: 10),
                              Text((d['description'] ?? '').toString()),
                              _thumbs(context, (d['evidence'] as List?) ?? const []),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (status == 'awaiting_client')
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add_a_photo_outlined, color: Colors.orange),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'The salon needs evidence. Please add photos below and send them.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        for (final m in msgs) _bubble(context, m.data()),

                        if (closed)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: status == 'resolved'
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status == 'resolved' ? 'Resolved' : 'Report closed',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if ((d['resolution'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(d['resolution'].toString()),
                                ],
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (!closed) _inputBar(status == 'awaiting_client'),
            ],
          );
        },
      ),
    );
  }

  Widget _bubble(BuildContext context, Map<String, dynamic> m) {
    final mine = m['senderType'] == 'client';
    final text = (m['text'] ?? '').toString();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mine ? _purple : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              const Text('Kotton Kandy',
                  style: TextStyle(fontSize: 10, color: _purple, fontWeight: FontWeight.bold)),
            if (text.isNotEmpty)
              Text(text, style: TextStyle(color: mine ? Colors.white : Colors.black87)),
            _thumbs(context, (m['evidence'] as List?) ?? const []),
            const SizedBox(height: 4),
            Text(_date(m['timestamp']),
                style: TextStyle(
                    fontSize: 10, color: mine ? Colors.white70 : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _inputBar(bool needsEvidence) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_photos.isNotEmpty)
              SizedBox(
                height: 70,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (int i = 0; i < _photos.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 6),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(_photos[i].path),
                                  width: 64, height: 64, fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => _photos.removeAt(i)),
                                child: const CircleAvatar(
                                    radius: 9,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close, size: 11, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: _sending ? null : _pickPhoto,
                  icon: Icon(Icons.add_a_photo_outlined,
                      color: needsEvidence ? Colors.orange : _purple),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        color: _lightPurple, borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !_sending,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: needsEvidence ? 'Add photos or details...' : 'Write a reply...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
                  child: IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}