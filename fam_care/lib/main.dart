import 'package:fam_care/screens/patient_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    const ProviderScope(
      child: FamCareApp(),
    ),
  );
}

class FamCareApp extends StatelessWidget {
  const FamCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamCARE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const PatientSelectScreen(),
    );
  }
}
