import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_assistant_service.dart';

class VoiceCommandButton extends StatelessWidget {
  const VoiceCommandButton({super.key});

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceAssistantService>(context);

    return Positioned(
      right: 16,
      bottom: 16,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            if (voiceService.isListening) {
              voiceService.stopListening();
            } else {
              voiceService.startListening();
            }
          },
          backgroundColor:
              voiceService.isListening
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child:
                voiceService.isListening
                    ? const Icon(Icons.mic, key: ValueKey('mic_on'), size: 28)
                    : const Icon(
                      Icons.mic_none,
                      key: ValueKey('mic_off'),
                      size: 28,
                    ),
          ),
        ),
      ),
    );
  }
}
