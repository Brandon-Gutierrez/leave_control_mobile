# Guía del repositorio

Esta guía describe los archivos fuente, configuración, pruebas y recursos de la aplicación Flutter presentes al momento de escribirla. Incluye también los archivos locales nuevos que no están versionados. Los directorios generados por Flutter, Gradle, CocoaPods o el IDE se explican en la sección de exclusiones; no son parte de la arquitectura mantenible.

## 1. Qué hace la aplicación

Aplicación móvil para registrar salidas temporales y retornos de empleados. Autentica contra un backend, conserva una sesión basada en cookies, valida el dispositivo, escanea QR, obtiene una prueba de ubicación y permite confirmar el motivo de salida.

### Recorrido principal

1. `lib/main_mobile.dart` inicializa Flutter y espera a que `ApiConfig` cargue las cookies persistidas.
2. `lib/screens/user/session_gate.dart` consulta la sesión con `ApiService.hasActiveSession()`. Si el backend confirma la sesión abre Inicio; si la rechaza abre Login. Un error de red permite reintentar.
3. `lib/screens/user/login_page.dart` valida las credenciales de formulario y delega el login a `ApiService`.
4. `lib/screens/user/home_page.dart` carga el estado laboral, presenta la acción QR para salida/retorno y mantiene el contador de una salida activa.
5. `lib/screens/user/scan_page.dart` lee un QR con `mobile_scanner`. `ApiService.userStatus()` captura ubicación mediante `LocationService`, envía la operación y devuelve la siguiente acción.
6. Si la API requiere un motivo, `lib/screens/user/reasons_page.dart` carga los motivos y envía el comprobante temporal de salida junto a la selección y otra prueba de ubicación.
7. `lib/services/storage_service.dart` persiste datos locales sensibles mediante almacenamiento seguro. `ApiConfig` persiste por separado las cookies de sesión.

Relación actual resumida: las pantallas llaman directamente a `ApiService`; este combina solicitudes HTTP, traducción de errores y algunas reglas de flujo; `ApiConfig` comparte Dio, cookies y encabezados; servicios especializados encapsulan almacenamiento, dispositivo y ubicación.

## 2. Código Dart

