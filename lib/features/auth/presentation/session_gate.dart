import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'home_page.dart';
import 'login_page.dart';

/// Pantalla de arranque: comprueba si ya hay una sesión válida (cookie
/// guardada en disco) y salta directo a [HomePage]; si no, muestra
/// [LoginPage]. Sin esto la app siempre pedía iniciar sesión de nuevo, sin
/// importar si la cookie seguía siendo válida.
class SessionGate extends StatefulWidget {
  final ApiService? apiService;

  const SessionGate({super.key, this.apiService});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  bool _hasNetworkError = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  // Usa /auth/me (no depende del sistema externo de salidas): si ese sistema
  // falla, la sesión sigue siendo válida y no se debe mandar al login.
  Future<void> _check() async {
    setState(() => _hasNetworkError = false);
    try {
      final hasSession = await _apiService.hasActiveSession();
      if (!mounted) return;
      _goTo(hasSession ? const HomePage() : const LoginPage());
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasNetworkError = true);
    }
  }

  void _goTo(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.loginBg,
      body: SafeArea(
        child: Center(
          child: _hasNetworkError ? _buildError() : _buildLoading(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'rsc/comteco.png',
          height: 60,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.business_rounded,
            size: 48,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 28),
        const CircularProgressIndicator(color: AppColors.primaryRed),
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No se pudo comprobar tu sesión',
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
              onPressed: _check,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _goTo(const LoginPage()),
            child: const Text('Iniciar sesión'),
          ),
        ],
      ),
    );
  }
}
