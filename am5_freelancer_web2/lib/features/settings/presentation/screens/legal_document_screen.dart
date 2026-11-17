import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.slug,
    required this.title,
  });
  final String slug;
  final String title;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  static const Color navy = Color(0xFF101D45);
  final FreelanceApi _api = FreelanceApi();
  Map<String, dynamic>? _page;
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
      final pages = await _api.legalPages(slug: widget.slug);
      if (!mounted) return;
      final matches = pages
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final page = matches.isEmpty ? null : matches.first;
      setState(() {
        _page = page;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FC),
    appBar: AppBar(
      title: Text(widget.title),
      backgroundColor: navy,
      foregroundColor: Colors.white,
    ),
    body: _buildContent(),
  );

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final page = _page;
    if (page == null) {
      return const Center(child: Text('This document is not available yet.'));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE2E7F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page['title']?.toString() ?? widget.title,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version ${page['version'] ?? '—'} • Effective ${page['effective_date'] ?? '—'}',
                      style: const TextStyle(
                        color: Color(0xFF778198),
                        fontSize: 12,
                      ),
                    ),
                    const Divider(height: 28),
                    SelectableText(
                      page['content']?.toString() ?? '',
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 14,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
