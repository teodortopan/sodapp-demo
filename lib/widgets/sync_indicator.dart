import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  static const Color lightBlue = Color(0xFF1292D3);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SyncService.instance.isSyncing,
      builder: (_, syncing, __) => syncing
          ? const SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFFFFD54F),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8F00)),
              ),
            )
          : Container(height: 2, color: lightBlue),
    );
  }
}
