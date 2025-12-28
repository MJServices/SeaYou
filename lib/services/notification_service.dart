import 'package:flutter/material.dart';
import '../widgets/in_app_notification.dart';

/// Singleton service to manage in-app notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  OverlayEntry? _currentOverlay;
  final List<_NotificationData> _queue = [];
  bool _isShowing = false;

  /// Show an in-app notification
  void show({
    required BuildContext context,
    required String title,
    required String message,
    Widget? icon,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    final data = _NotificationData(
      title: title,
      message: message,
      icon: icon,
      onTap: onTap,
      duration: duration,
    );

    _queue.add(data);
    _processQueue(context);
  }

  void _processQueue(BuildContext context) {
    if (_isShowing || _queue.isEmpty) return;

    _isShowing = true;
    final data = _queue.removeAt(0);

    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: InAppNotification(
            title: data.title,
            message: data.message,
            icon: data.icon,
            onTap: data.onTap,
            duration: data.duration,
            onDismiss: () {
              _dismiss();
              // Process next notification after a short delay
              Future.delayed(const Duration(milliseconds: 300), () {
                if (context.mounted) {
                  _processQueue(context);
                }
              });
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  void _dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
    _isShowing = false;
  }

  /// Clear all pending notifications
  void clearAll() {
    _queue.clear();
    _dismiss();
  }
}

class _NotificationData {
  final String title;
  final String message;
  final Widget? icon;
  final VoidCallback? onTap;
  final Duration duration;

  _NotificationData({
    required this.title,
    required this.message,
    this.icon,
    this.onTap,
    required this.duration,
  });
}
