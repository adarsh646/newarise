import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();

  factory ChatService() {
    return _instance;
  }

  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get or create a conversation between two users
  Future<String> getOrCreateConversation({
    required String otherUserId,
    required String otherUserName,
    String? currentUserName,
  }) async {
    try {
      final currentUserId = _auth.currentUser!.uid;

      // Get current user name if not provided
      final userName = currentUserName ?? await _getUserName(currentUserId);

      // Create a consistent conversation ID
      final conversationId = _createConversationId(currentUserId, otherUserId);

      // Check if conversation exists
      final convDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!convDoc.exists) {
        // Create new conversation
        await _firestore.collection('conversations').doc(conversationId).set({
          'participants': [currentUserId, otherUserId],
          'participantNames': {
            currentUserId: userName,
            otherUserId: otherUserName,
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': currentUserId,
          'isTyping': false,
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'direct_message',
        });

        // Create message collection
        await _firestore.collection('messages').doc(conversationId).set({
          'conversationId': conversationId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return conversationId;
    } catch (e) {
      throw Exception('Error creating/getting conversation: $e');
    }
  }

  /// Create a consistent conversation ID
  String _createConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Get user name from Firestore
  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        return userDoc['name'] ?? userDoc['email'] ?? 'User';
      }
      return 'User';
    } catch (e) {
      return 'User';
    }
  }

  /// Get unread count for a specific conversation
  Future<int> getUnreadCount(String conversationId) async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      final snapshot = await _firestore
          .collection('messages')
          .doc(conversationId)
          .collection('texts')
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get total unread count across all conversations
  Future<int> getTotalUnreadCount() async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      final conversations = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      int totalUnread = 0;
      for (var conv in conversations.docs) {
        final conversationId = conv.id;
        final unread = await getUnreadCount(conversationId);
        totalUnread += unread;
      }
      return totalUnread;
    } catch (e) {
      return 0;
    }
  }

  /// Mark all messages in a conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      final messagesSnap = await _firestore
          .collection('messages')
          .doc(conversationId)
          .collection('texts')
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in messagesSnap.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      throw Exception('Error marking conversation as read: $e');
    }
  }

  /// Get conversation stream
  Stream<DocumentSnapshot> getConversationStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots();
  }

  /// Get messages stream
  Stream<QuerySnapshot> getMessagesStream(String conversationId) {
    return _firestore
        .collection('messages')
        .doc(conversationId)
        .collection('texts')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    required String receiverId,
  }) async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      final currentUserName = await _getUserName(currentUserId);
      final timestamp = FieldValue.serverTimestamp();

      // Add message
      await _firestore
          .collection('messages')
          .doc(conversationId)
          .collection('texts')
          .add({
            'content': content,
            'senderId': currentUserId,
            'senderName': currentUserName,
            'receiverId': receiverId,
            'timestamp': timestamp,
            'isRead': false,
          });

      // Update conversation
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': content,
        'lastMessageTime': timestamp,
        'lastSenderId': currentUserId,
      });
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  /// Delete a conversation and all its messages
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete all messages
      final messagesSnap = await _firestore
          .collection('messages')
          .doc(conversationId)
          .collection('texts')
          .get();

      for (var doc in messagesSnap.docs) {
        await doc.reference.delete();
      }

      // Delete messages collection document
      await _firestore.collection('messages').doc(conversationId).delete();

      // Delete conversation
      await _firestore.collection('conversations').doc(conversationId).delete();
    } catch (e) {
      throw Exception('Error deleting conversation: $e');
    }
  }

  /// Update typing status
  Future<void> updateTypingStatus(String conversationId, bool isTyping) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'isTyping': isTyping,
      });
    } catch (e) {
      // Silent fail for typing status
    }
  }
}
