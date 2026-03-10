import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/warm_gradient_background.dart';
import '../../i18n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseScrollsScreen extends StatelessWidget {
  const PurchaseScrollsScreen({super.key});

  // TODO: Replace with your actual Stripe payment links for each scroll pack
  static const String _scrolls3Link =
      'https://buy.stripe.com/test_5kQ00ifqJawN6Gv6kW4gg03';
  static const String _scrolls10Link =
      'https://buy.stripe.com/test_dRm7sK2DX9sJfd1eRs4gg02';
  static const String _scrolls30Link =
      'https://buy.stripe.com/test_7sY00i2DX20h8OD8t44gg01';

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final user = Supabase.instance.client.auth.currentUser;
    String enrichedUrl = urlString;
    if (user != null) {
      enrichedUrl = '$urlString'
          '?client_reference_id=${user.id}'
          '&prefilled_email=${Uri.encodeComponent(user.email ?? '')}';
    }
    final Uri url = Uri.parse(enrichedUrl);
    if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open payment page. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);

    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      // Title
                      Text(
                        tr.tr('purchase_scrolls.title'),
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      // Subtitle
                      Text(
                        tr.tr('purchase_scrolls.subtitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4A148C),
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Pack 1: 3 Scrolls
                      _buildPackCard(
                        context,
                        title: tr.tr('purchase_scrolls.count',
                            params: {'count': '3'}),
                        price: '2,99 € /chacun',
                        onTap: () => _launchUrl(context, _scrolls3Link),
                        isPopular: false,
                        showBadge: false,
                        badgeText: '',
                        buttonColor: const Color(0xFFFFF8E1),
                        buttonTextColor: Colors.black87,
                      ),

                      const SizedBox(height: 14),

                      // Pack 2: 10 Scrolls (Popular)
                      _buildPackCard(
                        context,
                        title: tr.tr('purchase_scrolls.count',
                            params: {'count': '10'}),
                        price: '1.49€ /chacun',
                        onTap: () => _launchUrl(context, _scrolls10Link),
                        isPopular: true,
                        showBadge: true,
                        badgeText: tr.tr('purchase_scrolls.popular'),
                        badgeSideText: tr.tr('purchase_scrolls.save_percent',
                            params: {'percent': '50'}),
                        borderColor: const Color(0xFF7B1FA2),
                        buttonColor: const Color(0xFFE1BEE7),
                        buttonTextColor: Colors.black87,
                      ),

                      const SizedBox(height: 14),

                      // Pack 3: 30 Scrolls (Best Value)
                      _buildPackCard(
                        context,
                        title: tr.tr('purchase_scrolls.count',
                            params: {'count': '30'}),
                        price: '1.20€ /chacun',
                        onTap: () => _launchUrl(context, _scrolls30Link),
                        isPopular: false,
                        showBadge: true,
                        badgeText: tr.tr('purchase_scrolls.best_value'),
                        badgeSideText: tr.tr('purchase_scrolls.save_percent',
                            params: {'percent': '60'}),
                        borderColor: const Color(0xFFE0E0E0),
                        buttonColor: const Color(0xFFBBDEFB),
                        buttonTextColor: Colors.black87,
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          const Spacer(),
          Image.asset(
            'assets/images/scroll_icon.png',
            width: 40,
            errorBuilder: (c, o, s) =>
                const Icon(Icons.local_activity, color: Colors.amber, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildPackCard(
    BuildContext context, {
    required String title,
    required String price,
    required VoidCallback onTap,
    bool isPopular = false,
    bool showBadge = false,
    String badgeText = '',
    String badgeSideText = '',
    Color? borderColor,
    Color buttonColor = Colors.white,
    Color buttonTextColor = Colors.black87,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPopular
              ? Border.all(color: borderColor ?? Colors.purple, width: 2)
              : borderColor != null
                  ? Border.all(color: borderColor, width: 1.5)
                  : Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: isPopular
              ? [
                  BoxShadow(
                      color:
                          (borderColor ?? Colors.purple).withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 2)
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBadge) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    badgeText,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: borderColor ?? Colors.purple,
                    ),
                  ),
                  if (badgeSideText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeSideText,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 10),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quantity Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: buttonTextColor,
                    ),
                  ),
                ),
                // Price
                Text(
                  price,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
