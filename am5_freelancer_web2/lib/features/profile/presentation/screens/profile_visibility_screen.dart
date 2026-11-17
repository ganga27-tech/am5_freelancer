import 'package:flutter/material.dart';

class ProfileVisibilityScreen extends StatefulWidget {
  final bool initialVisibility;

  const ProfileVisibilityScreen({super.key, this.initialVisibility = true});

  @override
  State<ProfileVisibilityScreen> createState() =>
      _ProfileVisibilityScreenState();
}

class _ProfileVisibilityScreenState extends State<ProfileVisibilityScreen> {
  static const navy = Color(0xFF142B6F);
  static const cream = Color(0xFFFFF8E7);
  static const gold = Color(0xFFD4AF37);
  static const ink = Color(0xFF172033);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE8E0CE);

  late bool _visible;

  @override
  void initState() {
    super.initState();
    _visible = widget.initialVisibility;
  }

  void _saveVisibility() {
    Navigator.of(context).pop<bool>(_visible);
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text(
          'Profile Visibility',
          style: TextStyle(color: navy, fontWeight: FontWeight.w900),
        ),
        backgroundColor: cream,
        foregroundColor: navy,
        elevation: 0,
        surfaceTintColor: cream,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [navy, gold, Color(0xFFFFE9A8), gold],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 550),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: border),
                      boxShadow: [
                        BoxShadow(
                          color: navy.withValues(alpha: 0.07),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Visibility icon
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: _visible
                                ? const Color(0xFFE5F6ED)
                                : const Color(0xFFF1F2F5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _visible
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            color: _visible ? const Color(0xFF16856B) : muted,
                            size: 45,
                          ),
                        ),

                        const SizedBox(height: 22),

                        const Text(
                          'Control Profile Visibility',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          _visible
                              ? 'Your profile is currently marked as visible.'
                              : 'Your profile is currently marked as hidden.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Visibility switch
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: cream,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: border),
                          ),
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _visible,
                            title: Text(
                              _visible
                                  ? 'Profile is visible'
                                  : 'Profile is hidden',
                              style: const TextStyle(
                                color: ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              _visible
                                  ? 'Your visibility setting is enabled.'
                                  : 'Your visibility setting is disabled.',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            activeThumbColor: navy,
                            onChanged: (value) {
                              setState(() {
                                _visible = value;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Information note
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2D6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF8A5A00),
                                size: 19,
                              ),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'This setting updates the dashboard locally. '
                                  'Public visibility will change only after '
                                  'backend integration is implemented.',
                                  style: TextStyle(
                                    color: Color(0xFF8A5A00),
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _saveVisibility,
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 19,
                            ),
                            label: const Text(
                              'Save Settings',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Cancel button
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: _cancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: navy,
                              side: const BorderSide(color: gold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
