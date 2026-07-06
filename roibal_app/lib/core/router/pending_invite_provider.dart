import 'package:flutter_riverpod/legacy.dart';

/// Token de invitación pendiente de procesar después del login OAuth.
/// Se setea en JoinEventScreen cuando el usuario no está autenticado,
/// y el router lo consume post-login para redirigir a /join/:token.
final pendingInviteTokenProvider = StateProvider<String?>((ref) => null);
