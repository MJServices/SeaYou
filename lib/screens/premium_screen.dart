import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
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
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 5),
                        
                        // Title
                        Text(
                          tr.tr('premium.upgrade.title'),
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Cards Row
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Classique
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'SeaYou Classique',
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF666666),
                                          height: 1.1,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildFeature(
                                        icon: Icons.fiber_manual_record,
                                        iconColor: Color(0xFFFF9800),
                                        text: tr.tr('premium.classique.bottles_limit'),
                                        textColor: Color(0xFF666666),
                                      ),
                                      _buildFeature(
                                        icon: Icons.cancel,
                                        iconColor: Color(0xFFFF6B6B),
                                        text: tr.tr('premium.classique.bottles_locked'),
                                        textColor: Color(0xFF666666),
                                      ),
                                      _buildFeature(
                                        icon: Icons.fiber_manual_record,
                                        iconColor: Color(0xFFFF9800),
                                        text: tr.tr('premium.classique.distance_limit'),
                                        textColor: Color(0xFF666666),
                                      ),
                                      _buildFeature(
                                        icon: Icons.cancel,
                                        iconColor: Color(0xFFFF6B6B),
                                        text: tr.tr('premium.classique.souls_locked'),
                                        textColor: Color(0xFF666666),
                                      ),
                                      _buildFeature(
                                        icon: Icons.cancel,
                                        iconColor: Color(0xFFFF6B6B),
                                        text: tr.tr('premium.classique.desires_locked'),
                                        textColor: Color(0xFF666666),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 10),
                              
                              // Premium
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF9B7FED), Color(0xFF7B68EE)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF7B68EE).withOpacity(0.4),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.workspace_premium, color: Colors.yellow.shade200, size: 12),
                                            const SizedBox(width: 3),
                                            const Text(
                                              'SeaYou PREMIUM',
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildFeature(
                                        icon: Icons.check_circle,
                                        iconColor: Colors.white,
                                        text: tr.tr('premium.premium.bottles_unlimited'),
                                        textColor: Colors.white,
                                      ),
                                      _buildFeature(
                                        icon: Icons.check_circle,
                                        iconColor: Colors.white,
                                        text: tr.tr('premium.premium.bottles_open_unlimited'),
                                        textColor: Colors.white,
                                      ),
                                      _buildFeature(
                                        icon: Icons.check_circle,
                                        iconColor: Colors.white,
                                        text: tr.tr('premium.premium.distance_flexible'),
                                        textColor: Colors.white,
                                      ),
                                      _buildFeature(
                                        icon: Icons.check_circle,
                                        iconColor: Colors.white,
                                        text: tr.tr('premium.premium.souls_access'),
                                        textColor: Colors.white,
                                      ),
                                      _buildFeature(
                                        icon: Icons.check_circle,
                                        iconColor: Colors.white,
                                        text: tr.tr('premium.premium.desires_access'),
                                        textColor: Colors.white,
                                      ),
                                      _buildFeature(
                                        icon: Icons.check_circle,
                                        iconColor: Colors.white,
                                        text: tr.tr('premium.premium.direct_message'),
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
                        
                        // Button
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9B7FED), Color(0xFF7B68EE)],
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF7B68EE).withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(tr.tr('premium.upgrade.coming_soon')),
                                  backgroundColor: Color(0xFF7B68EE),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
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
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 10.5,
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
