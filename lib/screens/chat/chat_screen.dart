import 'package:flutter/material.dart';
import 'chat_list_screen.dart';

/// Main Chat Screen - Entry point for chat functionality
/// Directly shows the chat list following Figma design flow
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatListScreen();
  }
}
