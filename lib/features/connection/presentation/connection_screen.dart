import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/server_endpoint.dart';
import '../../../core/network/komga/api_failure.dart';
import '../../../app/widgets/ink_screen_header.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../application/session_controller.dart';
import '../domain/session.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({
    super.key,
    this.addServer = false,
    this.editing,
    this.modal = false,
  });
  final bool addServer;
  final SavedSession? editing;
  final bool modal;
  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _secret = TextEditingController();
  AuthenticationMethod _method = AuthenticationMethod.apiKey;
  bool _showSecret = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = widget.editing;
    if (saved != null) {
      _url.text = saved.endpoint.uri.toString();
      _method = saved.credentials.method;
      _username.text = saved.credentials.username ?? '';
      _secret.text = saved.credentials.secret;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving ||
        ref.read(sessionProvider).phase == SessionPhase.authenticating) {
      return;
    }
    if (!_form.currentState!.validate()) return;
    // Close the platform session before disabling fields or changing routes.
    // Password managers can otherwise deliver a result to the old input client.
    TextInput.finishAutofillContext(shouldSave: false);
    FocusScope.of(context).unfocus();
    final credentials = _method == AuthenticationMethod.apiKey
        ? Credentials.apiKey(_secret.text.trim())
        : Credentials.basic(_username.text, _secret.text);
    if (!widget.addServer) {
      await ref.read(sessionProvider.notifier).login(_url.text, credentials);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final controller = ref.read(sessionProvider.notifier);
      if (widget.editing != null) {
        await controller.updateServer(widget.editing!, _url.text, credentials);
      } else {
        await controller.addServer(_url.text, credentials);
      }
      if (mounted) {
        if (widget.modal) {
          Navigator.of(context).pop();
        } else {
          context.pop();
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error) {
            ActiveConnectionAlreadySaved() =>
              'This connection is already active.',
            ApiFailure failure => failure.message,
            _ => 'Unable to save this connection. Try again.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final busy = _saving || session.phase == SessionPhase.authenticating;
    return Scaffold(
      appBar: widget.addServer && !widget.modal
          ? const InkScreenHeader(title: LText('Add server'))
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                key: ValueKey(_method),
                onDisposeAction: AutofillContextAction.cancel,
                child: Form(
                  key: _form,
                  child: Column(
                    // The Form has a GlobalKey, so key its contents too: moving
                    // the Form to a new autofill group otherwise grafts old IDs.
                    key: ValueKey(_method),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!widget.addServer) ...[
                        const Center(child: InkoraWordmark(size: 42)),
                        const SizedBox(height: 20),
                      ] else ...[
                        LText(
                          widget.editing == null
                              ? 'Connect another server'
                              : 'Edit connection',
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      const LText(
                        'Connect your Komga server to start reading.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const Key('server-url'),
                        controller: _url,
                        enabled: !busy,
                        decoration: InputDecoration(
                          labelText: context.tr("Server URL"),
                          hintText: context.tr("https://komga.example.com"),
                        ),
                        keyboardType: TextInputType.url,
                        autofillHints: null,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          try {
                            ServerEndpoint(value?.trim() ?? '');
                            return null;
                          } catch (_) {
                            return context.tr(
                              'Enter an HTTPS URL, including any server subpath.',
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<AuthenticationMethod>(
                        segments: const [
                          ButtonSegment(
                            value: AuthenticationMethod.apiKey,
                            label: LText('API key'),
                          ),
                          ButtonSegment(
                            value: AuthenticationMethod.basic,
                            label: LText('Username / email'),
                          ),
                        ],
                        selected: {_method},
                        onSelectionChanged: busy
                            ? null
                            : (selection) {
                                TextInput.finishAutofillContext(
                                  shouldSave: false,
                                );
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  _method = selection.single;
                                  _secret.clear();
                                  _showSecret = false;
                                });
                              },
                      ),
                      if (_method == AuthenticationMethod.basic) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('username'),
                          controller: _username,
                          enabled: !busy,
                          decoration: InputDecoration(
                            labelText: context.tr("Username or email"),
                          ),
                          autofillHints: const [AutofillHints.username],
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              value == null ||
                                  value.trim().isEmpty ||
                                  value.contains(':')
                              ? context.tr('Enter a username or email.')
                              : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('secret'),
                        controller: _secret,
                        enabled: !busy,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            _method == AuthenticationMethod.apiKey
                                ? 'API key'
                                : 'Password',
                          ),
                          suffixIcon: IconButton(
                            tooltip: context.tr(
                              _showSecret ? 'Hide secret' : 'Show secret',
                            ),
                            onPressed: () =>
                                setState(() => _showSecret = !_showSecret),
                            icon: Icon(
                              _showSecret ? InkIcons.eyeSlash : InkIcons.eye,
                            ),
                          ),
                        ),
                        obscureText: !_showSecret,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.visiblePassword,
                        autofillHints: _method == AuthenticationMethod.basic
                            ? const [AutofillHints.password]
                            : null,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: busy ? null : (_) => _submit(),
                        validator: (value) =>
                            value == null ||
                                value.isEmpty ||
                                (_method == AuthenticationMethod.apiKey &&
                                    (value.trim().isEmpty ||
                                        value.contains(RegExp(r'[\r\n]'))))
                            ? context.tr(
                                _method == AuthenticationMethod.apiKey
                                    ? 'Enter your API key.'
                                    : 'Enter your password.',
                              )
                            : null,
                      ),
                      if ((widget.addServer
                              ? _error
                              : _error ?? session.message) !=
                          null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: LText(
                            (widget.addServer
                                ? _error
                                : _error ?? session.message)!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : LText(
                                widget.addServer ? 'Save server' : 'Sign in',
                              ),
                      ),
                      if (widget.modal)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const LText('Cancel'),
                        ),
                      if (!widget.addServer &&
                          session.phase == SessionPhase.expired)
                        TextButton(
                          onPressed: () =>
                              ref.read(sessionProvider.notifier).logout(),
                          child: const LText('Retry signing out'),
                        ),
                      if (!widget.addServer)
                        ...ref
                                .watch(savedSessionsProvider)
                                .asData
                                ?.value
                                .map(
                                  (saved) => ListTile(
                                    title: Text(saved.endpoint.uri.host),
                                    subtitle: Text(saved.user.email),
                                    trailing: const Icon(InkIcons.caretRight),
                                    enabled: !busy,
                                    onTap: () async {
                                      if (_saving) return;
                                      setState(() {
                                        _saving = true;
                                        _error = null;
                                      });
                                      try {
                                        await ref
                                            .read(sessionProvider.notifier)
                                            .selectServer(saved.accountId);
                                      } catch (_) {
                                        if (mounted) {
                                          setState(
                                            () => _error = 'Unable to open this saved connection.',
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _saving = false);
                                        }
                                      }
                                    },
                                  ),
                                ) ??
                            [],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
