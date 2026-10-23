import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class InternetBanner extends StatefulWidget {
  final Widget child;
  const InternetBanner({super.key, required this.child});

  @override
  State<InternetBanner> createState() => _InternetBannerState();
}

class _InternetBannerState extends State<InternetBanner> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    // Listen to internet changes
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final offline = results.contains(ConnectivityResult.none);
      if (mounted && _isOffline != offline) {
        setState(() => _isOffline = offline);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Animated Offline Banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isOffline ? 40 : 0,
          width: double.infinity,
          color: Colors.redAccent,
          child: _isOffline
              ? const SafeArea(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'No Internet Connection',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        ),
        // The rest of the app
        Expanded(child: widget.child),
      ],
    );
  }
}
