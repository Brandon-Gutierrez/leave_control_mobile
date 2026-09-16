import 'package:flutter/material.dart';

import 'login_page.dart';
import '../../services/api_service.dart';
import 'scan_page.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  String? _name;

  bool _isLeave = false;

  Timer? _timer;
  Duration _duration = Duration.zero;
  DateTime? _startDate;
  String? _dateLeave;

  // Paleta de colores
  static const primaryRed = Color(0xFFD32F2F);
  static const darkText = Color(0xFF111111);
  static const lightBg = Color(0xFFFAFAFA);

  @override
  //El estado inicial carga los datos del usuario
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _apiService.checkData();
      if (data != null && mounted) {
        setState(() {
          _name = data['name'];
          _isLeave = data['isLeave'] ?? false;
          _dateLeave = data['dateLeave'];
        });
        _initTimer();
      }
    } on SessionExpiredException catch (e) {
      _goToLogin(e.message);
    }
  }

  void _initTimer(){
    _timer?.cancel();
    if (!_isLeave || _dateLeave == null) {
      _startDate = null;
      return;
    }
    _startDate = DateTime.parse(_dateLeave!).toLocal();

    _updateDuration();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer){
      _updateDuration();
    });
  }

  void _updateDuration(){
    if (_startDate != null && mounted){
      final now = DateTime.now();
      setState((){
        final difference = now.difference(_startDate!);
        _duration = difference.isNegative ? Duration.zero : difference;
      });
    }
  }

  Future<void> _refreshData() => _loadUserData();

  @override
  void dispose(){
    _timer?.cancel();
    super.dispose();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatLeaveText(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    final date = DateTime.parse(rawDate).toLocal();
    final year = date.year;
    final month = _twoDigits(date.month);
    final day = _twoDigits(date.day);
    final hour = _twoDigits(date.hour);
    final minute = _twoDigits(date.minute);
    final second = _twoDigits(date.second);

    return 'Saliste el $day/$month/$year a las $hour:$minute:$second';
  }

  Future<void> _closeSession() async {
    await _apiService.logout();
    _goToLogin();
  }

  void _goToLogin([String? message]) {
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: primaryRed),
      );
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    final days = _duration.inDays;
    final hours = _twoDigits(_duration.inHours.remainder(24));
    final minutes = _twoDigits(_duration.inMinutes.remainder(60));
    final seconds = _twoDigits(_duration.inSeconds.remainder(60));

    final size = MediaQuery.sizeOf(context);
    final isSmallPhone = size.width < 360;
    final horizontalPadding = isSmallPhone ? 16.0 : 28.0;
    // Espacio entre el saludo y el contenido proporcional al alto de pantalla
    final topGap = (size.height * 0.08).clamp(24.0, 80.0);

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'REGISTRO DE SALIDAS TEMPORALES',
            style: TextStyle(
              color: darkText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: darkText, size: 22),
            tooltip: 'Cerrar sesión',
            onPressed: _closeSession,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
           onRefresh: _refreshData,
            color: Colors.white,            // Color del spinner
            backgroundColor: primaryRed,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      //LOGO
                      Center(
                        child: Image.asset(
                          'rsc/comteco.png',
                          height: isSmallPhone ? 40 : 50,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.business_rounded,
                            size: 40,
                            color: darkText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      //SALUDO
                      Text(
                        '¡Hola, ${_name ?? "Usuario"}!',
                        style: TextStyle(
                          fontSize: isSmallPhone ? 20 : 24,
                          fontWeight: FontWeight.w800,
                          color: darkText,
                          letterSpacing: -0.5,
                        ),
                      ),

                      SizedBox(height: topGap),
                      // INFORMACIÓN DE ESTADO(SI ESTA CON SALIDA ACTIVA)
                      if (_isLeave) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: isSmallPhone ? 12 : 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    color: primaryRed,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _formatLeaveText(_dateLeave),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: isSmallPhone ? 14 : 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  days > 0
                                  ? '$days días $hours:$minutes:$seconds'
                                  : '$hours:$minutes:$seconds',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: darkText,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tiempo transcurrido',
                                style: TextStyle(
                                  fontSize: isSmallPhone ? 14 : 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      Text(
                        _isLeave
                            ? 'Escanea el código QR para registrar tu retorno'
                            : 'Escanea el código QR para registrar tu salida',
                        style: TextStyle(
                          fontSize: isSmallPhone ? 15 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15.0),
                      // --- BOTÓN PRINCIPAL (ESCANEAR) ---
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                          label: const Text(
                            'Escanear código QR',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ScanPage()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ),
      ),
    );
  }
}
