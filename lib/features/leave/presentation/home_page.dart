import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/device/device_code_service.dart';
import '../../../core/format/date_text.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_bottom_bar.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/account_info.dart';
import '../../auth/presentation/login_page.dart';
import '../../device/presentation/device_tab.dart';
import '../data/leave_service.dart';
import '../models/leave_status.dart';
import 'date_range_sheet.dart';
import 'scan_page.dart';
import 'widgets/status_card.dart';
import 'widgets/trip_card.dart';
import 'widgets/week_strip.dart';

/// Pantalla principal: barra inferior con Inicio, el botón para escanear el QR
/// y Dispositivo. Aquí vive el estado de la persona y el detalle de sus salidas.
class HomePage extends StatefulWidget {
  /// Permiten inyectar servicios de prueba (p. ej. en tests de widgets).
  final LeaveService? leaveService;
  final AuthService? authService;

  /// Permite inyectar la consulta del código de dispositivo (pruebas).
  final Future<DeviceCodeInfo?> Function()? deviceCodeLoader;

  /// Permite inyectar la consulta de la cuenta mostrada en «Dispositivo»
  /// (pruebas).
  final Future<AccountInfo?> Function()? accountLoader;

  /// Reloj de la pantalla (pruebas): decide qué día es «hoy» sin depender de
  /// la fecha real del equipo.
  final DateTime Function()? clock;

  const HomePage({
    super.key,
    this.leaveService,
    this.authService,
    this.deviceCodeLoader,
    this.accountLoader,
    this.clock,
  });

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
  Map<String, LeaveStat> _stats = {};

  /// Fechas elegidas (tira de días o calendario); null = hoy (siempre al día).
  DateTimeRange? _range;
  LeaveStat? _rangeStat;
  bool _rangeLoading = false;

  /// Salidas de hoy: alimentan la tarjeta de estado (predio de la salida en
  /// curso, último retorno) y la lista cuando se está viendo hoy. Null mientras
  /// carga o si no se pudo consultar (la sección simplemente no aparece).
  List<LeaveDetail>? _todayDetails;

  /// Salidas del rango elegido (cuando no se está viendo hoy).
  List<LeaveDetail>? _rangeDetails;

  bool _isLeave = false;
  bool _isLoading = true;
  bool _hasError = false;

  /// Cuándo salió, si está fuera.
  DateTime? _leftAt;

