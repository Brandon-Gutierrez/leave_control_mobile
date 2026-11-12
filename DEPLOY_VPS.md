# Despliegue de prueba en VPS (sin dominio propio, aislado de otro proyecto)

Objetivo: levantar **API Laravel + Web (admin y manage_premise) + PostgreSQL + Redis** en un VPS que ya aloja otro proyecto, sin tocar nada de ese proyecto, y conectar la app móvil. Cuando exista el dominio y el servidor real, solo se cambian 3-4 valores (sección 10).

## Cómo queda armado

```text
Internet ──► https://controlsalidas.duckdns.org:8443 ──► contenedor "web" (nginx) ──► /      Flutter Web
                                                                                  └► /api   php-fpm (app) ─► db (Postgres)
Celular (APK) ───────────────────────────────────────────────────────────────────────────────────────────────► redis
```

- El **otro proyecto** conserva sus puertos (probablemente 80/443). Este usa **8081 (HTTP) y 8443 (HTTPS)**; elige otros si están ocupados.
- Aislamiento: el compose usa `name: control-salidas`, así que sus contenedores, red y volúmenes (`control-salidas_pgdata`, `control-salidas_redisdata`) tienen nombre propio. PostgreSQL y Redis **no publican puertos** en el host.
- **Sin dominio**: se usa un subdominio gratis de **DuckDNS** (`algo.duckdns.org`). Con él se obtiene un certificado **Let's Encrypt real** por validación DNS-01, que **no necesita los puertos 80/443**. Esto es importante: la web exige cookies `Secure` (HTTPS) y Android/iOS rechazan HTTPS con certificado autofirmado.

---

## 0. Antes de empezar (lo que necesitas)

| Dato | Cómo verlo |
|---|---|
| Acceso SSH con `sudo` al VPS | — |
| RAM del VPS (compilar Flutter Web pide ~2-3 GB) | `free -h` |
| Puertos ocupados | `sudo ss -tlnp` (busca 8081 y 8443) |
| Docker con Compose ≥ 2.24 | `docker compose version` |
| Los repos subidos a GitHub | Ya lo están (`main` sincronizado en los tres) |
| Valores de Comteco (`KEY_SOFTWARE`, `API_*`) y `SUPERADMIN_ITEM` | Están en tu `docker/.env` local |

> **Ojo:** el VPS de prueba tendrá otra IP pública. Si Comteco restringe por IP, el login contra Comteco fallará hasta que habiliten esa IP. Pregúntalo antes.

## 1. Subdominio gratis (DuckDNS)

1. Entra a https://www.duckdns.org e inicia sesión.
2. Crea un subdominio, p. ej. `controlsalidas`, y en *current ip* pon la **IP pública del VPS**.
3. Copia tu **token** (no lo compartas ni lo subas a git).

Comprueba desde tu PC: `nslookup controlsalidas.duckdns.org` debe devolver la IP del VPS.

## 2. Firewall

Abre solo el puerto HTTPS elegido (y el HTTP si quieres la redirección):

```bash
sudo ufw allow 8443/tcp
sudo ufw allow 8081/tcp      # opcional: solo redirige a HTTPS
```

Si el proveedor del VPS tiene firewall propio (panel web), abre ahí también esos puertos.

## 3. Docker (si no está instalado)

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER   # cierra sesión y vuelve a entrar
docker compose version          # debe ser v2.24 o superior
```

## 4. Código en el servidor

```bash
sudo mkdir -p /opt/control-salidas && sudo chown $USER /opt/control-salidas
cd /opt/control-salidas
git clone https://github.com/Brandon-Gutierrez/control_salida.git backend
git clone https://github.com/Brandon-Gutierrez/leave_control_web.git web
```

(Si los repos son privados, usa un *token* de GitHub o una *deploy key*.)

## 5. Variables (`.env`)

```bash
cd /opt/control-salidas/backend/docker
cp .env.example .env
```

Genera los secretos **nuevos** para este servidor (no reutilices los de tu PC):

```bash
echo "APP_KEY=base64:$(openssl rand -base64 32)"
echo "DB_PASSWORD=$(openssl rand -hex 24)"
echo "REDIS_PASSWORD=$(openssl rand -hex 24)"
```

Edita `.env` (`nano .env`). Lo que debe quedar:

```ini
BACKEND_PATH=..
WEB_PATH=../../web

PUBLIC_HOST=controlsalidas.duckdns.org:8443   # con el puerto
HTTP_PORT=8081
HTTPS_PORT=8443
TRUSTED_PROXY=127.0.0.1/32

API_BASE_URL=                                  # VACÍO (la web llama a /api en su propio origen)

APP_KEY=...            # los tres valores generados arriba
DB_PASSWORD=...
REDIS_PASSWORD=...

SUPERADMIN_ITEM=...    # copiar de tu .env local
SUPERADMIN_NAME=...
KEY_SOFTWARE=...       # copiar de tu .env local, junto con todas las API_*
API_LOGIN=...
API_LOGINWITHCARNET=...
API_GETEMPLOYEE=...
API_GETREASONS=...
API_GETCHECKOUT=...
API_REGISTERCHECKOUT=...
```

`PUBLIC_HOST` **debe** llevar `:8443`: de ahí salen `SANCTUM_STATEFUL_DOMAINS`, `CORS_ALLOWED_ORIGINS`, `APP_URL` y la redirección HTTP→HTTPS.

## 6. Certificado HTTPS (DNS-01 con DuckDNS)

Hazlo **antes** del primer `up`, para que no se genere el autofirmado.

```bash
curl https://get.acme.sh | sh -s email=TU_CORREO
source ~/.bashrc
export DuckDNS_Token="TU_TOKEN_DUCKDNS"

