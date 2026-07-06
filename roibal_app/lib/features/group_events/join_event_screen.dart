import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/supabase_config.dart';
import '../../core/router/pending_invite_provider.dart';

class JoinEventScreen extends ConsumerStatefulWidget {
  final String token;
  const JoinEventScreen({super.key, required this.token});

  @override
  ConsumerState<JoinEventScreen> createState() => _JoinEventScreenState();
}

class _JoinEventScreenState extends ConsumerState<JoinEventScreen> {
  bool _loading = true;
  bool _joining = false;
  String? _error;
  Map<String, dynamic>? _event;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    try {
      // Buscar el link de invitación por token
      final linkRow = await supabase
          .from('group_invite_links')
          .select('*, group_events(*)')
          .eq('token', widget.token)
          .maybeSingle();

      if (linkRow == null) {
        setState(() {
          _error = 'El link de invitación no existe o ya no es válido.';
          _loading = false;
        });
        return;
      }

      // Verificar expiración
      final expiresAt = linkRow['expires_at'] as String?;
      if (expiresAt != null && DateTime.parse(expiresAt).isBefore(DateTime.now())) {
        setState(() {
          _error = 'Este link de invitación ha expirado.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _event = linkRow['group_events'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar la invitación: $e';
        _loading = false;
      });
    }
  }

  Future<void> _join(String status) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      // Guardar token para retomar después del login
      ref.read(pendingInviteTokenProvider.notifier).state = widget.token;
      context.go('/login');
      return;
    }

    setState(() => _joining = true);
    try {
      final eventId = _event!['id'] as String;

      // Buscar si ya existe un row para este usuario en este evento
      final existing = await supabase
          .from('group_members')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) {
        // Ya es miembro → actualizar status si corresponde
        if (existing['status'] != 'accepted' || status == 'declined') {
          await supabase.from('group_members').update({
            'status': status,
            'joined_at': status == 'accepted' ? DateTime.now().toIso8601String() : null,
          }).eq('id', existing['id'] as String);
        }
      } else {
        // Buscar si hay una fila con su email (invitado por email)
        final byEmail = user.email != null
            ? await supabase
                .from('group_members')
                .select()
                .eq('event_id', eventId)
                .eq('invited_email', user.email!)
                .isFilter('user_id', null)
                .maybeSingle()
            : null;

        if (byEmail != null) {
          await supabase.from('group_members').update({
            'user_id': user.id,
            'display_name': user.userMetadata?['full_name'] as String? ?? user.email,
            'status': status,
            'joined_at': status == 'accepted' ? DateTime.now().toIso8601String() : null,
          }).eq('id', byEmail['id'] as String);
        } else {
          await supabase.from('group_members').insert({
            'event_id': eventId,
            'user_id': user.id,
            'display_name': user.userMetadata?['full_name'] as String? ?? user.email,
            'status': status,
            'joined_at': status == 'accepted' ? DateTime.now().toIso8601String() : null,
          });
        }
      }

      if (!mounted) return;
      if (status == 'accepted') {
        context.go('/groups/$eventId');
      } else {
        context.go('/groups');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = supabase.auth.currentSession != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Invitación a evento grupal')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Ir al inicio'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.group_add_outlined, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Te invitaron a unirte a:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _event?['name'] as String? ?? '',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        if (!isLoggedIn) ...[
                          const Text(
                            'Necesitás iniciar sesión para aceptar la invitación.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _joining ? null : () => _join('accepted'),
                            icon: const Icon(Icons.login),
                            label: const Text('Iniciar sesión y unirme'),
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton(
                                onPressed: _joining ? null : () => _join('declined'),
                                child: const Text('Declinar'),
                              ),
                              const SizedBox(width: 16),
                              FilledButton.icon(
                                onPressed: _joining ? null : () => _join('accepted'),
                                icon: _joining
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.check),
                                label: const Text('Unirme'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
        ),
      ),
    );
  }
}
