import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/nodelink_chat_theme.dart';
import '../../models/chat_message.dart';
import '../../models/node_user.dart';
import '../../providers/node_link_provider.dart';
import '../../services/chat_sync_service.dart';
import '../../services/local_chat_db.dart';
import '../../services/call_service.dart';
import '../call/voice_call_screen.dart';
import '../call/video_call_screen.dart';
import '../call/call_popup_banner.dart';
import 'user_profile_details_screen.dart';

class ChatConversationScreen extends StatefulWidget {
  final NodeUser peerUser;

  const ChatConversationScreen({super.key, required this.peerUser});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isAttachmentMenuOpen = false;
  bool _isEmojiPickerOpen = false;
  bool _isRecordingVoice = false;
  bool _isSending = false;
  int _recordDurationSec = 0;
  Timer? _recordTimer;
  String? _currentlyPlayingPath;
  PlayerState _playerState = PlayerState.stopped;
  int _lastMessageCount = 0;

  final List<String> _quickEmojis = [
    '😊', '😂', '👍', '❤️', '🔥', '🙏', '🚀', '🎉',
    '👋', '✨', '👌', '😎', '🙌', '💯', '📍', '💪'
  ];

  @override
  void initState() {
    super.initState();
    ChatSyncService.activeChatPeerId = widget.peerUser.id;
    _markRead();
    _initAudioPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final myId = context.read<NodeLinkProvider>().currentUser.id;
        ChatSyncService.instance.startInboxListener(myNodeId: myId);
      }
    });
  }

  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
  }

  Future<void> _markRead() async {
    await LocalChatDb.instance.markAllAsRead(widget.peerUser.id);
  }

  @override
  void dispose() {
    if (ChatSyncService.activeChatPeerId == widget.peerUser.id) {
      ChatSyncService.activeChatPeerId = null;
    }
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendTextMessage() async {
    if (_isSending) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
      _isAttachmentMenuOpen = false;
      _isEmojiPickerOpen = false;
    });

    try {
      final provider = context.read<NodeLinkProvider>();
      final myUser = provider.currentUser;

      final msg = ChatMessage(
        id: const Uuid().v4(),
        peerNodeId: widget.peerUser.id,
        senderId: myUser.id,
        decryptedText: text,
        messageType: 'text',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        status: 'sending',
        isOutgoing: true,
      );

      await ChatSyncService.instance.sendMessage(
        myNodeId: myUser.id,
        peerNodeId: widget.peerUser.id,
        message: msg,
      );

      _scrollToBottom();
    } catch (e) {
      debugPrint('[Chat] Error sending message: $e');
    } finally {
      if (mounted) {
        _textController.clear();
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendMediaMessage({
    required String type,
    String? mediaPath,
    String? mediaDuration,
    String caption = '',
    double? latitude,
    double? longitude,
  }) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _isAttachmentMenuOpen = false;
      _isEmojiPickerOpen = false;
    });

    try {
      final provider = context.read<NodeLinkProvider>();
      final myUser = provider.currentUser;

      final msg = ChatMessage(
        id: const Uuid().v4(),
        peerNodeId: widget.peerUser.id,
        senderId: myUser.id,
        decryptedText: caption,
        messageType: type,
        mediaPath: mediaPath,
        mediaDuration: mediaDuration,
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        status: 'sending',
        isOutgoing: true,
      );

      await ChatSyncService.instance.sendMessage(
        myNodeId: myUser.id,
        peerNodeId: widget.peerUser.id,
        message: msg,
      );

      _scrollToBottom();
    } catch (e) {
      debugPrint('[Chat] Error sending media message: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 70);
      if (picked != null) {
        await _sendMediaMessage(
          type: 'image',
          mediaPath: picked.path,
          caption: '',
        );
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        await _sendMediaMessage(
          type: 'video',
          mediaPath: picked.path,
          caption: 'Video',
        );
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  Future<void> _sendLiveLocation() async {
    try {
      setState(() => _isAttachmentMenuOpen = false);
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      await _sendMediaMessage(
        type: 'location',
        latitude: position.latitude,
        longitude: position.longitude,
        caption: 'Live GPS Coordinates',
      );
    } catch (e) {
      debugPrint('Location capture error: $e');
      if (!mounted) return;
      final myUser = context.read<NodeLinkProvider>().currentUser;
      await _sendMediaMessage(
        type: 'location',
        latitude: myUser.latitude,
        longitude: myUser.longitude,
        caption: 'Live GPS Coordinates',
      );
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecordingVoice) {
      // Stop recording and send
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() => _isRecordingVoice = false);

      if (path != null && _recordDurationSec > 0) {
        final minutes = _recordDurationSec ~/ 60;
        final seconds = _recordDurationSec % 60;
        final durStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

        await _sendMediaMessage(
          type: 'voice',
          mediaPath: path,
          mediaDuration: durStr,
          caption: '',
        );
      }
      _recordDurationSec = 0;
    } else {
      // Start recording
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required for voice notes.')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
        path: filePath,
      );

      setState(() {
        _isRecordingVoice = true;
        _recordDurationSec = 0;
        _isAttachmentMenuOpen = false;
        _isEmojiPickerOpen = false;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordDurationSec++);
      });
    }
  }

  Future<void> _toggleAudioPlayback(String? path) async {
    if (path == null || path.isEmpty) return;

    if (_currentlyPlayingPath == path && _playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      _currentlyPlayingPath = path;
      if (path.startsWith('http')) {
        await _audioPlayer.play(UrlSource(path));
      } else {
        await _audioPlayer.play(DeviceFileSource(path));
      }
    }
  }

  void _showMediaViewer(String mediaPath, String caption) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: mediaPath.startsWith('http')
                  ? Image.network(mediaPath, fit: BoxFit.contain)
                  : Image.file(File(mediaPath), fit: BoxFit.contain),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            if (caption.isNotEmpty)
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    caption,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    textAlign: TextAlign.center,
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
    final chatTheme = NodeLinkChatTheme.of(context);
    final peer = widget.peerUser;
    final isOnline = peer.status.toLowerCase() == 'online' || peer.status.toLowerCase() == 'active';

    return Scaffold(
      backgroundColor: chatTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: chatTheme.appBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: chatTheme.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserProfileDetailsScreen(peerUser: peer),
              ),
            );
          },
          child: Row(
            children: [
              _buildAppBarAvatar(peer, chatTheme),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 2),
                    Text(
                      isOnline ? 'online' : 'Node ID: ${peer.id}',
                      style: TextStyle(
                        color: isOnline ? chatTheme.onlineGreen : chatTheme.secondaryText,
                        fontSize: 12,
                        fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.videocam_rounded, color: chatTheme.primaryText),
            onPressed: () async {
              final provider = context.read<NodeLinkProvider>();
              final myUser = provider.currentUser;
              await CallService.instance.startCall(
                peerNodeId: peer.id,
                peerName: peer.name,
                peerAvatar: peer.avatarUrl,
                peerPhone: peer.phoneNumber,
                isVideo: true,
                myNodeId: myUser.id,
                myName: myUser.name,
                myAvatar: myUser.avatarUrl,
              );
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VideoCallScreen()),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.call_rounded, color: chatTheme.primaryText),
            onPressed: () async {
              final provider = context.read<NodeLinkProvider>();
              final myUser = provider.currentUser;
              await CallService.instance.startCall(
                peerNodeId: peer.id,
                peerName: peer.name,
                peerAvatar: peer.avatarUrl,
                peerPhone: peer.phoneNumber,
                isVideo: false,
                myNodeId: myUser.id,
                myName: myUser.name,
                myAvatar: myUser.avatarUrl,
              );
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VoiceCallScreen()),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: chatTheme.primaryText),
            color: chatTheme.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'view_contact') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileDetailsScreen(peerUser: peer),
                  ),
                );
              } else if (value == 'clear_chat') {
                await LocalChatDb.instance.clearChat(peer.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat history cleared.')),
                  );
                }
              } else if (value == 'mute') {
                final isMuted = await LocalChatDb.instance.isMuted(peer.id);
                await LocalChatDb.instance.setMuted(peer.id, !isMuted);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(!isMuted ? 'Muted notifications' : 'Unmuted')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'view_contact',
                child: Text('View contact', style: TextStyle(color: chatTheme.primaryText)),
              ),
              PopupMenuItem(
                value: 'clear_chat',
                child: Text('Clear chat', style: TextStyle(color: chatTheme.primaryText)),
              ),
              PopupMenuItem(
                value: 'mute',
                child: Text('Mute notifications', style: TextStyle(color: chatTheme.primaryText)),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Subtle WhatsApp-style Geometric Doodle Wallpaper
          Positioned.fill(
            child: CustomPaint(
              painter: _WhatsAppWallpaperPainter(isLight: chatTheme.isLight),
            ),
          ),

          // Main Column: Messages + Input Bar
          Column(
            children: [
              // Reactive UI Message Stream directly from Local SQLite Database
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: LocalChatDb.instance.watchMessages(peer.id),
                  builder: (context, snapshot) {
                    final messages = snapshot.data ?? [];

                    // Auto-scroll when new messages arrive/change
                    if (messages.length != _lastMessageCount) {
                      _lastMessageCount = messages.length;
                      _scrollToBottom();
                    }

                    if (messages.isEmpty) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: chatTheme.isLight
                                ? Colors.white.withValues(alpha: 0.9)
                                : const Color(0xFF1F2C34).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: chatTheme.dividerColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded, size: 16, color: chatTheme.primaryAccent),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Messages and calls are end-to-end encrypted. No one outside of this chat can read them.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: chatTheme.secondaryText,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return _buildMessageBubble(msg, chatTheme);
                      },
                    );
                  },
                ),
              ),

              // Quick Emoji Bar (if toggled)
              if (_isEmojiPickerOpen) _buildQuickEmojiBar(chatTheme),

              // WhatsApp Bottom Input Bar
              _buildBottomInputBar(chatTheme),
            ],
          ),

          // Floating Attachment Menu Overlay
          if (_isAttachmentMenuOpen)
            Positioned(
              left: 16,
              bottom: 74,
              child: _buildAttachmentMenu(chatTheme),
            ),

          // Heads-up Incoming Call Popup Banner
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CallPopupBanner(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarAvatar(NodeUser peer, NodeLinkChatTheme chatTheme) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: peer.profilePicUrl != null && peer.profilePicUrl!.startsWith('http')
            ? Image.network(peer.profilePicUrl!, fit: BoxFit.cover)
            : (peer.avatarPath.isNotEmpty && !peer.avatarPath.startsWith('http')
                ? Image.asset(
                    peer.avatarPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildFallbackInitial(peer, chatTheme),
                  )
                : _buildFallbackInitial(peer, chatTheme)),
      ),
    );
  }

  Widget _buildFallbackInitial(NodeUser peer, NodeLinkChatTheme chatTheme) {
    return Container(
      color: chatTheme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF233138),
      alignment: Alignment.center,
      child: Text(
        peer.name.isNotEmpty ? peer.name[0].toUpperCase() : 'N',
        style: TextStyle(
          color: chatTheme.primaryAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, NodeLinkChatTheme chatTheme) {
    final isOutgoing = msg.isOutgoing;
    final timeStr = DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(msg.timestamp));

    // Asymmetric Bubble Corners
    final borderRadius = isOutgoing
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
            topRight: Radius.circular(0),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
            topLeft: Radius.circular(0),
          );

    final bubbleBg = isOutgoing ? chatTheme.outgoingBubble : chatTheme.incomingBubble;

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: chatTheme.isLight ? 0.05 : 0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBubbleContent(msg, chatTheme),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: chatTheme.secondaryText,
                  ),
                ),
                if (isOutgoing) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.status == 'sending'
                        ? Icons.access_time_rounded
                        : (msg.status == 'read' ? Icons.done_all : Icons.done),
                    size: 15,
                    color: msg.status == 'read'
                        ? chatTheme.readTickBlue
                        : chatTheme.secondaryText,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleContent(ChatMessage msg, NodeLinkChatTheme chatTheme) {
    switch (msg.messageType) {
      case 'image':
      case 'video':
        return _buildImageVideoContent(msg, chatTheme);
      case 'voice':
      case 'audio':
        return _buildVoiceContent(msg, chatTheme);
      case 'location':
        return _buildLocationContent(msg, chatTheme);
      case 'document':
        return _buildDocumentContent(msg, chatTheme);
      case 'text':
      default:
        return Text(
          msg.decryptedText,
          style: TextStyle(
            color: chatTheme.primaryText,
            fontSize: 15.5,
            height: 1.35,
          ),
        );
    }
  }

  Widget _buildImageVideoContent(ChatMessage msg, NodeLinkChatTheme chatTheme) {
    final path = msg.mediaPath ?? '';
    final isVideo = msg.messageType == 'video';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showMediaViewer(path, msg.decryptedText),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 190,
                  width: double.infinity,
                  color: chatTheme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E2A30),
                  child: path.startsWith('http')
                      ? Image.network(path, fit: BoxFit.cover)
                      : (File(path).existsSync()
                          ? Image.file(File(path), fit: BoxFit.cover)
                          : const Center(child: Icon(Icons.broken_image, size: 40))),
                ),
                if (isVideo)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                  ),
              ],
            ),
          ),
        ),
        if (msg.decryptedText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            msg.decryptedText,
            style: TextStyle(color: chatTheme.primaryText, fontSize: 14.5),
          ),
        ],
      ],
    );
  }

  Widget _buildVoiceContent(ChatMessage msg, NodeLinkChatTheme chatTheme) {
    final isPlaying = _currentlyPlayingPath == msg.mediaPath && _playerState == PlayerState.playing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _toggleAudioPlayback(msg.mediaPath),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: chatTheme.primaryAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Mini Avatar
        ClipOval(
          child: SizedBox(
            width: 26,
            height: 26,
            child: _buildFallbackInitial(widget.peerUser, chatTheme),
          ),
        ),
        const SizedBox(width: 8),

        // Waveform Dots Simulation
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: List.generate(18, (i) {
                final height = (sin(i * 0.8) * 6 + 9).clamp(4.0, 16.0);
                return Container(
                  width: 3,
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 1.2),
                  decoration: BoxDecoration(
                    color: i < 6 && isPlaying ? chatTheme.primaryAccent : chatTheme.secondaryText,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              msg.mediaDuration ?? '0:24',
              style: TextStyle(fontSize: 11, color: chatTheme.secondaryText),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationContent(ChatMessage msg, NodeLinkChatTheme chatTheme) {
    final lat = msg.latitude ?? 6.9271;
    final lng = msg.longitude ?? 79.8612;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: chatTheme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E2A30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.map_rounded, size: 54, color: chatTheme.primaryAccent.withValues(alpha: 0.5)),
              Positioned(
                child: Icon(Icons.location_on, size: 34, color: chatTheme.dangerRed),
              ),
              Positioned(
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
            // User can see marker on main map
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_rounded, size: 18, color: chatTheme.primaryAccent),
                const SizedBox(width: 6),
                Text(
                  'View on Live Radar',
                  style: TextStyle(
                    color: chatTheme.primaryAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentContent(ChatMessage msg, NodeLinkChatTheme chatTheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: chatTheme.primaryAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.insert_drive_file_rounded, color: chatTheme.primaryAccent, size: 28),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.decryptedText.isNotEmpty ? msg.decryptedText : 'Document.pdf',
              style: TextStyle(
                color: chatTheme.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Encrypted PDF Document',
              style: TextStyle(color: chatTheme.secondaryText, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickEmojiBar(NodeLinkChatTheme chatTheme) {
    return Container(
      color: chatTheme.appBarBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickEmojis.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final emoji = _quickEmojis[i];
          return GestureDetector(
            onTap: () {
              _textController.text += emoji;
            },
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          );
        },
      ),
    );
  }

  Widget _buildBottomInputBar(NodeLinkChatTheme chatTheme) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Left Pill Container (24px radius)
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: chatTheme.inputFieldBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: chatTheme.isLight ? 0.06 : 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _isRecordingVoice
                  ? Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(Icons.mic, color: chatTheme.dangerRed, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Recording... ${_recordDurationSec}s',
                          style: TextStyle(
                            color: chatTheme.dangerRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            _audioRecorder.stop();
                            _recordTimer?.cancel();
                            setState(() => _isRecordingVoice = false);
                          },
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: chatTheme.secondaryText),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Emoji Toggle
                        IconButton(
                          icon: Icon(
                            _isEmojiPickerOpen
                                ? Icons.keyboard_alt_outlined
                                : Icons.sentiment_satisfied_alt_outlined,
                            color: chatTheme.iconMuted,
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _isEmojiPickerOpen = !_isEmojiPickerOpen;
                              _isAttachmentMenuOpen = false;
                            });
                          },
                        ),

                        // Message Text Field
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: TextStyle(color: chatTheme.primaryText, fontSize: 15.5),
                            decoration: InputDecoration(
                              hintText: 'Message',
                              hintStyle: TextStyle(color: chatTheme.secondaryText, fontSize: 15.5),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onTap: () {
                              setState(() {
                                _isEmojiPickerOpen = false;
                                _isAttachmentMenuOpen = false;
                              });
                            },
                          ),
                        ),

                        // Attachment Paperclip
                        IconButton(
                          icon: Icon(
                            Icons.attach_file,
                            color: _isAttachmentMenuOpen
                                ? chatTheme.primaryAccent
                                : chatTheme.iconMuted,
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
                              _isEmojiPickerOpen = false;
                            });
                          },
                        ),

                        // Camera Quick Icon
                        IconButton(
                          icon: Icon(Icons.camera_alt_outlined, color: chatTheme.iconMuted, size: 24),
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(width: 8),

          // Right Circular Action Button (Mic or Send)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;

              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isRecordingVoice ? chatTheme.dangerRed : chatTheme.primaryAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    hasText
                        ? Icons.send_rounded
                        : (_isRecordingVoice ? Icons.stop_rounded : Icons.mic_rounded),
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () {
                    if (hasText) {
                      _sendTextMessage();
                    } else {
                      _toggleVoiceRecording();
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentMenu(NodeLinkChatTheme chatTheme) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: chatTheme.attachmentMenuBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: chatTheme.isLight ? 0.12 : 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _buildAttachmentItem(
              icon: Icons.image_rounded,
              color: const Color(0xFF9333EA), // Purple
              label: 'Gallery',
              onTap: () => _pickImage(ImageSource.gallery),
              chatTheme: chatTheme,
            ),
            _buildAttachmentItem(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFFE11D48), // Rose
              label: 'Camera',
              onTap: () => _pickImage(ImageSource.camera),
              chatTheme: chatTheme,
            ),
            _buildAttachmentItem(
              icon: Icons.videocam_rounded,
              color: const Color(0xFFF59E0B), // Amber
              label: 'Video',
              onTap: _pickVideo,
              chatTheme: chatTheme,
            ),
            _buildAttachmentItem(
              icon: Icons.mic_rounded,
              color: const Color(0xFFF97316), // Orange
              label: 'Audio',
              onTap: _toggleVoiceRecording,
              chatTheme: chatTheme,
            ),
            _buildAttachmentItem(
              icon: Icons.location_on_rounded,
              color: const Color(0xFF10B981), // Green
              label: 'Live Location',
              onTap: _sendLiveLocation,
              chatTheme: chatTheme,
            ),
            _buildAttachmentItem(
              icon: Icons.insert_drive_file_rounded,
              color: const Color(0xFF0284C7), // Blue
              label: 'Document',
              onTap: () async {
                await _sendMediaMessage(
                  type: 'document',
                  caption: 'Project_Alpha_Specs.pdf',
                );
              },
              chatTheme: chatTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    required NodeLinkChatTheme chatTheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: chatTheme.primaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom WhatsApp wallpaper painter for subtle geometric line doodles
class _WhatsAppWallpaperPainter extends CustomPainter {
  final bool isLight;
  _WhatsAppWallpaperPainter({required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isLight ? const Color(0xFFCBD5E1) : const Color(0xFF16222A)).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const step = 60.0;
    for (double x = 10; x < size.width; x += step) {
      for (double y = 10; y < size.height; y += step) {
        // Draw miniature soft geometric glyphs
        if ((x + y) % (step * 2) == 0) {
          canvas.drawCircle(Offset(x, y), 6, paint);
        } else {
          canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 8, height: 8), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WhatsAppWallpaperPainter oldDelegate) {
    return oldDelegate.isLight != isLight;
  }
}
