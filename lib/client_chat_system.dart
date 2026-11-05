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

/// Message shown to clients when something goes wrong behind the scenes
/// (Firebase, network, etc.). Never show raw error text to clients.
const String kSystemDownMessage =
    'Our chat is temporarily unavailable.\nPlease try again later.';

/// Turns any error into something a normal person can understand.
/// The real error is only printed to the debug console.
String friendlyChatError(Object error) {
  debugPrint('Chat error: $error');
  if (error.toString().contains('must be signed in')) {
    return 'Please sign in to use the chat.';
  }
  return kSystemDownMessage;
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
  final String type; // 'bot' (assistant chat) or 'owner' (chat with the owner)
  final bool suggestOwner;

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
    this.type = '',
    this.suggestOwner = false,
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
      type: data['type']?.toString() ?? '',
      suggestOwner: data['suggestOwner'] == true,
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

  /// Chat with the owner (this is where the owner's replies and unread counts live).
  String chatIdFor({
    required String clientId,
    required String salonId,
  }) {
    return ownerChatIdFor(clientId: clientId, salonId: salonId);
  }

  /// The assistant (chatbot) conversation. This keeps the ORIGINAL chat id,
  /// so the client's existing messages still show. The owner never sees it.
  String botChatIdFor({
    required String clientId,
    required String salonId,
  }) {
    return '${clientId}_$salonId';
  }

  /// The direct conversation with the owner (shown on the admin side).
  String ownerChatIdFor({
    required String clientId,
    required String salonId,
  }) {
    return '${clientId}_${salonId}_owner';
  }

  String _clientNameFor(User user) {
    return (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'Client');
  }

  /// Finds (or starts) the assistant chat for this client and salon.
  Future<String> getOrCreateBotChat({
    required String salonId,
    required String salonName,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in to start a chat.');
    }

    final String clientId = user.uid;
    final String clientName = _clientNameFor(user);

    final String chatId = botChatIdFor(clientId: clientId, salonId: salonId);
    final DocumentReference<Map<String, dynamic>> docRef = _chats.doc(chatId);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();

    // Start a fresh bot session for a new chat, a closed chat, or an old chat
    // that was handed to the owner (the owner now has their own separate chat).
    final bool needsNewSession = !snapshot.exists ||
        snapshot.data()?['closed'] == true ||
        snapshot.data()?['isBotSession'] == false;

    if (needsNewSession) {
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
        if (snapshot.data()?['suggestOwner'] == true) 'suggestOwner': false,
        'closed': false,
        'sessionStartedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _botSay(docRef, clientId, SupportBot.greeting, SupportBot.topics);
    }

    return chatId;
  }

  /// Kept so older code that calls getOrCreateChat still works (assistant chat).
  Future<String> getOrCreateChat({
    required String salonId,
    required String salonName,
  }) =>
      getOrCreateBotChat(salonId: salonId, salonName: salonName);

  /// Makes sure the direct chat with the owner exists. It stays hidden from the
  /// owner until the client sends the first message.
  Future<String> ensureOwnerChat({
    required String salonId,
    required String salonName,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in to start a chat.');
    }

    final String chatId =
    ownerChatIdFor(clientId: user.uid, salonId: salonId);
    final DocumentReference<Map<String, dynamic>> docRef = _chats.doc(chatId);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();

    if (!snapshot.exists) {
      await docRef.set({
        'type': 'owner',
        'clientId': user.uid,
        'clientName': _clientNameFor(user),
        'salonId': salonId,
        'salonName': salonName,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderType': 'client',
        'unreadForClient': 0,
        'unreadForSalon': 0,
        'isBotSession': false,
        'awaitingSalon': false,
        'closed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
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

    final Map<String, dynamic> chatData = (await chatRef.get()).data() ?? {};
    final bool isOwnerChat = chatData['type'] == 'owner';
    final bool wasClosed = chatData['closed'] == true;
    // The assistant chat always answers. The owner chat is never answered by the bot
    // and notifies the owner.
    final bool withBot = isClient && !isOwnerChat;
    final bool notifyOwner = isClient && isOwnerChat;

    if (isClient && wasClosed) {
      // A closed chat starts again when the customer writes again.
      await chatRef.set({
        'closed': false,
        'awaitingSalon': false,
        if (chatData['suggestOwner'] == true) 'suggestOwner': false,
        if (!isOwnerChat) ...{
          'isBotSession': true,
          'sessionStartedAt': FieldValue.serverTimestamp(),
        },
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
        notifyOwner ? FieldValue.increment(1) : FieldValue.increment(0),
        if (notifyOwner) 'awaitingSalon': true,
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
        if (reply.escalate) {
          // The owner has their own chat now: point the client to the Owner tab.
          await _botSay(
            chatRef,
            user.uid,
            'You can message the owner directly in the Messages tab.',
            const [],
          );
          try {
            await chatRef.set({'suggestOwner': true}, SetOptions(merge: true));
          } catch (e) {
            debugPrint('Owner suggestion error: $e');
          }
        }
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

  /// Hides the "chat with the owner" nudge in the assistant chat.
  Future<void> dismissOwnerSuggestion(String chatId) async {
    await _chats.doc(chatId).set({'suggestOwner': false}, SetOptions(merge: true));
  }

  /// Ends the session. The transcript stays in Firestore (archived).
  Future<void> closeChat(String chatId) async {
    final DocumentReference<Map<String, dynamic>> ref = _chats.doc(chatId);
    if (!(await ref.get()).exists) return;
    await ref.set({
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
// Two separate chats:
//   1. ChatScreen          : Messages tab, direct chat with the salon owner.
//   2. AssistantChatScreen : the chatbot (floating bot button). The owner is NOT notified.
// ============================================================

const Color _primaryPurple = Color(0xFF6B3A82);
const Color _lightPurple = Color(0xFFF3EAF6);

const String _cloudinaryCloudName = 'nuqsuqyw';
const String _cloudinaryUploadPreset = 'profile_uploads';

/// Messages tab: the direct chat with the salon owner.
class ChatScreen extends StatelessWidget {
  final String salonId;
  final String salonName;

  const ChatScreen({
    super.key,
    required this.salonId,
    required this.salonName,
  });

  @override
  Widget build(BuildContext context) {
    return _ConversationScreen(
      isOwner: true,
      salonId: salonId,
      salonName: salonName,
    );
  }
}

/// Chat assistant (the chatbot). Opened by the floating bot button.
/// The owner is never notified about this chat.
class AssistantChatScreen extends StatelessWidget {
  final String salonId;
  final String salonName;

  const AssistantChatScreen({
    super.key,
    required this.salonId,
    required this.salonName,
  });

  @override
  Widget build(BuildContext context) {
    return _ConversationScreen(
      isOwner: false,
      salonId: salonId,
      salonName: salonName,
    );
  }
}

/// A single open conversation (Assistant or Owner).
class _ConversationScreen extends StatefulWidget {
  final bool isOwner;
  final String salonId;
  final String salonName;

  const _ConversationScreen({
    required this.isOwner,
    required this.salonId,
    required this.salonName,
  });

  @override
  State<_ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<_ConversationScreen> {
  final GlobalKey<_ChatPaneState> _paneKey = GlobalKey<_ChatPaneState>();

  Future<String> _load() {
    return widget.isOwner
        ? ChatService.instance.ensureOwnerChat(
      salonId: widget.salonId,
      salonName: widget.salonName,
    )
        : ChatService.instance.getOrCreateBotChat(
      salonId: widget.salonId,
      salonName: widget.salonName,
    );
  }

  void _goToOwner() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _ConversationScreen(
          isOwner: true,
          salonId: widget.salonId,
          salonName: widget.salonName,
        ),
      ),
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
              backgroundColor: _lightPurple,
              child: Icon(
                widget.isOwner ? Icons.support_agent : Icons.smart_toy_outlined,
                color: _primaryPurple,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isOwner ? 'Owner' : 'Assistant',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  widget.salonName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'end') _paneKey.currentState?.endChat();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'end', child: Text('End this chat')),
            ],
          ),
        ],
      ),
      body: _ChatPane(
        key: _paneKey,
        isOwner: widget.isOwner,
        active: true,
        loadChatId: _load,
        onOpenOwner: widget.isOwner ? null : _goToOwner,
      ),
    );
  }
}

/// One conversation (either the Assistant or the Owner).
class _ChatPane extends StatefulWidget {
  final bool isOwner;
  final bool active;
  final Future<String> Function() loadChatId;
  final VoidCallback? onOpenOwner;

  const _ChatPane({
    super.key,
    required this.isOwner,
    required this.active,
    required this.loadChatId,
    this.onOpenOwner,
  });

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final ChatService _chatService = ChatService.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _chatId;
  Stream<List<ChatMessage>>? _messages;
  Stream<ChatSummary?>? _summary;
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
    if (mounted && (_error != null || !_loading)) {
      setState(() {
        _error = null;
        _loading = true;
      });
    }
    try {
      final String chatId = await widget.loadChatId();

      if (!mounted) return;

      setState(() {
        _chatId = chatId;
        _messages = _chatService.messagesStream(chatId);
        _summary = _chatService.chatStream(chatId);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = friendlyChatError(e);
        _loading = false;
      });
    }
  }

  /// Called from the menu: ends this conversation and leaves the screen.
  Future<void> endChat() async {
    try {
      if (_chatId != null) {
        await _chatService.closeChat(_chatId!);
      }
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('Chat end error: $e');
      _showSnack('Something went wrong. Please try again later.');
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
      debugPrint('Chat send error: $e');
      if (mounted && _messageController.text.isEmpty) {
        _messageController.text = text;
      }
      _showSnack('Message not sent. Please try again later.');
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
    } catch (e) {
      debugPrint('Chat topic error: $e');
      _showSnack('Message not sent. Please try again later.');
    }
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
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
        _showSnack('Image not sent. Please try again later.');
      }
    } catch (e) {
      debugPrint('Chat image error: $e');
      _showSnack('Image not sent. Please try again later.');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryPurple),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 15),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: 16),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: _init,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildTopBanner(),
        Expanded(child: _buildMessageList()),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildTopBanner() {
    return StreamBuilder<ChatSummary?>(
      stream: _summary,
      builder: (context, snap) {
        final ChatSummary? chat = snap.data;
        if (chat == null || chat.closed) return const SizedBox.shrink();

        String? text;
        Widget? action;

        if (widget.isOwner) {
          text = chat.awaitingSalon
              ? 'Your message was sent. The owner will reply here soon.'
              : null;
        } else if (chat.suggestOwner) {
          text = 'Need a real person? You can chat with the owner directly.';
          action = TextButton(
            onPressed: () {
              if (_chatId != null) {
                _chatService.dismissOwnerSuggestion(_chatId!).catchError((e) {
                  debugPrint('Dismiss suggestion error: $e');
                });
              }
              widget.onOpenOwner?.call();
            },
            child: const Text('Open Owner chat', style: TextStyle(fontSize: 12)),
          );
        }

        if (text == null) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          color: _lightPurple,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.support_agent, size: 18, color: _primaryPurple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: const TextStyle(fontSize: 12)),
              ),
              if (action != null) action,
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<ChatMessage>>(
      stream: _messages,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryPurple),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 15),
                  Text(
                    friendlyChatError(snapshot.error!),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  ),
                ],
              ),
            ),
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
                    widget.isOwner
                        ? Icons.support_agent
                        : Icons.chat_bubble_outline,
                    size: 70,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    widget.isOwner ? 'Chat with the owner' : 'No messages yet',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isOwner
                        ? 'Send a message and the owner will reply here.'
                        : 'Ask a question to start the conversation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        // Only mark messages as read while this chat is on screen.
        if (widget.active && _chatId != null) {
          _chatService
              .markRead(chatId: _chatId!, readerType: SenderType.client)
              .catchError((e) {
            debugPrint('Mark read error: $e');
          });
        }

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
          color: isMe ? _primaryPurple : Colors.white,
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
                          color: _primaryPurple,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (message.text.isNotEmpty) const SizedBox(height: 6),
            ],
            if (message.senderType == SenderType.bot)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Assistant',
                    style: TextStyle(
                        fontSize: 10,
                        color: _primaryPurple,
                        fontWeight: FontWeight.bold)),
              ),
            if (message.senderType == SenderType.salon)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Owner',
                    style: TextStyle(
                        fontSize: 10,
                        color: _primaryPurple,
                        fontWeight: FontWeight.bold)),
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
                  backgroundColor: _lightPurple,
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
    final String hour =
    (date.hour % 12 == 0 ? 12 : date.hour % 12).toString();
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
                  color: _primaryPurple,
                ),
              )
                  : const Icon(Icons.image_outlined, color: _primaryPurple),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _lightPurple,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: widget.isOwner
                        ? 'Message the owner...'
                        : 'Ask a question...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: _primaryPurple,
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