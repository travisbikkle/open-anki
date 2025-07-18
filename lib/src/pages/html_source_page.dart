import 'package:flutter/material.dart';

class HtmlSourcePage extends StatelessWidget {
  final String html;
  const HtmlSourcePage({required this.html, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HTML源码')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText(html, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
      ),
    );
  }
} 