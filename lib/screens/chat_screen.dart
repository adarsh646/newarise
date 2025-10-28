import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String currentUserName;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.currentUserName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _currentUserId;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _markMessagesAsRead();

    // Also mark as read when the widget is resumed from background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final messagesSnap = await FirebaseFirestore.instance
          .collection('messages')
          .doc(widget.conversationId)
          .collection('texts')
          .where('receiverId', isEqualTo: _currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      if (messagesSnap.docs.isNotEmpty) {
        // Mark all unread messages as read
        for (var doc in messagesSnap.docs) {
          await doc.reference.update({'isRead': true});
        }

        // Add a small delay to ensure Firestore has updated before UI refreshes
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final timestamp = FieldValue.serverTimestamp();

      // Add message to messages collection
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(widget.conversationId)
          .collection('texts')
          .add({
            'content': messageText,
            'senderId': _currentUserId,
            'senderName': widget.currentUserName,
            'receiverId': widget.otherUserId,
            'timestamp': timestamp,
            'isRead': false,
          });

      // Update conversation with last message
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
            'lastMessage': messageText,
            'lastMessageTime': timestamp,
            'lastSenderId': _currentUserId,
          });

      // Scroll to bottom
      _scrollToBottom();

      setState(() => _isTyping = false);
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isCurrentUser) {
    final timestamp = message['timestamp'] as Timestamp?;
    final time = timestamp != null
        ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? const Color(0xFF667eea)
              : const Color(0xFF764ba2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message['content'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                if (isCurrentUser && message['isRead'] == true)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.done_all,
                      size: 12,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Ensure messages are marked as read before leaving
        await _markMessagesAsRead();
        Navigator.pop(context, true); // Return true to notify parent to refresh
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 238, 255, 65),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherUserName,
                style: const TextStyle(color: Colors.black, fontSize: 16),
              ),
              const SizedBox(height: 2),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('conversations')
                    .doc(widget.conversationId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final isOtherTyping = snapshot.data!['isTyping'] ?? false;
                    if (isOtherTyping) {
                      return const Text(
                        'typing...',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    }
                  }
                  return const Text(
                    'Online',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  );
                },
              ),
            ],
          ),
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
            ),
          ),
          child: Column(
            children: [
              // Messages list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('messages')
                      .doc(widget.conversationId)
                      .collection('texts')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    // Reactively mark unread messages for current user as read
                    final unreadDocs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['receiverId'] == _currentUserId &&
                          (data['isRead'] == false || data['isRead'] == null);
                    }).toList();
                    if (unreadDocs.isNotEmpty) {
                      Future.microtask(() async {
                        for (final d in unreadDocs) {
                          try {
                            await d.reference.update({'isRead': true});
                          } catch (_) {}
                        }
                      });
                    }

                    final messages = docs;

                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          'No messages yet. Start a conversation!',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      );
                    }

                    Future.delayed(
                      const Duration(milliseconds: 100),
                      _scrollToBottom,
                    );

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index].data() as Map<String, dynamic>;
                        final isCurrentUser =
                            message['senderId'] == _currentUserId;

                        return _buildMessageBubble(message, isCurrentUser);
                      },
                    );
                  },
                ),
              ),

              // Input area
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onChanged: (value) {
                          setState(() => _isTyping = value.isNotEmpty);
                          // Update typing status in Firestore
                          FirebaseFirestore.instance
                              .collection('conversations')
                              .doc(widget.conversationId)
                              .update({'isTyping': _isTyping})
                              .catchError((e) => debugPrint('Error: $e'));
                        },
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF667eea),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
