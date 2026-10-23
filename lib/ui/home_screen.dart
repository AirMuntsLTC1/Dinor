import 'package:flutter/material.dart';
import '../ffi/dinor_bindings.dart';
import 'chat_screen.dart';
import 'ai_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _nativeStatus = 'Checking core...';

  final List<Map<String, String>> _chats = [
    {'name': 'Alice', 'msg': 'Hey, are we still on for tomorrow?', 'time': '10:45 AM'},
    {'name': 'Bob', 'msg': 'Sent the files over.', 'time': 'Yesterday'},
    {'name': 'Project Dinor', 'msg': 'Build successful!', 'time': 'Monday'},
  ];

  @override
  void initState() {
    super.initState();
    _checkNativeCore();
  }

  void _checkNativeCore() {
    try {
      final core = DinorCore.load();
      setState(() => _nativeStatus = core.version());
    } catch (e) {
      setState(() => _nativeStatus = 'Core offline');
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF229ED9);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: brandBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: brandBlue, width: 1.5),
                    ),
                    child: const Icon(Icons.person, color: brandBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Dinor',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: brandBlue),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.black54),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // 2. Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: const TextStyle(color: Colors.black45),
                  prefixIcon: const Icon(Icons.search, color: Colors.black45),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 3. Custom AI Conversation Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatScreen(title: 'Dinor AI', isAi: true),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF229ED9), Color(0xFF24A1DE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: brandBlue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const AnimatedAIAvatar(size: 48),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dinor AI Assistant',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Ask me anything!',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.7), size: 16),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Chat List
            Expanded(
              child: ListView.separated(
                itemCount: _chats.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: brandBlue.withValues(alpha: 0.15),
                      child: Text(
                        chat['name']![0],
                        style: const TextStyle(color: brandBlue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(chat['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(chat['msg']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(chat['time']!, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(title: chat['name']!),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            // 5. Native Core Status Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.black12,
              child: Text(
                'Native Core: $_nativeStatus',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.chat),
      ),
    );
  }
}
