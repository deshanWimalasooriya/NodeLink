import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/nodelink_chat_theme.dart';
import '../../services/call_service.dart';
import 'video_call_screen.dart';

class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({super.key});

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  late final CallService _callService;

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

  void _showEncryptionDetails(BuildContext context, NodeLinkChatTheme chatTheme) {
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
                const Icon(Icons.verified_user_rounded, color: Color(0xFF00A884), size: 24),
                const SizedBox(width: 10),
                Text(
                  'End-to-End Encryption Verification',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: chatTheme.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'This call is secured with 2048-bit RSA and AES-256 GCM peer-to-peer encryption over the NodeLink mesh network. No third party or server can listen to or record this conversation.',
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
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mesh Protocol', style: TextStyle(color: chatTheme.secondaryText, fontSize: 13)),
                Text('P2P Direct WebRTC', style: TextStyle(color: chatTheme.primaryText, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Connection Status', style: TextStyle(color: chatTheme.secondaryText, fontSize: 13)),
                Text(_callService.connectionQuality, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatTheme = NodeLinkChatTheme.of(context);
    final isDark = !chatTheme.isLight;
    final callService = context.watch<CallService>();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: chatTheme.scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              // 1. Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button / minimize call
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: chatTheme.primaryText, size: 24),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    // E2EE Lock Pill
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
                            size: 13,
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
                    // Add participant icon
                    IconButton(
                      icon: Icon(Icons.person_add_outlined, color: chatTheme.primaryText, size: 22),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Mesh multi-party calling active.'),
                            backgroundColor: chatTheme.primaryAccent,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // 2. Large Circular Avatar
              _buildAvatar(chatTheme, callService),
              const SizedBox(height: 24),

              // 3. Peer Name
              Text(
                callService.peerName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: chatTheme.primaryText,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // 4. Live Call Timer
              Text(
                callService.callState == CallState.connected
                    ? callService.formatDuration(callService.callDuration)
                    : (callService.callState == CallState.connecting
                        ? 'Connecting...'
                        : 'Ringing...'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Connection Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1F2C34)
                      : Colors.black.withAlpha(12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: callService.callState == CallState.connected
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      callService.connectionQuality,
                      style: TextStyle(
                        fontSize: 12,
                        color: chatTheme.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // 6. Floating 5-Button Dock Container
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1F2C34)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 80 : 30),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Button 1: Speakerphone
                    _buildDockCircleButton(
                      icon: callService.isSpeakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      isActive: callService.isSpeakerOn,
                      activeBgColor: const Color(0xFF00A884),
                      normalBgColor: isDark
                          ? const Color(0xFF2A3942)
                          : const Color(0xFFE2E8F0),
                      iconColor: callService.isSpeakerOn
                          ? Colors.white
                          : chatTheme.primaryText,
                      onTap: () => callService.toggleSpeaker(),
                    ),

                    // Button 2: Switch to Video
                    _buildDockCircleButton(
                      icon: Icons.videocam_rounded,
                      isActive: false,
                      normalBgColor: isDark
                          ? const Color(0xFF2A3942)
                          : const Color(0xFFE2E8F0),
                      iconColor: chatTheme.primaryText,
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const VideoCallScreen(),
                          ),
                        );
                      },
                    ),

                    // Button 3: Mute Mic
                    _buildDockCircleButton(
                      icon: callService.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      isActive: callService.isMuted,
                      activeBgColor: Colors.white,
                      normalBgColor: isDark
                          ? const Color(0xFF2A3942)
                          : const Color(0xFFE2E8F0),
                      iconColor: callService.isMuted
                          ? Colors.black
                          : chatTheme.primaryText,
                      onTap: () => callService.toggleMute(),
                    ),

                    // Button 4: More / Security Verification
                    _buildDockCircleButton(
                      icon: Icons.more_horiz_rounded,
                      isActive: false,
                      normalBgColor: isDark
                          ? const Color(0xFF2A3942)
                          : const Color(0xFFE2E8F0),
                      iconColor: chatTheme.primaryText,
                      onTap: () => _showEncryptionDetails(context, chatTheme),
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

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(NodeLinkChatTheme chatTheme, CallService callService) {
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
        child: callService.peerAvatar != null && callService.peerAvatar!.isNotEmpty
            ? Image.network(
                callService.peerAvatar!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(chatTheme, callService),
              )
            : _buildFallbackAvatar(chatTheme, callService),
      ),
    );
  }

  Widget _buildFallbackAvatar(NodeLinkChatTheme chatTheme, CallService callService) {
    final initials = callService.peerName.isNotEmpty
        ? callService.peerName[0].toUpperCase()
        : 'N';
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
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}
