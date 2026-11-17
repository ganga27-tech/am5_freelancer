import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme/app_theme.dart';

class AM5FreelancerApp extends StatelessWidget {
  const AM5FreelancerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AM5 ROYAL Freelancer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
