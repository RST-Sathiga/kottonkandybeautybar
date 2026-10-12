import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'support_bot.dart';



enum SenderType { client, salon, bot }

SenderType senderTypeFromString(String? value) {
  if (value == 'salon') return SenderType.salon;
  if (value == 'bot') return SenderType.bot;
  return SenderType.client;
}

String senderTypeToString(SenderType type) {
  if (type == SenderType.salon) return 'salon';
  if (type == SenderType.bot) return 'bot';
  return 'client';
}



class ChatMessage {
  final String id;
  final String senderId;
  final SenderType senderType;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;
  final bool read;
  final List<String> suggestions;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.text,
    required this.timestamp,
    required this.read,
    this.imageUrl,
    this.suggestions = const [],
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId']?.toString() ?? '',
      senderType: senderTypeFromString(data['senderType']?.toString()),
      text: data['text']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString(),
      timestamp:
      (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] == true,
      suggestions: (data['suggestions'] is List)
          ? (data['suggestions'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}

// ============================================================
// CHAT SUMMARY
// ============================================================

class ChatSummary {
  final String id;
  final String clientId;
  final String clientName;
  final String salonId;
  final String salonName;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final SenderType lastMessageSenderType;
  final int unreadForClient;
  final int unreadForSalon;
  final bool isBotSession;
  final bool awaitingSalon;
  final bool closed;

  ChatSummary({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.salonId,
    required this.salonName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSenderType,
    required this.unreadForClient,
    required this.unreadForSalon,
    this.isBotSession = true,
    this.awaitingSalon = false,
    this.closed = false,
  });

  factory ChatSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return ChatSummary(
      id: doc.id,
      clientId: data['clientId']?.toString() ?? '',
      clientName: data['clientName']?.toString() ?? 'Client',
      salonId: data['salonId']?.toString() ?? '',
      salonName: data['salonName']?.toString() ?? 'Salon',
      lastMessage: data['lastMessage']?.toString() ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderType:
      senderTypeFromString(data['lastMessageSenderType']?.toString()),
      unreadForClient: (data['unreadForClient'] as num?)?.toInt() ?? 0,
      unreadForSalon: (data['unreadForSalon'] as num?)?.toInt() ?? 0,
      isBotSession: data['isBotSession'] != false,
      awaitingSalon: data['awaitingSalon'] == true,
      closed: data['closed'] == true,
    );
  }
}



class ChatService {
  ChatService._internal();

  static final ChatService instance = ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  String chatIdFor({
    required String clientId,
    required String salonId,
  }) {
    return '${clientId}_$salonId';
  }

