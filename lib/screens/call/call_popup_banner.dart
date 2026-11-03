import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nodelink_chat_theme.dart';
import '../../providers/node_link_provider.dart';
import '../../services/call_service.dart';
import 'incoming_call_screen.dart';
import 'video_call_screen.dart';
import 'voice_call_screen.dart';

class CallPopupBanner extends StatelessWidget {
  const CallPopupBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final callService = context.watch<CallService>();

    if (callService.callState != CallState.incomingRinging) {
      return const SizedBox.shrink();
    }

    final provider = context.watch<NodeLinkProvider>();
    final chatTheme = NodeLinkChatTheme.of(context);
    final isDark = !chatTheme.isLight;
    final myId = provider.currentUser.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IncomingCallScreen(
                  peerId: callService.peerId ?? '',
                  peerName: callService.peerName,
                  peerAvatar: callService.peerAvatar,
                  peerPhone: callService.peerPhone,
                  peerDistance: callService.peerDistance,
                  isVideo: callService.isVideo,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1F2C34)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 100 : 40),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: chatTheme.dividerColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // 1. Caller Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: chatTheme.scaffoldBg,
                    border: Border.all(
                      color: const Color(0xFF00A884),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: callService.peerAvatar != null &&
                            callService.peerAvatar!.isNotEmpty
                        ? Image.network(
                            callService.peerAvatar!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(
                                callService.peerName.isNotEmpty
                                    ? callService.peerName[0].toUpperCase()
                                    : 'N',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: chatTheme.primaryAccent,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              callService.peerName.isNotEmpty
                                  ? callService.peerName[0].toUpperCase()
                                  : 'N',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: chatTheme.primaryAccent,
                                fontSize: 18,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Caller Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        callService.peerName,
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
                        '${callService.peerPhone.isNotEmpty ? "${callService.peerPhone} • " : ""}Incoming ${callService.isVideo ? "video" : "voice"} call...',
                        style: TextStyle(
                          color: chatTheme.secondaryText,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // 3. Decline Button (Red)
                GestureDetector(
                  onTap: () => callService.declineCall(myNodeId: myId),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_end_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // 4. Accept Button (Green)
                GestureDetector(
                  onTap: () async {
                    await callService.acceptCall(myNodeId: myId);
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => callService.isVideo
                              ? const VideoCallScreen()
                              : const VoiceCallScreen(),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A884),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
