import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_typography.dart';

void main() => runApp(const SynchronicityApp());

class SynchronicityApp extends StatelessWidget {
  const SynchronicityApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Synchronicity',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const WelcomeScreen(),
  );
}
