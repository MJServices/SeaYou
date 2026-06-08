import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      return _buildPlaceholder();
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        key: ValueKey(imageUrl),
        fit: BoxFit.cover,
        // Show placeholder icon instantly — no spinner
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
        fadeInDuration: const Duration(milliseconds: 150),
        maxHeightDiskCache: 600,
        maxWidthDiskCache: 600,
      );
    }

    return _buildPlaceholder();
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
