import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import '../providers/node_link_provider.dart';
import '../services/firebase_sync_service.dart';
import 'home_screen.dart';

class RegistrationSetupScreen extends StatefulWidget {
  const RegistrationSetupScreen({super.key});

  @override
  State<RegistrationSetupScreen> createState() => _RegistrationSetupScreenState();
}

class _RegistrationSetupScreenState extends State<RegistrationSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _pickedImagePath;
  Uint8List? _pickedImageBytes;
  bool _isLoading = false;

  // Live Username Validation & Suggestions
  Timer? _usernameDebounce;
  bool _isCheckingUsername = false;
  bool _isUsernameTaken = false;
  List<String> _usernameSuggestions = [];

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    final text = _usernameController.text.trim();

    if (text.isEmpty || text.length < 3) {
      if (_isUsernameTaken || _usernameSuggestions.isNotEmpty || _isCheckingUsername) {
        setState(() {
          _isUsernameTaken = false;
          _isCheckingUsername = false;
          _usernameSuggestions = [];
        });
      }
      return;
    }

    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isCheckingUsername = true);
      final taken = await FirebaseSyncService.isUsernameTaken(text);
      if (!mounted) return;

      if (taken) {
        final suggestions = await FirebaseSyncService.generateAvailableSuggestions(text);
        if (!mounted) return;
        setState(() {
          _isCheckingUsername = false;
          _isUsernameTaken = true;
          _usernameSuggestions = suggestions;
        });
      } else {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameTaken = false;
          _usernameSuggestions = [];
        });
      }
    });
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Open Image Picker to choose from Gallery or Camera
  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: AppTheme.electricCyan.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Add Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.electricCyan),
              title: const Text(
                'Take Photo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.neonGreen),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (picked != null) {
        Uint8List? bytes;
        try {
          bytes = await FlutterImageCompress.compressWithFile(
            picked.path,
            minWidth: 512,
            minHeight: 512,
            quality: 75,
            format: CompressFormat.jpeg,
          );
        } catch (_) {
          bytes = await picked.readAsBytes();
        }

        bytes ??= await picked.readAsBytes();

        setState(() {
          _pickedImagePath = picked.path;
          _pickedImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  /// Generate secure 16-character alphanumeric cryptographic Node ID
  String _generateUniqueNodeId() {
    return FirebaseSyncService.generateSecureNodeId();
  }

  /// Handle "CONTINUE TO DASHBOARD"
  Future<void> _handleContinue() async {
    if (_isUsernameTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose an available username before continuing'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final phoneRaw = _phoneController.text.trim();
      final fullPhoneNumber = phoneRaw.startsWith('+') ? phoneRaw : '+94 $phoneRaw';
      final nodeId = _generateUniqueNodeId();

      // 1. Upload photo if selected
      String profilePicUrl = '';
      if (_pickedImageBytes != null) {
        try {
          final uploadedUrl = await FirebaseSyncService.uploadProfilePhoto(
            nodeId: nodeId,
            imageBytes: _pickedImageBytes!,
          );
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            profilePicUrl = uploadedUrl;
            // CRITICAL FIX: Explicitly write download URL string back to user's Realtime Database node
            await FirebaseSyncService.updateProfilePhotoUrl(
              nodeId: nodeId,
              photoUrl: profilePicUrl,
            );
          }
        } catch (e) {
          debugPrint('Photo upload deferred: $e');
        }
      }

      // 2. Save credentials to local SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('phoneNumber', fullPhoneNumber);
      await prefs.setString('nodeId', nodeId);
      await prefs.setString('nodelink_user_profile', username);
      await prefs.setString('nodelink_node_id', nodeId);
      if (profilePicUrl.isNotEmpty) {
        await prefs.setString('profilePicUrl', profilePicUrl);
        await prefs.setString('nodelink_profile_pic_url', profilePicUrl);
      }
      if (_pickedImagePath != null) {
        await prefs.setString('localPhotoPath', _pickedImagePath!);
      }

      // 3. Instantiate user record inside Firebase Realtime Database
      // Permanent 6-digit Node ID storage: users/<node_id>/nodeId: "123456"
      await FirebaseSyncService.instantiateUserRecord(
        nodeId: nodeId,
        name: username,
        phoneNumber: fullPhoneNumber,
        profilePicUrl: profilePicUrl,
      );

      // 4. Initialize Provider state & update local state
      if (!mounted) return;
      final provider = context.read<NodeLinkProvider>();
      await provider.initializeNewAccount(
        name: username,
        nodeId: nodeId,
        phoneNumber: fullPhoneNumber,
        profilePicUrl: profilePicUrl,
        localPhotoPath: _pickedImagePath,
      );

      // 5. Smoothly transition Navigator to HomeScreen removing onboarding stack
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration error: $e'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? AppTheme.lightBg : AppTheme.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ambient Background Map Grid
          CustomPaint(
            painter: _DetailsBackgroundPainter(),
          ),

          // 2. Cyan & Green Ambient Glows
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.electricCyan.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.neonGreen.withValues(alpha: 0.08),
              ),
            ),
          ),

          // 3. Main Scrollable Content matching Set up details page.png
          SafeArea(
            child: Column(
              children: [
                // Top Header Row with Back Button and NodeLink Wordmark
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Back Button on top-left
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.spaceIndigo.withValues(alpha: 0.45),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1.0,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      // NodeLink Wordmark Centered
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Node',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            TextSpan(
                              text: 'Link',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.electricCyan,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),

                          // Title: "Set Up Your Node"
                          const Text(
                            'Set Up Your Node',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Subtitle: "Enter your details to create your location-tracking identity."
                          const Text(
                            'Enter your details to create your\nlocation-tracking identity.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                              height: 1.35,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Profile Image Selector matching UI Mockup
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      // Glowing Neon Green Border Ring
                                      Container(
                                        width: 104,
                                        height: 104,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppTheme.neonGreen,
                                            width: 2.8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.neonGreen
                                                  .withValues(alpha: 0.40),
                                              blurRadius: 16,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: _pickedImageBytes != null
                                              ? Image.memory(
                                                  _pickedImageBytes!,
                                                  fit: BoxFit.cover,
                                                )
                                              : (_pickedImagePath != null
                                                  ? Image.file(
                                                      File(_pickedImagePath!),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Container(
                                                      color: const Color(0xFF1B2A47),
                                                      child: Center(
                                                        child: Icon(
                                                          Icons.person_rounded,
                                                          size: 58,
                                                          color: Colors.white
                                                              .withValues(alpha: 0.7),
                                                        ),
                                                      ),
                                                    )),
                                        ),
                                      ),

                                      // Camera Overlay Badge on bottom right
                                      Positioned(
                                        bottom: 0,
                                        right: -2,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF1E293B),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.3),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.5),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // "Add Photo" Label
                                const Text(
                                  'Add Photo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 26),

                          // Form Input Card: Heavily Rounded Frosted Glass Container
                          ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 24,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.spaceIndigo.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: AppTheme.electricCyan.withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. Username Label
                                    Text(
                                      'Username',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Username Input Field
                                    TextFormField(
                                      controller: _usernameController,
                                      style: TextStyle(
                                        color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      cursorColor: AppTheme.electricCyan,
                                      decoration: InputDecoration(
                                        hintText: 'Enter Username',
                                        hintStyle: TextStyle(
                                          color: isLight
                                              ? AppTheme.lightTextMuted
                                              : Colors.white.withValues(alpha: 0.35),
                                          fontSize: 14,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.person_rounded,
                                          color: isLight
                                              ? AppTheme.lightTextSecondary
                                              : Colors.white.withValues(alpha: 0.5),
                                          size: 20,
                                        ),
                                        filled: true,
                                        fillColor: isLight
                                            ? const Color(0xFFF1F5F9)
                                            : const Color(0xFF0F172A).withValues(alpha: 0.65),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: _isUsernameTaken
                                                ? AppTheme.warningRed
                                                : (isLight
                                                    ? AppTheme.lightBorder
                                                    : Colors.white.withValues(alpha: 0.12)),
                                            width: _isUsernameTaken ? 1.6 : 1.0,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: _isUsernameTaken
                                                ? AppTheme.warningRed
                                                : (isLight
                                                    ? AppTheme.lightBorder
                                                    : Colors.white.withValues(alpha: 0.12)),
                                            width: _isUsernameTaken ? 1.6 : 1.0,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: _isUsernameTaken
                                                ? AppTheme.warningRed
                                                : AppTheme.electricCyan,
                                            width: 1.8,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: AppTheme.warningRed,
                                            width: 1.6,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your username';
                                        }
                                        if (_isUsernameTaken) {
                                          return 'This username is already taken.';
                                        }
                                        return null;
                                      },
                                    ),

                                    // Live Feedback & Smart Suggestions
                                    if (_isCheckingUsername) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: AppTheme.electricCyan,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Checking username availability...',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isLight
                                                  ? AppTheme.lightTextSecondary
                                                  : AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (_isUsernameTaken) ...[
                                      const SizedBox(height: 6),
                                      const Text(
                                        'This username is already taken.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.warningRed,
                                        ),
                                      ),
                                      if (_usernameSuggestions.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Available suggestions:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isLight
                                                ? AppTheme.lightTextSecondary
                                                : AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: _usernameSuggestions.map((suggestion) {
                                            return FilterChip(
                                              label: Text(
                                                suggestion,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: isLight
                                                      ? AppTheme.deepNavy
                                                      : Colors.white,
                                                ),
                                              ),
                                              backgroundColor: isLight
                                                  ? const Color(0xFFE2E8F0)
                                                  : AppTheme.spaceIndigo.withValues(alpha: 0.8),
                                              side: BorderSide(
                                                color: AppTheme.electricCyan.withValues(alpha: 0.6),
                                                width: 1.0,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              onSelected: (_) {
                                                _usernameController.text = suggestion;
                                                _usernameController.selection =
                                                    TextSelection.fromPosition(
                                                  TextPosition(offset: suggestion.length),
                                                );
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],

                                    const SizedBox(height: 18),

                                    // 2. Phone Number Label
                                    const Text(
                                      'Phone Number',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Phone Number Input Field with +94 Country Code Block
                                    TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      cursorColor: AppTheme.electricCyan,
                                      decoration: InputDecoration(
                                        hintText: 'Enter Phone Number',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.35),
                                          fontSize: 14,
                                        ),
                                        prefixIcon: Container(
                                          padding: const EdgeInsets.only(left: 12, right: 10),
                                          margin: const EdgeInsets.only(right: 8),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                '🇱🇰',
                                                style: TextStyle(fontSize: 18),
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                '+94',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 1,
                                                height: 20,
                                                color: Colors.white.withValues(alpha: 0.2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFF0F172A).withValues(alpha: 0.65),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.12),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.12),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: AppTheme.electricCyan,
                                            width: 1.5,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: AppTheme.warningRed,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your phone number';
                                        }
                                        final cleanDigits =
                                            value.replaceAll(RegExp(r'[^0-9]'), '');
                                        if (cleanDigits.length < 7) {
                                          return 'Enter a valid phone number';
                                        }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 24),

                                    // CTA Button: "CONTINUE TO DASHBOARD"
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _handleContinue,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.electricCyan,
                                          foregroundColor: AppTheme.deepNavy,
                                          disabledBackgroundColor:
                                              AppTheme.electricCyan.withValues(alpha: 0.4),
                                          elevation: 8,
                                          shadowColor:
                                              AppTheme.electricCyan.withValues(alpha: 0.5),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(26),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: AppTheme.deepNavy,
                                                ),
                                              )
                                            : const Text(
                                                'CONTINUE TO DASHBOARD',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.8,
                                                  color: AppTheme.deepNavy,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cyber Map background painter for registration screen
class _DetailsBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = AppTheme.electricCyan.withValues(alpha: 0.05)
      ..strokeWidth = 3.0;

    canvas.drawLine(
      Offset(-20, size.height * 0.2),
      Offset(size.width + 20, size.height * 0.4),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, 0),
      Offset(size.width * 0.2, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(-30, size.height * 0.75),
      Offset(size.width + 30, size.height * 0.65),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
