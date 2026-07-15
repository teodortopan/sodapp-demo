import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_tokens.dart';

class AdminMessageBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Duration duration;

  const AdminMessageBanner({
    super.key,
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<AdminMessageBanner> createState() => _AdminMessageBannerState();
}

class _AdminMessageBannerState extends State<AdminMessageBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _timer?.cancel();
    widget.onDismiss();
  }

  void _tap() {
    if (_dismissed) return;
    _dismissed = true;
    _timer?.cancel();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final top = MediaQuery.of(context).padding.top + 8;
    final width = MediaQuery.of(context).size.width - 32;

    return SlideTransition(
      position: _offset,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: Center(
          child: SizedBox(
            width: width,
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.up,
              onDismissed: (_) => _dismiss(),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _tap,
                  borderRadius: BorderRadius.circular(16),
                  splashColor: tokens.success.withValues(alpha: 0.16),
                  highlightColor: tokens.success.withValues(alpha: 0.08),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.success, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 28,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 22,
                          color: tokens.success,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textSub,
                                  fontSize: 12.5,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _dismiss,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: tokens.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
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
