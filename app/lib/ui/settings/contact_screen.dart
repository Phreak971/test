import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../l10n/app_localizations.dart';
import '../hud.dart';
import 'settings_screen.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

/// Validates contact form input. Returns an error key or null.
String? validateContact(String email, String message) {
  if (email.trim().isEmpty || message.trim().isEmpty) return 'empty';
  if (!_emailRe.hasMatch(email.trim())) return 'email';
  return null;
}

/// Contact form. Sends via the user's mail app (no backend needed); the
/// reference app posted to a helpdesk API.
class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _email = TextEditingController();
  final _message = TextEditingController();
  String? _error;
  String? _errorKey;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = L.of(context);
    final err = validateContact(_email.text, _message.text);
    _errorKey = err;
    setState(() => _error = err == null ? null : (err == 'empty' ? l.contactErrorEmpty : l.contactErrorEmail));
    if (err != null) return;
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      query: _encode({'subject': 'Overworld support ($appVersion)', 'body': '${_message.text.trim()}\n\n— ${_email.text.trim()}'}),
    );
    final ok = await launchUrl(uri);
    if (!mounted) return;
    setState(() {
      _sent = ok;
      if (!ok) _error = L.of(context).somethingWrong;
    });
  }

  static String _encode(Map<String, String> params) =>
      params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    return Theme(
      data: buildAppTheme(hud),
      child: Scaffold(
        appBar: AppBar(title: Text(l.contactTitle)),
        body: SafeArea(
          child: _sent
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mark_email_read_rounded, color: hud.accentText, size: 64),
                        const SizedBox(height: 12),
                        Text(l.contactSentTitle, style: displayStyle(hud, 22), textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text(
                          l.contactSentBody,
                          style: TextStyle(color: hud.muted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        PrimaryButton(hud: hud, label: l.done, onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      l.contactEmail,
                      style: TextStyle(color: hud.muted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      style: TextStyle(color: hud.text),
                      decoration: InputDecoration(
                        hintText: l.contactEmailHint,
                        labelText: l.contactEmail,
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        errorText: _errorKey == 'email' ? l.contactErrorEmail : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.contactMessage,
                      style: TextStyle(color: hud.muted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _message,
                      minLines: 5,
                      maxLines: 10,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: hud.text),
                      decoration: InputDecoration(
                        hintText: l.contactMessageHint,
                        labelText: l.contactMessage,
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                      ),
                    ),
                    // Email problems show on the field itself.
                    if (_error != null && _errorKey != 'email')
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _error!,
                            style: TextStyle(color: hud.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    PrimaryButton(hud: hud, label: l.contactSend, icon: Icons.send_rounded, onPressed: _send),
                  ],
                ),
        ),
      ),
    );
  }
}
