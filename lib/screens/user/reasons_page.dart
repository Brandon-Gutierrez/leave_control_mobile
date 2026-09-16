import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'home_page.dart';
import 'login_page.dart';

class ReasonPage extends StatefulWidget {
  final String qrData;
  const ReasonPage({super.key, required this.qrData});

  @override
  State<ReasonPage> createState() => _ReasonPageState();
}

class _ReasonPageState extends State<ReasonPage>{

  final ApiService _apiService = ApiService();

  String _namePremise = '';
  String? _selectedReason;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<String> _reasons = [];

  static const primaryRed = Color(0xFFD32F2F);
  static const darkText = Color(0xFF111111);
  static const lightBg = Color(0xFFFAFAFA);

  @override
  void initState(){
    super.initState();
    _namePremise = widget.qrData.split('+').first;
    _loadReasons();
  }

  Future<void> _refreshData() => _loadReasons();

  Future<void> _loadReasons() async {
    setState((){
      _isLoading = true;
      _errorMessage = null;
    });

    try{
      final data = await _apiService.getReasons(_namePremise);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
    bool result = await _apiService.confirmLeave(
      _namePremise,
      _selectedReason!,
      widget.qrData,
    );

    // Verificar si el widget sigue activo en el árbol tras la llamada asíncrona
    if (!mounted) return;

    if (!result) {
      // Reestablecer estado si falla la confirmación
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo registrar la salida. Intenta nuevamente.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar SnackBar de éxito
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Salida registrada correctamente'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    // Navegar a HomePage limpiando las pantallas anteriores de la pila
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  } on SessionExpiredException catch (e) {
    _goToLogin(e.message);
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ocurrió un error inesperado en el servidor.'),
        backgroundColor: Colors.red,
      ),
    );
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
                      fontSize: 15,
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
                height: 52,
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
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
