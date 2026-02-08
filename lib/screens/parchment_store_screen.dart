import 'package:flutter/material.dart';

class ParchmentStoreScreen extends StatefulWidget {
  const ParchmentStoreScreen({super.key});

  @override
  State<ParchmentStoreScreen> createState() => _ParchmentStoreScreenState();
}

class _ParchmentStoreScreenState extends State<ParchmentStoreScreen> {
  int _selectedOptionIndex = 1; // Default to middle option (Popular)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8C6FF), // Light Pink top
              Color(0xFFFFFDE7), // Light Yellow bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Close Button
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              const SizedBox(height: 10),

              // Header
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Obtenir des Parchemins',
                        style: TextStyle(
                          fontFamily: 'Montserrat', // Or PlayfairDisplay
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white, 
                          shadows: [
                            Shadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Image.asset(
                        'assets/images/letter.png',
                        width: 40,
                        height: 40,
                        errorBuilder: (_,__,___) => const Icon(Icons.history_edu, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Jusqu\'à 5x plus de\nchances de Matcher !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay', // Elegant
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3E2723), // Dark Brown
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    _buildOption(
                      index: 0,
                      count: 3,
                      pricePerUnit: '3.99 €/chacun',
                      badge: null,
                    ),
                    const SizedBox(height: 16),
                    _buildOption(
                      index: 1,
                      count: 12,
                      pricePerUnit: '2.79 €/chacun',
                      badge: 'Populaire',
                      savings: 'Économise 30%',
                    ),
                    const SizedBox(height: 16),
                    _buildOption(
                      index: 2,
                      count: 50,
                      pricePerUnit: '1.60 €/chacun',
                      badge: 'Le plus avantageux',
                      savings: 'Économise 60%',
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Continue Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Simulated Purchase...')),
                    );
                    // Implement purchase logic later
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8A2BE2), // Deep Purple
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8A2BE2).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Continuer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

  Widget _buildOption({
    required int index,
    required int count,
    required String pricePerUnit,
    String? badge,
    String? savings,
  }) {
    final isSelected = _selectedOptionIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedOptionIndex = index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF3E5F5) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF8A2BE2) : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (savings != null || badge == 'Populaire') ...[
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       if (badge == 'Populaire')
                         Text(
                           'Populaire',
                           style: TextStyle(
                             fontFamily: 'Montserrat',
                             fontSize: 12,
                             fontWeight: FontWeight.w600,
                             color: Colors.black87,
                           ),
                         )
                       else 
                         // Le plus avantageux handling if badge non-populaire
                         badge != null ? Text(
                           badge,
                           style: TextStyle(
                             fontFamily: 'Montserrat',
                             fontSize: 12,
                             fontWeight: FontWeight.w600,
                             color: Color(0xFF4CAF50), // Green for advantage
                           ),
                         ) : SizedBox(),

                       if (savings != null)
                         Text(
                           savings,
                           style: TextStyle(
                             fontFamily: 'Montserrat',
                             fontSize: 12,
                             fontWeight: FontWeight.w700,
                             color: Colors.black87,
                           ),
                         ),
                     ],
                   ),
                   const Divider(height: 24),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Count with background
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE1BEE7) : const Color(0xFFFFF9C4), // Purple or Yellow bg
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count parchemins',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    
                    Text(
                      pricePerUnit,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Selection Checkmark? Or just border.
          // Screenshot doesn't show checkmark clearly, just border.
        ],
      ),
    );
  }
}
