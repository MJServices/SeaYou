import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final bool isLoading;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine effective size (diameter)
    final size = radius * 2;

    Widget content = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEEEEEE), // Skeleton/Background color
      ),
      child: ClipOval(
        child: _buildInnerContent(),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }

  Widget _buildInnerContent() {
    if (isLoading) {
      return _buildSkeleton();
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildSkeleton();
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildSkeleton() {
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0AC5C5)),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.person,
        size: radius, // Icon size relative to radius
        color: const Color(0xFFBDBDBD),
      ),
    );
  }
}
