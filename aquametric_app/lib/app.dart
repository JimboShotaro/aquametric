import 'package:flutter/material.dart';
import 'package:aquametric_app/core/theme/app_theme.dart';
import 'package:aquametric_app/features/dashboard/presentation/pages/dashboard_page.dart';

class AquaMetricApp extends StatelessWidget {
  const AquaMetricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaMetric',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const DashboardPage(),
    );
  }
}