| Archivo | Función y relaciones | Mejora de Clean Code / arquitectura |
|---|---|---|
| `lib/main_mobile.dart` | Punto de entrada de esta aplicación (`-t lib/main_mobile.dart`); configura `MaterialApp`, tema, sesión inicial y espera de cookies. | Mantener el arranque pequeño. Mover la composición de dependencias a un `AppBootstrap`/contenedor y construir el tema en un archivo propio; evitar que el widget raíz conozca inicialización de infraestructura. |
| `lib/config/api_config.dart` | Singleton del cliente Dio. Configura URL, timeouts, encabezados, `DeviceId`, cookie persistente y limpieza de sesión. Usa `DeviceService` y `path_provider`. | Separar configuración inmutable (`ApiEnvironment`), creación de Dio, almacenamiento de cookies e interceptor. Inyectar cliente/dependencias; exigir HTTPS y una URL de release validada. Revisar `ignoreExpires: true` con el contrato de sesión del backend: el servidor debe seguir siendo autoridad y una cookie expirada no debería prolongarse accidentalmente. |
| `lib/config/api_routes.dart` | Constantes de rutas del backend y construcción codificada de la ruta de razones por predio. Consumido por `ApiService`. | Centralizar rutas junto a contratos/API por feature cuando crezca el cliente; tipar parámetros/response en vez de acoplar strings a widgets. |
| `lib/models/auth_user.dart` | Archivo existente, actualmente vacío; no participa en el flujo. | Implementar un modelo de usuario solo cuando exista un contrato estable (`fromJson`, tipos y validación) o eliminarlo para no prometer una abstracción que no se usa. |
| `lib/services/api_service.dart` | Fachada usada por las pantallas para login, sesión, estado, escaneo y confirmación. Traduce respuestas Dio a errores y coordina `LocationService`, `StorageService`, `ApiConfig` y rutas. | Es el principal candidato a dividir por responsabilidad: repositorios de autenticación/salidas, DTOs y casos de uso. Evitar `Map<String, dynamic>` y retornos ambiguos `null`/`String?`; modelar estados/errores tipados. Distinguir fallos de red, HTTP y parseo en todos los métodos, no ocultarlos con `catch` genérico. Inyectar interfaces en vez de crear servicios internamente. |
| `lib/services/device_service.dart` | Lee o genera un identificador aleatorio persistente y lo entrega al encabezado que agrega `ApiConfig`. | Definir contrato y ciclo de vida con backend (reinstalación, cambio de dispositivo, revocación); probar generación/estabilidad usando un almacenamiento inyectado. Tratar el ID como identificador, no como secreto de autenticación. |
| `lib/services/location_service.dart` | Comprueba permisos/GPS/VPN, captura coordenadas y marca ubicación simulada. `LocationProof.toJson()` define el payload enviado en escaneo y confirmación. | Mantener separado el acceso a plugins de la política de negocio: interfaz de proveedor de ubicación/conectividad, errores tipados y tests de permisos/timeout. Validar límites de frescura/precisión también en backend; la señal del cliente no es una garantía ant fraude. |
| `lib/services/storage_service.dart` | Persiste nombre, item, token e identificador del dispositivo usando `FlutterSecureStorage`; lo usan `ApiService` y `DeviceService`. | Inyectar una abstracción de almacenamiento, documentar qué datos son necesarios y su retención, y probar lectura/escritura/borrado. Revisar si guardar `token` es necesario cuando la autenticación efectiva se hace mediante cookie. Evitar secuencias de escrituras parcialmente aplicadas o definir su recuperación. |
| `lib/screens/user/session_gate.dart` | Estado inicial que valida la sesión remota y enruta a Login o Inicio. Expone inyección opcional de `ApiService`. | Llevar decisión de sesión al estado de autenticación/router; modelar explícitamente loading, sesión inválida y error de red. La opción de inyección es buen inicio, pero debe aplicarse de manera consistente a las demás pantallas. |
| `lib/screens/user/login_page.dart` | Formulario de credenciales, validación, visibilidad de contraseña, indicador de carga y navegación tras login. Utiliza `ApiService`, tema y popup de error. | Mantener UI declarativa y mover estado/acción de login a un controlador/notifier; no mezclar navegación, validación de backend y presentación en el mismo `State`. Cubrir validación, loading, errores y éxito con widget tests. |
| `lib/screens/user/home_page.dart` | Consulta y presenta identidad/estado de salida, actualización manual, tiempo transcurrido, logout y acceso al escáner. Utiliza `ApiService`, `Timer`, `ScanPage` y tema. | Separar el estado de pantalla y el cálculo/formato de duración; parsear fechas de forma segura en el límite de datos. Controlar concurrencia de refresh y logout y presentar estados tipados. Extraer componentes visuales solo si se reutilizan o reducen complejidad. |
| `lib/screens/user/scan_page.dart` | Maneja el ciclo de cámara, lectura QR, linterna/cámara, progreso, errores y navegación a motivos/Inicio/Login. Depende de `mobile_scanner`, `ApiService` y `LocationService` (excepciones). | Separar el controlador de cámara del flujo de negocio; definir estados explícitos, evitar reiniciar cámara después de desmontar y probar duplicados/errores/permisos. El QR y el comprobante son datos distintos: conservar ese contrato tipado. |
| `lib/screens/user/reasons_page.dart` | Extrae el predio del QR, obtiene motivos, selecciona uno, cuenta atrás del comprobante y confirma con ubicación. Navega según éxito, expiración o sesión caducada. | Separar parsing del QR/ticket, temporizador y coordinación API en un controlador/caso de uso. Usar DTO tipado para ticket/expiración y errores; cubrir carrera entre expiración y envío, refresh, selección y confirmación. |
| `lib/theme/app_colors.dart` | Tokens de color compartidos por pantallas y estilos. | Completar el sistema mediante `ThemeData`/`ColorScheme`, estados semánticos y soporte de tema oscuro/accesibilidad; evitar colores duplicados en pantallas. |
| `lib/theme/app_text_styles.dart` | Estilos `AppText` y medidas `AppDimens`; empleado en las pantallas. | Unificar tipografía/medidas en el tema Flutter para heredar escalado y accesibilidad; `caption` puede ser `const` si no necesita color calculado. Evitar valores visuales repetidos fuera de los tokens. |
| `lib/widgets/error_popup.dart` | Popup superpuesto no modal con autocierre de siete segundos y botón de cierre; llamado desde los flujos de UI. | Considerar `ScaffoldMessenger` o un sistema de notificaciones central con semántica accesible. Garantizar ciclo de vida del `OverlayEntry` y evitar duplicados; añadir tests para autocierre y cierre manual. |

