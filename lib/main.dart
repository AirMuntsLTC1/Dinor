import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://skvgbzftnbditpztqewl.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrdmdiemZ0bmJkaXRwenRxZXdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3NDA1NDEsImV4cCI6MjEwODMxNjU0MX0.zHDtiHxAUBb-n2HpXjBbOHaO58pp4SgF__r9zq5JmkM',
  );
  runApp(const MonitorApp());
}

class MonitorApp extends StatelessWidget {
  const MonitorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dinor Monitor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF14181C),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF229ED9)),
      ),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final supabase = Supabase.instance.client;
  int _totalUsers = 0;
  int _totalMessages = 0;
  int _totalCalls = 0;
  List<dynamic> _recentEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _listenToLiveData();
  }

  Future<void> _fetchData() async {
    try {
      final users = await supabase.from('profiles').select('id');
      final messages = await supabase.from('messages').select('id');
      final calls = await supabase.from('calls').select('id');
      final events = await supabase.from('analytics').select().order('created_at', ascending: false).limit(10);

      setState(() {
        _totalUsers = users.length;
        _totalMessages = messages.length;
        _totalCalls = calls.length;
        _recentEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _listenToLiveData() {
    supabase.channel('monitor').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'analytics',
      callback: (payload) {
        _fetchData(); // Refresh dashboard on new event
      },
    ).subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dinor Monitor'),
        backgroundColor: const Color(0xFF1E242B),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stat Cards
                Row(
                  children: [
                    _buildStatCard('Users', _totalUsers, Icons.people),
                    const SizedBox(width: 12),
                    _buildStatCard('Messages', _totalMessages, Icons.message),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatCard('Active Calls', _totalCalls, Icons.call),
                
                const SizedBox(height: 24),
                
                // Live Feed Header
                const Text('Live Analytics Feed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                // Live Feed List
                ..._recentEvents.map((event) => Card(
                  color: const Color(0xFF1E242B),
                  child: ListTile(
                    leading: const Icon(Icons.data_usage, color: Color(0xFF229ED9)),
                    title: Text(event['event_type'].toString().toUpperCase()),
                    subtitle: Text(event['created_at'].toString().substring(11, 19)), // Show time
                  ),
                )),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E242B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF229ED9)),
            const SizedBox(height: 12),
            Text(value.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
