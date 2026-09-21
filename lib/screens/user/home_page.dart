import 'package:flutter/material.dart';
import 'dart:async';

import 'login_page.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
  /// Permite inyectar un [ApiService] de prueba (p. ej. en tests de widgets).
  final ApiService? apiService;

  const HomePage({super.key, this.apiService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  String? _name;
  String? _reason;

  bool _isLeave = false;
  bool _isLoading = true;
  bool _hasError = false;

  Timer? _timer;
  Duration _duration = Duration.zero;
  DateTime? _startDate;
  String? _dateLeave;

  // Paleta de colores
  static const primaryRed = AppColors.primaryRed;
  static const darkText = AppColors.darkText;
  static const lightBg = AppColors.lightBg;

  @override
  //El estado inicial carga los datos del usuario
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Solo se muestra la pantalla de carga completa la primera vez;
    // un refresh posterior no debe hacer desaparecer los datos ya visibles.
    final isFirstLoad = _name == null;
    if (isFirstLoad && mounted) setState(() => _isLoading = true);

    try {
      final data = await _apiService.checkData();
      if (!mounted) return;

      if (data == null) {
        setState(() => _isLoading = false);
        if (isFirstLoad) {
          setState(() => _hasError = true);
        } else {
          _showSnackBar('No se pudo actualizar. Desliza para reintentar.');
        }
        return;
      }

      setState(() {
        _hasError = false;
        _isLoading = false;
        _name = data['name'];
        _isLeave = data['isLeave'] ?? false;
        _dateLeave = data['dateLeave'];
        _reason = data['reason'];
      });
      _initTimer();
    } on SessionExpiredException catch (e) {
      _goToLogin(e.message);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.grey.shade800),
    );
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

  void _goToScan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.logout, color: darkText, size: AppDimens.iconSize),
            tooltip: 'Cerrar sesión',
            onPressed: _closeSession,
          ),
        ],
      ),
      // Nunca queda una pantalla en blanco: siempre hay una vista de carga,
      // de error con reintento, o el contenido ya cargado.
      body: SafeArea(
        child: _isLoading ? _buildLoadingView() : _buildBody(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'rsc/comteco.png',
            height: 50,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.business_rounded,
              size: 40,
              color: darkText,
            ),
          ),
          const SizedBox(height: 28),
          const CircularProgressIndicator(color: primaryRed),
          const SizedBox(height: 16),
          Text(
            'Cargando tu información...',
            style: AppText.body.copyWith(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.white,            // Color del spinner
      backgroundColor: primaryRed,
      child: _hasError ? _buildErrorView() : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No se pudo cargar tu información',
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Revisa tu conexión e inténtalo de nuevo',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: AppDimens.buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: _loadUserData,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final days = _duration.inDays;
    final hours = _twoDigits(_duration.inHours.remainder(24));
    final minutes = _twoDigits(_duration.inMinutes.remainder(60));
    final seconds = _twoDigits(_duration.inSeconds.remainder(60));

    final size = MediaQuery.sizeOf(context);
    final isSmallPhone = size.width < 360;
    final horizontalPadding = isSmallPhone ? 16.0 : 24.0;

    return SingleChildScrollView(
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
              const SizedBox(height: 20),

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
              const SizedBox(height: 20),

              // --- ACCIÓN PRINCIPAL: ESCANEAR (siempre lo primero y más visible) ---
              _buildScanCta(isSmallPhone),

              // INFORMACIÓN DE ESTADO (SI ESTA CON SALIDA ACTIVA)
              if (_isLeave) ...[
                const SizedBox(height: 20),
                _buildStatusCard(isSmallPhone, days, hours, minutes, seconds),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanCta(bool isSmallPhone) {
    final title = _isLeave ? 'Registrar mi retorno' : 'Registrar mi salida';
    final subtitle = _isLeave
        ? 'Escanea el código QR al volver'
        : 'Escanea el código QR al salir';

    return Material(
      color: primaryRed,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        onTap: _goToScan,
        child: Padding(
          padding: EdgeInsets.all(isSmallPhone ? 16 : 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallPhone ? 17 : 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isSmallPhone, int days, String hours, String minutes, String seconds) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 20,
        horizontal: isSmallPhone ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
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
          // MOTIVO DE LA SALIDA
          if (_reason != null && _reason!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey.shade600, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Motivo: $_reason',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isSmallPhone ? 14 : 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
