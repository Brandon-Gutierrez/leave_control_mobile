import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/api_service.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'reasons_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final ApiService _apiService = ApiService();

  bool _isProcessing = false;

  // Paleta
  static const primaryRed = Color(0xFFD32F2F);
  static const darkText = Color(0xFF111111);

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null)  return;

    final String qrData = barcodes.first.rawValue!;

    void handleError(String message){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      _scannerController.start();
      setState((){
        _isProcessing = false;
      });
    }

    setState((){
      _isProcessing = true;
    });

    await _scannerController.stop();

    try{
      final response = await _apiService.userStatus(qrData);
      if (!mounted) return;

      if (response == null) {
        // En caso de que la respuesta de la API sea nula
        handleError('Código QR inválido o vencido.');
        return;
      }

      final String message = response['message'] ?? 'Acción completada.';
      if (response['status'] == 1){
        handleError(message);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      if (response['action'] == 'showReasons') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ReasonPage(qrData: qrData)),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    } on SessionExpiredException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
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
      backgroundColor: darkText, // Fondo oscuro para resaltar la cámara
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Escanear QR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          // Control del Flash
          ValueListenableBuilder(
            valueListenable: _scannerController,
            builder: (context, state, child) {
              return IconButton(
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  color: Colors.white,
                ),
                onPressed: () => _scannerController.toggleTorch(),
              );
            },
          ),
          // Cambiar Cámara (frontal / trasera)
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Lector de Cámara
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // 2. Máscara/Overlay Minimalista
          Center(
            child: Container(
              width: frameSize,
              height: frameSize,
              decoration: BoxDecoration(
                border: Border.all(color: primaryRed, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // 3. Indicador de procesamiento
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // 4. Indicador de texto inferior
          Positioned(
            bottom: mediaQuery.padding.bottom + 32,
            left: 20,
            right: 20,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Apunta al código QR dentro del marco',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
