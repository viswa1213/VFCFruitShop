import 'package:flutter/material.dart';
import 'package:fruit_shop/services/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Builder(
          builder: (context) {
            final primary = Theme.of(context).colorScheme.primary;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, Color.lerp(primary, Colors.white, 0.2)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Appearance', 0),
          _appearanceCard(context),
          const SizedBox(height: 14),
          _sectionHeader('Notifications', 1),
          _notificationsCard(context),
          const SizedBox(height: 14),
          _sectionHeader('Contact & Support', 2),
          _contactCard(context),
          const SizedBox(height: 14),
          _sectionHeader('Legal', 3),
          _legalCard(context),
          const SizedBox(height: 14),
          _sectionHeader('About', 4),
          _aboutCard(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int idx) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t) * (1 + idx * 0.07)),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Appearance section (accent picker only; no theme mode controls)
  Widget _appearanceCard(BuildContext context) {
    return _animatedCard(
      0,
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.color_lens,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Accent color',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<Color>(
              valueListenable: AppTheme.accent,
              builder: (context, color, _) {
                final options = <Color>[
                  Theme.of(context).colorScheme.primary,
                  Colors.red.shade600,
                  Colors.pink.shade400,
                  Colors.purple.shade600,
                  Colors.deepPurple.shade600,
                  Colors.indigo.shade600,
                  Colors.blue.shade600,
                  Colors.lightBlue.shade600,
                  Colors.cyan.shade600,
                  Colors.teal.shade600,
                  Colors.green.shade600,
                  Colors.lightGreen.shade600,
                  Colors.lime.shade700,
                  Colors.amber.shade700,
                  Colors.orange.shade700,
                  Colors.deepOrange.shade600,
                  Colors.brown.shade600,
                  Colors.blueGrey.shade600,
                ];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: options.map((c) {
                    final selected = c.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => AppTheme.setAccent(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : Theme.of(context).dividerColor,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationsCard(BuildContext context) {
    return _animatedCard(
      1,
      Column(
        children: const [
          SwitchListTile(
            value: true,
            onChanged: null,
            title: Text('Order updates'),
            secondary: Icon(Icons.notifications_active),
          ),
          Divider(height: 1),
          SwitchListTile(
            value: true,
            onChanged: null,
            title: Text('Offers & marketing'),
            secondary: Icon(Icons.local_offer),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard(BuildContext context) {
    return _animatedCard(
      4,
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('VFC Fruit Shop'),
        subtitle: const Text('Version 1.0.0'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          showAboutDialog(
            context: context,
            applicationName: 'VFC Fruit Shop',
            applicationVersion: '1.0.0',
            applicationIcon: const Icon(Icons.local_grocery_store),
            children: const [
              Text(
                'VFC brings you farm-fresh fruits with uncompromising quality.',
              ),
              SizedBox(height: 8),
              Text('© 2025 VFC. All rights reserved.'),
            ],
          );
        },
      ),
    );
  }

  Widget _contactCard(BuildContext context) {
    return _animatedCard(
      2,
      Column(
        children: [
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email support'),
            subtitle: const Text('support@vfc.com'),
            onTap: () {
              _showInfo(
                context,
                'Email support',
                'Write to us at support@vfc.com and we\'ll get back within 24 hours.',
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Chat with us'),
            subtitle: const Text('Live chat coming soon'),
            onTap: () => _showInfo(
              context,
              'Chat',
              'Live chat is coming soon. In the meantime, email support@vfc.com',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.call_outlined),
            title: const Text('Phone'),
            subtitle: const Text('+91 90000 00000'),
            onTap: () => _showInfo(
              context,
              'Phone',
              'Our support line is available 9am–6pm IST, Mon–Sat.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _legalCard(BuildContext context) {
    return _animatedCard(
      3,
      Column(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _showInfo(
              context,
              'Privacy Policy',
              'We respect your privacy. This is placeholder content for the policy.',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            onTap: () => _showInfo(
              context,
              'Terms of Service',
              'These are placeholder terms. Replace with your actual legal text.',
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String text) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(text),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _animatedCard(int idx, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t) * (1 + idx * 0.06)),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
