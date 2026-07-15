import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/app_database.dart';
import '../demo/demo_mode.dart';
import '../services/auth_service.dart';
import '../utils/argentina_time.dart';
import '../utils/app_tokens.dart';
import 'clientes_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotificationWithMessageId> _notifications = [];
  // Per-notification reparto label, keyed by clienteId. Built once on load
  // so we don't re-query the DB per render. Notifications without a
  // clienteId (or whose cliente has been deleted) map to null / absent.
  final Map<int, String> _repartoNameByClienteId = {};
  VoidCallback? _dbListener;
  Future<void>? _reloadInFlight;

  @override
  void initState() {
    super.initState();
    _dbListener = () {
      _reloadInFlight ??= _loadNotifications().whenComplete(() {
        _reloadInFlight = null;
      });
    };
    AppDatabase.instance.addDataListener(_dbListener!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotifications());
  }

  @override
  void dispose() {
    if (_dbListener != null) {
      AppDatabase.instance.removeDataListener(_dbListener!);
    }
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final notifications = await AppDatabase.instance
        .getAllNotificationsWithMessageIds();
    if (!mounted) return;

    // Build the clienteId → repartoName cache. One pass over repartos +
    // one getCliente per unique clienteId. Different clientes may live in
    // different repartos so we can't shortcut by reparto.
    final userId = AuthService.currentUser?.id;
    final repartoNameById = <int, String>{};
    if (userId != null) {
      final repartos = await AppDatabase.instance.getRepartosForUser(userId);
      for (final r in repartos) {
        repartoNameById[r.id] = r.nombre;
      }
    }
    final byCliente = <int, String>{};
    final seen = <int>{};
    for (final entry in notifications) {
      final n = entry.notification;
      final cid = n.clienteId;
      if (cid == null || !seen.add(cid)) continue;
      final cliente = await AppDatabase.instance.getCliente(cid);
      if (cliente == null) continue;
      final name = repartoNameById[cliente.repartoId];
      if (name != null && name.isNotEmpty) byCliente[cid] = name;
    }
    if (!mounted) return;

    setState(() {
      _notifications = notifications;
      _repartoNameByClienteId
        ..clear()
        ..addAll(byCliente);
    });
    await AppDatabase.instance.markAllNotificationsRead();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.card,
        surfaceTintColor: tokens.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: tokens.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: tokens.text,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notificaciones',
          style: TextStyle(
            color: tokens.text,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: tokens.text),
            color: tokens.card,
            onSelected: (v) async {
              if (v == 'clear') {
                if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
                for (final entry in _notifications) {
                  final n = entry.notification;
                  final messageId = entry.messageId;
                  if (n.type == 'admin_message' && messageId != null) {
                    await AppDatabase.instance.dismissAdminMessage(
                      n.id,
                      messageId,
                    );
                  } else {
                    await AppDatabase.instance.deleteNotification(n.id);
                  }
                }
                if (mounted) setState(() => _notifications.clear());
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'clear',
                child: Text(
                  'Borrar todas',
                  style: TextStyle(color: tokens.text),
                ),
              ),
            ],
          ),
        ],
        shape: Border(bottom: BorderSide(color: tokens.cardBorder, width: 1)),
      ),
      body: SafeArea(
        child: _notifications.isEmpty
            ? _emptyState(tokens)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _notifications.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final entry = _notifications[i];
                  final n = entry.notification;
                  final accent = _notifAccent(n.type, tokens);

                  return Dismissible(
                    key: ValueKey(n.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async =>
                        kDemoAllowLiveFlow || !blockDemoAction(context),
                    onDismissed: (_) async {
                      final messageId = entry.messageId;
                      if (n.type == 'admin_message' && messageId != null) {
                        await AppDatabase.instance.dismissAdminMessage(
                          n.id,
                          messageId,
                        );
                      } else if (n.clienteId != null) {
                        await AppDatabase.instance.dismissNotif(
                          n.clienteId!,
                          n.type,
                        );
                        await AppDatabase.instance.deleteNotification(n.id);
                      } else {
                        await AppDatabase.instance.deleteNotification(n.id);
                      }
                      if (mounted) {
                        setState(
                          () => _notifications.removeWhere(
                            (entry) => entry.notification.id == n.id,
                          ),
                        );
                      }
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: tokens.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: tokens.danger,
                        size: 22,
                      ),
                    ),
                    child: _NotificationCard(
                      n: n,
                      tokens: tokens,
                      accent: accent,
                      icon: _notifIcon(n.type),
                      timeAgo: _formatTimeAgo(n.createdAt),
                      repartoName: n.clienteId == null
                          ? null
                          : _repartoNameByClienteId[n.clienteId!],
                      onTap: n.clienteId == null
                          ? null
                          : () => _openClienteNotification(n),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _emptyState(AppTokens tokens) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              color: tokens.textMuted,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Sin notificaciones',
            style: TextStyle(
              color: tokens.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Te avisaremos cuando algo necesite tu atención',
            style: TextStyle(color: tokens.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'deuda_weeks':
        return Icons.warning_amber_rounded;
      case 'inactive_weeks':
        return Icons.person_off;
      case 'stock_low':
        return Icons.inventory_2;
      case 'admin_message':
        return Icons.forum_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _notifAccent(String type, AppTokens tokens) {
    switch (type) {
      case 'deuda_weeks':
        return tokens.warn;
      case 'inactive_weeks':
        return tokens.textMuted;
      case 'stock_low':
        return tokens.danger;
      case 'admin_message':
        return tokens.success;
      default:
        return tokens.primaryBlue;
    }
  }

  String _formatTimeAgo(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final displayTime = dt.isUtc
          ? dt.toUtc().subtract(const Duration(hours: 3))
          : dt;
      final diff = argentinaTime().difference(displayTime);
      if (diff.inMinutes < 1) return 'ahora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}sem';
    } catch (_) {
      return '';
    }
  }

  Future<void> _openClienteNotification(AppNotification n) async {
    final clienteId = n.clienteId;
    if (clienteId == null) return;

    await AppDatabase.instance.markNotificationRead(n.id);

    final cliente = await AppDatabase.instance.getCliente(clienteId);
    if (cliente == null) return;

    final userId = AuthService.currentUser?.id;
    if (userId == null) return;

    final repartos = await AppDatabase.instance.getRepartosForUser(userId);
    Reparto? reparto;
    for (final r in repartos) {
      if (r.id == cliente.repartoId) {
        reparto = r;
        break;
      }
    }
    if (reparto == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientesScreen(
          repartoId: cliente.repartoId,
          repartoNombre: reparto!.nombre,
          // Open on the cliente's own day so the focused row is actually
          // in view (otherwise Clientes lands on today and the highlight
          // never fires because the cliente isn't in the visible list).
          initialSelectedDay: cliente.diaSemana,
          focusClienteId: clienteId,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.n,
    required this.tokens,
    required this.accent,
    required this.icon,
    required this.timeAgo,
    this.repartoName,
    this.onTap,
  });

  final AppNotification n;
  final AppTokens tokens;
  final Color accent;
  final IconData icon;
  final String timeAgo;
  final String? repartoName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 14,
            bottom: 14,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        n.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSub,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          if (repartoName != null &&
                              repartoName!.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                '·',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            // Reparto label — preserve the sodero's
                            // original casing, no transform.
                            Flexible(
                              child: Text(
                                repartoName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }
}
