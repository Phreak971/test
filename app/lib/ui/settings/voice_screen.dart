import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../nav/voice.dart';
import '../../state/nav_controller.dart';
import '../../state/providers.dart';
import '../hud.dart';
import '../paywall/paywall_screen.dart';

/// Circular persona avatar: glyph on the persona colour (no likenesses).
class PersonaAvatar extends StatelessWidget {
  const PersonaAvatar({super.key, required this.persona, this.size = 52, this.selected = false});

  final VoicePersona persona;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = Color(persona.accent);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Color.lerp(c, Colors.white, 0.25)!, c]),
        border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 3 : 1.5),
      ),
      alignment: Alignment.center,
      child: Text(persona.emoji, style: TextStyle(fontSize: size * 0.48)),
    );
  }
}

class VoiceScreen extends ConsumerWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final s = ref.watch(settingsProvider);
    final premium = ref.watch(entitlementProvider).premium;
    final lang = Localizations.localeOf(context).languageCode;

    return Theme(
      data: buildAppTheme(hud),
      child: Scaffold(
        appBar: AppBar(title: Text(l.voiceTitle)),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SwitchListTile.adaptive(
              value: !s.voiceMuted,
              activeTrackColor: hud.accent,
              secondary: Icon(s.voiceMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: hud.accent),
              title: Text(s.voiceMuted ? l.unmute : l.mute, style: TextStyle(color: hud.text, fontWeight: FontWeight.w600)),
              onChanged: (v) => ref.read(settingsProvider.notifier).setVoiceMuted(!v),
            ),
            const Divider(),
            for (final p in voicePersonas)
              ListTile(
                minTileHeight: 72,
                leading: PersonaAvatar(persona: p, selected: p.id == s.voiceId),
                title: Row(
                  children: [
                    Flexible(child: Text(p.name, style: displayStyle(hud, 17))),
                    if (p.isPremium && !premium) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock_rounded, size: 16, color: hud.muted),
                    ],
                  ],
                ),
                subtitle: Text(p.tagline, style: TextStyle(color: hud.muted)),
                selected: p.id == s.voiceId,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l.voicePreview,
                      icon: Icon(Icons.play_circle_rounded, color: hud.accent, size: 32),
                      onPressed: () => ref.read(speakerProvider).speak(samplePhrase(p, lang), p, lang),
                    ),
                    if (p.id == s.voiceId) Icon(Icons.check_rounded, color: hud.accent),
                  ],
                ),
                onTap: () {
                  if (p.isPremium && !premium) {
                    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen()));
                    return;
                  }
                  HapticFeedback.selectionClick();
                  ref.read(settingsProvider.notifier).setVoice(p.id);
                  ref.read(speakerProvider).speak(samplePhrase(p, lang), p, lang);
                },
              ),
          ],
        ),
      ),
    );
  }
}
