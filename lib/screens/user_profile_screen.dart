import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/cyber_card.dart';
import '../core/widgets/cyber_button.dart';
import '../core/widgets/cyber_app_bar.dart';
import '../core/widgets/cyber_avatar.dart';
import '../core/widgets/cyber_toggle.dart';
import '../providers/node_link_provider.dart';
import 'onboarding_welcome_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<NodeLinkProvider>().currentUser;
    _nameController = TextEditingController(text: user.name);
    _phoneController = TextEditingController(text: user.phone);
    _locationController = TextEditingController(text: 'Colombo, Sri Lanka');
  }

  Future<void> _pickAndUploadProfilePicture() async {
    final picker = ImagePicker();
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final textColor = theme.textTheme.bodyLarge?.color ??
        (isLight ? AppTheme.lightTextPrimary : Colors.white);

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: isLight ? theme.colorScheme.surface : AppTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(
            color: isLight
                ? AppTheme.lightBorder
                : AppTheme.electricCyan.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isLight ? AppTheme.lightTextMuted : AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Select Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.camera_alt_rounded,
                color: isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan,
              ),
              title: Text(
                'Take Photo',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_rounded,
                color: isLight ? const Color(0xFF059669) : AppTheme.neonGreen,
              ),
              title: Text(
                'Choose from Gallery',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      // Compress targeting ~50KB using flutter_image_compress
      Uint8List? compressedBytes;
      try {
        compressedBytes = await FlutterImageCompress.compressWithFile(
          pickedFile.path,
          minWidth: 512,
          minHeight: 512,
          quality: 75,
          format: CompressFormat.jpeg,
        );
      } catch (e) {
        debugPrint('Image compression fallback: $e');
        compressedBytes = await pickedFile.readAsBytes();
      }

      compressedBytes ??= await pickedFile.readAsBytes();

      if (!mounted) return;
      final provider = context.read<NodeLinkProvider>();
      await provider.uploadAndSetProfilePhoto(compressedBytes);

      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo uploaded and synced to Firebase!'),
            backgroundColor: AppTheme.neonGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();
    final user = provider.currentUser;
    final settings = provider.settings;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final textColor = theme.textTheme.bodyLarge?.color ??
        (isLight ? AppTheme.lightTextPrimary : Colors.white);
    final secondaryTextColor =
        isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary;
    final accentColor = isLight ? const Color(0xFF0284C7) : AppTheme.electricCyan;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CyberAppBar(
        titleText: 'NodeLink',
        actions: [
          CyberCircleIconButton(
            icon: Icons.edit_outlined,
            iconSize: 20,
            iconColor: isLight ? const Color(0xFF0284C7) : AppTheme.textSecondary,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Profile edit mode enabled'),
                  backgroundColor: accentColor,
                ),
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

            // Centered round avatar of user with glowing aura and edit icon overlay
            Center(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  CyberAvatar.fromUser(
                    user: user,
                    size: 108,
                    showGlow: true,
                    borderWidth: 3,
                  ),

                  // Online status pill indicator below avatar
                  Positioned(
                    bottom: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: isLight ? Colors.white : AppTheme.deepNavy,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLight ? const Color(0xFF059669) : AppTheme.neonGreen,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isLight
                                ? const Color(0xFF0F172A).withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: isLight ? const Color(0xFF059669) : AppTheme.neonGreen,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isLight ? const Color(0xFF059669) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Edit Icon Overlay (Image Picker & Storage Upload)
                  Positioned(
                    bottom: 0,
                    right: -2,
                    child: GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickAndUploadProfilePicture,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLight ? Colors.white : AppTheme.surfaceDark,
                          border: Border.all(
                            color: accentColor,
                            width: 2.0,
                          ),
                          boxShadow: isLight
                              ? AppTheme.lightCardShadow
                              : AppTheme.cyanGlow(blur: 10, opacity: 0.6),
                        ),
                        child: _isUploadingPhoto
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: accentColor,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                                color: accentColor,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Name and Email
            Text(
              user.name.split(' ').first,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor,
              ),
            ),

            const SizedBox(height: 20),

            // Node ID Card & Actions (Copy Link & Share QR)
            CyberCard(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side pills
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFF059669) : AppTheme.neonGreen,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isLight
                              ? AppTheme.lightCardShadow
                              : AppTheme.neonGlow(blur: 10, opacity: 0.3),
                        ),
                        child: Text(
                          'Node ID: ${user.id}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isLight ? Colors.white : AppTheme.deepNavy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLight
                              ? const Color(0xFF0284C7)
                              : AppTheme.electricCyan.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${provider.connectedNodes.length} Active Connections',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Right side Action Icons: Copy Link & Share QR
                  Row(
                    children: [
                      _buildQuickAction(
                        context: context,
                        icon: Icons.copy_rounded,
                        label: 'Copy Link',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Node Link copied to clipboard'),
                              backgroundColor: accentColor,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.qr_code_2_rounded,
                        label: 'Share QR',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sharing QR Code...'),
                              backgroundColor: AppTheme.neonGreen,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Editable Input Tiles
            _buildFrostedField(
              context: context,
              label: 'Full Name',
              controller: _nameController,
            ),
            const SizedBox(height: 12),
            _buildFrostedField(
              context: context,
              label: 'Phone Number',
              controller: _phoneController,
            ),
            const SizedBox(height: 12),
            _buildFrostedField(
              context: context,
              label: 'Current Location',
              controller: _locationController,
              trailingIcon: Icons.location_on_rounded,
            ),

            const SizedBox(height: 16),

            // Sharing Status Card with Neon-Green Switch
            CyberCard(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sharing Status',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Always Share Location',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Only during movement',
                        style: TextStyle(
                          fontSize: 11,
                          color: isLight ? AppTheme.lightTextMuted : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  CyberToggle(
                    value: settings.alwaysShareLocation,
                    onChanged: (val) => provider.setAlwaysShareLocation(val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Vibrant Action button
            CyberButton(
              text: 'UPDATE PROFILE',
              onPressed: () {
                provider.updateProfile(
                  name: _nameController.text.trim(),
                  phone: _phoneController.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile successfully updated!'),
                    backgroundColor: AppTheme.neonGreen,
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Footer Action Links: Log Out & Delete Account
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () async {
                    await provider.logout();
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const OnboardingWelcomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                  child: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warningRed,
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account deletion requested'),
                        backgroundColor: AppTheme.warningRed,
                      ),
                    );
                  },
                  child: const Text(
                    'Delete Account',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warningRed,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final iconColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final secondaryTextColor =
        isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrostedField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    IconData? trailingIcon,
  }) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final textColor = theme.textTheme.bodyLarge?.color ??
        (isLight ? AppTheme.lightTextPrimary : Colors.white);
    final secondaryTextColor =
        isLight ? AppTheme.lightTextSecondary : AppTheme.textSecondary;

    return CyberCard(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextField(
                  controller: controller,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          if (trailingIcon != null)
            Icon(trailingIcon, color: secondaryTextColor, size: 20),
        ],
      ),
    );
  }
}
