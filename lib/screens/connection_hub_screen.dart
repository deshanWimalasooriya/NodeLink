import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_card.dart';
import '../core/widgets/cyber_button.dart';
import '../core/widgets/cyber_app_bar.dart';
import '../core/widgets/cyber_avatar.dart';
import '../models/neighbor_group.dart';
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
  int _selectedSection = 0; // 0: Active Connections, 1: Groups
  final TextEditingController _nodeIdInputController = TextEditingController();

  @override
  void dispose() {
    _nodeIdInputController.dispose();
    super.dispose();
  }

  Future<void> _handleLinkDevice(NodeLinkProvider provider) async {
    final text = _nodeIdInputController.text.trim().replaceAll(' ', '').replaceAll('-', '');
    if (text.isEmpty || text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 16-character Node ID'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
      return;
    }

    final success = await provider.linkDevice(text);
    if (mounted && success) {
      _nodeIdInputController.clear();
      final displayId = text.length >= 16
          ? '${text.substring(0, 8)}...${text.substring(text.length - 4)}'
          : text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully linked node $displayId'),
          backgroundColor: AppTheme.neonGreen,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showCreateGroupDialog(BuildContext context, NodeLinkProvider provider) {
    final controller = TextEditingController();
    final isLight = Theme.of(context).brightness == Brightness.light;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isLight ? AppTheme.lightSurface : AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: AppTheme.electricCyan.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        title: Text(
          'Create Neighbor Group',
          style: TextStyle(
            color: isLight ? AppTheme.lightTextPrimary : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organize your neighbors into custom groups (e.g., Family, Work, Friends).',
              style: TextStyle(
                color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Enter group name (e.g. Family)',
                hintStyle: TextStyle(
                  color: isLight ? AppTheme.lightTextMuted : AppTheme.textMuted,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: isLight ? const Color(0xFFF1F5F9) : AppTheme.deepNavy,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isLight ? AppTheme.lightBorder : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.electricCyan, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isLight ? AppTheme.lightTextSecondary : AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.electricCyan,
              foregroundColor: AppTheme.deepNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await provider.createGroup(name);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showAssignMembersSheet(
    BuildContext context,
    NodeLinkProvider provider,
    NeighborGroup group,
  ) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final connectedNodes = provider.connectedNodes;
    final Map<String, bool> currentMembers = Map.from(group.members);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: isLight ? AppTheme.lightSurface : AppTheme.surfaceDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: AppTheme.electricCyan.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isLight ? AppTheme.lightBorder : AppTheme.textMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign to "${group.name}"',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Select neighbors to include in this group',
                            style: TextStyle(
                              fontSize: 12,
                              color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () async {
                          await provider.updateGroupMembers(group.id, currentMembers);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: AppTheme.electricCyan,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: isLight ? AppTheme.lightBorder : Colors.white12),
                  if (connectedNodes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          'No active neighbors to assign yet.\nPair neighbors first to add them to groups.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: connectedNodes.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final node = connectedNodes[index];
                          final isMember = currentMembers[node.id] == true;

                          return CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            activeColor: AppTheme.electricCyan,
                            checkColor: AppTheme.deepNavy,
                            secondary: CyberAvatar.fromUser(user: node, size: 38),
                            title: Text(
                              node.name,
                              style: TextStyle(
                                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              node.id.length >= 16
                                  ? '${node.id.substring(0, 8)}...${node.id.substring(node.id.length - 4)}'
                                  : node.id,
                              style: TextStyle(
                                color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            value: isMember,
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  currentMembers[node.id] = true;
                                } else {
                                  currentMembers.remove(node.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();
    final user = provider.currentUser;
    final connectedNodes = provider.connectedNodes;
    final groups = provider.groups;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? AppTheme.lightBg : AppTheme.deepNavy,
      appBar: CyberAppBar(
        titleText: 'NodeLink',
        actions: [
          CyberCircleIconButton(
            icon: Icons.settings_outlined,
            iconSize: 22,
            iconColor: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
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
            Text(
              'Connect Nodes',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _mode == ConnectionMode.nodeId
                  ? "Share your Node ID or enter a friend's ID to pair."
                  : 'Share your Node ID or QR code to pair.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 22),

            // Upper Panel: "Your Secure Node ID" Frosted Card
            CyberCard(
              borderRadius: 26,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              borderColor: isLight
                  ? AppTheme.lightCardBorder
                  : AppTheme.electricCyan.withValues(alpha: 0.25),
              child: Column(
                children: [
                  // Tabbed Toggle Switch: [Node ID] & [QR Code]
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFFF1F5F9)
                          : AppTheme.deepNavy.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isLight
                            ? AppTheme.lightBorder
                            : AppTheme.electricCyan.withValues(alpha: 0.2),
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
                                        : (isLight
                                            ? AppTheme.lightTextSecondary
                                            : AppTheme.textSecondary),
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
                                        : (isLight
                                            ? AppTheme.lightTextSecondary
                                            : AppTheme.textSecondary),
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
                  Text(
                    'Your Secure Node ID',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mode Content
                  if (_mode == ConnectionMode.nodeId) ...[
                    // Digital 16-Character ID Code Box with Copy Button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isLight
                            ? const Color(0xFFF8FAFC)
                            : AppTheme.deepNavy.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isLight
                              ? AppTheme.electricCyan
                              : AppTheme.neonGreen.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isLight ? AppTheme.electricCyan : AppTheme.neonGreen)
                                .withValues(alpha: 0.15),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.id,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: user.id.length > 12 ? 18 : 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: isLight ? AppTheme.deepNavy : AppTheme.neonGreen,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: user.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Node ID copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isLight ? AppTheme.deepNavy : Colors.white)
                                    .withValues(alpha: 0.08),
                              ),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 18,
                                color: isLight
                                    ? AppTheme.deepNavy
                                    : AppTheme.electricCyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Cyber Neon QR Code
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.white
                            : AppTheme.deepNavy.withValues(alpha: 0.85),
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
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: isLight ? AppTheme.deepNavy : AppTheme.neonGreen,
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
                        color: isLight
                            ? const Color(0xFFF1F5F9)
                            : AppTheme.spaceIndigo.withValues(alpha: 0.6),
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Form Input Field
            TextField(
              controller: _nodeIdInputController,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Enter 16-Character Node ID or Scan QR',
                hintStyle: TextStyle(
                  color: isLight ? AppTheme.lightTextMuted : AppTheme.textMuted,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: isLight
                    ? const Color(0xFFF1F5F9)
                    : AppTheme.deepNavy.withValues(alpha: 0.6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: isLight
                        ? AppTheme.lightBorder
                        : AppTheme.electricCyan.withValues(alpha: 0.5),
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

            const SizedBox(height: 28),

            // Section Selector: [Connections] vs [Groups]
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFF1F5F9)
                    : AppTheme.deepNavy.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isLight
                      ? AppTheme.lightBorder
                      : AppTheme.electricCyan.withValues(alpha: 0.2),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSection = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: _selectedSection == 0
                              ? AppTheme.electricCyan
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            'Connections (${connectedNodes.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _selectedSection == 0
                                  ? AppTheme.deepNavy
                                  : (isLight
                                      ? AppTheme.lightTextSecondary
                                      : AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSection = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: _selectedSection == 1
                              ? AppTheme.electricCyan
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            'Groups (${groups.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _selectedSection == 1
                                  ? AppTheme.deepNavy
                                  : (isLight
                                      ? AppTheme.lightTextSecondary
                                      : AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section 0: Active Connections List
            if (_selectedSection == 0) ...[
              if (connectedNodes.isEmpty)
                CyberCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 40,
                          color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No Active Neighbors Yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scan a QR code or enter a 16-character Node ID above to link.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: connectedNodes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final node = connectedNodes[index];
                    final isOnline = node.status.toLowerCase() == 'online';

                    return CyberCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          CyberAvatar.fromUser(
                            user: node,
                            size: 44,
                            showStatusBadge: true,
                          ),
                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  node.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (isOnline) ...[
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
                                      Text(
                                        node.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

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
            ],

            // Section 1: Neighbor Groups Management
            if (_selectedSection == 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Groups',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showCreateGroupDialog(context, provider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppTheme.electricCyan,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: AppTheme.deepNavy),
                          SizedBox(width: 4),
                          Text(
                            'Create Group',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.deepNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (groups.isEmpty)
                CyberCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_shared_outlined,
                          size: 40,
                          color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No Neighbor Groups Yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create groups like "Family" or "Work" to filter your map.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groups.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final memberCount = group.members.length;

                    return CyberCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.electricCyan.withValues(alpha: 0.15),
                              border: Border.all(
                                color: AppTheme.electricCyan.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.group_rounded,
                                color: AppTheme.electricCyan,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$memberCount member${memberCount == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Assign button
                          GestureDetector(
                            onTap: () => _showAssignMembersSheet(context, provider, group),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: AppTheme.electricCyan.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: AppTheme.electricCyan.withValues(alpha: 0.5),
                                  width: 1.0,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_add_rounded, size: 14, color: AppTheme.electricCyan),
                                  SizedBox(width: 4),
                                  Text(
                                    'Assign',
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
                          const SizedBox(width: 8),

                          // Delete group button
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: AppTheme.warningRed,
                            ),
                            onPressed: () => provider.deleteGroup(group.id),
                            tooltip: 'Delete Group',
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