## 3. Pruebas

| Archivo | Qué verifica | Cómo elevar cobertura/fiabilidad |
|---|---|---|
| `test/location_proof_test.dart` | Serialización de `LocationProof`, formato UTC y precisión mínima positiva. | Añadir casos de precisión normal, fecha local/UTC y valores límite. Probar aparte la política de permisos y errores a través de proveedores falsos. |
| `test/login_flow_test.dart` | Contrato HTTP de login/sesión: respuestas 401/403/5xx, respuesta no JSON, encabezados del cliente e identidad estable del dispositivo. Usa adaptador Dio falso y plugins simulados. | Aislar configuración global de Dio entre tests, probar logout/cookie/errores de parseo y verificar el payload completo. Preferir factories inyectables para no mutar el singleton global. |
| `test/widget_test.dart` | Casos de widgets para Login, Home y selección de motivo en varios tamaños; carga y error/reintento de Home con `ApiService` falso. | Incorporar tests del flujo QR/sesión/confirmación, accesibilidad y navegación; extraer fake común si aparece duplicación. Evitar depender de detalles de implementación cuando baste verificar comportamiento visible. |
| `ios/RunnerTests/RunnerTests.swift` | Plantilla XCTest nativa sin pruebas de lógica actualmente. | Añadir pruebas solo para código nativo propio; la lógica de producto debe probarse principalmente en Dart. Eliminar la plantilla si no se usa. |

## 4. Configuración raíz y herramientas

| Archivo | Función y relaciones | Mejora recomendada |
|---|---|---|
| `README.md` | Descripción inicial generada por Flutter; actualmente no explica el producto ni cómo ejecutarlo. | Sustituirla por propósito, requisitos, configuración de URL/API, comandos de test/análisis, build por plataforma y límites de soporte. Enlazar esta guía. |
| `pubspec.yaml` | Identidad del paquete, SDK Dart, dependencias/plugins, lints y declaración del recurso `rsc/`. | Mantener dependencias justificadas y actualizadas con revisión de changelog; definir flavors/entornos y scripts de CI. Verificar que el constraint SDK coincida con CI y máquinas del equipo. |
| `pubspec.lock` | Resuelve versiones transitivas exactas para builds reproducibles de la app. | Versionarlo (como está), actualizarlo junto con cambios deliberados a dependencias y validar `flutter pub get` en CI. No editar a mano. |
| `analysis_options.yaml` | Incluye `flutter_lints`; excluye carpetas/plataformas generadas del análisis Dart. | Activar progresivamente reglas útiles (por ejemplo, errores de `avoid_print`, reglas de estilo y documentación pública según convenga) y ejecutar `flutter analyze` como gate de CI. Evitar excepciones amplias que oculten código Dart propio. |
| `.gitignore` | Excluye build, cachés, IDE, secretos `.env`, logs y artefactos de Flutter. | Mantener fuera secretos y outputs. Revisar que solo ignore archivos regenerables; definir ejemplo de variables no sensibles separado de `.env`. |
| `.metadata` | Estado de plantilla/versión Flutter usado para migraciones. No contiene comportamiento de la app. | Mantenerlo bajo control de versiones y dejar que Flutter lo actualice; no editar manualmente salvo procedimiento oficial. |
| `.vscode/settings.json` | Configura la actualización de builds de Java para VS Code. | Compartir solo ajustes de equipo no personales; agregar formato/análisis consistente si el equipo acuerda esas preferencias. |
| `control_input_output.iml` | Metadatos locales del módulo IntelliJ/Android Studio; está ignorado y no es configuración funcional de Flutter. | No versionarlo salvo una necesidad concreta del equipo. |
| `flutter_01.log` | Log local de una ejecución Flutter; está ignorado por patrón `*.log`. | No versionarlo ni incluir tokens, URLs privadas o datos personales en logs. |
| `.env` | Archivo local excluido por Git; su contenido no se inspecciona ni se reproduce en esta guía. | Tratarlo como potencialmente sensible, rotar cualquier secreto expuesto y documentar nombres/valores de ejemplo en un `.env.example` sin credenciales. |

