import 'package:flutter/material.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../services/app_controller.dart';
import '../services/playback_hub.dart';
import '../services/recording_service.dart';
import 'brand.dart';
import 'practice_panel.dart';

class SpeakPage extends StatelessWidget {
  const SpeakPage({super.key, required this.app, required this.recorder, required this.playback});
  final AppController app;
  final RecordingService recorder;
  final PlaybackHub playback;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    return ListView(
      padding: const EdgeInsets.fromLTRB(SlSpace.page, 0, SlSpace.page, SlSpace.page),
      children: [
        SlPanel(
          color: c.raised,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.speakQuestion, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(l.speakHelp, style: TextStyle(color: c.muted)),
            ],
          ),
        ),
        const SizedBox(height: SlSpace.md),
        SlPanel(
          child: PracticePanel(
            app: app,
            recorder: recorder,
            playback: playback,
            kind: 'free-speaking',
            showAllHistory: true,
          ),
        ),
      ],
    );
  }
}
