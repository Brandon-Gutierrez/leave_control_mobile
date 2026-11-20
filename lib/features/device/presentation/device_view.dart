import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/device/device_code_service.dart';
import '../../../core/format/date_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../auth/models/account_info.dart';

typedef DeviceCodeLoader = Future<DeviceCodeInfo?> Function();
typedef AccountLoader = Future<AccountInfo?> Function();

/// El código de este teléfono y para qué sirve. Se usa en la pestaña
/// «Dispositivo» (con sesión: también muestra la cuenta vinculada) y en la hoja
/// del inicio de sesión (sin sesión).
class DeviceView extends StatefulWidget {
  /// Permite inyectar la consulta del código (pruebas).
  final DeviceCodeLoader? codeLoader;

  /// Consulta de la cuenta con la sesión abierta. Null = no hay sesión (login):
  /// no se muestra la tarjeta de cuenta y el estado no dice «tu cuenta».
  final AccountLoader? accountLoader;

  const DeviceView({super.key, this.codeLoader, this.accountLoader});

  @override
  State<DeviceView> createState() => _DeviceViewState();
}

class _DeviceViewState extends State<DeviceView> {
  DeviceCodeInfo? _info;
  AccountInfo? _account;
  bool _loading = true;
  bool _copied = false;
  Timer? _copiedTimer;

  bool get _signedIn => widget.accountLoader != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Las dos consultas salen a la vez; la cuenta es un dato de apoyo.
    final infoFuture = (widget.codeLoader ?? DeviceCodeService().fetch)();
    final accountFuture =
        widget.accountLoader?.call() ?? Future<AccountInfo?>.value();
    final info = await infoFuture;
    final account = await accountFuture;
    if (!mounted) return;
    setState(() {
      _info = info;
      _account = account;
      _loading = false;
    });
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
      );
    }
    final info = _info;
    if (info == null) return _buildFailure();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCodeCard(info),
        const SizedBox(height: 16),
        const _WhyCard(),
        if (_account != null) ...[
          const SizedBox(height: 16),
          _buildAccountCard(_account!, info),
        ],
      ],
    );
  }

  Widget _buildFailure() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No se pudo obtener el código de este teléfono',
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
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(DeviceCodeInfo info) {
    final String status;
    final Color statusFg;
    final Color statusBg;
    if (info.linked && _signedIn) {
      status = 'Vinculado a tu cuenta';
      statusFg = AppColors.success;
      statusBg = AppColors.successBg;
    } else if (info.linked) {
      status = 'Vinculado a una cuenta';
      statusFg = AppColors.info;
      statusBg = AppColors.infoBg;
    } else {
      status = 'Aún sin vincular';
      statusFg = AppColors.info;
      statusBg = AppColors.infoBg;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.smartphone_rounded,
              size: 30,
              color: AppColors.info,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Código de este dispositivo',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              info.code,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                height: 1.1,
                color: AppColors.darkText,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: statusFg,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildCopyButton(info.code),
        ],
      ),
    );
  }

  Widget _buildCopyButton(String code) {
    final color = _copied ? AppColors.success : AppColors.primaryRed;
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => _copy(code),
        icon: Icon(
          _copied ? Icons.check_rounded : Icons.copy_rounded,
          size: 20,
        ),
        label: Text(_copied ? 'Código copiado' : 'Copiar código'),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: appFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(AccountInfo account, DeviceCodeInfo info) {
    final item = account.item;
    final linkedAt = info.linkedAt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusButton),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cuenta vinculada',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            item == null ? account.name : '${account.name} · Item $item',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          if (info.linked && linkedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Vinculado el ${DateText.dayMonthYear(linkedAt)} '
              'a las ${DateText.hm(linkedAt)}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// «¿Para qué sirve este código?»: tres motivos, en palabras simples.
class _WhyCard extends StatelessWidget {
  const _WhyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Para qué sirve este código?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: 14),
          _WhyRow(
            icon: Icons.smartphone_rounded,
            text:
                'Identifica este teléfono. Tu cuenta solo funciona en un '
                'teléfono a la vez.',
          ),
          SizedBox(height: 14),
          _WhyRow(
            icon: Icons.repeat_rounded,
            text:
                '¿Cambiarás de teléfono? Dicta este código a Recursos '
                'Humanos para que liberen este.',
          ),
          SizedBox(height: 14),
          _WhyRow(
            icon: Icons.person_add_alt_rounded,
            text:
                'Si otra persona usó este teléfono antes y se bloquea su '
                'acceso, también se resuelve con este código.',
          ),
        ],
      ),
    );
  }
}

class _WhyRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _WhyRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 20, color: AppColors.info),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF444444),
            ),
          ),
        ),
      ],
    );
  }
}