## 5. Android

| Archivo(s) | Función y relaciones | Mejora recomendada |
|---|---|---|
| `android/settings.gradle.kts` | Configura resolución de plugins Flutter/Android/Kotlin e incluye el módulo `:app`; obtiene la ruta Flutter desde `local.properties`. | Fijar y actualizar versiones de plugins con CI; mantener `local.properties` local y validar compatibilidad Flutter/Gradle/JDK. |
| `android/build.gradle.kts` | Repositorios Gradle, directorios de salida compartidos y tarea `clean`. | Dejar aquí solo configuración compartida necesaria y seguir la DSL vigente de Flutter/Gradle al actualizar. |
| `android/app/build.gradle.kts` | Compilación de app, namespace/ID, SDK, Java/Kotlin 17, versión Flutter y firma. | Cambiar `com.example.control_input_output` por un identificador de producción; configurar flavors, permisos/SDK mínimos justificados y firma release mediante secretos de CI (nunca debug key). |
| `android/gradle.properties` | Ajustes JVM y flags AndroidX/DSL Kotlin de Gradle. | Dimensionar memoria para CI/estaciones reales y retirar flags de compatibilidad cuando ya no hagan falta, tras validar el plugin chain. |
| `android/gradle/wrapper/gradle-wrapper.properties` | Fija la distribución de Gradle utilizada por el wrapper. | Actualizar de manera coordinada con AGP/Flutter y validar builds en CI; conservar checksum de distribución si la política lo requiere. |
| `android/gradlew` y `android/gradlew.bat` | Lanzadores del wrapper para Unix y Windows. | Mantener como scripts generados por Gradle; usar el wrapper en automatización para builds reproducibles. |
| `android/gradle/wrapper/gradle-wrapper.jar` | Ejecutable Java del wrapper Gradle presente localmente. | Es infraestructura binaria del wrapper; versionarlo solo si la política/repo lo requiere y validar su procedencia e integridad. |
| `android/.gitignore` | Ignora outputs locales Android/Gradle. | Mantener fuera `local.properties`, firma y directorios de build; revisar reglas al incorporar tooling nuevo. |
| `android/local.properties` | Rutas locales del SDK Flutter/Android; no portable y no debe compartirse. | No versionarlo. Cada desarrollador/CI configura SDK mediante su entorno. |
| `android/control_input_output_android.iml` | Metadatos locales de módulo IDE. | Mantener ignorado; no forma parte del producto. |
| `android/app/src/main/AndroidManifest.xml` | Declara la app/activity launcher y permisos de ubicación/red usados por plugins y `LocationService`. | Revisar permisos mínimos, texto y políticas de privacidad; asegurar configuración de cámara necesaria para QR y validar manifiesto merged en release. El `applicationId` debe ser definitivo para publicar. |
| `android/app/src/debug/AndroidManifest.xml` | Configuración de manifiesto específica del build debug (plantilla Flutter). | Mantener solo overrides requeridos para desarrollo; nunca introducir aquí permisos necesarios únicamente en release sin verificar el manifiesto final. |
| `android/app/src/profile/AndroidManifest.xml` | Configuración del manifiesto para profiling. | Mantener alineada con permisos/runtime de la app, evitando diferencias que invaliden mediciones. |
| `android/app/src/main/kotlin/com/example/control_input_output/MainActivity.kt` | Activity Flutter nativa sin lógica adicional. | Mantener mínima; mover a plugin/capa nativa específica cualquier integración que aparezca y probarla en dispositivo. |
| `android/app/src/main/res/values/styles.xml` | Tema claro nativo y fondo mientras Flutter inicializa. | Coordinar splash/branding con Flutter y verificar el arranque en distintas densidades y versiones Android. |
| `android/app/src/main/res/values-night/styles.xml` | Tema nativo durante arranque cuando Android está en modo oscuro. | Alinear colores de splash con la experiencia real en tema oscuro. |
| `android/app/src/main/res/drawable/launch_background.xml` | Fondo inicial para dispositivos Android que usan el recurso drawable estándar. | Generar splash con configuración/herramienta oficial para mantener consistencia y evitar editar recursos redundantes a mano. |
| `android/app/src/main/res/drawable-v21/launch_background.xml` | Variante del fondo de inicio para API 21 o superior. | Mantenerla sincronizada con `drawable/` o reemplazar ambas mediante el generador de splash. |
| `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`, `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`, `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`, `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`, `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` | Icono de launcher Android en densidades hdpi a xxxhdpi, referenciado por el manifest. | Regenerar desde un asset maestro con adaptive icon y revisar legibilidad, safe area y branding de publicación. |
| `android/build/reports/problems/problems-report.html` | Informe HTML de problemas Gradle que aparece versionado en este repositorio; es salida diagnóstica, no lógica de producto. | No actualizar como documentación manual; confirmar si debe dejar de versionarse y mantener reports de build fuera del repositorio. |

