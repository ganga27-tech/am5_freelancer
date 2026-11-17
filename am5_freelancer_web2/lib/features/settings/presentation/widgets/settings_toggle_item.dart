import 'package:flutter/material.dart';

class SettingsToggleItem extends StatelessWidget {
  const SettingsToggleItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool showDivider;

  static const Color blue = Color(0xFF2449A5);
  static const Color text = Color(0xFF17233F);
  static const Color grey = Color(0xFF778198);
  static const Color border = Color(0xFFE2E9F7);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 3,
          ),
          secondary: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: blue, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              subtitle,
              style: const TextStyle(color: grey, fontSize: 12, height: 1.4),
            ),
          ),
          value: value,
          activeThumbColor: blue,
          onChanged: enabled ? onChanged : null,
        ),
        if (showDivider)
          const Divider(height: 1, indent: 18, endIndent: 18, color: border),
      ],
    );
  }
}
