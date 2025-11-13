import 'package:flutter/material.dart';
import '../widgets/status_bar.dart';
import '../widgets/bottle_card.dart';

class ReceivedBottlesScreen extends StatelessWidget {
  const ReceivedBottlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CustomStatusBar(),
            const SizedBox(height: 18),
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildTitle(),
            const SizedBox(height: 8),
            _buildNote(),
            const SizedBox(height: 16),
            Expanded(
              child: _buildBottlesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF151515),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Received Bottles',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF151515),
          ),
        ),
      ),
    );
  }

  Widget _buildNote() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Note: Bottles disappears into the sea 30 days after connection has not been established.',
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: Color(0xFF737373),
        ),
      ),
    );
  }

  Widget _buildBottlesList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildBottleRow(),
        const SizedBox(height: 20),
        _buildBottleRow(),
        const SizedBox(height: 20),
        _buildBottleRow(),
        const SizedBox(height: 20),
        _buildBottleRow(),
      ],
    );
  }

  Widget _buildBottleRow() {
    return Row(
      children: [
        Expanded(
          child: BottleCard(
            icon: Icons.mic,
            title: 'Voice Chat',
            hasAudio: true,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: BottleCard(
            icon: Icons.chat,
            title: 'Text',
            subtitle: 'Hi. Prior to our previous conversation...',
            backgroundColor: const Color(0xFFFCF8FF),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
