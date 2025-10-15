import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_command_button.dart';
import 'home_screen.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    _readHelpContent();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _readHelpContent() async {
    await _flutterTts.speak(
      "Welcome to the help section. Here you can find information about using the app and voice commands.",
    );
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceAssistantService>(context);

    if (voiceService.lastCommand != null) {
      final command = voiceService.lastCommand!;

      if (command.type == VoiceCommandType.navigation) {
        final destination = command.parameters['destination'] as String?;

        if (destination == 'home') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          });
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection('Voice Commands', [
                  'Say "home" to go to the home screen',
                  'Say "cart" to view your shopping cart',
                  'Say "wishlist" to view your wishlist',
                  'Say "my orders" to view your order history',
                  'Say "help" to view this help screen',
                  'Say "back" or "return" to go back',
                ], Icons.mic),
                const SizedBox(height: 24),
                _buildSection('Shopping', [
                  'Browse products by category',
                  'Add items to your cart or wishlist',
                  'View product details by tapping on a product',
                  'Use voice commands to navigate and shop',
                ], Icons.shopping_bag),
                const SizedBox(height: 24),
                _buildSection('Accessibility Features', [
                  'Voice navigation throughout the app',
                  'Screen reader support',
                  'High contrast mode',
                  'Large text options',
                  'Voice feedback for all actions',
                ], Icons.accessibility_new),
                const SizedBox(height: 24),
                _buildSection('Contact Support', [
                  'Email: support@electronicstore.com',
                  'Phone: 1234567890',
                  'Hours: Monday - Friday, 9 AM - 5 PM',
                ], Icons.support_agent),
              ],
            ),
          ),
          const VoiceCommandButton(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> items, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
