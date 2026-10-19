import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_popup.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_page.dart';
import '../data/leave_service.dart';
import '../models/leave_status.dart';
import 'date_range_sheet.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
  /// Permiten inyectar servicios de prueba (p. ej. en tests de widgets).
  final LeaveService? leaveService;
  final AuthService? authService;

  const HomePage({super.key, this.leaveService, this.authService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final LeaveService _leaveService = widget.leaveService ?? LeaveService();
  late final AuthService _authService = widget.authService ?? AuthService();
  String? _name;
  String? _reason;
  String? _role;
  String? _jobTitle;
  String? _photoUrl;
  Map<String, LeaveStat> _stats = {};

  /// Fechas elegidas en el calendario; null = hoy (siempre al día).
  DateTimeRange? _range;
  LeaveStat? _rangeStat;
  bool _rangeLoading = false;
  List<UnreturnedLeave> _unreturnedLeaves = [];

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
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
  }

  /// Al volver a la app (desde segundo plano) se actualiza el estado.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_loadUserData());
  }

  Future<void> _loadUserData() async {
    // Solo se muestra la pantalla de carga completa la primera vez;
    // un refresh posterior no debe hacer desaparecer los datos ya visibles.
    final isFirstLoad = _name == null;
    if (isFirstLoad && mounted) setState(() => _isLoading = true);

    try {
      final status = await _leaveService.fetchLeaveStatus();
      if (!mounted) return;

      if (status == null) {
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
        _name = status.name;
        _isLeave = status.isLeave;
        _dateLeave = status.dateLeave;
        _reason = status.reason;
        _role = status.role;
        _jobTitle = status.jobTitle;
        _photoUrl = status.photoUrl;
        _stats = status.stats;
        _unreturnedLeaves = status.unreturnedLeaves;
      });
      _initTimer();
      if (_range != null) unawaited(_loadRange(_range!));
    } on SessionExpiredException catch (e) {
      _goToLogin(e.message);
    }
  }

  /// Sin rango: las del último mes. Con rango: solo las de esas fechas
  /// (hoy nunca se advierte, porque aún puede marcar su retorno).
  List<UnreturnedLeave> get _visibleUnreturned => _range != null
      ? (_rangeStat?.unreturnedLeaves ?? const [])
      : _unreturnedLeaves;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _isSingleDay(DateTimeRange r) =>
      _dateOnly(r.start) == _dateOnly(r.end);

  Future<void> _pickRange() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDateRangeSheet(
      context,
      initial: _range ?? DateTimeRange(start: today, end: today),
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    _showRange(
      DateTimeRange(start: _dateOnly(picked.start), end: _dateOnly(picked.end)),
    );
  }

  /// Mueve la fecha un día; al llegar a hoy vuelve al modo "hoy".
  void _shiftDay(int delta) {
    final base = _range?.start ?? _dateOnly(DateTime.now());
    final day = DateTime(base.year, base.month, base.day + delta);
    _showRange(DateTimeRange(start: day, end: day));
  }

  void _showRange(DateTimeRange range) {
    final today = _dateOnly(DateTime.now());
    if (_isSingleDay(range) && !range.start.isBefore(today)) {
      _clearRange();
      return;
    }
    setState(() {
      _range = range;
      _rangeStat = null;
    });
    unawaited(_loadRange(range));
  }

  Future<void> _loadRange(DateTimeRange range) async {
    setState(() => _rangeLoading = true);
    try {
      final stat = await _leaveService.fetchRangeStats(range.start, range.end);
      if (!mounted || _range != range) return;
      setState(() {
        _rangeStat = stat;
        _rangeLoading = false;
      });
      if (stat == null) _showSnackBar('No se pudo consultar esas fechas.');
    } on SessionExpiredException catch (e) {
      _goToLogin(e.message);
    }
  }

  void _clearRange() => setState(() {
    _range = null;
    _rangeStat = null;
    _rangeLoading = false;
  });

  String _formatDay(DateTime d) =>
      '${_twoDigits(d.day)}/${_twoDigits(d.month)}/${d.year}';

  /// "Hoy", "Ayer", una fecha o un rango, según lo elegido.
  String _rangeTitle() {
    final r = _range;
    if (r == null) return 'Hoy';
    if (!_isSingleDay(r)) {
      return '${_formatDay(r.start)} – ${_formatDay(r.end)}';
    }
    final today = _dateOnly(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    return r.start == yesterday ? 'Ayer' : _formatDay(r.start);
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    showErrorPopup(context, message);
  }

  void _initTimer() {
    _timer?.cancel();
    if (!_isLeave || _dateLeave == null) {
      _startDate = null;
      return;
    }
    _startDate = DateTime.parse(_dateLeave!).toLocal();

    _updateDuration();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateDuration();
    });
  }

  void _updateDuration() {
    if (_startDate != null && mounted) {
      final now = DateTime.now();
      setState(() {
        final difference = now.difference(_startDate!);
        _duration = difference.isNegative ? Duration.zero : difference;
      });
    }
  }

  Future<void> _refreshData() => _loadUserData();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    await _authService.logout();
    _goToLogin();
  }

  void _goToLogin([String? message]) {
    if (!mounted) return;
    if (message != null) {
      showErrorPopup(context, message);
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _goToScan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanPage()),
    );
    // Al volver del escáner se actualiza el estado de salida.
    if (mounted) unawaited(_loadUserData());
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
            icon: const Icon(
              Icons.logout,
              color: AppColors.danger,
              size: AppDimens.iconSize,
            ),
            tooltip: 'Cerrar sesión',
            onPressed: _closeSession,
          ),
        ],
      ),
      // Nunca queda una pantalla en blanco: siempre hay una vista de carga,
      // de error con reintento, o el contenido ya cargado.
      body: SafeArea(child: _isLoading ? _buildLoadingView() : _buildBody()),
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
            errorBuilder: (_, _, _) =>
                const Icon(Icons.business_rounded, size: 40, color: darkText),
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
      color: Colors.white, // Color del spinner
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
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
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
    final size = MediaQuery.sizeOf(context);
    final pad = size.width < 360 ? 16.0 : 20.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildIdentity(pad),
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 18, pad, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusPanel(),
                    const SizedBox(height: 14),
                    _buildScanButton(),
                    const SizedBox(height: 28),
                    _buildStats(),
                    if (_visibleUnreturned.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildUnreturnedWarnings(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Quién es: foto, nombre y rol real (lo envía el servidor).
  Widget _buildIdentity(double pad) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 16),
      child: Row(
        children: [
          _Avatar(photoUrl: _photoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name ?? 'Usuario',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: darkText,
                    height: 1.15,
                  ),
                ),
                if (_role != null && _role!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        size: 18,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _role!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_jobTitle != null && _jobTitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _jobTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Estado en un vistazo: verde = adentro, gris = fuera.
  Widget _buildStatusPanel() {
    // Adentro = verde apagado; fuera = gris neutro (sin un tercer color).
    final color = _isLeave ? AppColors.darkText : AppColors.success;
    final bg = _isLeave ? AppColors.infoBg : AppColors.successBg;
    final days = _duration.inDays;
    final hms =
        '${_twoDigits(_duration.inHours.remainder(24))}:${_twoDigits(_duration.inMinutes.remainder(60))}:${_twoDigits(_duration.inSeconds.remainder(60))}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: color, width: 8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isLeave
                    ? Icons.directions_walk_rounded
                    : Icons.check_circle_rounded,
                color: color,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isLeave ? 'Estás fuera' : 'Estás adentro',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (_isLeave) ...[
            const SizedBox(height: 10),
            Text(
              _formatLeaveText(_dateLeave),
              style: const TextStyle(fontSize: 15, color: darkText),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                days > 0 ? '$days días $hms' : hms,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const Text(
              'Tiempo transcurrido',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            if (_reason != null && _reason!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Motivo: $_reason',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: darkText,
                ),
              ),
            ],
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Cuando salgas, escanea el código QR del predio.',
                style: TextStyle(fontSize: 15, color: darkText),
              ),
            ),
        ],
      ),
    );
  }

  /// Una advertencia por cada salida del último mes que no marcó retorno.
  Widget _buildUnreturnedWarnings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final leave in _visibleUnreturned)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: const BorderSide(color: AppColors.danger, width: 5),
                top: BorderSide(color: AppColors.line),
                right: BorderSide(color: AppColors.line),
                bottom: BorderSide(color: AppColors.line),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      size: 26,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Salida sin retorno',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Saliste el ${_twoDigits(leave.leftAt.day)}/${_twoDigits(leave.leftAt.month)}/${leave.leftAt.year} a las ${_twoDigits(leave.leftAt.hour)}:${_twoDigits(leave.leftAt.minute)}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.darkText,
                  ),
                ),
                if (leave.reason != null && leave.reason!.isNotEmpty)
                  Text(
                    'Motivo: ${leave.reason}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'No se incluye en tus contadores.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildScanButton() {
    final title = _isLeave ? 'Registrar mi retorno' : 'Registrar mi salida';
    return SizedBox(
      height: 68,
      child: FilledButton.icon(
        onPressed: _goToScan,
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 32),
        label: Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  /// Cuántas veces y cuánto tiempo salió en la fecha elegida (por defecto hoy).
  Widget _buildStats() {
    final range = _range;
    final stat = range != null ? _rangeStat : _stats['day'];
    final loading = range != null && _rangeLoading;
    final exits = loading ? null : stat?.exits;
    final minutes = loading ? null : stat?.minutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tus salidas',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: darkText,
          ),
        ),
        const SizedBox(height: 10),
        _buildDateBar(),
        const SizedBox(height: 12),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.line),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              _StatNumber(
                value: exits == null ? '—' : '$exits',
                label: 'Salidas',
                icon: Icons.logout_rounded,
              ),
              Container(width: 1, height: 52, color: AppColors.line),
              _StatNumber(
                value: minutes == null ? '—' : _formatMinutes(minutes),
                label: 'Tiempo fuera',
                icon: Icons.timer_outlined,
              ),
            ],
          ),
        ),
        if (exits == 0)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'No saliste en esta fecha.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
      ],
    );
  }

  /// Selector de fecha: flechas para ir día a día y toque central para
  /// abrir el calendario (un día o un rango).
  Widget _buildDateBar() {
    final range = _range;
    final canGoNext = range != null && _isSingleDay(range);
    final canGoPrev = range == null || _isSingleDay(range);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Día anterior',
                onPressed: canGoPrev ? () => _shiftDay(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
              ),
              Expanded(
                child: Tooltip(
                  message: 'Elegir fecha',
                  child: InkWell(
                    onTap: _pickRange,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 20,
                                color: AppColors.info,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _rangeTitle(),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: darkText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Toca para elegir otra fecha',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Día siguiente',
                onPressed: canGoNext ? () => _shiftDay(1) : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 30),
              ),
            ],
          ),
        ),
        if (range != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _clearRange,
              icon: const Icon(Icons.today_rounded, size: 18),
              label: const Text('Volver a hoy'),
              style: TextButton.styleFrom(foregroundColor: AppColors.info),
            ),
          ),
      ],
    );
  }
}

class _StatNumber extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatNumber({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: Colors.black54),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// Foto de perfil; si no hay o no carga, una imagen predeterminada.
class _Avatar extends StatelessWidget {
  final String? photoUrl;

  const _Avatar({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    const fallback = CircleAvatar(
      radius: 30,
      backgroundColor: AppColors.infoBg,
      child: Icon(Icons.person_rounded, size: 38, color: AppColors.info),
    );
    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}
