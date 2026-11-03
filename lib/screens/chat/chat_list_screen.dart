import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nodelink_chat_theme.dart';
import '../../models/chat_message.dart';
import '../../models/node_user.dart';
import '../../providers/node_link_provider.dart';
import '../../services/e2ee_service.dart';
import '../../services/local_chat_db.dart';
import '../../services/chat_sync_service.dart';
import '../call/call_popup_banner.dart';
import 'chat_conversation_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _selectedFilter = 'All'; // All, Unread, Groups, Nearby Nodes
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final myId = context.read<NodeLinkProvider>().currentUser.id;
        ChatSyncService.instance.startInboxListener(myNodeId: myId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(int timestampMs) {
    if (timestampMs == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) {
      return DateFormat('h:mm a').format(dt);
    } else if (today.difference(msgDate).inDays == 1) {
      return 'Yesterday';
    } else if (today.difference(msgDate).inDays < 7) {
      return DateFormat('EEEE').format(dt);
    } else {
      return DateFormat('M/d/yy').format(dt);
    }
  }

  Future<void> _openCamera() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Captured: ${photo.name}. Select a contact to send.'),
            backgroundColor: const Color(0xFF0284C7),
          ),
        );
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  void _showEncryptionInfoDialog(BuildContext context, NodeLinkChatTheme chatTheme) {
    final myKey = E2EEService.myPublicKeyPem;
    final fingerprint = E2EEService.getPublicKeyFingerprint(myKey);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: chatTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock_rounded, color: chatTheme.primaryAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                'End-to-End Encryption',
                style: TextStyle(
                  color: chatTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Messages, voice notes, and media exchanged on NodeLink are secured with Hybrid RSA-2048 + AES-256. Decrypted messages reside solely on your device in local SQLite storage.',
                style: TextStyle(
                  color: chatTheme.secondaryText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Device Key Fingerprint:',
                style: TextStyle(
                  color: chatTheme.primaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: chatTheme.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1F2C34),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: chatTheme.dividerColor),
                ),
                child: SelectableText(
                  fingerprint,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: chatTheme.primaryAccent,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: chatTheme.primaryAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNewChatDialog(
    BuildContext context,
    NodeLinkChatTheme chatTheme,
    List<NodeUser> connectedNodes,
    NodeUser currentUser,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: chatTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Start New Chat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: chatTheme.primaryText,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: chatTheme.iconMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (connectedNodes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No connected peer nodes yet.\nConnect nodes via Connection Hub to chat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: chatTheme.secondaryText, fontSize: 14),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: connectedNodes.length,
                      itemBuilder: (context, index) {
                        final peer = connectedNodes[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: _buildAvatar(peer, chatTheme, 44),
                          title: Text(
                            peer.name,
                            style: TextStyle(
                              color: chatTheme.primaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Node ID: ${peer.id}',
                            style: TextStyle(color: chatTheme.secondaryText, fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatConversationScreen(peerUser: peer),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(NodeUser user, NodeLinkChatTheme chatTheme, double size) {
    final hasRemotePic = user.profilePicUrl != null && user.profilePicUrl!.startsWith('http');
    final hasBase64 = user.profilePicUrl != null && user.profilePicUrl!.startsWith('data:image');
    final isOnline = user.status.toLowerCase() == 'online' || user.status.toLowerCase() == 'active';

    Widget imageWidget;
    if (hasRemotePic) {
      imageWidget = Image.network(
        user.profilePicUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildInitialsFallback(user, chatTheme, size),
      );
    } else if (hasBase64) {
      try {
        final b64 = user.profilePicUrl!.split(',').last;
        imageWidget = Image.memory(
          base64Decode(b64),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsFallback(user, chatTheme, size),
        );
      } catch (_) {
        imageWidget = _buildInitialsFallback(user, chatTheme, size);
      }
    } else if (user.avatarPath.isNotEmpty &&
        (user.avatarPath.endsWith('.jpg') ||
            user.avatarPath.endsWith('.png') ||
            user.avatarPath.endsWith('.jpeg'))) {
      imageWidget = Image.asset(
        user.avatarPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildInitialsFallback(user, chatTheme, size),
      );
    } else {
      imageWidget = _buildInitialsFallback(user, chatTheme, size);
    }

    return Stack(
      children: [
        ClipOval(child: SizedBox(width: size, height: size, child: imageWidget)),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: chatTheme.onlineGreen,
                shape: BoxShape.circle,
                border: Border.all(
                  color: chatTheme.cardBg,
                  width: 2.2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitialsFallback(NodeUser user, NodeLinkChatTheme chatTheme, double size) {
    final initial = user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : 'N';
    return Container(
      width: size,
      height: size,
      color: chatTheme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF233138),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: chatTheme.primaryAccent,
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSubtitle(ChatMessage? lastMsg, NodeLinkChatTheme chatTheme) {
    if (lastMsg == null) {
      return Text(
        'Tap to start encrypted chat',
        style: TextStyle(
          color: chatTheme.secondaryText,
          fontSize: 13.5,
          fontStyle: FontStyle.italic,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    Widget? leadingIcon;
    String textPreview = lastMsg.decryptedText;

    if (lastMsg.isOutgoing) {
      final isRead = lastMsg.status == 'read';
      leadingIcon = Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(
          Icons.done_all,
          size: 16,
          color: isRead ? chatTheme.readTickBlue : chatTheme.secondaryText,
        ),
      );
    }

    if (lastMsg.messageType == 'voice' || lastMsg.messageType == 'audio') {
      textPreview = lastMsg.mediaDuration?.isNotEmpty == true
          ? '🎤 ${lastMsg.mediaDuration}'
          : '🎤 Voice message';
    } else if (lastMsg.messageType == 'image') {
      textPreview = textPreview.isNotEmpty ? '📷 $textPreview' : '📷 Photo';
    } else if (lastMsg.messageType == 'video') {
      textPreview = textPreview.isNotEmpty ? '🎥 $textPreview' : '🎥 Video';
    } else if (lastMsg.messageType == 'location') {
      textPreview = '📍 Live Location';
    } else if (lastMsg.messageType == 'document') {
      textPreview = textPreview.isNotEmpty ? '📄 $textPreview' : '📄 Document';
    }

    return Row(
      children: [
        ?leadingIcon,
        Expanded(
          child: Text(
            textPreview,
            style: TextStyle(
              color: chatTheme.secondaryText,
              fontSize: 13.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatTheme = NodeLinkChatTheme.of(context);
    final provider = context.watch<NodeLinkProvider>();
    final connectedNodes = provider.connectedNodes;
    final currentUser = provider.currentUser;

    return Scaffold(
      backgroundColor: chatTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: chatTheme.appBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        leading: _isSearching
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: chatTheme.primaryText),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: chatTheme.primaryText, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search chats or messages...',
                  hintStyle: TextStyle(color: chatTheme.secondaryText),
                  border: InputBorder.none,
                ),
              )
            : Text(
                'NodeLink',
                style: TextStyle(
                  color: chatTheme.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: Icon(Icons.search, color: chatTheme.primaryText),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
            IconButton(
              icon: Icon(Icons.camera_alt_outlined, color: chatTheme.primaryText),
              onPressed: _openCamera,
            ),
          ],
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: chatTheme.primaryText),
            color: chatTheme.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'mark_read') {
                await LocalChatDb.instance.markAllConversationsAsRead();
              } else if (value == 'toggle_theme') {
                provider.toggleThemeMode();
              } else if (value == 'encryption_info') {
                _showEncryptionInfoDialog(context, chatTheme);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'mark_read',
                child: Text('Mark all as read', style: TextStyle(color: chatTheme.primaryText)),
              ),
              PopupMenuItem(
                value: 'toggle_theme',
                child: Text(
                  chatTheme.isLight ? 'Switch to Dark Mode' : 'Switch to Light Mode',
                  style: TextStyle(color: chatTheme.primaryText),
                ),
              ),
              PopupMenuItem(
                value: 'encryption_info',
                child: Text('Encryption Keys Info', style: TextStyle(color: chatTheme.primaryText)),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<void>(
            stream: LocalChatDb.instance.onDatabaseChanged,
            builder: (context, _) {
          return FutureBuilder<List<String>>(
            future: LocalChatDb.instance.getAllPeerIds(),
            builder: (context, snapshot) {
              final dbPeerIds = snapshot.data ?? [];

              // Merge discovered connected nodes with peer IDs that have local conversations
              final Map<String, NodeUser> mergedPeers = {};

              for (final node in connectedNodes) {
                mergedPeers[node.id] = node;
              }

              for (final peerId in dbPeerIds) {
                if (!mergedPeers.containsKey(peerId)) {
                  // Fallback stub for peers stored in DB but not active in mesh right now
                  mergedPeers[peerId] = NodeUser(
                    id: peerId,
                    name: 'Node ${peerId.length > 8 ? peerId.substring(0, 8) : peerId}',
                    avatarPath: '',
                    status: 'Offline',
                    batteryLevel: 0,
                    latitude: 0.0,
                    longitude: 0.0,
                    lastUpdated: DateTime.now(),
                    isSelf: false,
                  );
                }
              }

              final allPeersList = mergedPeers.values.toList();

              return Column(
                children: [
                  // Filter Chips Bar
                  Container(
                    color: chatTheme.appBarBg,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', chatTheme),
                          const SizedBox(width: 8),
                          _buildFilterChip('Unread', chatTheme),
                          const SizedBox(width: 8),
                          _buildFilterChip('Groups', chatTheme),
                          const SizedBox(width: 8),
                          _buildFilterChip('Nearby Nodes', chatTheme),
                        ],
                      ),
                    ),
                  ),

                  // Divider between header and chats
                  Divider(height: 1, color: chatTheme.dividerColor),

                  // Conversation List
                  Expanded(
                    child: allPeersList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 56,
                                    color: chatTheme.secondaryText.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No conversations yet',
                                    style: TextStyle(
                                      color: chatTheme.primaryText,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap the button below to start a secure chat with a discovered node.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: chatTheme.secondaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: allPeersList.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              thickness: 0.6,
                              indent: 76,
                              color: chatTheme.dividerColor,
                            ),
                            itemBuilder: (context, index) {
                              final peer = allPeersList[index];

                              return FutureBuilder<Map<String, dynamic>>(
                                future: () async {
                                  final last = await LocalChatDb.instance.getLastMessage(peer.id);
                                  final unread = await LocalChatDb.instance.getUnreadCount(peer.id);
                                  return {'last': last, 'unread': unread};
                                }(),
                                builder: (context, asyncSnap) {
                                  final lastMsg = asyncSnap.data?['last'] as ChatMessage?;
                                  final unreadCount = asyncSnap.data?['unread'] as int? ?? 0;

                                  // Apply Filter Chips
                                  if (_selectedFilter == 'Unread' && unreadCount == 0) {
                                    return const SizedBox.shrink();
                                  }
                                  if (_selectedFilter == 'Nearby Nodes' &&
                                      peer.status.toLowerCase() != 'online' &&
                                      peer.status.toLowerCase() != 'active') {
                                    return const SizedBox.shrink();
                                  }

                                  // Apply Search Filter
                                  if (_searchQuery.isNotEmpty) {
                                    final matchName = peer.name.toLowerCase().contains(_searchQuery);
                                    final matchMsg = lastMsg?.decryptedText.toLowerCase().contains(_searchQuery) ?? false;
                                    if (!matchName && !matchMsg) {
                                      return const SizedBox.shrink();
                                    }
                                  }

                                  final timestampText = lastMsg != null
                                      ? _formatTimestamp(lastMsg.timestamp)
                                      : '';

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ChatConversationScreen(peerUser: peer),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            // 52px Avatar with status dot
                                            _buildAvatar(peer, chatTheme, 52),
                                            const SizedBox(width: 14),

                                            // Name + Last Message Subtitle
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    peer.name,
                                                    style: TextStyle(
                                                      color: chatTheme.primaryText,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  _buildSubtitle(lastMsg, chatTheme),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            // Timestamp + Unread badge
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  timestampText,
                                                  style: TextStyle(
                                                    color: unreadCount > 0
                                                        ? chatTheme.unreadBadge
                                                        : chatTheme.secondaryText,
                                                    fontSize: 12,
                                                    fontWeight: unreadCount > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                if (unreadCount > 0)
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: chatTheme.unreadBadge,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    constraints: const BoxConstraints(
                                                      minWidth: 20,
                                                      minHeight: 20,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        unreadCount > 99 ? '99+' : '$unreadCount',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  const SizedBox(height: 20),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
      const Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: CallPopupBanner(),
      ),
    ],
  ),
  floatingActionButton: FloatingActionButton(
        heroTag: 'chat_list_fab',
        backgroundColor: chatTheme.primaryAccent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showNewChatDialog(context, chatTheme, connectedNodes, currentUser),
        child: const Icon(Icons.edit_square, size: 22),
      ),
    );
  }

  Widget _buildFilterChip(String label, NodeLinkChatTheme chatTheme) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? chatTheme.chipSelectedBg : chatTheme.chipUnselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : chatTheme.chipBorder,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? chatTheme.chipSelectedText : chatTheme.chipUnselectedText,
          ),
        ),
      ),
    );
  }
}
