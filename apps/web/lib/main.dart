import 'package:flutter/material.dart';

void main() {
  runApp(const NotJustDexWebApp());
}

class NotJustDexWebApp extends StatelessWidget {
  const NotJustDexWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NotJustDex Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('NotJustDex Web')),
      ),
    );
  }
}
