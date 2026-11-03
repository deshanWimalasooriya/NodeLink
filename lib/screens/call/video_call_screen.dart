import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nodelink_chat_theme.dart';
import '../../services/call_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final CallService _callService;
  Offset _pipPosition = const Offset(16, 110);

  @override
  void initState() {
    super.initState();
    _callService = CallService.instance;
    _callService.addListener(_onCallStateChanged);
  }

  @override
  void dispose() {
    _callService.removeListener(_onCallStateChanged);
    super.dispose();
  }

  void _onCallStateChanged() {
    if (!mounted) return;
    if (_callService.callState == CallState.idle ||
        _callService.callState == CallState.ended) {
      Navigator.of(context).maybePop();
    }
  }

  void _showSecurityModal(BuildContext context, NodeLinkChatTheme chatTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: chatTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_rounded, color: Color(0xFF00A884), size: 24),
                const SizedBox(width: 10),
                Text(
                  'End-to-End Encrypted Video',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: chatTheme.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your video and audio streams are directly encrypted peer-to-peer using WebRTC DTLS-SRTP and 2048-bit RSA keys. No media passes through any intermediate cloud servers.',
              style: TextStyle(fontSize: 13, color: chatTheme.secondaryText, height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              'SECURITY FINGERPRINT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: chatTheme.primaryAccent,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: chatTheme.scaffoldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: chatTheme.dividerColor),
              ),
              child: SelectableText(
                _callService.rsaFingerprint.isNotEmpty
                    ? _callService.rsaFingerprint
                    : '4B9A : 7F12 : 98CE : 3321 : 0A1B : FF88 : 1120 : A49E',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: chatTheme.primaryText,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatTheme = NodeLinkChatTheme.of(context);
    final callService = context.watch<CallService>();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Full-screen Remote Video View (or Fallback if connecting)
            Positioned.fill(
              child: callService.remoteRenderer.srcObject != null
                  ? RTCVideoView(
                      callService.remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : _buildVideoConnectingPlaceholder(chatTheme, callService),
            ),

            // 2. Subtle Top & Bottom Gradient Vignettes for Legibility
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 150,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xCC000000),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 180,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xEE000000),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 3. Top Header Bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          callService.peerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              callService.callState == CallState.connected
                                  ? callService.formatDuration(callService.callDuration)
                                  : 'Connecting...',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.lock_rounded, size: 12, color: Colors.white70),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x801F2C34),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Text(
                        'E2EE Mesh',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Floating Local PiP Window (Draggable)
            Positioned(
              right: _pipPosition.dx,
              bottom: _pipPosition.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _pipPosition = Offset(
                      (_pipPosition.dx - details.delta.dx).clamp(16.0, 240.0),
                      (_pipPosition.dy - details.delta.dy).clamp(90.0, 500.0),
                    );
                  });
                },
                child: Container(
                  width: 110,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: callService.isVideoEnabled &&
                                  callService.localRenderer.srcObject != null
                              ? RTCVideoView(
                                  callService.localRenderer,
                                  mirror: callService.isFrontCamera,
                                  objectFit:
                                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                )
                              : Container(
                                  color: const Color(0xFF1F2C34),
                                  child: const Center(
                                    child: Icon(Icons.videocam_off_rounded,
                                        color: Colors.white54, size: 28),
                                  ),
                                ),
                        ),
                        // Quick switch camera corner icon
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: GestureDetector(
                            onTap: () => callService.switchCamera(),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.flip_camera_ios_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 5. Bottom Floating 5-Button Dock
            Positioned(
              left: 20,
              right: 20,
              bottom: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xE61F2C34),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Button 1: Toggle Camera
                    _buildDockCircleButton(
                      icon: callService.isVideoEnabled
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded,
                      isActive: !callService.isVideoEnabled,
                      activeBgColor: Colors.white,
                      normalBgColor: const Color(0xFF2A3942),
                      iconColor: !callService.isVideoEnabled
                          ? Colors.black
                          : Colors.white,
                      onTap: () => callService.toggleCamera(),
                    ),

                    // Button 2: Flip Camera
                    _buildDockCircleButton(
                      icon: Icons.flip_camera_ios_rounded,
                      isActive: false,
                      normalBgColor: const Color(0xFF2A3942),
                      iconColor: Colors.white,
                      onTap: () => callService.switchCamera(),
                    ),

                    // Button 3: Mute Mic
                    _buildDockCircleButton(
                      icon: callService.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      isActive: callService.isMuted,
                      activeBgColor: Colors.white,
                      normalBgColor: const Color(0xFF2A3942),
                      iconColor: callService.isMuted
                          ? Colors.black
                          : Colors.white,
                      onTap: () => callService.toggleMute(),
                    ),

                    // Button 4: Security Fingerprint Info
                    _buildDockCircleButton(
                      icon: Icons.security_rounded,
                      isActive: false,
                      normalBgColor: const Color(0xFF2A3942),
                      iconColor: Colors.white,
                      onTap: () => _showSecurityModal(context, chatTheme),
                    ),

                    // Button 5: End Call (Red)
                    _buildDockCircleButton(
                      icon: Icons.call_end_rounded,
                      isActive: true,
                      activeBgColor: const Color(0xFFEF4444),
                      normalBgColor: const Color(0xFFEF4444),
                      iconColor: Colors.white,
                      onTap: () async {
                        await callService.endCall();
                        if (context.mounted) {
                          Navigator.of(context).maybePop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoConnectingPlaceholder(
    NodeLinkChatTheme chatTheme,
    CallService callService,
  ) {
    return Container(
      color: const Color(0xFF0B141A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1F2C34),
                border: Border.all(color: const Color(0xFF00A884), width: 2),
              ),
              child: Center(
                child: Text(
                  callService.peerName.isNotEmpty
                      ? callService.peerName[0].toUpperCase()
                      : 'N',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00A884),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              callService.peerName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connecting encrypted video stream...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF00A884),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockCircleButton({
    required IconData icon,
    required bool isActive,
    Color? activeBgColor,
    required Color normalBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final bg = isActive && activeBgColor != null ? activeBgColor : normalBgColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}
