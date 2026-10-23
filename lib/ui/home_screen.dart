import 'package:flutter/material.dart';
import '../ffi/dinor_bindings.dart';

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
      
      // Custom Header: Profile Picture + Search Bar
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header (Profile & Title)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  // Small Circle Profile Picture Placeholder
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: brandBlue.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: brandBlue, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: brandBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Dinor',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: brandBlue,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.black54),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // 2. Rounded Search Bar
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
                    borderRadius: BorderRadius.circular(30), // Rounded corners
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 3. Chat List
            Expanded(
              child: ListView.separated(
                itemCount: _chats.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: brandBlue.withOpacity(0.15),
                      child: Text(
                        chat['name']![0],
                        style: const TextStyle(
                          color: brandBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(chat['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      chat['msg']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      chat['time']!,
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                    onTap: () {
                      // TODO: Navigate to Chat Screen
                    },
                  );
                },
              ),
            ),
            
            // 4. Native Core Status Footer
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
