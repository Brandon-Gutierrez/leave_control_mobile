import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum PopupKind { success, error }

/// Aviso flotante arriba de la pantalla: verde = salió bien, rojo = algo
/// falló. Se cierra solo a los 7 segundos o con la (X); no bloquea la pantalla.
void showAppPopup(
  BuildContext context,
  String message, {
  PopupKind kind = PopupKind.success,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;

  void remove() {
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _PopupCard(message: message, kind: kind, onClose: remove),
  );
  overlay.insert(entry);
}

void showErrorPopup(BuildContext context, String message) =>
    showAppPopup(context, message, kind: PopupKind.error);

void showSuccessPopup(BuildContext context, String message) =>
    showAppPopup(context, message);

class _PopupCard extends StatefulWidget {
  final String message;
  final PopupKind kind;
  final VoidCallback onClose;

  const _PopupCard({
    required this.message,
    required this.kind,
    required this.onClose,
  });

  @override
  State<_PopupCard> createState() => _PopupCardState();
}

class _PopupCardState extends State<_PopupCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 7), widget.onClose);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.kind == PopupKind.error;
    final color = isError ? AppColors.danger : AppColors.success;
    final tint = isError ? AppColors.dangerBg : AppColors.successBg;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          liveRegion: true,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimens.radiusButton),
              border: Border.all(color: color.withValues(alpha: 0.25)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isError ? Icons.priority_high_rounded : Icons.check_rounded,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isError ? 'Algo salió mal' : 'Listo',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