acme.sh --issue --dns dns_duckdns --server letsencrypt -d controlsalidas.duckdns.org

acme.sh --install-cert -d controlsalidas.duckdns.org \
  --key-file       /opt/control-salidas/backend/docker/certs/privkey.pem \
  --fullchain-file /opt/control-salidas/backend/docker/certs/fullchain.pem \
  --reloadcmd "docker compose -f /opt/control-salidas/backend/docker/docker-compose.yml exec -T web nginx -s reload || true"
```

`acme.sh` crea su cron y renueva solo (cada ~60 días) y recarga nginx. Verifica: `ls -l /opt/control-salidas/backend/docker/certs/`.

## 7. Levantar todo

```bash
cd /opt/control-salidas/backend/docker
docker compose up -d --build
docker compose ps
docker compose logs -f app     # espera "[entrypoint] API lista."
```

- La **primera compilación tarda** (descarga Flutter y compila la web). Si el VPS tiene < 4 GB de RAM y el build se corta (*Killed*), añade swap:
  `sudo fallocate -l 3G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`
- Al arrancar, `app` ejecuta solo las migraciones y siembra roles + el ADMIN (`SUPERADMIN_ITEM`).
- `scheduler` corre la sincronización de motivos con Comteco (lun-vie 00:00 hora Bolivia).

## 8. Verificación

Desde **tu PC** (no desde el VPS):

```bash
curl -i https://controlsalidas.duckdns.org:8443/api/health     # 200 {"status":"OK"}
curl -I http://controlsalidas.duckdns.org:8081/                # 301 → https://...:8443/
```

Luego en el navegador `https://controlsalidas.duckdns.org:8443`:

1. Inicia sesión como ADMIN (item de `SUPERADMIN_ITEM`, credenciales de Comteco).
2. Crea un **predio** (con ubicación) y sus motivos (botón *sincronizar motivos* si el catálogo está vacío).
3. Crea una cuenta **MANAGE_PREMISE** para ese predio, cierra sesión y entra con ella: debe mostrar el QR.
4. Confirma que el otro proyecto sigue funcionando igual.

## 9. App móvil

La URL se compila dentro de la app (`--dart-define`). **Sin barra final y con el puerto**:

```bash
cd control_leaves_mobile
flutter build apk --release --dart-define=API_BASE_URL=https://controlsalidas.duckdns.org:8443
# APK: build/app/outputs/flutter-apk/app-release.apk
```

Para depurar en un teléfono conectado: `flutter run --dart-define=API_BASE_URL=https://controlsalidas.duckdns.org:8443`.

> Corregido en este repo: faltaba `android.permission.INTERNET` en `android/app/src/main/AndroidManifest.xml` (solo estaba en debug/profile), por lo que un APK *release* no habría podido conectarse.

Prueba completa: abre la web como MANAGE_PREMISE (QR) → desde el celular inicia sesión, escanea, elige motivo (estando a ≤ 50 m del predio y con GPS ≤ 30 m de precisión) → vuelve a escanear para el retorno.

## 10. Pasar al servidor real (con dominio)

1. Apunta el dominio al servidor real (registro A).
2. Clona repos y copia `.env` como en la sección 5, cambiando:
   - `PUBLIC_HOST=midominio.com`, `HTTP_PORT=80`, `HTTPS_PORT=443` (o los que correspondan).
   - Secretos nuevos, `SUPERADMIN_*` y `API_*` de producción. `API_BASE_URL` sigue vacío.
3. Certificado: Let's Encrypt con `certbot --webroot` (ver `docker/README.md`, sección *Certificados*) o el de la empresa en `certs/`.
4. `docker compose up -d --build`.
5. **Recompila el APK** con `--dart-define=API_BASE_URL=https://midominio.com` (la URL va dentro de la app).
6. Si migras datos de prueba: `pg_dump` / `psql` (ver `docker/README.md`, *Datos y persistencia*). Normalmente en producción se parte de base vacía.

## Operación diaria

| Qué | Comando (desde `backend/docker`) |
|---|---|
| Ver estado / logs | `docker compose ps` · `docker compose logs -f app web` |
| Actualizar código | `git pull` en `../` y `../../web`, luego `docker compose up -d --build` |
| Reiniciar | `docker compose restart` |
| Apagar (conserva datos) | `docker compose down` |
| ⚠ Borrar TODO, incluida la base | `docker compose down -v` |
| Respaldo | `docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -Fc "$POSTGRES_DB"' > respaldo.dump` |

## Problemas frecuentes

| Síntoma | Causa probable |
|---|---|
| `Bind for 0.0.0.0:8443 failed: port is already allocated` | Puerto ocupado: cambia `HTTPS_PORT` y `PUBLIC_HOST`. |
| Navegador: "conexión no segura" | Se generó el autofirmado: faltaba el certificado al hacer `up`. Instala el cert (sección 6) y `docker compose restart web`. |
| Web carga pero el login da 419/401 | `PUBLIC_HOST` sin el puerto, o se entra por otra URL/IP distinta a `PUBLIC_HOST`. |
| Login falla con 503 `AUTH_SERVICE_UNAVAILABLE` | El VPS no alcanza Comteco (IP no autorizada o `API_*` mal copiadas). |
| App: "No hay conexión a internet" | Firewall/puerto cerrado, URL con barra final/sin puerto, o APK sin permiso INTERNET (ya corregido). |
| `docker compose` dice "Define APP_KEY en .env" | Falta alguna de las tres claves generadas. |
| Build web "Killed" | Falta RAM: añade swap (sección 7). |
