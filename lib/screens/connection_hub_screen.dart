import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_card.dart';
import '../core/widgets/cyber_button.dart';
import '../core/widgets/cyber_app_bar.dart';
import '../core/widgets/cyber_avatar.dart';
import '../providers/node_link_provider.dart';
import 'qr_scanner_screen.dart';
import 'settings_screen.dart';

enum ConnectionMode {
  nodeId,
  qrCode,
}

class ConnectionHubScreen extends StatefulWidget {
  const ConnectionHubScreen({super.key});

  @override
  State<ConnectionHubScreen> createState() => _ConnectionHubScreenState();
}

class _ConnectionHubScreenState extends State<ConnectionHubScreen> {
  ConnectionMode _mode = ConnectionMode.nodeId;
  final TextEditingController _nodeIdInputController = TextEditingController();

  @override
  void dispose() {
    _nodeIdInputController.dispose();
    super.dispose();
  }

  Future<void> _handleLinkDevice(NodeLinkProvider provider) async {
    final text = _nodeIdInputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 6-digit Node ID'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
      return;
    }

    final success = await provider.linkDevice(text);
    if (mounted && success) {
      _nodeIdInputController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully linked node $text'),
          backgroundColor: AppTheme.neonGreen,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();
    final user = provider.currentUser;
    final connectedNodes = provider.connectedNodes;

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: CyberAppBar(
        titleText: 'NodeLink',
        actions: [
          CyberCircleIconButton(
            icon: Icons.settings_outlined,
            iconSize: 22,
            iconColor: AppTheme.textSecondary,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            // Screen Header Title & Subtitle
            const Text(
              'Connect Nodes',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _mode == ConnectionMode.nodeId
                  ? "Share your Node ID or enter a friend's ID to pair."
                  : 'Share your Node ID or QR code to pair.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 22),

            // Upper Panel: "Your Secure Node ID" Frosted Card
            CyberCard(
              borderRadius: 26,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              borderColor: AppTheme.electricCyan.withValues(alpha: 0.25),
              child: Column(
                children: [
                  // Tabbed Toggle Switch: [Node ID] & [QR Code]
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.deepNavy.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppTheme.electricCyan.withValues(alpha: 0.2),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _mode = ConnectionMode.nodeId),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: _mode == ConnectionMode.nodeId
                                    ? AppTheme.electricCyan
                                    : Colors.transparent,
                                boxShadow: _mode == ConnectionMode.nodeId
                                    ? AppTheme.cyanGlow(blur: 10, opacity: 0.3)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Node ID',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _mode == ConnectionMode.nodeId
                                        ? AppTheme.deepNavy
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _mode = ConnectionMode.qrCode),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: _mode == ConnectionMode.qrCode
                                    ? AppTheme.electricCyan
                                    : Colors.transparent,
                                boxShadow: _mode == ConnectionMode.qrCode
                                    ? AppTheme.cyanGlow(blur: 10, opacity: 0.3)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'QR Code',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _mode == ConnectionMode.qrCode
                                        ? AppTheme.deepNavy
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Your Secure Node ID',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mode Content
                  if (_mode == ConnectionMode.nodeId) ...[
                    // Digital ID Code Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.deepNavy.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.neonGreen.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.neonGreen.withValues(alpha: 0.15),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          user.id,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: AppTheme.neonGreen,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Cyber Neon QR Code
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.deepNavy.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.electricCyan.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.electricCyan.withValues(alpha: 0.2),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: 'nodelink:${user.id}',
                        version: QrVersions.auto,
                        size: 130.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppTheme.electricCyan,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppTheme.neonGreen,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // "🔄 Generate New" button
                  GestureDetector(
                    onTap: () => provider.generateNewNodeId(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppTheme.spaceIndigo.withValues(alpha: 0.6),
                        border: Border.all(
                          color: AppTheme.electricCyan.withValues(alpha: 0.3),
                          width: 1.0,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, size: 16, color: AppTheme.electricCyan),
                          SizedBox(width: 6),
                          Text(
                            'Generate New',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.electricCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Middle Panel: "Link a New Device"
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Link a New Device',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Form Input Field
            TextField(
              controller: _nodeIdInputController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: _mode == ConnectionMode.nodeId
                    ? 'Enter 6-digit Node ID'
                    : 'Enter 6-Digit Node ID or Scan QR',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppTheme.deepNavy.withValues(alpha: 0.6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: AppTheme.electricCyan.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: AppTheme.electricCyan,
                    width: 1.8,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.electricCyan),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Solid Electric Cyan LINK DEVICE Action Button
            CyberButton(
              text: _mode == ConnectionMode.nodeId ? 'LINK DEVICE' : 'LINK DEVICE / SCAN',
              onPressed: () {
                if (_mode == ConnectionMode.qrCode && _nodeIdInputController.text.trim().isEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                  );
                } else {
                  _handleLinkDevice(provider);
                }
              },
            ),

            const SizedBox(height: 26),

            // Bottom Panel: "Active Connections (X)" Scrollable Tiles
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Active Connections (${connectedNodes.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neonGreen,
                ),
              ),
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: connectedNodes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final node = connectedNodes[index];
                final isAlex = node.name == 'Alex';

                return CyberCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // User Photo with CachedNetworkImage and Fallback Placeholder
                      CyberAvatar.fromUser(
                        user: node,
                        size: 44,
                        showStatusBadge: true,
                      ),
                      const SizedBox(width: 14),

                      // Name and Status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (isAlex || node.status == 'Online') ...[
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.neonGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Online',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.neonGreen,
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 11,
                                    color: AppTheme.electricCyan,
                                  ),
                                  const SizedBox(width: 3),
                                  const Text(
                                    'Active',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Translucent Red "Disconnect" Button
                      GestureDetector(
                        onTap: () => provider.disconnectDevice(node.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppTheme.warningRed.withValues(alpha: 0.12),
                            border: Border.all(
                              color: AppTheme.warningRed.withValues(alpha: 0.45),
                              width: 1.0,
                            ),
                          ),
                          child: const Text(
                            'Disconnect',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warningRed,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
