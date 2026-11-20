import 'package:flutter/material.dart';

import '../../../core/device/device_code_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_popup.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../device/presentation/device_code_sheet.dart';
import '../../leave/presentation/home_page.dart';
import '../data/auth_service.dart';

class LoginPage extends StatefulWidget {
  /// Permite inyectar la consulta del código de dispositivo (pruebas).
  final Future<DeviceCodeInfo?> Function()? deviceCodeLoader;

  const LoginPage({super.key, this.deviceCodeLoader});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    //Si el estado del formulario es valido
    if (_isLoading || !_formKey.currentState!.validate()) return;
    //Muestra el estado de carga
    setState(() {
      _isLoading = true;
    });
    //realiza la petición a backend; null significa que inició sesión bien
    final error = await _authService.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    //Desactiva el estado de carga
    setState(() {
      _isLoading = false;
    });
    //si la peticion fue exitosa realiza la navegacion a la pantalla de inicio
    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
      //si la peticion no fue exitosa muestra el motivo (p. ej. dispositivo
      //vinculado a otra cuenta) para que el usuario sepa que debe contactar
      //a Recursos Humanos.
    } else {
      showErrorPopup(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isSmallPhone = size.width < 360 || size.height < 640;
    final gap = isSmallPhone ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallPhone ? 20.0 : 28.0,
              vertical: 24.0,
            ),
            child: ConstrainedBox(
              // Evita que el formulario se estire en teléfonos grandes o en horizontal
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: AppLogo(size: isSmallPhone ? 120 : 190)),
                      SizedBox(height: gap),

                      // Título
                      const Text(
                        'Salidas Temporales',
                        textAlign: TextAlign.center,
                        style: AppText.display,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Registra tus salidas y retornos',
                        textAlign: TextAlign.center,
                        style: AppText.caption,
                      ),
                      SizedBox(height: gap + 4),

                      // Campo Usuario
                      TextFormField(
                        controller: _usernameController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        style: const TextStyle(
                          color: AppColors.darkText,
                          fontSize: 15,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Usuario',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            size: 22,
                            color: AppColors.darkText,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Campo requerido'
                            : null,
                      ),
                      SizedBox(height: gap - 4),

                      // Campo Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _isPasswordObscured,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _login(),
                        style: const TextStyle(
                          color: AppColors.darkText,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 22,
                            color: AppColors.darkText,
                          ),
                          suffixIcon: IconButton(
                            tooltip: _isPasswordObscured
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            icon: Icon(
                              _isPasswordObscured
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 22,
                              color: AppColors.muted,
                            ),
                            onPressed: () => setState(
                              () => _isPasswordObscured = !_isPasswordObscured,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Campo requerido' : null,
                      ),
                      SizedBox(height: gap + 4),

                      AppPrimaryButton(
                        label: 'Ingresar',
                        loading: _isLoading,
                        onPressed: _login,
                      ),
                      // Quien no pueda ingresar (p. ej. su teléfono quedó
                      // vinculado a otra cuenta) dicta el código a RR. HH.
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => showDeviceCodeSheet(
                          context,
                          codeLoader: widget.deviceCodeLoader,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.info,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          textStyle: const TextStyle(
                            fontFamily: appFontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        // El ícono va dentro del texto: si la frase se parte en
                        // dos líneas, todo queda centrado junto.
                        child: const Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.smartphone_rounded,
                                    size: 18,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: '¿No puedes ingresar? Ver código del teléfono ›',
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
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
