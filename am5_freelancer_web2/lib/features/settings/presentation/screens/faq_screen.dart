import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});
  static const Color navy = Color(0xFF101D45);
  static const Color blue = Color(0xFF2449A5);
  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final FreelanceApi _api = FreelanceApi();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.faqs();
      if (!mounted) return;
      setState(() {
        _items = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F6FD),
    appBar: AppBar(
      title: const Text('Frequently Asked Questions'),
      backgroundColor: FaqScreen.navy,
      foregroundColor: Colors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'How can we help?',
          style: TextStyle(
            color: FaqScreen.navy,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Browse common questions about your account.',
          style: TextStyle(color: Color(0xFF778198)),
        ),
        const SizedBox(height: 20),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: Text(_error!),
              trailing: TextButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ),
          ),
        if (!_loading && _error == null && _items.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No FAQs are available yet.'),
            ),
          ),
        for (final faq in _items)
          Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Color(0xFFE5EAF5)),
            ),
            child: ExpansionTile(
              leading: const Icon(
                Icons.help_outline_rounded,
                color: FaqScreen.blue,
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              title: Text(
                faq['question']?.toString() ?? '',
                style: const TextStyle(
                  color: FaqScreen.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    faq['answer']?.toString() ?? '',
                    style: const TextStyle(
                      color: Color(0xFF65718A),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
