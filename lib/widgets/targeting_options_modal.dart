import 'package:flutter/material.dart';
import '../services/entitlements_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/premium_screen.dart';
import '../i18n/app_localizations.dart';
import '../utils/french_departments.dart';

class TargetingOptionsModal extends StatefulWidget {
  final RangeValues currentAgeRange;
  final List<String> currentGenders;
  final double currentDistance;
  final List<String> currentDepartments;
  final Function(RangeValues ageRange, List<String> genders, double distance, List<String> departments) onApply;

  const TargetingOptionsModal({
    super.key,
    required this.currentAgeRange,
    required this.currentGenders,
    required this.currentDistance,
    required this.currentDepartments,
    required this.onApply,
  });

  @override
  State<TargetingOptionsModal> createState() => _TargetingOptionsModalState();
}

class _TargetingOptionsModalState extends State<TargetingOptionsModal> {
  late RangeValues _ageRange;
  late List<String> _selectedGenders;
  late double _distance;
  late List<String> _selectedDepartments;
  bool _isPremium = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ageRange = widget.currentAgeRange;
    _selectedGenders = List.from(widget.currentGenders);
    _distance = widget.currentDistance;
    _selectedDepartments = List.from(widget.currentDepartments);
    _checkPremium();
  }

  Future<void> _checkPremium() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final isPremium = await EntitlementsService().isPremium(userId);
      if (mounted) {
        setState(() {
          _isPremium = isPremium;
          _isLoading = false;
          // Force 150km if not premium
          if (!_isPremium) {
            _distance = 150;
            _selectedDepartments = []; // Reset to full country if not premium
          }
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF0AC5C5))),
      );
    }

    return Container(
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Title
          const Text(
            'Targeting Criteria',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF151515),
            ),
          ),
          const SizedBox(height: 24),

          // Age Range
          Text(
            'Age Range: ${_ageRange.start.round()} - ${_ageRange.end.round()}',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF151515),
            ),
          ),
          RangeSlider(
            values: _ageRange,
            min: 18,
            max: 99,
            divisions: 81,
            activeColor: const Color(0xFF0AC5C5),
            inactiveColor: const Color(0xFFE0E0E0),
            onChanged: (values) {
              setState(() {
                _ageRange = values;
              });
            },
          ),
          
          const SizedBox(height: 24),

          // Gender
          const Text(
            'Gender (Select multiple)',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF151515),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Man', 'Woman', 'Non-binary'].map((gender) {
              final isSelected = _selectedGenders.contains(gender);
              return FilterChip(
                label: Text(gender),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedGenders.add(gender);
                    } else {
                      _selectedGenders.remove(gender);
                    }
                  });
                },
                selectedColor: const Color(0xFF0AC5C5).withValues(alpha: 0.2),
                checkmarkColor: const Color(0xFF0AC5C5),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? const Color(0xFF0AC5C5) : const Color(0xFF5D5D5D),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF0AC5C5) : const Color(0xFFE0E0E0),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Target Departments
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Target Departments',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF151515),
                ),
              ),
              if (!_isPremium)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PremiumScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFFC107)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Icon(Icons.lock, size: 12, color: Color(0xFFA07800)),
                         SizedBox(width: 4),
                         Text(
                          'Premium',
                          style: TextStyle(
                            fontFamily: 'Montserrat', 
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: Color(0xFFA07800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_isPremium)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _showDepartmentSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedDepartments.isEmpty 
                                ? 'Select Departments' 
                                : _selectedDepartments.length == frenchDepartments.length
                                    ? 'All France'
                                    : '${_selectedDepartments.length} Departments Selected',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                              color: Color(0xFF151515),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF737373)),
                      ],
                    ),
                  ),
                ),
                if (_selectedDepartments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _selectedDepartments.take(3).join(', ') + (_selectedDepartments.length > 3 ? '...' : ''),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Color(0xFF737373),
                      ),
                    ),
                  ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.public, color: Color(0xFF0AC5C5), size: 20),
                  SizedBox(width: 12),
                  Text(
                    'All France (Random)',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: Color(0xFF5D5D5D),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),
          
          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_ageRange, _selectedGenders, _distance, _selectedDepartments);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0AC5C5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Apply Criteria',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDepartmentSelector() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _DepartmentSelectionDialog(
        selectedDepartments: _selectedDepartments,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedDepartments = result;
      });
    }
  }
}

class _DepartmentSelectionDialog extends StatefulWidget {
  final List<String> selectedDepartments;

  const _DepartmentSelectionDialog({required this.selectedDepartments});

  @override
  State<_DepartmentSelectionDialog> createState() => _DepartmentSelectionDialogState();
}

class _DepartmentSelectionDialogState extends State<_DepartmentSelectionDialog> {
  late List<String> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.selectedDepartments);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Departments',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                     setState(() {
                       if (_tempSelected.length == frenchDepartments.length) {
                         _tempSelected.clear();
                       } else {
                         _tempSelected = List.from(frenchDepartments);
                       }
                     });
                  },
                  child: Text(
                    _tempSelected.length == frenchDepartments.length ? 'Clear All' : 'Select All',
                    style: const TextStyle(color: Color(0xFF0AC5C5)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 400, // Fixed height for list
            child: ListView.builder(
              itemCount: frenchDepartments.length,
              itemBuilder: (context, index) {
                final dept = frenchDepartments[index];
                final isSelected = _tempSelected.contains(dept);
                return CheckboxListTile(
                  title: Text(dept, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 14)),
                  value: isSelected,
                  activeColor: const Color(0xFF0AC5C5),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _tempSelected.add(dept);
                      } else {
                        _tempSelected.remove(dept);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _tempSelected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0AC5C5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


}

