import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../auth/presentation/login_page.dart';
import '../data/leave_service.dart';
import '../models/leave_reason.dart';
import 'home_page.dart';
import 'widgets/countdown_ring.dart';

class ReasonsPage extends StatefulWidget {
  final String qrData;

  /// Comprobante que devolvió el servidor al escanear el QR. Es lo que hay
  /// que enviar al confirmar el motivo (no el texto del QR original).
  final String leaveTicket;

  /// Momento en el que el comprobante deja de ser válido. Si es null no se
  /// muestra cuenta atrás (p. ej. en pruebas).
  final DateTime? ticketExpiresAt;

  /// Permite inyectar un [LeaveService] de prueba (p. ej. en tests de widgets).
  final LeaveService? leaveService;

  /// Reloj de la cuenta atrás (pruebas); por defecto la hora real.
  final DateTime Function()? clock;

  const ReasonsPage({
    super.key,
    required this.qrData,
    required this.leaveTicket,
    this.ticketExpiresAt,
    this.leaveService,
    this.clock,
  });

  @override
  State<ReasonsPage> createState() => _ReasonsPageState();
}

class _ReasonsPageState extends State<ReasonsPage> {
  late final LeaveService _leaveService = widget.leaveService ?? LeaveService();

  String _namePremise = '';
  String? _selectedReason;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<LeaveReasonOption> _reasons = [];

  Timer? _countdownTimer;
  int? _secondsLeft;

  /// Segundos con los que empezó la cuenta atrás: el anillo parte lleno.
  int _totalSeconds = 1;

  @override
  void initState() {
    super.initState();
    _namePremise = widget.qrData.split('+').first;
    _loadReasons();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  DateTime _now() => (widget.clock ?? DateTime.now)();

  /// Cuenta atrás visible: el usuario tiene hasta que el comprobante venza
  /// para elegir el motivo. Si se acaba el tiempo, vuelve solo al inicio.
  void _startCountdown() {
    final expiresAt = widget.ticketExpiresAt;
    if (expiresAt == null) return;

    _totalSeconds = expiresAt.difference(_now()).inSeconds.clamp(1, 3600);

    void tick() {
      if (!mounted) return;
      final remaining = expiresAt.difference(_now()).inSeconds;
      setState(() => _secondsLeft = remaining < 0 ? 0 : remaining);
      if (remaining <= 0) {
        _countdownTimer?.cancel();
        _onTicketExpired();
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _onTicketExpired() {
    if (!mounted || _isSubmitting) return;
    showErrorPopup(
      context,
      'Se acabó el tiempo para elegir el motivo. Vuelva a escanear el QR.',
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _refreshData() => _loadReasons();

  Future<void> _loadReasons() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _leaveService.getReasons(_namePremise);
      if (!mounted) return;
      setState(() {
        if (data == null) {
          _errorMessage = 'No se pudieron cargar los motivos de salida';
        } else {
          _reasons = data;
        }
        _isLoading = false;
      });
    } on SessionExpiredException catch (e) {
      _goToLogin(e.message);
    }
  }

  void _goToLogin(String message) {
    if (!mounted) return;
    showErrorPopup(context, message);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  /// Tocar un motivo registra la salida de inmediato, sin otro botón.
  Future<void> _confirmSelection(String reason) async {
    if (_isSubmitting) return;

    setState(() {
      _selectedReason = reason;
      _isSubmitting = true;
    });

    try {
      await _leaveService.confirmLeave(
        _namePremise,
        reason,
        widget.leaveTicket,
      );

      // Verificar si el widget sigue activo en el árbol tras la llamada asíncrona
      if (!mounted) return;
      _countdownTimer?.cancel();

      showSuccessPopup(context, 'Salida registrada correctamente');

      // Navegar a HomePage limpiando las pantallas anteriores de la pila
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } on SessionExpiredException catch (e) {
      _goToLogin(e.message);
    } on ApiRequestException catch (e) {
      if (!mounted) return;
      // El comprobante del escaneo ya no sirve: no tiene sentido dejar al
      // usuario reintentando con el mismo motivo, hay que volver a escanear.
      const expiredCodes = {'LEAVE_TICKET_EXPIRED', 'LEAVE_TICKET_INVALID'};
      if (expiredCodes.contains(e.code)) {
        _countdownTimer?.cancel();
        showErrorPopup(context, e.message);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      showErrorPopup(context, e.message);
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      showErrorPopup(context, e.message);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      showErrorPopup(context, 'Ocurrió un error inesperado en el servidor.');
    }
  }

  /// «Predio Prado»; si el nombre ya empieza con «Predio» se deja igual.
  String get _premiseLabel {
    final name = _namePremise.trim();
    if (name.isEmpty) return 'Predio';
    return name.toLowerCase().startsWith('predio') ? name : 'Predio $name';
  }

  double _sidePadding(double width) => width > 600
      ? (width - 520) / 2
      : width < 360
      ? 16.0
      : 22.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = _sidePadding(width);

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BackButton(onTap: () => Navigator.maybePop(context)),
                  if (_secondsLeft != null)
                    CountdownRing(
                      secondsLeft: _secondsLeft!,
                      totalSeconds: _totalSeconds,
                    )
                  else
                    const SizedBox(height: 54),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: Colors.white,
                backgroundColor: AppColors.primaryRed,
                child: _buildBody(pad),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(double pad) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(pad, 14, pad, 24),
      children: [
        const Text(
          'Elige tu motivo de salida',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.15,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 4),
        const Text('Toca uno para registrar tu salida', style: AppText.caption),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _premiseLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._buildContent(),
      ],
    );
  }

  List<Widget> _buildContent() {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primaryRed),
          ),
        ),
      ];
    }

    if (_errorMessage != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.info),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: 'Reintentar',
                icon: Icons.refresh_rounded,
                onPressed: _loadReasons,
              ),
            ],
          ),
        ),
      ];
    }

    if (_reasons.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Text(
            'No hay motivos disponibles para este predio.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ),
      ];
    }

    return [for (final reason in _reasons) _buildReasonTile(reason)];
  }

  Widget _buildReasonTile(LeaveReasonOption option) {
    final blocked = option.isBlocked;
    // El motivo tocado, mientras se registra la salida.
    final isSelected =
        !blocked && _isSubmitting && _selectedReason == option.name;
    final radius = BorderRadius.circular(AppDimens.radiusButton);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: blocked ? AppColors.infoBg : Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          // Un motivo que llegó a su límite no se puede elegir; mientras se
          // registra una salida tampoco se puede tocar otro.
          onTap: blocked || _isSubmitting
              ? null
              : () => _confirmSelection(option.name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryRed
                    : blocked
                    ? const Color(0xFFE6E6E6)
                    : const Color(0xFFE0E0E0),
                width: isSelected ? 2.0 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: blocked
                              ? const Color(0xFF777777)
                              : isSelected
                              ? AppColors.primaryRed
                              : AppColors.darkText,
                        ),
                      ),
                      if (blocked)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            option.blockedNote!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Mientras se registra la salida con este motivo.
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  )
                else if (!blocked)
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: Color(0xFFBBBBBB),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado de volver, igual al de las demás pantallas.
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Volver',
      child: Semantics(
        button: true,
        label: 'Volver',
        excludeSemantics: true,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: onTap,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.chevron_left_rounded,
                size: 26,
                color: AppColors.darkText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