  /// 0 = Inicio, 1 = Dispositivo. La pestaña Dispositivo se crea al abrirla.
  int _tab = 0;
  bool _deviceTabOpened = false;

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        _leftAt = status.dateLeave == null
            ? null
            : DateTime.tryParse(status.dateLeave!)?.toLocal();
        _reason = status.reason;
        _role = status.role;
        _jobTitle = status.jobTitle;
        _stats = status.stats;
      });
      unawaited(_loadTodayDetails());
      if (_range != null) {
        unawaited(_loadRange(_range!));
        unawaited(_loadRangeDetails());
      }
    } on SessionExpiredException catch (e) {
      _goToLogin(e.message);
    }
  }

  /// Solo con un rango elegido y únicamente las de esas fechas. En la vista
  /// de hoy no hay advertencias, porque aún puede marcar su retorno.
  List<UnreturnedLeave> get _visibleUnreturned =>
      _range != null ? (_rangeStat?.unreturnedLeaves ?? const []) : const [];

  DateTime _now() => (widget.clock ?? DateTime.now)();

  static DateTime _dateOnly(DateTime d) => DateText.dateOnly(d);

  static bool _isSingleDay(DateTimeRange r) =>
      _dateOnly(r.start) == _dateOnly(r.end);

  Future<void> _pickRange() async {
    final today = _dateOnly(_now());
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

  /// Elegir un día de la tira de la semana.
  void _selectDay(DateTime day) =>
      _showRange(DateTimeRange(start: day, end: day));

  void _showRange(DateTimeRange range) {
    final today = _dateOnly(_now());
    if (_isSingleDay(range) && !range.start.isBefore(today)) {
      _clearRange();
      return;
    }
    setState(() {
      _range = range;
      _rangeStat = null;
      _rangeDetails = null;
    });
    unawaited(_loadRange(range));
    unawaited(_loadRangeDetails());
  }

  /// Salidas de hoy. Si falla no molesta: las secciones que las usan no
  /// aparecen.
  Future<void> _loadTodayDetails() async {
    final today = _dateOnly(_now());
    try {
      final details = await _leaveService.fetchLeaveDetails(today, today);
      if (!mounted) return;
      setState(() => _todayDetails = details);
    } on SessionExpiredException catch (e) {
      _goToLogin(e.message);
    }
  }

  /// Salidas del rango que se está viendo.
  Future<void> _loadRangeDetails() async {
    final requested = _range;
    if (requested == null) return;
    try {
      final details = await _leaveService.fetchLeaveDetails(
        requested.start,
        requested.end,
      );
      if (!mounted || _range != requested) return;
      setState(() => _rangeDetails = details);
    } on SessionExpiredException catch (e) {
      _goToLogin(e.message);
    }
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

  void _clearRange() {
    setState(() {
      _range = null;
      _rangeStat = null;
      _rangeLoading = false;
      _rangeDetails = null;
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    showErrorPopup(context, message);
  }

  Future<void> _refreshData() => _loadUserData();

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

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      if (index == 1) _deviceTabOpened = true;
    });
  }

  // ---------------------------------------------------------------------
  // Datos derivados
  // ---------------------------------------------------------------------

  /// Salidas de la fecha o rango que se está viendo.
  List<LeaveDetail>? get _shownDetails =>
      _range == null ? _todayDetails : _rangeDetails;

  /// Predio de la salida en curso (si se conoce).
  String? get _currentPremise =>
      _todayDetails?.where((d) => d.isOpen).map((d) => d.premise).firstOrNull;

  /// Hora del último retorno de hoy.
  DateTime? get _lastReturnToday {
    final now = _now();
    DateTime? last;
    for (final d in _todayDetails ?? const <LeaveDetail>[]) {
      final r = d.returnedAt;
      if (r != null &&
          DateText.sameDay(r, now) &&
          (last == null || r.isAfter(last))) {
        last = r;
      }
    }
    return last;
  }

  String get _dateTitle {
    final r = _range;
    if (r == null) return DateText.longDate(_now());
    if (_isSingleDay(r)) return DateText.longDate(r.start);
    return '${DateText.dayMonthYear(r.start)} – ${DateText.dayMonthYear(r.end)}';
  }

  /// «Hoy saliste 2 veces · 1 h 25 min fuera en total».
  String? get _summary {
    final range = _range;
    if (range != null && _rangeLoading) return 'Consultando…';
    final stat = range != null ? _rangeStat : _stats['day'];
    if (stat == null) return null;

    final String when;
    if (range == null) {
      when = 'Hoy';
    } else if (_isSingleDay(range)) {
      final today = _dateOnly(_now());
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      when = range.start == yesterday
          ? 'Ayer'
          : 'El ${DateText.dayMonthYear(range.start)}';
    } else {
      when =
          'Del ${DateText.dayMonthYear(range.start)} '
          'al ${DateText.dayMonthYear(range.end)}';
    }

    final exits = stat.exits ?? 0;
    if (exits == 0) {
      return range == null ? 'Hoy aún no has salido' : '$when no saliste';
    }
    final times = exits == 1 ? '1 vez' : '$exits veces';
    final minutes = stat.minutes;
    final away = minutes == null
        ? ''
        : ' · ${DateText.duration(minutes)} fuera '
              '${range == null && _isLeave ? 'hasta ahora' : 'en total'}';
    return '$when saliste $times$away';
  }

  // ---------------------------------------------------------------------
  // Pantalla
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ready = !_isLoading && !_hasError;
    return PopScope(
      // Atrás desde Dispositivo vuelve a Inicio en vez de salir de la app.
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBg,
        extendBody: true,
        // Nunca queda una pantalla en blanco: siempre hay una vista de carga,
        // de error con reintento, o el contenido ya cargado.
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab,
            children: [
              _isLoading ? _buildLoadingView() : _buildBody(),
              if (_deviceTabOpened)
                DeviceTab(
                  codeLoader: widget.deviceCodeLoader,
                  accountLoader:
                      widget.accountLoader ?? _authService.currentAccount,
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomBar(
          selectedIndex: _tab,
          onSelect: _selectTab,
          scanLabel: _isLeave ? 'Registrar retorno' : 'Registrar salida',
          onScan: ready ? _goToScan : null,
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(size: 120),
          const SizedBox(height: 16),
          const CircularProgressIndicator(color: AppColors.primaryRed),
          const SizedBox(height: 16),
          Text(
            'Cargando tu información...',
            style: AppText.body.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.white, // Color del spinner
      backgroundColor: AppColors.primaryRed,
      child: _hasError ? _buildErrorView() : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
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
                    style: AppText.body.copyWith(color: AppColors.info),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Revisa tu conexión e inténtalo de nuevo',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 20),
                  AppPrimaryButton(
                    label: 'Reintentar',
                    icon: Icons.refresh_rounded,
                    onPressed: _loadUserData,
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
    final pad = size.width < 360 ? 16.0 : 22.0;
    final details = _shownDetails;
    final range = _range;
    // Con varios días cada hora lleva su fecha.
    final multiDay = range != null && !_isSingleDay(range);
    final today = _dateOnly(_now());
    final summary = _summary;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        pad,
        20,
        pad,
        // Deja libre la barra inferior y el botón central que sobresale.
        AppBottomBar.totalHeight(context) + 8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              StatusCard(
                isLeave: _isLeave,
                leftAt: _leftAt,
                premise: _currentPremise,
                reason: _reason,
                lastReturnAt: _lastReturnToday,
                clock: widget.clock,
              ),
              const SizedBox(height: 14),
              _buildDateRow(),
              const SizedBox(height: 10),
              WeekStrip(
                selectedStart: range?.start ?? today,
                selectedEnd: range?.end ?? today,
                today: today,
                onSelect: _selectDay,
              ),
              const SizedBox(height: 16),
              const Text(
                'Detalle de tus salidas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                ),
              ),
              if (summary != null) ...[
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 12),
              if (details != null)
                for (final leave in details)
                  TripCard(
                    leave: leave,
                    showDates: multiDay,
                    canStillReturn: DateText.sameDay(leave.leftAt, _now()),
                  )
              else if (_visibleUnreturned.isNotEmpty)
                // Si no se pudo cargar el detalle, al menos se avisa de las
                // salidas sin retorno del rango.
                for (final leave in _visibleUnreturned)
                  _UnreturnedWarning(leave: leave),
            ],
          ),
        ),
      ),
    );
  }

  /// Quién es: logo, rol y nombre, y cerrar sesión.
  Widget _buildHeader() {
    final role = (_role ?? '').trim();
    final job = (_jobTitle ?? '').trim();
    final roleLine = [
      if (role.isNotEmpty) role,
      if (job.isNotEmpty) job,
    ].join(' · ');

    return Row(
      children: [
        const AppLogo(size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (roleLine.isNotEmpty)
                Text(
                  roleLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              Text(
                'Hola, ${_name ?? 'Usuario'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _SquareButton(
          tooltip: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          color: AppColors.danger,
          onTap: _closeSession,
        ),
      ],
    );
  }

  /// «Jueves 19 de noviembre», «Volver a hoy» y el calendario.
  Widget _buildDateRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _dateTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
        ),
        if (_range != null)
          TextButton(
            onPressed: _clearRange,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryRed,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Volver a hoy'),
          ),
        const SizedBox(width: 4),
        _SquareButton(
          tooltip: 'Elegir fecha',
          icon: Icons.calendar_month_rounded,
          color: AppColors.primaryRed,
          onTap: _pickRange,
        ),
      ],
    );
  }
}

/// Botón cuadrado con borde, para acciones secundarias (cerrar sesión, calendario).
class _SquareButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SquareButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
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
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 20, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso de una salida sin retorno, cuando no se pudo cargar el detalle del rango.
class _UnreturnedWarning extends StatelessWidget {
  final UnreturnedLeave leave;

  const _UnreturnedWarning({required this.leave});

  @override
  Widget build(BuildContext context) {
    final left = leave.leftAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F9),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: const Color(0xFFE9B8B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 24,
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
            'Saliste el ${DateText.dayMonthYear(left)} a las ${DateText.hm(left)}',
            style: const TextStyle(fontSize: 14, color: AppColors.darkText),
          ),
          if ((leave.reason ?? '').isNotEmpty)
            Text(
              'Motivo: ${leave.reason}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            'No se incluye en tus contadores.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
