import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle displayText = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.black,
  );

  static const TextStyle bodyText = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.grey,
  );

  static const TextStyle labelText = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.grey,
  );

  static const TextStyle largeTitle = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 40,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.black,
  );

  static const TextStyle mediumTitle = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.black,
  );
}
