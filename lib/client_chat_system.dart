// ============================================================
// CLIENT CHAT SYSTEM — single-file version
//
// Everything the CLIENT side of the marketplace app needs for
// real-time chat with the salon, combined into one file:
//
//   1. Data models   (ChatMessage, ChatSummary)
//   2. Chat service  (all Firestore reads/writes)
//   3. ChatScreen    (the chat UI for the "Messages" tab)
//
// HOW TO LINK IT UP
// ------------------
// Nothing in marketplace.dart needs to change structurally.
// Wherever the message icon / Messages tab currently returns its
// placeholder widget, just return this instead:
//
//   Widget _buildMessages() {
//     return const ChatScreen(
//       salonId: 'kotton_kandy',
//       salonName: 'Kotton Kandy',
//     );
//   }
//
// That's the entire link — one return statement. ChatScreen
// creates/opens the Firestore conversation itself the moment it
// is built, so no other setup is required.
// ============================================================

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';


// ============================================================
// SENDER TYPE
//
// Every message is sent either by the client (the person using
// the marketplace app) or by the salon owner (replying from
// their own owner-facing app).
// ============================================================

enum SenderType { client, salon }

SenderType senderTypeFromString(String? value) {
  return value == 'salon' ? SenderType.salon : SenderType.client;
}

String senderTypeToString(SenderType type) {
  return type == SenderType.salon ? 'salon' : 'client';
}

// ============================================================
// CHAT MESSAGE
//
// A single message inside chats/{chatId}/messages/{messageId}
// ============================================================

class ChatMessage {
  final String id;
  final String senderId;
  final SenderType senderType;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;
  final bool read;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.text,
    required this.timestamp,
    required this.read,
    this.imageUrl,
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
    );
  }
}

// ============================================================
// CHAT SUMMARY
//
// The parent chats/{chatId} document. One document per
// (client, salon) pair. Used to build the salon owner's inbox
// list and to show unread badges.
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
    );
  }
}

// ============================================================
// CHAT SERVICE
//
// Single source of truth for all chat reads/writes. Both the
// client-facing marketplace app and the salon owner's app use
// this exact same service, so messages sent by either side are
// always written to (and read from) the same Firestore data.
//
// FIRESTORE SCHEMA
// -----------------
// chats (collection)
//   {clientId}_{salonId} (document)
//     clientId            : string
//     clientName          : string
//     salonId             : string
//     salonName           : string
//     lastMessage         : string
//     lastMessageTime     : timestamp
//     lastMessageSenderType : 'client' | 'salon'
//     unreadForClient     : number
//     unreadForSalon      : number
//     createdAt           : timestamp
//
//     messages (subcollection)
//       {messageId} (document)
//         senderId   : string  (Firebase Auth uid)
//         senderType : 'client' | 'salon'
//         text       : string
//         imageUrl   : string | null
//         timestamp  : timestamp
//         read       : bool
// ============================================================

class ChatService {
  ChatService._internal();

  static final ChatService instance = ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  // ============================================================
  // CHAT ID
  //
  // Deterministic id so the client and the salon always land on
  // the same conversation document, with no lookup required.
  // ============================================================

  String chatIdFor({
    required String clientId,
    required String salonId,
  }) {
    return '${clientId}_$salonId';
  }

  // ============================================================
  // GET OR CREATE CHAT
  //
  // Called from the CLIENT side (marketplace app) the first
  // time the "Messages" tab is opened for a given salon.
  // ============================================================

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

    if (!snapshot.exists) {
      await docRef.set({
        'clientId': clientId,
        'clientName': clientName,
        'salonId': salonId,
        'salonName': salonName,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderType': 'client',
        'unreadForClient': 0,
        'unreadForSalon': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return chatId;
  }

  // ============================================================
  // MESSAGES STREAM
  //
  // Real-time list of messages for a single conversation,
  // newest first (the chat UI renders it in a reversed ListView).
  // ============================================================

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

  // ============================================================
  // SINGLE CHAT STREAM
  //
  // Used to show the other party's name / last-seen style info
  // in the chat app bar and to react to unread-count changes.
  // ============================================================

  Stream<ChatSummary?> chatStream(String chatId) {
    return _chats.doc(chatId).snapshots().map(
          (doc) => doc.exists ? ChatSummary.fromDoc(doc) : null,
        );
  }

  // ============================================================
  // SALON INBOX STREAM
  //
  // Called from the SALON OWNER'S app: every conversation a
  // given salon is part of, most recently active first.
  // ============================================================

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

  // ============================================================
  // SEND MESSAGE
  //
  // Writes the message itself AND updates the parent chat
  // document (last message preview + unread counters) in one
  // atomic batch, so the inbox list and the chat badge never
  // fall out of sync.
  // ============================================================

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
            isClient ? FieldValue.increment(1) : FieldValue.increment(0),
        'unreadForClient':
            isClient ? FieldValue.increment(0) : FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // ============================================================
  // MARK READ
  //
  // Zeroes out the reader's unread counter and flags the other
  // party's messages as read (for read-receipt ticks).
  // ============================================================

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
//
// Drop this straight into the "Messages" tab of the marketplace
// app. It opens (or creates) the one conversation between the
// signed-in client and the given salon, and keeps it in sync in
// real time with Firestore.
//
// Usage from marketplace.dart:
//
//   Widget _buildMessages() {
//     return const ChatScreen(
//       salonId: 'kotton_kandy',
//       salonName: 'Kotton Kandy',
//     );
//   }
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

  // ============================================================
  // INIT — get or create the chat, then mark it read.
  // ============================================================

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

  // ============================================================
  // SEND TEXT MESSAGE
  // ============================================================

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

  // ============================================================
  // SEND IMAGE (e.g. a reference photo / inspiration picture)
  // ============================================================

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
      final String path =
          'chat_images/$_chatId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final UploadTask task =
          FirebaseStorage.instance.ref(path).putFile(File(picked.path));

      final TaskSnapshot snapshot = await task;
      final String url = await snapshot.ref.getDownloadURL();

      await _chatService.sendMessage(
        chatId: _chatId!,
        senderType: SenderType.client,
        imageUrl: url,
      );
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

  // ============================================================
  // BUILD
  // ============================================================

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
        Expanded(child: _buildMessageList()),
        _buildInputBar(),
      ],
    );
  }

  // ============================================================
  // MESSAGE LIST
  // ============================================================

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
                    'Say hello to ${widget.salonName} to start the conversation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        // New unread salon messages arriving while the screen is
        // open should still be marked read.
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
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
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

  // ============================================================
  // INPUT BAR
  // ============================================================

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
                    hintText: 'Message the salon...',
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
