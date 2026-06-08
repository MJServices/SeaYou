import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A universal avatar widget that uses disk cache for instant display.
/// After the first download, the image appears immediately on all subsequent views.
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? placeholder;
  final Color? backgroundColor;

  const AppAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.placeholder,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    final defaultPlaceholder = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? const Color(0xFFE3E3E3),
      child: Icon(
        Icons.person,
        size: radius * 0.9,
        color: const Color(0xFFAAAAAA),
      ),
    );

    if (url == null || url.isEmpty) {
      return placeholder ?? defaultPlaceholder;
    }

    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
        backgroundColor: backgroundColor ?? const Color(0xFFE3E3E3),
      ),
      // Show placeholder immediately — no spinner
      placeholder: (context, url) => placeholder ?? defaultPlaceholder,
      // On error, fall back to placeholder
      errorWidget: (context, url, error) => placeholder ?? defaultPlaceholder,
      // Keep images in disk cache for 7 days
      maxHeightDiskCache: 400,
      maxWidthDiskCache: 400,
    );
  }
}
