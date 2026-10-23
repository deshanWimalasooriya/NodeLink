import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'providers/node_link_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

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
  final hasAccount = prefs.getString('nodelink_user_profile') != null;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NodeLinkProvider()),
      ],
      child: NodeLinkApp(hasAccount: hasAccount),
    ),
  );
}

class NodeLinkApp extends StatelessWidget {
  final bool hasAccount;
  const NodeLinkApp({super.key, this.hasAccount = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NodeLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: hasAccount ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