  Future<String> getOrCreateChat({
    required String salonId,
    required String salonName,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in to start a chat.');
    }

    final String clientId = user.uid;

    final String clientName =
    (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'Client');

    final String chatId = chatIdFor(clientId: clientId, salonId: salonId);
    final DocumentReference<Map<String, dynamic>> docRef = _chats.doc(chatId);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();

    final bool needsNewSession =
        !snapshot.exists || snapshot.data()?['closed'] == true;

    if (needsNewSession) {
      // New chat (or a previous one was closed): start a fresh bot session.
      await docRef.set({
        'clientId': clientId,
        'clientName': clientName,
        'salonId': salonId,
        'salonName': salonName,
        'lastMessage': SupportBot.greeting,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderType': 'bot',
        'unreadForClient': 0,
        'unreadForSalon': 0,
        'isBotSession': true,
        'awaitingSalon': false,
        'closed': false,
        'sessionStartedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _botSay(docRef, clientId, SupportBot.greeting, SupportBot.topics);
    }

    return chatId;
  }

  Stream<List<ChatMessage>> messagesStream(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
          snapshot.docs.map((doc) => ChatMessage.fromDoc(doc)).toList(),
    );
  }

  Stream<ChatSummary?> chatStream(String chatId) {
    return _chats.doc(chatId).snapshots().map(
          (doc) => doc.exists ? ChatSummary.fromDoc(doc) : null,
    );
  }

  Stream<List<ChatSummary>> salonChatsStream(String salonId) {
    return _chats
        .where('salonId', isEqualTo: salonId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
          snapshot.docs.map((doc) => ChatSummary.fromDoc(doc)).toList(),
    );
  }

  Future<void> sendMessage({
    required String chatId,
    required SenderType senderType,
    String text = '',
    String? imageUrl,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in to send a message.');
    }

    final String trimmed = text.trim();

    if (trimmed.isEmpty && imageUrl == null) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> chatRef = _chats.doc(chatId);
    final DocumentReference<Map<String, dynamic>> messageRef =
    chatRef.collection('messages').doc();

    final bool isClient = senderType == SenderType.client;
    final WriteBatch batch = _firestore.batch();

    // While the customer is still talking to the chatbot, the owner is not notified.
    final Map<String, dynamic> chatData = (await chatRef.get()).data() ?? {};
    final bool wasClosed = chatData['closed'] == true;
    // A closed chat starts a fresh chatbot session when the customer writes again.
    final bool withBot = isClient && (wasClosed || chatData['isBotSession'] != false);
    if (isClient && wasClosed) {
      await chatRef.set({
        'closed': false,
        'isBotSession': true,
        'awaitingSalon': false,
        'sessionStartedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    batch.set(messageRef, {
      'senderId': user.uid,
      'senderType': senderTypeToString(senderType),
      'text': trimmed,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    batch.set(
      chatRef,
      {
        'lastMessage': trimmed.isEmpty ? '📷 Photo' : trimmed,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderType': senderTypeToString(senderType),
        'unreadForSalon':
        (isClient && !withBot) ? FieldValue.increment(1) : FieldValue.increment(0),
        'unreadForClient':
        isClient ? FieldValue.increment(0) : FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    // Chatbot: answer text questions while the chat is still a bot session.
    if (isClient && trimmed.isNotEmpty) {
      if (withBot) {
        final BotReply reply = await SupportBot.generateResponse(trimmed);
        await _botSay(chatRef, user.uid, reply.text, reply.suggestions);
        if (reply.escalate) await escalateToOwner(chatId);
      }
    } else if (!isClient && senderType == SenderType.salon) {
      // The owner replied: no longer waiting.
      await chatRef.set({'awaitingSalon': false}, SetOptions(merge: true));
    }
  }

  /// Bot messages carry the customer's uid (Firestore rules require
  /// senderId == signed-in user) and are marked senderType 'bot'.
  Future<void> _botSay(
      DocumentReference<Map<String, dynamic>> chatRef,
      String uid,
      String text,
      List<String> suggestions,
      ) async {
    await chatRef.collection('messages').add({
      'senderId': uid,
      'senderType': 'bot',
      'isFromBot': true,
      'text': text,
      'suggestions': suggestions,
      'timestamp': FieldValue.serverTimestamp(),
      'read': true,
    });
    await chatRef.set({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderType': 'bot',
    }, SetOptions(merge: true));
  }

  /// Hands the chat to the owner (live support).
  Future<void> escalateToOwner(String chatId) async {
    await _chats.doc(chatId).set({
      'isBotSession': false,
      'awaitingSalon': true,
      'unreadForSalon': FieldValue.increment(1),
      'escalatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Customer chooses to go back to the chatbot while waiting for the owner.
  Future<void> backToBot(String chatId) async {
    await _chats.doc(chatId).set({
      'isBotSession': true,
      'awaitingSalon': false,
    }, SetOptions(merge: true));
  }

  /// Ends the session. The transcript stays in Firestore (archived).
  Future<void> closeChat(String chatId) async {
    await _chats.doc(chatId).set({
      'closed': true,
      'awaitingSalon': false,
      'closedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markRead({
    required String chatId,
    required SenderType readerType,
  }) async {
    final DocumentReference<Map<String, dynamic>> chatRef = _chats.doc(chatId);

    await chatRef.set(
      {
        readerType == SenderType.client ? 'unreadForClient' : 'unreadForSalon':
        0,
      },
      SetOptions(merge: true),
    );

    final String otherType =
    readerType == SenderType.client ? 'salon' : 'client';

    final QuerySnapshot<Map<String, dynamic>> unread = await chatRef
        .collection('messages')
        .where('senderType', isEqualTo: otherType)
        .where('read', isEqualTo: false)
        .get();

    if (unread.docs.isEmpty) {
      return;
    }

    final WriteBatch batch = _firestore.batch();

    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }
}

// ============================================================
// CLIENT CHAT SCREEN
// ============================================================

class ChatScreen extends StatefulWidget {
  final String salonId;
  final String salonName;

  const ChatScreen({
    super.key,
    required this.salonId,
    required this.salonName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color primaryPurple = Color(0xFF6B3A82);
  static const Color lightPurple = Color(0xFFF3EAF6);

  static const String cloudinaryCloudName = 'nuqsuqyw';
  static const String cloudinaryUploadPreset = 'profile_uploads';

  final ChatService _chatService = ChatService.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _chatId;
  bool _loading = true;
  bool _sending = false;
  bool _uploadingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final String chatId = await _chatService.getOrCreateChat(
        salonId: widget.salonId,
        salonName: widget.salonName,
      );

      if (!mounted) return;

      setState(() {
        _chatId = chatId;
        _loading = false;
      });

      await _chatService.markRead(
        chatId: chatId,
        readerType: SenderType.client,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text;

    if (text.trim().isEmpty || _chatId == null || _sending) {
      return;
    }

    setState(() => _sending = true);
    _messageController.clear();

    try {
      await _chatService.sendMessage(
        chatId: _chatId!,
        senderType: SenderType.client,
        text: text,
      );
    } catch (e) {
      _showSnack('Could not send message. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendTopic(String topic) async {
    if (_chatId == null) return;
    try {
      await _chatService.sendMessage(
        chatId: _chatId!,
        senderType: SenderType.client,
        text: topic,
      );
    } catch (_) {
      _showSnack('Could not send message. Please try again.');
    }
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(responseData);
      return jsonResponse['secure_url'];
    } else {
      debugPrint('Cloudinary Chat Upload Error: $responseData');
      return null;
    }
  }

  Future<void> _sendImage() async {
    if (_chatId == null || _uploadingImage) return;

    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (picked == null) return;

    setState(() => _uploadingImage = true);

    try {
      final file = File(picked.path);
      final String? url = await _uploadImageToCloudinary(file);

      if (url != null) {
        await _chatService.sendMessage(
          chatId: _chatId!,
          senderType: SenderType.client,
          imageUrl: url,
        );
      } else {
        _showSnack('Could not send image. Upload failed.');
      }
    } catch (e) {
      _showSnack('Could not send image. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: lightPurple,
              child: Text(
                widget.salonName.isNotEmpty
                    ? widget.salonName[0].toUpperCase()
                    : 'S',
                style: const TextStyle(
                  color: primaryPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.salonName,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (_chatId == null) return;
              if (v == 'owner') {
                await _chatService.sendMessage(
                  chatId: _chatId!,
                  senderType: SenderType.client,
                  text: 'I would like to speak to the owner',
                );
              } else if (v == 'end') {
                await _chatService.closeChat(_chatId!);
                if (mounted) Navigator.of(context).maybePop();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'owner', child: Text('Speak to the owner')),
              PopupMenuItem(value: 'end', child: Text('End chat')),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryPurple),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      );
    }

    return Column(
      children: [
        StreamBuilder<ChatSummary?>(
          stream: _chatService.chatStream(_chatId!),
          builder: (context, snap) {
            final chat = snap.data;
            if (chat == null || chat.closed || chat.isBotSession) {
              return const SizedBox.shrink();
            }
            return Container(
              width: double.infinity,
              color: lightPurple,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, size: 18, color: primaryPurple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chat.awaitingSalon
                          ? 'You are chatting with the owner. She will reply here soon.'
                          : 'You are chatting with the owner.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _chatService.backToBot(_chatId!),
                    child: const Text('Back to chatbot', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(child: _buildMessageList()),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<ChatMessage>>(
      stream: _chatService.messagesStream(_chatId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: primaryPurple),
          );
        }

        final List<ChatMessage> messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 70,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'No messages yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask a question to start the conversation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        _chatService.markRead(
          chatId: _chatId!,
          readerType: SenderType.client,
        );

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final ChatMessage message = messages[index];
            final bool isMe = message.senderType == SenderType.client;
            return _buildBubble(message, isMe);
          },
        );
      },
    );
  }

  Widget _buildBubble(ChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? primaryPurple : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  message.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 140,
                      width: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: primaryPurple,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (message.text.isNotEmpty) const SizedBox(height: 6),
            ],
            if (message.senderType == SenderType.bot)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Assistant',
                    style: TextStyle(fontSize: 10, color: primaryPurple, fontWeight: FontWeight.bold)),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            if (message.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.suggestions
                    .map((s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  backgroundColor: lightPurple,
                  onPressed: () => _sendTopic(s),
                ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.75)
                        : Colors.grey[600],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.read ? Icons.done_all : Icons.done,
                    size: 13,
                    color: message.read
                        ? Colors.lightBlueAccent
                        : Colors.white.withValues(alpha: 0.75),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final String hour = (date.hour % 12 == 0 ? 12 : date.hour % 12)
        .toString();
    final String minute = date.minute.toString().padLeft(2, '0');
    final String period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _uploadingImage ? null : _sendImage,
              icon: _uploadingImage
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryPurple,
                ),
              )
                  : const Icon(Icons.image_outlined, color: primaryPurple),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: lightPurple,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Ask a question...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: primaryPurple,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _sending ? null : _sendMessage,
                icon: _sending
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}