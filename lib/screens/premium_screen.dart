import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../i18n/app_localizations.dart';
import 'purchase_scrolls_screen.dart';
import 'home_screen.dart';
import '../services/iap_service.dart';
import '../services/database_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';

class PremiumScreen extends StatefulWidget {
  final VoidCallback? onPremiumActivated;

  const PremiumScreen({super.key, this.onPremiumActivated});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with WidgetsBindingObserver {
  static const String _subscriptionLink =
      'https://buy.stripe.com/test_cNi4gybatdIZfd15gS4gg04';
  static const String _manageSubscriptionLink =
      'https://billing.stripe.com/p/login/9B66oHgmyaVH4U0dC62Nq00';

  bool _isPremium = false;
  String? _userGender;
  bool _isLoading = true;
  bool _stripeOpened =
      false; // tracks whether Stripe was opened to show refresh button
  StreamSubscription<PurchaseDetails>? _purchaseSubscription;
  StreamSubscription<Map<String, dynamic>>? _profileSubscription;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPremiumStatus();

    // Listen for purchase updates
    _purchaseSubscription = IapService().purchaseStream.listen((purchase) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _loadPremiumStatus();
      }
    });

    _setupProfileSubscription();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _purchaseSubscription?.cancel();
    _profileSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-fetch premium status when returning to the app
      _loadPremiumStatus();
    }
  }

  Future<void> _loadPremiumStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('tier, gender')
            .eq('id', userId)
            .single();

        if (mounted) {
          setState(() {
            final tier = profile['tier'] as String? ?? 'free';
            _isPremium = tier == 'premium' || tier == 'elite';
            _userGender = profile['gender'] as String?;
            _isLoading = false;
          });

          // CRITICAL: If female, they shouldn't be here. Pop back.
          final gender = _userGender?.toLowerCase();
          final isFemale =
              gender == 'female' || gender == 'woman' || gender == 'femme';
          if (isFemale) {
            debugPrint('🚫 Female user reached PremiumScreen - redirecting');
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading premium status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupProfileSubscription() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _profileSubscription?.cancel();
      _profileSubscription =
          DatabaseService().subscribeProfile(userId).listen((data) async {
        if (mounted) {
          final tier = data['tier'] as String? ?? 'free';
          final isNowPremium = tier == 'premium' || tier == 'elite';

          if (isNowPremium && !_isPremium) {
            debugPrint('💎 Premium status detected via realtime!');
            _pollingTimer?.cancel();
            await closeInAppWebView();
            if (mounted) {
              setState(() {
                _isPremium = true;
                _isLoading = false;
              });
              if (widget.onPremiumActivated != null) {
                // Custom return navigation (e.g. back to chat)
                widget.onPremiumActivated!();
              } else {
                // Default: redirect directly to home
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              }
            }
          } else if (data.containsKey('tier')) {
            // Update status even if not premium (e.g. downgraded or already premium)
            setState(() {
              _isPremium = isNowPremium;
            });
          }
        }
      });
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Poll every 1.5 seconds for faster confirmation (previously 3 seconds)
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      await _loadPremiumStatus();
      if (_isPremium) {
        timer.cancel();
        debugPrint('💎 Premium status detected via polling fallback!');
        await closeInAppWebView();
        if (mounted) {
          if (widget.onPremiumActivated != null) {
            widget.onPremiumActivated!();
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        }
      }
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // For the subscription link, append parameters. For management portal, just open it.
    String enrichedUrl = urlString;
    if (urlString.contains('buy.stripe.com')) {
      final separator = urlString.contains('?') ? '&' : '?';
      enrichedUrl = '$urlString'
          '${separator}client_reference_id=${user.id}'
          '&prefilled_email=${Uri.encodeComponent(user.email ?? '')}';
    }

    final Uri url = Uri.parse(enrichedUrl);
    
    // Start polling as a safeguard just before opening Stripe
    _startPolling();

    // User requested to keep it running in-app.
    if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
      _pollingTimer?.cancel();
      throw Exception('Could not launch $enrichedUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8D0F5),
              Color(0xFFD4B5E8),
              Color(0xFFC8A8E8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              const SizedBox(height: 5),

                              // Title
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontFamily: 'PlayfairDisplay',
                                    color: Color(0xFF7B68EE),
                                    height: 1.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _isPremium
                                          ? 'SeaYou\n'
                                          : 'Passez à SeaYou\n',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: 'PREMIUM',
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              if (_isPremium) ...[
                                // Premium Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('👑',
                                          style: TextStyle(fontSize: 24)),
                                      const SizedBox(width: 12),
                                      Text(
                                        tr.tr('premium.upgrade.status_active'),
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF7B68EE),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 40),

                                // Manage Button
                                Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _launchUrl(_manageSubscriptionLink),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(26)),
                                    ),
                                    child: Text(
                                      tr.tr('profile.manage_subscription'),
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF7B68EE),
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // Cards Row
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Classique
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.7),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Flexible(
                                                child: Text(
                                                  'Classique',
                                                  style: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF666666),
                                                    height: 1.1,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              _buildFeature(
                                                icon: Icons.fiber_manual_record,
                                                iconColor:
                                                    const Color(0xFFFF9800),
                                                text: tr.tr(
                                                    'premium.classique.bottles_limit'),
                                                textColor:
                                                    const Color(0xFF666666),
                                              ),
                                              _buildFeature(
                                                icon: Icons.cancel,
                                                iconColor:
                                                    const Color(0xFFFF6B6B),
                                                text: tr.tr(
                                                    'premium.classique.bottles_locked'),
                                                textColor:
                                                    const Color(0xFF666666),
                                              ),
                                              _buildFeature(
                                                icon: Icons.fiber_manual_record,
                                                iconColor:
                                                    const Color(0xFFFF9800),
                                                text: tr.tr(
                                                    'premium.classique.distance_limit'),
                                                textColor:
                                                    const Color(0xFF666666),
                                              ),
                                              _buildFeature(
                                                icon: Icons.cancel,
                                                iconColor:
                                                    const Color(0xFFFF6B6B),
                                                text: tr.tr(
                                                    'premium.classique.souls_locked'),
                                                textColor:
                                                    const Color(0xFF666666),
                                              ),
                                              _buildFeature(
                                                icon: Icons.cancel,
                                                iconColor:
                                                    const Color(0xFFFF6B6B),
                                                text: tr.tr(
                                                    'premium.classique.desires_locked'),
                                                textColor:
                                                    const Color(0xFF666666),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // Premium
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF9B7FED),
                                                Color(0xFF7B68EE)
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF7B68EE)
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 15,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      'SeaYou PREMIUM',
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'Montserrat',
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: Colors.white,
                                                        height: 1.1,
                                                        letterSpacing: 0.2,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              _buildFeature(
                                                icon: Icons.check_circle,
                                                iconColor: Colors.white,
                                                text: tr.tr(
                                                    'premium.premium.bottles_unlimited'),
                                                textColor: Colors.white,
                                              ),
                                              _buildFeature(
                                                icon: Icons.check_circle,
                                                iconColor: Colors.white,
                                                text: tr.tr(
                                                    'premium.premium.bottles_open_unlimited'),
                                                textColor: Colors.white,
                                              ),
                                              _buildFeature(
                                                icon: Icons.check_circle,
                                                iconColor: Colors.white,
                                                text: tr.tr(
                                                    'premium.premium.distance_flexible'),
                                                textColor: Colors.white,
                                              ),
                                              _buildFeature(
                                                icon: Icons.check_circle,
                                                iconColor: Colors.white,
                                                text: tr.tr(
                                                    'premium.premium.souls_access'),
                                                textColor: Colors.white,
                                              ),
                                              _buildFeature(
                                                icon: Icons.check_circle,
                                                iconColor: Colors.white,
                                                text: tr.tr(
                                                    'premium.premium.desires_access'),
                                                textColor: Colors.white,
                                              ),
                                              _buildFeature(
                                                icon: Icons.check_circle,
                                                iconColor: Colors.white,
                                                text: tr.tr(
                                                    'premium.premium.direct_message'),
                                                textColor: Colors.white,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Price
                                Text(
                                  tr.tr('premium.upgrade.price'),
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                    letterSpacing: 0,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 20),

                                // Subscribe Button
                                Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF9B7FED),
                                        Color(0xFF7B68EE)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7B68EE)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await _launchUrl(_subscriptionLink);
                                      if (mounted) {
                                        setState(() => _stripeOpened = true);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8A2BE2),
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(26)),
                                    ),
                                    child: Text(
                                      tr.tr('premium.upgrade.continue'),
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

                                // After Stripe opened: show a refresh button
                                if (_stripeOpened) ...[
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () async {
                                      setState(() => _isLoading = true);
                                      await _loadPremiumStatus();
                                    },
                                    icon: const Icon(Icons.refresh,
                                        color: Color(0xFF7B68EE)),
                                    label: const Text(
                                      'J\'ai payé – Actualiser mon statut',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF7B68EE),
                                      ),
                                    ),
                                  ),
                                ],
                              ],

                              const SizedBox(height: 20),

                              // Get Scrolls Button
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const PurchaseScrollsScreen()),
                                  );
                                },
                                child: Text(
                                  tr.tr('purchase_scrolls.title'),
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7B68EE),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Manage Subscription (Always Visible)
                              TextButton(
                                onPressed: () =>
                                    _launchUrl(_manageSubscriptionLink),
                                child: Text(
                                  tr.tr('profile.manage_subscription'),
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF666666),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
