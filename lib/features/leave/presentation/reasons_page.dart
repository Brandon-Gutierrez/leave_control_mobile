import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_popup.dart';
import '../../auth/presentation/login_page.dart';
import '../data/leave_service.dart';
import 'home_page.dart';

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

  const ReasonsPage({
    super.key,
    required this.qrData,
    required this.leaveTicket,
    this.ticketExpiresAt,
    this.leaveService,
  });

  @override
  State<ReasonsPage> createState() => _ReasonsPageState();
}

class _ReasonsPageState extends State<ReasonsPage>{

  late final LeaveService _leaveService = widget.leaveService ?? LeaveService();

  String _namePremise = '';
  String? _selectedReason;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<String> _reasons = [];

  Timer? _countdownTimer;
  int? _secondsLeft;

  static const primaryRed = AppColors.primaryRed;
  static const darkText = AppColors.darkText;
  static const lightBg = AppColors.lightBg;

  @override
  void initState(){
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

  /// Cuenta atrás visible: el usuario tiene hasta que el comprobante venza
  /// para elegir el motivo. Si se acaba el tiempo, vuelve solo al inicio.
  void _startCountdown() {
    final expiresAt = widget.ticketExpiresAt;
    if (expiresAt == null) return;

    void tick() {
      if (!mounted) return;
      final remaining = expiresAt.difference(DateTime.now()).inSeconds;
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
    showErrorPopup(context, 'Se acabó el tiempo para elegir el motivo. Vuelva a escanear el QR.');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _refreshData() => _loadReasons();

  Future<void> _loadReasons() async {
    setState((){
      _isLoading = true;
      _errorMessage = null;
    });

    try{
      final data = await _leaveService.getReasons(_namePremise);
      if (!mounted) return;
      setState((){
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

  Future<void> _confirmSelection() async {
  if (_selectedReason == null || _isSubmitting) return;

  setState(() {
    _isSubmitting = true;
  });

  try {
    await _leaveService.confirmLeave(
      _namePremise,
      _selectedReason!,
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('SELECCIONAR MOTIVO DE SALIDA',
          style: TextStyle(
            color:darkText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkText),
        actions: [
          if (_secondsLeft != null) _buildCountdownBadge(),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: Colors.white,
          backgroundColor: primaryRed,
          child: _buildBody(),
        ),
      ),
      bottomNavigationBar: _buildBottomAction(),
    );
  }

  Widget _buildCountdownBadge() {
    final seconds = _secondsLeft ?? 0;
    final isUrgent = seconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isUrgent ? primaryRed.withValues(alpha: 0.12) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: isUrgent ? primaryRed : Colors.grey.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            '${seconds}s',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isUrgent ? primaryRed : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryRed),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _loadReasons,
                  icon: const Icon(Icons.refresh_rounded, color: primaryRed),
                  label: const Text('Reintentar', style: TextStyle(color: primaryRed)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_reasons.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: Center(
              child: Text(
                'No hay motivos disponibles para este predio.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adaptabilidad según el ancho del teléfono (o tablet en horizontal)
        final double width = constraints.maxWidth;
        final double horizontalPadding = width > 600
            ? (width - 520) / 2
            : width < 360
                ? 16.0
                : 28.0;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16.0),
          children: [
            Text(
              'Selecciona la razón de tu salida',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            ..._reasons.map((reason) => _buildReasonTile(reason)),
          ],
        );
      },
    );
  }

  Widget _buildReasonTile(String reason) {
    final isSelected = _selectedReason == reason;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _selectedReason = reason;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? primaryRed : Colors.grey.shade300,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: isSelected ? primaryRed : Colors.grey.shade400,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? darkText : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    final isSmallPhone = MediaQuery.sizeOf(context).width < 360;

    return Container(
      color: lightBg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallPhone ? 16.0 : 28.0,
            vertical: isSmallPhone ? 16.0 : 20.0,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SizedBox(
                height: AppDimens.buttonHeight,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade500,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _selectedReason != null && !_isSubmitting ? _confirmSelection : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Confirmar Selección',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
