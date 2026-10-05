import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum PopupKind { success, error }

/// Aviso flotante arriba de la pantalla: verde = salió bien, rojo = algo
/// falló. Se cierra solo a los 7 segundos o con la (X); no bloquea la pantalla.
void showAppPopup(BuildContext context, String message, {PopupKind kind = PopupKind.success}) {
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

void showSuccessPopup(BuildContext context, String message) => showAppPopup(context, message);

class _PopupCard extends StatefulWidget {
  final String message;
  final PopupKind kind;
  final VoidCallback onClose;

  const _PopupCard({required this.message, required this.kind, required this.onClose});

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
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border(left: BorderSide(color: color, width: 8)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(isError ? Icons.error_rounded : Icons.check_circle_rounded, color: color, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isError ? 'Algo salió mal' : 'Listo',
                      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.message, style: const TextStyle(fontSize: 15, color: AppColors.darkText)),
                  ],
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
    );
  }
}