## 6. iOS

| Archivo(s) | Función y relaciones | Mejora recomendada |
|---|---|---|
| `ios/Runner.xcodeproj/project.pbxproj` | Proyecto Xcode: targets, build settings, referencias de recursos, signing y configuración Flutter. | Gestionar Bundle ID/equipos/perfiles por configuración, revisar entitlements y evitar secretos; cambios delicados deben validarse con build de Xcode/CI. |
| `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | Scheme compartido usado para ejecutar, testear y archivar Runner. | Asegurar que CI usa el scheme/configuración correctos para debug y release. |
| `ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata`, `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`, `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | Workspace y preferencias de Xcode vinculadas al proyecto. | Conservar solo metadatos compartibles; no depender de preferencias personales para compilar. |
| `ios/Runner.xcworkspace/contents.xcworkspacedata`, `ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`, `ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | Workspace que abre CocoaPods/Flutter junto al proyecto Runner. | Abrir el `.xcworkspace` para builds iOS; mantener archivos de workspace generados coherentes con las dependencias. |
| `ios/Runner/AppDelegate.swift` | Inicializa Flutter y registra plugins en el engine implícito. | Añadir solo integración nativa necesaria; conservar registro de plugins y verificar en dispositivo tras actualizar Flutter/plugins. |
| `ios/Runner/SceneDelegate.swift` | Delegate de escena Flutter; actualmente sin lógica adicional. | Mantener vacío mientras no haya lifecycle/deep links nativos propios. |
| `ios/Runner/Info.plist` | Identidad, orientaciones, storyboards y explicación del permiso de ubicación. | Añadir descripciones explícitas de los permisos de cámara que requiera el plugin, validar privacidad/App Store y separar valores por build configuration cuando corresponda. |
| `ios/Runner/Runner-Bridging-Header.h` | Cabecera de interoperabilidad Objective-C/Swift del target Runner. | Mantener mínima y retirar si deja de ser necesaria al eliminar referencias Objective-C. |
| `ios/Runner/GeneratedPluginRegistrant.h` y `ios/Runner/GeneratedPluginRegistrant.m` | Registro Objective-C generado para plugins Flutter en iOS. | No editar manualmente; regenerar desde Flutter al cambiar plugins y revisar si la política del proyecto mantiene estos archivos versionados. |
| `ios/Flutter/AppFrameworkInfo.plist` | Metadatos del framework Flutter embebido. | Mantener administrado por Flutter y actualizar con las herramientas oficiales. |
| `ios/Flutter/Debug.xcconfig` y `ios/Flutter/Release.xcconfig` | Importan la configuración generada Flutter para builds debug/release. | Añadir overrides con archivos de configuración versionables y no secretos; no editar los `Generated.xcconfig` locales. |
| `ios/Runner/Base.lproj/Main.storyboard` | Storyboard principal de entrada nativa Flutter. | Mantener consistente con el ciclo de arranque; lógica de interfaz de producto permanece en Flutter. |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` | Pantalla de lanzamiento iOS antes del primer frame Flutter. | Alinear con branding y requisitos de launch screen de Apple; probar modo claro/oscuro y diferentes tamaños. |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` | Asocia imágenes de icono con tamaños/escala requeridos por Xcode. | Validar que todas las escalas y slots corresponden al asset final usando herramientas de Xcode. |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`, `Icon-App-20x20@1x.png`, `Icon-App-20x20@2x.png`, `Icon-App-20x20@3x.png`, `Icon-App-29x29@1x.png`, `Icon-App-29x29@2x.png`, `Icon-App-29x29@3x.png`, `Icon-App-40x40@1x.png`, `Icon-App-40x40@2x.png`, `Icon-App-40x40@3x.png`, `Icon-App-60x60@2x.png`, `Icon-App-60x60@3x.png`, `Icon-App-76x76@1x.png`, `Icon-App-76x76@2x.png`, `Icon-App-83.5x83.5@2x.png` | Variantes raster del icono de la app para los tamaños de iPhone/iPad configurados en `Contents.json`. | Generarlas desde una fuente de alta resolución y automatizar validación para prevenir escalas faltantes o arte inconsistente. |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`, `LaunchImage.png`, `LaunchImage@2x.png`, `LaunchImage@3x.png` | Catálogo y variantes de la imagen de lanzamiento heredada. | Confirmar si sigue referenciada por el proyecto; retirar el asset obsoleto o mantener tamaños sincronizados con el storyboard. |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` | Nota generada/documental del catálogo de LaunchImage. | Actualizar o quitar si se elimina el imageset heredado. |
| `ios/RunnerTests/RunnerTests.swift` | Target XCTest nativo con un test de ejemplo vacío. | Reemplazar el placeholder por pruebas nativas solo si se añade lógica Swift; evitar mantener tests vacíos como señal engañosa de cobertura. |
| `ios/.gitignore` | Exclusiones específicas de artefactos iOS/Xcode. | Mantener fuera DerivedData y configuración personal, pero conservar los archivos compartidos necesarios para abrir/build. |

