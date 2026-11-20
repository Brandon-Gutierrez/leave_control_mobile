import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../auth/presentation/login_page.dart';
import '../data/leave_service.dart';
import 'home_page.dart';
import 'reasons_page.dart';
import 'widgets/location_status_pill.dart';
import 'widgets/scan_overlay.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final LeaveService _leaveService = LeaveService();
  final LocationService _locationService = LocationService();

  bool _isProcessing = false;

  /// Estado de la ubicación; null hasta la primera comprobación.
  LocationReadiness? _readiness;
  StreamSubscription<LocationReadiness>? _readinessSub;

  @override
  void initState() {
    super.initState();
    // Enciende el GPS y lo mantiene encendido mientras el escáner está abierto:
    // al escanear, la lectura precisa ya suele estar lista y la validación de
    // ubicación no falla la primera vez. El aviso de abajo refleja su estado.
    _readinessSub = _locationService.readiness().listen((state) {
      if (mounted) setState(() => _readiness = state);
    });
  }

  @override
  void dispose() {
    _readinessSub?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    final String qrData = barcodes.first.rawValue!;

    void handleError(String message) {
      showErrorPopup(context, message);
      _scannerController.start();
      setState(() {
        _isProcessing = false;
      });
    }

    setState(() {
      _isProcessing = true;
    });

    await _scannerController.stop();

    try {
      final scan = await _leaveService.scanQr(qrData);
      if (!mounted) return;

      showSuccessPopup(context, scan.message);

      if (scan.showsReasons) {
        // El servidor devuelve un comprobante (leaveTicket) distinto del QR
        // escaneado: es lo que hay que enviar al confirmar el motivo, no el
        // texto del QR original.
        final leaveTicket = scan.leaveTicket;
        final ticketExpiresAt = scan.leaveTicketExpiresAt;
        if (leaveTicket == null || leaveTicket.isEmpty) {
          handleError(
            'No se pudo iniciar la selección de motivo. Vuelva a escanear.',
          );
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReasonsPage(
              qrData: qrData,
              leaveTicket: leaveTicket,
              ticketExpiresAt: ticketExpiresAt,
            ),
          ),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    } on ApiRequestException catch (e) {
      if (mounted) handleError(e.message);
    } on LocationException catch (e) {
      if (mounted) handleError(e.message);
    } on SessionExpiredException catch (e) {
      if (!mounted) return;
      showErrorPopup(context, e.message);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        handleError('Ocurrió un error al procesar el QR.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Marco del escáner proporcional al teléfono
    final frameSize = (mediaQuery.size.shortestSide * 0.7).clamp(200.0, 320.0);

    return Scaffold(
      backgroundColor:
          AppColors.darkText, // Fondo oscuro para resaltar la cámara
      body: ValueListenableBuilder<MobileScannerState>(
        valueListenable: _scannerController,
        builder: (context, state, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              //CAMARA
              MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
              ),
              //MARCO DE ESCANEO
              ScanOverlay(frameSize: frameSize),

              //ESTADO DE LA CAMARA
              if (state.error != null)
                _buildCameraError(state.error!)
              else if (!state.isInitialized)
                _buildCameraStarting(),

              //PROCESAMIENTO DEL QR
              if (state.isInitialized && _isProcessing) _buildProcessing(),

              //UBICACION Y TEXTO INFERIOR
              if (!_isProcessing && state.isInitialized)
                Positioned(
                  bottom: mediaQuery.padding.bottom + 40,
                  left: 24,
                  right: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LocationStatusPill(readiness: _readiness),
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Apunta el código QR dentro del marco',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              //BARRA SUPERIOR (siempre encima de lo demás)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: _buildTopBar(state)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(MobileScannerState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundButton(
            tooltip: 'Volver',
            icon: Icons.chevron_left_rounded,
            iconSize: 28,
            onTap: () => Navigator.pop(context),
          ),
          const Text(
            'Escanear QR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          _RoundButton(
            tooltip: state.torchState == TorchState.on
                ? 'Apagar linterna'
                : 'Encender linterna',
            icon: state.torchState == TorchState.on
                ? Icons.flashlight_on_rounded
                : Icons.flashlight_off_rounded,
            onTap: state.isInitialized
                ? () => _scannerController.toggleTorch()
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Verificando ubicación y código...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraStarting() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 20),
          Text(
            'Iniciando cámara...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraError(MobileScannerException error) {
    final isPermission =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: AppColors.darkText,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPermission
                      ? Icons.no_photography_rounded
                      : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  isPermission
                      ? 'Necesitamos permiso de la cámara para escanear el código QR.'
                      : 'No se pudo iniciar la cámara.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPermission
                      ? 'Actívalo en los ajustes de tu teléfono y vuelve a intentar.'
                      : error.errorCode.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
                ),
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: 'Reintentar',
                  icon: Icons.refresh_rounded,
                  onPressed: () => _scannerController.start(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón circular translúcido sobre la cámara (volver, linterna).
class _RoundButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;

  const _RoundButton({
    required this.tooltip,
    required this.icon,
    this.iconSize = 22,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: Colors.white.withValues(alpha: onTap == null ? 0.07 : 0.14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                size: iconSize,
                color: Colors.white.withValues(alpha: onTap == null ? 0.4 : 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
