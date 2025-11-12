import 'package:flutter/material.dart';
// Replaced simple About with an advanced, animated About page
import 'package:fruit_shop/pages/advanced_about_page.dart';
import 'package:fruit_shop/services/app_theme.dart';
import 'package:fruit_shop/utils/responsive.dart';
import 'package:fruit_shop/widgets/animated_sections.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: responsive.fontSize(20, 22),
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, Color.lerp(primary, Colors.white, 0.2)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(responsive.isMobile ? 16 : 20),
        children: [
          _sectionHeader('Appearance', 0, responsive),
          SizedBox(height: responsive.spacing(8, 12)),
          _appearanceCard(context, responsive),
          SizedBox(height: responsive.spacing(20, 24)),
          _sectionHeader('Notifications', 1, responsive),
          SizedBox(height: responsive.spacing(8, 12)),
          _notificationsCard(context, responsive),
          SizedBox(height: responsive.spacing(20, 24)),
          _sectionHeader('Contact & Support', 2, responsive),
          SizedBox(height: responsive.spacing(8, 12)),
          _contactCard(context, responsive),
          SizedBox(height: responsive.spacing(20, 24)),
          _sectionHeader('Legal', 3, responsive),
          SizedBox(height: responsive.spacing(8, 12)),
          _legalCard(context, responsive),
          SizedBox(height: responsive.spacing(20, 24)),
          _sectionHeader('About', 4, responsive),
          SizedBox(height: responsive.spacing(8, 12)),
          _aboutCard(context, responsive),
          SizedBox(height: responsive.spacing(24, 32)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int idx, Responsive responsive) {
    return Builder(
      builder: (context) => FadeInSlide(
        offset: const Offset(-30, 0),
        duration: const Duration(milliseconds: 500),
        delay: Duration(milliseconds: 100 * idx),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: responsive.fontSize(18, 20),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Appearance section (accent picker only; no theme mode controls)
  Widget _appearanceCard(BuildContext context, Responsive responsive) {
    return _animatedCard(
      0,
      Padding(
        padding: EdgeInsets.all(responsive.isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.color_lens,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: responsive.fontSize(16, 18),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.spacing(16, 20)),
            Text(
              'Choose your accent color',
              style: TextStyle(
                fontSize: responsive.fontSize(14, 16),
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            SizedBox(height: responsive.spacing(12, 16)),
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
                  spacing: responsive.isMobile ? 12 : 16,
                  runSpacing: responsive.isMobile ? 12 : 16,
                  children: options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final c = entry.value;
                    final selected = c.toARGB32() == color.toARGB32();
                    return FadeInSlide(
                      offset: const Offset(0, 20),
                      duration: const Duration(milliseconds: 400),
                      delay: Duration(milliseconds: 30 * idx),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => AppTheme.setAccent(c),
                          borderRadius: BorderRadius.circular(30),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            width: responsive.isMobile ? 44 : 50,
                            height: responsive.isMobile ? 44 : 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [c, c.withValues(alpha: 0.8)],
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: c.withValues(alpha: 0.5),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.grey.shade300,
                                width: selected ? 3 : 2,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : null,
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

  Widget _notificationsCard(BuildContext context, Responsive responsive) {
    return _animatedCard(
      1,
      Column(
        children: [
          _buildSwitchTile(
            context,
            responsive,
            Icons.notifications_active,
            'Order updates',
            'Get notified about your order status',
            true,
            (v) {},
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildSwitchTile(
            context,
            responsive,
            Icons.local_offer,
            'Offers & marketing',
            'Receive special deals and promotions',
            true,
            (v) {},
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    Responsive responsive,
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: responsive.isMobile ? 16 : 20,
        vertical: responsive.isMobile ? 8 : 12,
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: responsive.fontSize(15, 17),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: responsive.fontSize(12, 14),
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        // activeColor is deprecated; use activeThumbColor for thumb color
        activeThumbColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _aboutCard(BuildContext context, Responsive responsive) {
    return _animatedCard(
      4,
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdvancedAboutPage()),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(responsive.isMobile ? 16 : 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: responsive.spacing(16, 20)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VFC Fruit Shop',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: responsive.fontSize(16, 18),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Story, mission, live stats & platform',
                        style: TextStyle(
                          fontSize: responsive.fontSize(12, 14),
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context, Responsive responsive) {
    return _animatedCard(
      2,
      Column(
        children: [
          _buildContactTile(
            context,
            responsive,
            Icons.email_outlined,
            'Email support',
            'support@vfc.com',
            Colors.blue,
            () => _showInfo(
              context,
              'Email support',
              'Write to us at support@vfc.com and we\'ll get back within 24 hours.',
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildContactTile(
            context,
            responsive,
            Icons.chat_bubble_outline,
            'Chat with us',
            'Live chat coming soon',
            Colors.green,
            () => _showInfo(
              context,
              'Chat',
              'Live chat is coming soon. In the meantime, email support@vfc.com',
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildContactTile(
            context,
            responsive,
            Icons.call_outlined,
            'Phone',
            '+91 90000 00000',
            Colors.orange,
            () => _showInfo(
              context,
              'Phone',
              'Our support line is available 9am–6pm IST, Mon–Sat.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context,
    Responsive responsive,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.isMobile ? 16 : 20,
            vertical: responsive.isMobile ? 12 : 16,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: responsive.spacing(16, 20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: responsive.fontSize(15, 17),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: responsive.fontSize(12, 14),
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legalCard(BuildContext context, Responsive responsive) {
    return _animatedCard(
      3,
      Column(
        children: [
          _buildLegalTile(
            context,
            responsive,
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            Colors.purple,
            () => _showInfo(
              context,
              'Privacy Policy',
              'We respect your privacy. This is placeholder content for the policy.',
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildLegalTile(
            context,
            responsive,
            Icons.description_outlined,
            'Terms of Service',
            Colors.indigo,
            () => _showInfo(
              context,
              'Terms of Service',
              'These are placeholder terms. Replace with your actual legal text.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalTile(
    BuildContext context,
    Responsive responsive,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.isMobile ? 16 : 20,
            vertical: responsive.isMobile ? 12 : 16,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: responsive.spacing(16, 20)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: responsive.fontSize(15, 17),
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
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
    return Builder(
      builder: (context) => StaggeredAnimation(
        index: idx,
        duration: const Duration(milliseconds: 500),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
