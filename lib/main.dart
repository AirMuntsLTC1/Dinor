import 'package:flutter/material.dart';
import 'ffi/dinor_bindings.dart';

void main() => runApp(const DinorApp());

class DinorApp extends StatelessWidget {
  const DinorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dinor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late DinorCore _core;
  String _status = 'loading...';

  @override
  void initState() {
    super.initState();
    try {
      _core = DinorCore.load();
      setState(() => _status = _core.version());
    } catch (e) {
      setState(() => _status = 'native core unavailable: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dinor')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Core: $_status', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
