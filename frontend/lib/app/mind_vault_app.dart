import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class MindVaultApp extends StatelessWidget {
  const MindVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MindVault',
      debugShowCheckedModeBanner: false,
      theme: buildMindVaultTheme(),
      routerConfig: appRouter,
    );
  }
}
