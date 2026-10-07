# App móvil de salidas temporales

Aplicación Flutter para que el personal registre sus salidas temporales y retornos escaneando el QR del predio. Valida la ubicación (GPS, a 50 m del predio), vincula cada cuenta a un único teléfono y guarda la sesión en una cookie persistente.

El backend es el proyecto Laravel `control_salida`; la administración se hace desde `control_leaves_web`.

## Requisitos

- Flutter con Dart `^3.13`.
- Backend accesible desde el teléfono.

## Ejecutar

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://mi-api
```

Si no se indica `API_BASE_URL` se usa la URL por defecto de `lib/core/config/api_config.dart`.

## Pruebas y análisis

```bash
flutter analyze
flutter test
```

## Estructura

```text
lib/
├── main.dart          Punto de entrada
├── app/                      MaterialApp
├── core/                     Código compartido
│   ├── config/               URL y rutas del backend
│   ├── network/              Cliente HTTP, cookies, errores y respuestas
│   ├── storage/              Almacenamiento seguro e identificador del dispositivo
│   ├── location/             Captura de ubicación y señales antifraude
│   ├── theme/                Colores, textos y tema
│   └── widgets/              Aviso flotante
└── features/
    ├── auth/                 Inicio de sesión (data + presentation)
    └── leave/                Estado de salida, escaneo QR y motivos (data + models + presentation)
```

Más detalle en [GUIA_DEL_REPOSITORIO.md](GUIA_DEL_REPOSITORIO.md).