## 7. Web y recursos

La presencia de `web/` permite compilar Flutter Web, pero las capacidades principales dependen de plugins nativos y de cookies; no debe suponerse que QR, almacenamiento y ubicación funcionan igual en navegador sin validación explícita.

| Archivo(s) | Función y relaciones | Mejora recomendada |
|---|---|---|
| `web/index.html` | Documento anfitrión y bootstrap de Flutter Web; define base href, título, descripción, favicon y manifest. | Reemplazar el texto de plantilla, revisar metadatos/CSP y probar rutas de despliegue con base href distinta de `/`. |
| `web/manifest.json` | Metadatos PWA, colores, modo de visualización y referencias a iconos web. | Ajustar nombre, descripción y colores de marca; confirmar orientación y estrategia PWA según soporte real. |
| `web/favicon.png` | Favicon del sitio compilado. | Sustituir por identidad visual final y verificar contraste/tamaño en pestaña. |
| `web/icons/Icon-192.png`, `web/icons/Icon-512.png` | Iconos PWA estándar referenciados desde el manifest. | Regenerar desde un asset maestro y validar instalación/mascarado en navegadores objetivo. |
| `web/icons/Icon-maskable-192.png`, `web/icons/Icon-maskable-512.png` | Versiones maskable para iconos adaptables del sistema. | Revisar zona segura para que el recorte no oculte el símbolo. |
| `rsc/comteco.png` | Logo mostrado en SessionGate y en estados de carga de Login/Home; declarado como recurso en `pubspec.yaml`. | Documentar procedencia/licencia corporativa, optimizar dimensiones y centralizar referencia/alternativa accesible en un widget de marca. |

## 8. Otras configuraciones y archivos locales

| Archivo(s) | Función y relación | Recomendación |
|---|---|---|
| `android/gradle/wrapper/gradle-wrapper.properties` | Configuración del wrapper Gradle descrita en Android; fija versión exacta y ubicación de distribución. | La definición completa figura en la sección Android para evitar duplicar recomendaciones. |
| `ios/Flutter/Generated.xcconfig`, `ios/Flutter/flutter_export_environment.sh`, `ios/Flutter/ephemeral/**` | Salidas de Flutter generadas localmente para el SDK y compilación iOS. No son contratos fuente. | No editarlas a mano ni incluirlas en la guía de archivos mantenibles; regenerarlas con Flutter. |
| `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` | Registro de plugins generado para Android. | No editar a mano; Flutter lo regenera a partir de `pubspec.lock`/plugins. |

## 9. Exclusiones del inventario mantenible

