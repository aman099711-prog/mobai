import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const GoogleWebViewApp());
}

class GoogleWebViewApp extends StatelessWidget {
  const GoogleWebViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Google WebView',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GoogleWebViewPage(),
    );
  }
}

class GoogleWebViewPage extends StatefulWidget {
  const GoogleWebViewPage({super.key});

  @override
  State<GoogleWebViewPage> createState() => _GoogleWebViewPageState();
}

class _GoogleWebViewPageState extends State<GoogleWebViewPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.parse('https://www.google.com'),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google'),
      ),
      body: WebViewWidget(
        controller: controller,
      ),
    );
  }
}