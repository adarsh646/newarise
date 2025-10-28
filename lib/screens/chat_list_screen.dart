import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late String _currentUserId;
  late String _currentUserName;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _loadCurrentUserName();
  }

  Future<void> _loadCurrentUserName() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (mounted) {
        setState(() {
          _currentUserName = userDoc['name'] ?? userDoc['email'] ?? 'User';
        });
      }
    } catch (e) {
      debugPrint('Error loading user name: $e');
      if (mounted) {
        setState(() => _currentUserName = 'User');
      }
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      // Delete all messages
      final messagesSnap = await FirebaseFirestore.instance
          .collection('messages')
          .doc(conversationId)
          .collection('texts')
          .get();

      for (var doc in messagesSnap.docs) {
        await doc.reference.delete();
      }

      // Delete conversation
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Conversation deleted')));
      }
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (msgDate == today) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(msgDate).inDays < 7) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][msgDate.weekday -
          1];
    } else {
      return '${msgDate.month}/${msgDate.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 238, 255, 65),
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .where('participants', arrayContains: _currentUserId)
              .orderBy('lastMessageTime', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            final conversations = snapshot.data?.docs ?? [];

            if (conversations.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.message, size: 64, color: Colors.white30),
                    SizedBox(height: 16),
                    Text(
                      'No conversations yet',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final data = conv.data() as Map<String, dynamic>;
                final conversationId = conv.id;

                // Determine other user ID
                final participants = List<String>.from(
                  data['participants'] ?? [],
                );
                final otherUserId = participants.firstWhere(
                  (id) => id != _currentUserId,
                  orElse: () => '',
                );

                if (otherUserId.isEmpty) return const SizedBox();

                final lastMessage = data['lastMessage'] ?? 'No messages yet';
                final lastMessageTime = data['lastMessageTime'] as Timestamp?;
                final time = lastMessageTime != null
                    ? _formatTime(lastMessageTime.toDate())
                    : '';
                final lastSenderId = data['lastSenderId'] ?? '';

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(otherUserId)
                      .get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const SizedBox();
                    }

                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    final otherUserName =
                        userData['name'] ?? userData['email'] ?? 'User';

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('messages')
                          .doc(conversationId)
                          .collection('texts')
                          .where('receiverId', isEqualTo: _currentUserId)
                          .where('isRead', isEqualTo: false)
                          .snapshots(),
                      builder: (context, msgSnapshot) {
                        final unreadCount = msgSnapshot.data?.docs.length ?? 0;

                        return GestureDetector(
                          onTap: () async {
                            // Mark as read before navigating so badges clear immediately
                            await ChatService().markConversationAsRead(conversationId);
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  conversationId: conversationId,
                                  otherUserId: otherUserId,
                                  otherUserName: otherUserName,
                                  currentUserName: _currentUserName,
                                ),
                              ),
                            );
                            // Force refresh after returning from chat
                            if (result == true && mounted) {
                              setState(() {});
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF667eea),
                                child: Text(
                                  otherUserName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      otherUserName,
                                      style: TextStyle(
                                        fontWeight: unreadCount > 0
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    time,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        if (lastSenderId == _currentUserId)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(
                                              Icons.done_all,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            lastMessage,
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 12,
                                              fontWeight: unreadCount > 0
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF667eea),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          'Delete Conversation?',
                                        ),
                                        content: const Text(
                                          'This will permanently delete all messages in this conversation.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deleteConversation(
                                                conversationId,
                                              );
                                            },
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete Conversation'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