No se cataloga archivo por archivo cada salida de compilación o caché porque se regenera y puede cambiar entre máquinas: `build/**`, `.dart_tool/**`, `.idea/**`, `.gradle/**`, `ios/Flutter/ephemeral/**`, `android/local.properties`, `.flutter-plugins-dependencies` y caches de paquetes/plugins. Los archivos `*.iml` y `flutter_01.log` son metadatos/logs locales; `.env` es local y potencialmente sensible. El informe versionado `android/build/reports/problems/problems-report.html` sí se documenta expresamente arriba por estar presente en el índice de Git.

Esta exclusión es deliberada: la guía cubre responsabilidades del producto y configuración fuente, no cada archivo temporal dependiente de SDK, sistema operativo o máquina.

## 10. Ruta de mejora hacia estándares de producción

### Prioridad 0: fiabilidad y seguridad

- Sustituir la URL de desarrollo `http://10.0.2.2:8000` por configuración por entorno/flavor; impedir builds release con HTTP o una URL de desarrollo. No incluir secretos dentro de `--dart-define` pensando que quedan protegidos en el binario.
- Confirmar el ciclo de expiración y revocación de cookie con el backend; usar TLS, políticas de cookie/CSRF correctas y pruebas de logout/expiración.
- Cambiar el application ID Android y Bundle ID iOS de ejemplo, cerrar firma release, permisos, nombre e iconos antes de distribuir.
- Revisar privacidad/retención de ubicación, identificador del dispositivo y logs; validar antifraude en backend, nunca confiar solo en señales del cliente.

### Prioridad 1: contratos y límites

- Definir DTOs inmutables para usuario, estado de salida, respuesta del escaneo, ticket temporal, motivos, prueba de ubicación y errores.
- Separar cliente HTTP, fuentes remotas/locales y repositorios; hacer que las pantallas dependan de casos de uso/estado de presentación, no de Dio ni almacenamiento.
- Reemplazar errores ambiguos (`null`, strings) por resultados tipados o excepciones de dominio consistentes. No silenciar errores que la UI necesita distinguir.
- Inyectar dependencias desde composición de app. Conservar singletons solo para recursos verdaderamente compartidos y con ciclo de vida definido.

### Prioridad 2: organización y mantenibilidad

Una evolución proporcionada al tamaño actual puede organizarse por feature, con separación interna de responsabilidades:

```text
lib/
  app/                 # bootstrap, navegación y tema global
  core/                # red común, errores, utilidades compartidas
  features/
    auth/
      data/            # DTO, datasource y repositorio concreto
      domain/          # entidades, contratos y casos de uso
      presentation/    # páginas y controlador/notifier
    leave/
      data/
      domain/
      presentation/
    scan/              # integración de cámara y flujo QR
  infrastructure/      # plugins y adaptadores de almacenamiento/ubicación
```

No hace falta crear todas estas carpetas de una vez. Migrar un flujo completo (por ejemplo login) y verificar que la nueva frontera reduce acoplamiento antes de replicarla. Elegir una sola estrategia de estado/navegación acorde al equipo; no incorporar paquetes por moda.

### Prioridad 3: calidad continua

- Automatizar en CI `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` y builds de debug/release para plataformas soportadas.
- Añadir tests de repositorio/casos de uso, widget tests de estados y tests de integración del contrato API; probar expiración del ticket, desconexión, doble escaneo y permisos denegados.
- Definir estrategia de localization y accesibilidad: strings fuera de widgets, semántica, escalado de texto, contraste, navegación con lector y tamaños de toque.
- Registrar cambios incompatibles del backend y versionar contratos; no registrar credenciales, cookies, QR/tickets ni coordenadas en telemetría.
- Establecer revisión periódica de dependencias, análisis de vulnerabilidades, política de versiones y checklist de publicación.

## 11. Comandos útiles

Desde la raíz, con Flutter/Dart compatibles con `pubspec.yaml`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -t lib/main_mobile.dart --dart-define=API_BASE_URL=https://<api-del-entorno>
```

Los builds iOS requieren macOS/Xcode; Android requiere JDK y SDK Android compatibles con el wrapper/Flutter. El comando de ejecución utiliza la entrada móvil explícita y la URL de API debe pertenecer al entorno elegido.
