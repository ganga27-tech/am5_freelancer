import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});
  @override
  Widget build(BuildContext context) => const LegalDocumentScreen(
    slug: 'terms-and-conditions',
    title: 'Terms & Conditions',
  );
}
