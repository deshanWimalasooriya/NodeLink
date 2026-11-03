import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nodelink_chat_theme.dart';
import '../../providers/node_link_provider.dart';
import '../../services/call_service.dart';
import 'video_call_screen.dart';
import 'voice_call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final String peerId;
  final String peerName;
  final String? peerAvatar;
  final String peerPhone;
  final String peerDistance;
  final bool isVideo;

  const IncomingCallScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
    this.peerPhone = '',
    this.peerDistance = '0.4 km away',
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();
    final chatTheme = NodeLinkChatTheme.of(context);
    final isDark = !chatTheme.isLight;
    final myId = provider.currentUser.id;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          CallService.instance.declineCall(myNodeId: myId);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: chatTheme.scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // 1. Top E2EE Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1F2C34)
                      : Colors.black.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: chatTheme.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'End-to-end encrypted',
                      style: TextStyle(
                        fontSize: 12,
                        color: chatTheme.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 2. Call Type Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isVideo ? 'NodeLink Video Call' : 'NodeLink Voice Call',
                  style: const TextStyle(
                    color: Color(0xFF0C4A6E),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const Spacer(),

              // 3. Center Caller Avatar
              _buildAvatar(chatTheme),
              const SizedBox(height: 20),

              // 4. Caller Name
              Text(
                peerName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: chatTheme.primaryText,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // 5. Mesh Distance & Subtitle
              Text(
                'Incoming mesh call • $peerDistance',
                style: TextStyle(
                  fontSize: 15,
                  color: chatTheme.secondaryText,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(),

              // 6. Quick Action Pills Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPillButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Reply with message',
                      chatTheme: chatTheme,
                      onTap: () {
                        CallService.instance.declineCall(myNodeId: myId);
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 14),
                    _buildPillButton(
                      icon: Icons.access_time_rounded,
                      label: 'Remind me',
                      chatTheme: chatTheme,
                      onTap: () {
                        CallService.instance.declineCall(myNodeId: myId);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 7. Accept & Decline Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Decline Button
                    _buildCallActionButton(
                      icon: Icons.call_end_rounded,
                      label: 'Decline',
                      color: const Color(0xFFEF4444),
                      textColor: chatTheme.primaryText,
                      onPressed: () async {
                        await CallService.instance.declineCall(myNodeId: myId);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),

                    // Accept Button
                    _buildCallActionButton(
                      icon: Icons.call_rounded,
                      label: 'Accept',
                      color: const Color(0xFF00A884),
                      textColor: chatTheme.primaryText,
                      onPressed: () async {
                        await CallService.instance.acceptCall(myNodeId: myId);
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => isVideo
                                  ? const VideoCallScreen()
                                  : const VoiceCallScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(NodeLinkChatTheme chatTheme) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: chatTheme.cardBg,
        border: Border.all(
          color: chatTheme.primaryAccent.withAlpha(60),
          width: 3,
        ),
      ),
      child: ClipOval(
        child: peerAvatar != null && peerAvatar!.isNotEmpty
            ? Image.network(
                peerAvatar!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(chatTheme),
              )
            : _buildFallbackAvatar(chatTheme),
      ),
    );
  }

  Widget _buildFallbackAvatar(NodeLinkChatTheme chatTheme) {
    final initials = peerName.isNotEmpty ? peerName[0].toUpperCase() : 'N';
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 54,
          fontWeight: FontWeight.bold,
          color: chatTheme.primaryAccent,
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required IconData icon,
    required String label,
    required NodeLinkChatTheme chatTheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: chatTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chatTheme.dividerColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: chatTheme.secondaryText),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: chatTheme.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(80),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
