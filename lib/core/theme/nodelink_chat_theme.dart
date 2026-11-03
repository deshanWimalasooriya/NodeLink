import 'package:flutter/material.dart';

/// WhatsApp-style Theme Tokens for NodeLink Chat System.
/// Strictly removes all neon glow, outer box shadows, and sci-fi borders,
/// providing calm, production-ready dark and light mode aesthetics.
class NodeLinkChatTheme {
  final bool isLight;
  final Color scaffoldBg;
  final Color appBarBg;
  final Color cardBg;
  final Color sectionBg;
  final Color attachmentMenuBg;
  final Color outgoingBubble;
  final Color incomingBubble;
  final Color primaryAccent;
  final Color primaryText;
  final Color secondaryText;
  final Color onlineGreen;
  final Color dangerRed;
  final Color dividerColor;
  final Color inputBarBg;
  final Color inputFieldBg;
  final Color readTickBlue;
  final Color unreadBadge;
  final Color chipSelectedBg;
  final Color chipSelectedText;
  final Color chipUnselectedBg;
  final Color chipUnselectedText;
  final Color chipBorder;
  final Color actionCardBg;
  final Color iconMuted;

  const NodeLinkChatTheme._({
    required this.isLight,
    required this.scaffoldBg,
    required this.appBarBg,
    required this.cardBg,
    required this.sectionBg,
    required this.attachmentMenuBg,
    required this.outgoingBubble,
    required this.incomingBubble,
    required this.primaryAccent,
    required this.primaryText,
    required this.secondaryText,
    required this.onlineGreen,
    required this.dangerRed,
    required this.dividerColor,
    required this.inputBarBg,
    required this.inputFieldBg,
    required this.readTickBlue,
    required this.unreadBadge,
    required this.chipSelectedBg,
    required this.chipSelectedText,
    required this.chipUnselectedBg,
    required this.chipUnselectedText,
    required this.chipBorder,
    required this.actionCardBg,
    required this.iconMuted,
  });

  /// Factory resolving theme based on active Brightness
  factory NodeLinkChatTheme.of(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return isLight ? light : dark;
  }

  /// Dark Mode Palette - Matte Charcoal & Deep Slate
  static const NodeLinkChatTheme dark = NodeLinkChatTheme._(
    isLight: false,
    scaffoldBg: Color(0xFF0B141A),
    appBarBg: Color(0xFF1F2C34),
    cardBg: Color(0xFF111B21),
    sectionBg: Color(0xFF111B21),
    attachmentMenuBg: Color(0xFF233138),
    outgoingBubble: Color(0xFF025169), // Calm Ocean Teal
    incomingBubble: Color(0xFF202C33), // Muted Dark Grey
    primaryAccent: Color(0xFF0284C7),  // Calm Sky Blue / #00A884
    primaryText: Color(0xFFFFFFFF),    // Crisp White
    secondaryText: Color(0xFF8696A0),  // Muted Grey
    onlineGreen: Color(0xFF10B981),    // Flat Emerald Green
    dangerRed: Color(0xFFEF4444),      // Soft Flat Red
    dividerColor: Color(0xFF1E2A30),
    inputBarBg: Color(0xFF0B141A),
    inputFieldBg: Color(0xFF1F2C34),
    readTickBlue: Color(0xFF38BDF8),
    unreadBadge: Color(0xFF0284C7),
    chipSelectedBg: Color(0xFF0284C7),
    chipSelectedText: Color(0xFFFFFFFF),
    chipUnselectedBg: Color(0xFF1F2C34),
    chipUnselectedText: Color(0xFF8696A0),
    chipBorder: Color(0xFF2A3942),
    actionCardBg: Color(0xFF1F2C34),
    iconMuted: Color(0xFF8696A0),
  );

  /// Light Mode Palette - Warm Off-White & Clean Slate
  static const NodeLinkChatTheme light = NodeLinkChatTheme._(
    isLight: true,
    scaffoldBg: Color(0xFFF0F2F5),
    appBarBg: Color(0xFFFFFFFF),
    cardBg: Color(0xFFFFFFFF),
    sectionBg: Color(0xFFFFFFFF),
    attachmentMenuBg: Color(0xFFFFFFFF),
    outgoingBubble: Color(0xFFE0F2FE), // Soft Sky Tint / WhatsApp Light Green (#D9FDD3)
    incomingBubble: Color(0xFFFFFFFF), // Clean White Card
    primaryAccent: Color(0xFF0284C7),  // Deep Calm Blue
    primaryText: Color(0xFF111B21),    // Dark Charcoal
    secondaryText: Color(0xFF667781),  // Muted Slate Grey
    onlineGreen: Color(0xFF10B981),    // Flat Emerald Green
    dangerRed: Color(0xFFDC2626),      // Crisp Red
    dividerColor: Color(0xFFE9EDEF),
    inputBarBg: Color(0xFFF0F2F5),
    inputFieldBg: Color(0xFFFFFFFF),
    readTickBlue: Color(0xFF0284C7),
    unreadBadge: Color(0xFF0284C7),
    chipSelectedBg: Color(0xFF0284C7),
    chipSelectedText: Color(0xFFFFFFFF),
    chipUnselectedBg: Color(0xFFFFFFFF),
    chipUnselectedText: Color(0xFF667781),
    chipBorder: Color(0xFFE2E8F0),
    actionCardBg: Color(0xFFFFFFFF),
    iconMuted: Color(0xFF667781),
  );
}

