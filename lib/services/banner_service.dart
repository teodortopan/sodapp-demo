import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../screens/notifications_screen.dart';
import '../widgets/admin_message_banner.dart';

const String notificationsRouteName = '/notifications';

class BannerServiceRouteObserver extends NavigatorObserver {
  String? currentRouteName;

  void _set(Route<dynamic>? route) {
    currentRouteName = route?.settings.name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _set(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _set(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _set(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _set(previousRoute);
  }
}

class BannerService {
  static final BannerService instance = BannerService._();
  BannerService._();

  final routeObserver = BannerServiceRouteObserver();

  GlobalKey<NavigatorState>? _navigatorKey;
  OverlayEntry? _currentEntry;
  int? _lastShownMessageId;

  void bindNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  void resetForUser() {
    _lastShownMessageId = null;
    _dismissCurrent();
  }

  void showAdminMessage(AppNotificationWithMessageId msg) {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final messageId = msg.messageId;
    if (messageId == null) return;
    if (messageId == _lastShownMessageId) return;
    if (routeObserver.currentRouteName == notificationsRouteName) return;

    final overlay = _navigatorKey?.currentState?.overlay;
    if (overlay == null) return;

    _lastShownMessageId = messageId;
    _dismissCurrent();

    final notification = msg.notification;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: AdminMessageBanner(
          title: notification.title.isEmpty
              ? 'Mensaje del administrador'
              : notification.title,
          body: _preview(notification.body),
          onTap: () {
            _dismissCurrent();
            _navigateToNotifications();
          },
          onDismiss: _dismissCurrent,
        ),
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
  }

  String _preview(String body) {
    if (body.length <= 120) return body;
    return '${body.substring(0, 120)}...';
  }

  void _dismissCurrent() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  void _navigateToNotifications() {
    _navigatorKey?.currentState?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: notificationsRouteName),
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }
}
