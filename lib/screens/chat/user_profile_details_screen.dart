import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nodelink_chat_theme.dart';
import '../../models/chat_message.dart';
import '../../models/node_user.dart';
import '../../providers/node_link_provider.dart';
import '../../services/e2ee_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/local_chat_db.dart';
import '../../services/call_service.dart';
import '../call/voice_call_screen.dart';
import '../call/video_call_screen.dart';

class UserProfileDetailsScreen extends StatefulWidget {
  final NodeUser peerUser;

  const UserProfileDetailsScreen({super.key, required this.peerUser});

  @override
  State<UserProfileDetailsScreen> createState() => _UserProfileDetailsScreenState();
}

class _UserProfileDetailsScreenState extends State<UserProfileDetailsScreen> {
  bool _isMuted = false;
  String? _peerPublicKeyPem;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndKey();
  }

  Future<void> _loadSettingsAndKey() async {
    final muted = await LocalChatDb.instance.isMuted(widget.peerUser.id);
    final pubKey = await E2EEService.fetchPeerPublicKey(widget.peerUser.id);

    if (mounted) {
      setState(() {
        _isMuted = muted;
        _peerPublicKeyPem = pubKey;
      });
    }
  }

  String _calculateDistance(NodeUser currentUser, NodeUser peerUser) {
    if ((currentUser.latitude == 0 && currentUser.longitude == 0) ||
        (peerUser.latitude == 0 && peerUser.longitude == 0)) {
      return 'Nearby';
    }
    final meters = Geolocator.distanceBetween(
      currentUser.latitude,
      currentUser.longitude,
      peerUser.latitude,
      peerUser.longitude,
    );
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m away';
    } else {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(1)} km away';
    }
  }

  void _showSecurityModal(BuildContext context, NodeLinkChatTheme chatTheme) {
    final fingerprint = E2EEService.getPublicKeyFingerprint(_peerPublicKeyPem);

    showModalBottomSheet(
      context: context,
      backgroundColor: chatTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: chatTheme.primaryAccent, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Encryption / Node Security',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: chatTheme.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Messages and calls with ${widget.peerUser.name} are encrypted with 2048-bit RSA and AES-256 session keys. Verify the security fingerprint below:',
                  style: TextStyle(
                    fontSize: 13,
                    color: chatTheme.secondaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: chatTheme.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1F2C34),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: chatTheme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RSA Public Key Fingerprint',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: chatTheme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        fingerprint,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: chatTheme.primaryAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: chatTheme.onlineGreen, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Verified Decentralized Node Protocol',
                      style: TextStyle(
                        color: chatTheme.primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: chatTheme.primaryAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMediaViewer(String mediaPath) {
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
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearChat(NodeLinkChatTheme chatTheme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: chatTheme.cardBg,
        title: Text('Clear Chat History?', style: TextStyle(color: chatTheme.primaryText)),
        content: Text(
          'This will permanently delete all decrypted messages with ${widget.peerUser.name} stored on this device.',
          style: TextStyle(color: chatTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: chatTheme.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Clear', style: TextStyle(color: chatTheme.dangerRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await LocalChatDb.instance.clearChat(widget.peerUser.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat history cleared.')),
        );
      }
    }
  }

  Future<void> _confirmRemoveConnection(NodeLinkChatTheme chatTheme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: chatTheme.cardBg,
        title: Text('Remove Node Connection?', style: TextStyle(color: chatTheme.primaryText)),
        content: Text(
          'Remove ${widget.peerUser.name} from active mesh neighbors? You will no longer track mutual live coordinates.',
          style: TextStyle(color: chatTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: chatTheme.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove', style: TextStyle(color: chatTheme.dangerRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<NodeLinkProvider>();
      final myId = provider.currentUser.id;

      provider.disconnectDevice(widget.peerUser.id);
      await FirebaseSyncService.disconnectNodes(myId, widget.peerUser.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Disconnected ${widget.peerUser.name}.')),
        );
        // Pop back to home screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatTheme = NodeLinkChatTheme.of(context);
    final provider = context.watch<NodeLinkProvider>();
    final currentUser = provider.currentUser;
    final peer = widget.peerUser;
    final distanceStr = _calculateDistance(currentUser, peer);
    final commonGroups = provider.groups.where((g) => g.containsMember(peer.id)).toList();

    return Scaffold(
      backgroundColor: chatTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: chatTheme.appBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: chatTheme.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Top Profile Card
            Container(
              width: double.infinity,
              color: chatTheme.cardBg,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  // 110px Centered Circle Avatar
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: peer.profilePicUrl != null && peer.profilePicUrl!.startsWith('http')
                          ? Image.network(peer.profilePicUrl!, fit: BoxFit.cover)
                          : (peer.avatarPath.isNotEmpty && !peer.avatarPath.startsWith('http')
                              ? Image.asset(
                                  peer.avatarPath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildFallbackInitial(peer, chatTheme, 110),
                                )
                              : _buildFallbackInitial(peer, chatTheme, 110)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bold 22px Contact Name
                  Text(
                    peer.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: chatTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Phone number
                  Text(
                    peer.phone.isNotEmpty ? peer.phone : '+94 76 103 1853',
                    style: TextStyle(
                      fontSize: 14,
                      color: chatTheme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Node ID Pill Badge with Copy Button
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: peer.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied Node ID: ${peer.id}'),
                          backgroundColor: chatTheme.primaryAccent,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: chatTheme.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1F2C34),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: chatTheme.dividerColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Node ID: ${peer.id}',
                            style: TextStyle(
                              fontSize: 12,
                              color: chatTheme.secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.copy_rounded, size: 14, color: chatTheme.secondaryText),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 2. Action Buttons Row (3 equal-width flat rounded cards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.volume_up_rounded,
                      label: 'Audio',
                      chatTheme: chatTheme,
                      onTap: () async {
                        final myUser = currentUser;
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
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.videocam_rounded,
                      label: 'Video',
                      chatTheme: chatTheme,
                      onTap: () async {
                        final myUser = currentUser;
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
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.location_on_rounded,
                      label: 'Locate on Map',
                      chatTheme: chatTheme,
                      onTap: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 3. Status/About Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: chatTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: chatTheme.dividerColor, width: 0.8),
              ),
              child: Text(
                'Status: Active on mesh • $distanceStr',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: chatTheme.primaryText,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 4. Media, Links, and Docs Card
            FutureBuilder<List<ChatMessage>>(
              future: LocalChatDb.instance.getMediaMessages(peer.id),
              builder: (context, snapshot) {
                final mediaList = snapshot.data ?? [];

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: chatTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: chatTheme.dividerColor, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Media, links, and docs',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: chatTheme.primaryText,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${mediaList.length}',
                                style: TextStyle(fontSize: 14, color: chatTheme.secondaryText),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right, size: 20, color: chatTheme.secondaryText),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (mediaList.isEmpty)
                        Text(
                          'No media files shared yet.',
                          style: TextStyle(fontSize: 13, color: chatTheme.secondaryText),
                        )
                      else
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: mediaList.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final msg = mediaList[i];
                              final path = msg.mediaPath ?? '';
                              final isVideo = msg.messageType == 'video';

                              return GestureDetector(
                                onTap: () {
                                  if (path.isNotEmpty) _showMediaViewer(path);
                                },
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: chatTheme.isLight
                                        ? const Color(0xFFE2E8F0)
                                        : const Color(0xFF1E2A30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (path.startsWith('http'))
                                          Image.network(path, fit: BoxFit.cover, width: 72, height: 72)
                                        else if (File(path).existsSync())
                                          Image.file(File(path), fit: BoxFit.cover, width: 72, height: 72)
                                        else
                                          Icon(Icons.image_rounded, color: chatTheme.secondaryText),
                                        if (isVideo)
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // 5. Settings Card (Mute + Encryption Info)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: chatTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: chatTheme.dividerColor, width: 0.8),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: chatTheme.primaryText,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text(
                      'Mute notifications',
                      style: TextStyle(color: chatTheme.primaryText, fontSize: 14.5),
                    ),
                    trailing: Switch.adaptive(
                      value: _isMuted,
                      activeTrackColor: chatTheme.primaryAccent,
                      onChanged: (val) async {
                        setState(() => _isMuted = val);
                        await LocalChatDb.instance.setMuted(peer.id, val);
                      },
                    ),
                  ),
                  Divider(height: 1, indent: 16, color: chatTheme.dividerColor),
                  ListTile(
                    title: Text(
                      'Encryption / Node Security',
                      style: TextStyle(color: chatTheme.primaryText, fontSize: 14.5),
                    ),
                    trailing: Icon(Icons.chevron_right, color: chatTheme.secondaryText),
                    onTap: () => _showSecurityModal(context, chatTheme),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 6. Common Groups Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: chatTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: chatTheme.dividerColor, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Common Groups',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: chatTheme.primaryText,
                        ),
                      ),
                      Text(
                        '${commonGroups.length} groups in common',
                        style: TextStyle(fontSize: 13, color: chatTheme.secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (commonGroups.isEmpty)
                    Text(
                      'No shared groups.',
                      style: TextStyle(fontSize: 13, color: chatTheme.secondaryText),
                    )
                  else
                    ...commonGroups.map((g) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: chatTheme.primaryAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.group_rounded, color: chatTheme.primaryAccent, size: 22),
                        ),
                        title: Text(
                          g.name,
                          style: TextStyle(color: chatTheme.primaryText, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${g.members.length} members',
                          style: TextStyle(color: chatTheme.secondaryText, fontSize: 12),
                        ),
                        trailing: Icon(Icons.chevron_right, color: chatTheme.secondaryText),
                      );
                    }),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 7. Danger Zone Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: chatTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: chatTheme.dividerColor, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
                    child: Text(
                      'Danger Zone',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: chatTheme.primaryText,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.block_rounded, color: chatTheme.dangerRed),
                    title: Text(
                      'Block ${peer.name}',
                      style: TextStyle(color: chatTheme.dangerRed, fontWeight: FontWeight.w600),
                    ),
                    onTap: () => _confirmClearChat(chatTheme),
                  ),
                  Divider(height: 1, indent: 56, color: chatTheme.dividerColor),
                  ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: chatTheme.dangerRed),
                    title: Text(
                      'Remove Node Connection',
                      style: TextStyle(color: chatTheme.dangerRed, fontWeight: FontWeight.w600),
                    ),
                    onTap: () => _confirmRemoveConnection(chatTheme),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackInitial(NodeUser peer, NodeLinkChatTheme chatTheme, double size) {
    return Container(
      color: chatTheme.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF233138),
      alignment: Alignment.center,
      child: Text(
        peer.name.isNotEmpty ? peer.name[0].toUpperCase() : 'N',
        style: TextStyle(
          color: chatTheme.primaryAccent,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required NodeLinkChatTheme chatTheme,
    required VoidCallback onTap,
  }) {
    return Material(
      color: chatTheme.actionCardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: chatTheme.dividerColor, width: 0.8),
          ),
          child: Column(
            children: [
              Icon(icon, color: chatTheme.primaryAccent, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: chatTheme.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
