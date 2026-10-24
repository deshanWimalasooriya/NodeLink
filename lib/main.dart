import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'providers/node_link_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set cyber status bar & navigation bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.deepNavy,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('username') ?? prefs.getString('nodelink_user_profile');
  final phoneNumber = prefs.getString('phoneNumber');

  // Auth State Gateway: check for existence of username and phoneNumber strings
  final bool hasAuth = (username != null && username.trim().isNotEmpty) &&
      (phoneNumber != null && phoneNumber.trim().isNotEmpty);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NodeLinkProvider()),
      ],
      child: NodeLinkApp(hasAccount: hasAuth),
    ),
  );
}

class NodeLinkApp extends StatelessWidget {
  final bool hasAccount;
  const NodeLinkApp({super.key, this.hasAccount = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NodeLinkProvider>();

    return MaterialApp(
      title: 'NodeLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: provider.themeMode,
      home: hasAccount ? const HomeScreen() : const OnboardingWelcomeScreen(),
    );
  }
}
