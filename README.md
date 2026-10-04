# dockctl · Contenedores Docker en la bandeja

Una app de escritorio para la **bandeja del sistema** que muestra el estado de
tus contenedores Docker y te permite gestionarlos (iniciar, detener, reiniciar,
eliminar), ver sus logs, su consumo y un análisis del sistema, todo sin abrir
una terminal.

Está escrita en Python (**PySide6**) con una interfaz QML basada en **Kirigami**,
y funciona de forma **totalmente independiente**: no necesita Plasma, ni un
servicio systemd, ni un backend externo.

![Licencia](https://img.shields.io/badge/Licencia-GPL--3.0-brightgreen)
![Python](https://img.shields.io/badge/Python-3.9+-yellow)
![PySide6](https://img.shields.io/badge/PySide6-6.x-blue)
![Versión](https://img.shields.io/badge/Versión-1.2.0-blue)

## Descargas

La última versión se publica en la pestaña **Releases** con el código fuente
comprimido (`.tar.gz` / `.zip`).

[Ir a los releases](https://github.com/JoseFEstevesP/dockctl/releases)

## Funcionalidades

- Listado de contenedores agrupados por **stack** (docker compose) con estado
  y salud (punto verde / naranja / gris).
- Acciones rápidas por contenedor: `start`, `stop`, `restart`, `remove`.
- Acción **"reiniciar todos"** por stack, con confirmación.
- Detalle de contenedor: ips, redes, puertos, fecha de creación/inicio,
  política de reinicio y **diagnóstico** (salud degradada, reinicios en bucle,
  puertos abiertos a la red local, falta de límites o de política de reinicio).
- Visor de logs con scroll, botón **Actualizar**, **Copiar al portapapeles** y
  filtro por nivel (**Todos**, **Avisos+**, **Errores**).
- Procesos del contenedor (`docker top`) con lectura de CPU, memoria y comando.
- Página de **Consumo**: qué contenedor gasta más CPU, RAM, red, disco o
  procesos, ordenable por métrica y con barras comparativas.
- Chip en la cabecera con el contenedor que más CPU está usando (configurable).
- Página de **Análisis**: espacio en disco recuperable (imágenes, volúmenes,
  caché de build) y hallazgos priorizados, con botones de limpieza que piden
  confirmación.
- Ventana redimensionable; al cerrarla se oculta en la bandeja y el polling se
  detiene (silencioso en segundo plano).
- **Instancia única**: si ya está abierta y vuelves a lanzarla (menú, acceso
  directo o `dockctl`), se **levanta la ventana existente** en vez de abrir otra.
- Arranque automático al iniciar sesión (opcional durante la instalación); en
  ese caso arranca **oculta en la bandeja**.

### Consumo y Análisis: por qué no saturan el sistema

`docker stats` tarda unos 2 s y `docker system df` unos 5-8 s, así que ninguno
de los dos se ejecuta en el bucle de refresco:

- La **lista principal** solo usa `docker ps` (rápido) cada 5 s.
- La página de **Consumo** mide por su cuenta según el intervalo configurado
  (10 s por defecto) y se cachea 10 s, así que abrirla dos veces seguidas no
  duplica el trabajo.
- La página de **Análisis** usa una caché de 5 minutos; el botón de refresco
  fuerza una medición real de todo.

### Limpieza: qué se puede ejecutar y qué no

Desde **Análisis** se puede liberar espacio con confirmación previa. Cada
comando se muestra en el diálogo antes de ejecutarlo:

| Botón | Comando | Nota |
| --- | --- | --- |
| Liberar caché de build | `docker builder prune -f` | Solo caché de compilación. |
| Liberar sin etiqueta | `docker image prune -f` | Imágenes sin etiqueta. |
| Liberar todas (agresivo) | `docker image prune -a -f` | También borra imágenes que no usa ningún contenedor: habrá que volver a descargarlas. |
| Eliminar detenidos | `docker container prune -f` | Se pierden logs y configuración de los parados. |
| Volúmenes sin usar | `docker volume prune` | **No se ejecuta**: la app solo muestra el comando para copiarlo, porque los volúmenes pueden contener datos. |

El backend acepta únicamente esos destinos; cualquier otro se rechaza con
`400`, y los volúmenes se rechazan siempre.

## Capturas

Consumo por contenedor, análisis del sistema y procesos:

![Consumo por contenedor](docs/screenshots/vista-consumo.png)

![Análisis del sistema](docs/screenshots/vista-analisis.png)

![Procesos del contenedor](docs/screenshots/vista-top.png)

Vista principal, detalle de stack, detalle de contenedor y visor de logs con
el filtro de nivel:

![Vista principal](docs/screenshots/vista-principal.png)

![Vista de stack](docs/screenshots/vista-stack.png)

![Detalle de contenedor](docs/screenshots/vista-diagnostico.png)

![Visor de logs](docs/screenshots/vista-logs-filtro.png)

## Arquitectura

Un único proceso con dos capas:

| Pieza | Dónde | Qué hace |
| --- | --- | --- |
| **App** | `app/dockctl_app.py` (PySide6) | Arranca el backend en un hilo, carga la UI QML y gestiona la bandeja del sistema (`QSystemTrayIcon`). |
| **UI** | `app/qml/` (QML + Kirigami) | Ventana con las vistas; se comunica con el backend por HTTP en `127.0.0.1`. |
| **Backend** | `backend/backend.py` (Python stdlib) | Ejecuta `docker` y expone una API JSON. Se importa como módulo y escucha en un **puerto libre efímero** de `127.0.0.1`. |

No hay servicio systemd: el backend vive dentro del propio proceso de la app y
se apaga con ella. Al ser un puerto efímero, no choca con nada aunque haya otra
instancia o el puerto `8427` esté ocupado.

La comunicación entre instancias usa un `QLockFile` (para garantizar una sola
instancia) y un `QLocalServer`/`QLocalSocket` (para que el segundo lanzamiento
levante la ventana de la primera).

## Requisitos

- Linux con un **área de bandeja del sistema** (Plasma, GNOME con extensión de
  bandeja, Xfce, etc.).
- Docker funcionando (`docker ps` sin sudo; el usuario debe estar en el grupo
  `docker`).
- Python 3.9+ y **PySide6** (Qt 6).
- Los módulos QML de **Kirigami** (`org.kde.kirigami`).

Paquetes habituales:

- Arch: `sudo pacman -S python pyside6 kirigami docker`
- Fedora: `sudo dnf install python3 python3-pyside6 kirigami docker-ce`
- Debian/Ubuntu: `sudo apt install python3 python3-pyside6.qml qml-module-org-kde-kirigami docker.io`

## Tutorial de instalación

### Paso 0 — Preparar Docker

Comprueba que Docker funciona sin `sudo`:

```bash
docker ps
```

Si da error de permisos, añade tu usuario al grupo `docker` y vuelve a iniciar
sesión (o reinicia):

```bash
sudo usermod -aG docker "$USER"
```

### Paso 1 — Clonar el repositorio

```bash
git clone https://github.com/JoseFEstevesP/dockctl
cd dockctl
```

### Paso 2 — Instalar

```bash
./install.sh
```

O en una sola línea:

```bash
git clone https://github.com/JoseFEstevesP/dockctl && cd dockctl && ./install.sh
```

El instalador hace lo siguiente:

1. Copia la app a `~/.local/share/dockctl/` (QML, imágenes, backend y Python).
2. Crea el lanzador `~/.local/bin/dockctl`.
3. Instala el icono en `~/.local/share/icons/hicolor/scalable/apps/dockctl.svg`
   y la entrada de menú `Contenedores Docker`.
4. Crea un **acceso directo en el escritorio** (`<Escritorio>/dockctl.desktop`),
   como symlink a la entrada de menú. El directorio se detecta con
   `xdg-user-dir DESKTOP` (p. ej. `~/Escritorio` en español).
5. Pregunta si quieres **arrancarla al iniciar sesión** (autostart). Si dices que
   sí, se crea `~/.config/autostart/org.gato99.dockctl.desktop` y la app se
   iniciará **oculta en la bandeja**.
6. Retira los restos de versiones anteriores (widget de Plasma y servicio
   systemd) si los hubiera.

> `SKIP_AUTOSTART=1 ./install.sh` omite por completo la pregunta de autostart
> (no lo crea ni lo elimina). Si prefieres contestar, responde `n` para
> desactivarlo.

### Paso 3 — Primer arranque

Arranca la app desde el menú (**Contenedores Docker**), desde el acceso directo
del escritorio, o con:

```bash
dockctl
```

Si `dockctl` dice *command not found*, añade `~/.local/bin` al `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

Tras unos segundos verás la **ventana** y el **icono en la bandeja**.

### Paso 4 (opcional) — Actualizar

```bash
git pull && ./update.sh --no-dist
```

`update.sh` refresca la app instalada, el lanzador, el icono, las entradas y el
acceso directo. Opciones:

- `--no-dist`: no regenerar los paquetes de `dist/`.
- `--release`: además sube/actualiza los assets de la release `v<versión>` con
  `gh` (requiere `gh` autenticado y `dist/` regenerado).

## Uso

- **Abrir**: icono de la bandeja, menú, acceso directo o `dockctl`.
- En el icono de la bandeja:
  - **Clic izquierdo o central** → mostrar/ocultar la ventana.
  - **Clic derecho** → menú con **Mostrar / ocultar** y **Salir**.
- **Cerrar la ventana con la X** la oculta en la bandeja (no cierra la app) y
  **detiene el polling** para no molestar en segundo plano.
- **Para salir de verdad**: clic derecho en el icono → **Salir**. Esto apaga el
  backend y termina el proceso por completo (no queda nada en segundo plano).
- Si la app **ya está en marcha** y pulsas de nuevo el lanzador, el acceso
  directo o el menú, se **levanta la ventana** existente (instancia única).
- Navegación dentro de la ventana:
  - **Vista principal**: lista de stacks y contenedores con acciones rápidas.
  - **Detalle de stack**: reinicia todos sus contenedores.
  - **Detalle de contenedor**: métricas, redes, puertos y diagnóstico.
  - **Logs**: con filtro de nivel, refresco y copia al portapapeles.
  - **Procesos** (`docker top`) del contenedor.
  - **Consumo**: ranking por CPU, RAM, red, disco o procesos.
  - **Análisis**: espacio recuperable y limpieza guiada.

## Configuración

Desde la propia app, con el icono de la **llave inglesa** de la cabecera:

| Opción | Descripción |
| --- | --- |
| Actualizar cada | Segundos entre consultas (1 a 120). |
| Medir consumo cada | Segundos entre mediciones de la página de Consumo (5 a 120, 10 por defecto). |
| Mostrar contenedores detenidos | Lista también los contenedores parados. |
| Mostrar chip de consumo | Muestra el contenedor que más CPU usa en la cabecera. |
| Confirmar antes de eliminar | Pide confirmación al eliminar. Las limpiezas de Análisis piden confirmación siempre. |

La configuración se guarda con `QSettings` del usuario en:

```
~/.config/dockctl/dockctl.conf
```

Para restablecerla, borra ese fichero (o `rm -rf ~/.config/dockctl`).

## API del backend

Para desarrollo y pruebas, el backend expone una API JSON en `127.0.0.1` (en el
puerto efímero que elija el sistema). Rutas:

| Método | Ruta | Descripción |
| --- | --- | --- |
| `GET` | `/api/containers` | Lista de contenedores (running primero). |
| `GET` | `/api/containers/:name` | Detalle: ips, redes, puertos, salud, fechas y diagnóstico. |
| `GET` | `/api/containers/:name/logs?lines=N` | Logs (N entre 1 y 5000, default 300). |
| `GET` | `/api/containers/:name/top` | Procesos del contenedor (`docker top`, 200 filas). |
| `GET` | `/api/stats?refresh=1` | Consumo por contenedor (CPU, RAM, red, disco, pids). Cacheado 10 s. |
| `GET` | `/api/analysis?refresh=1` | Espacio en disco y hallazgos. Cacheado 5 min. |
| `POST` | `/api/containers/:name/start` | Inicia un contenedor. |
| `POST` | `/api/containers/:name/stop` | Detiene un contenedor. |
| `POST` | `/api/containers/:name/restart` | Reinicia un contenedor. |
| `POST` | `/api/containers/:name/remove` | Elimina un contenedor (`docker rm -f`). |
| `POST` | `/api/stacks/:name/restart` | Reinicia todos los contenedores de un stack. |
| `POST` | `/api/maintain/:target` | Limpieza: `images-safe`, `images-all`, `containers`, `buildcache`. |

`/api/maintain/volumes` responde siempre `400`: los volúmenes nunca se borran
desde la app. Los destinos fuera de la lista también se rechazan con `400`.

Errores de Docker en `GET` responden `200` con `{"ok": false, "error": "..."}`
(la app los muestra en rojo); en `POST` responden `500`. Orígenes CORS no
locales reciben `403`.

## Desarrollo

```bash
# Tests del backend (no requieren docker real; se mockea el comando docker)
python3 backend/test_backend.py

# Comprobar que los .qml compilan con el motor de Qt
QT_QPA_PLATFORM=offscreen python3 -c "
import pathlib
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtCore import QUrl
app = QGuiApplication([]); e = QQmlEngine()
for p in sorted(pathlib.Path('app/qml').glob('*.qml')):
    c = QQmlComponent(e, QUrl.fromLocalFile(str(p.resolve())))
    print('FALLA' if c.isError() else 'ok', p.name, [x.toString() for x in c.errors()])
"

# Ejecutar la app sin instalar (usa el repo directamente)
QT_QPA_PLATFORM=offscreen python3 app/dockctl_app.py

# Instala/reinstala desde el repo
./install.sh
```

Estructura:

```
dockctl/
├── app/
│   ├── dockctl_app.py              # Proceso principal: backend + bandeja + QML
│   ├── org.gato99.dockctl.desktop  # Entrada de menú
│   ├── qml/                        # Interfaz (main.qml, vistas, DockStyle.js)
│   └── images/                     # Iconos
├── backend/
│   ├── backend.py                  # Servidor HTTP + capa docker
│   └── test_backend.py             # Tests (79)
├── aur/
│   └── PKGBUILD                    # Paquete para el AUR
├── docs/screenshots/               # Capturas del README
├── dist/                           # Paquetes generados por build.sh
├── install.sh                      # Instalación completa (también acceso directo)
├── update.sh                       # Actualiza la app instalada y regenera dist/
├── build.sh                        # Genera dist/dockctl-v<version>.tar.gz/.zip
├── uninstall.sh                    # Desinstalación
└── VERSION                         # Versión actual
```

## Desinstalación

```bash
./uninstall.sh
```

Detiene la app y borra el código, el lanzador, el icono, la entrada de menú, el
acceso directo del escritorio y el autostart. **Mantiene** la configuración.

Para borrar también la configuración:

```bash
rm -rf ~/.config/dockctl
```

## Instalación por AUR (Arch)

Todavía no está publicado. El registro de cuentas nuevas del AUR está cerrado
temporalmente por un [incidente de seguridad](https://archlinux.org/news/active-aur-malicious-packages-incident/)
y no hay fecha de reapertura. El `PKGBUILD` está preparado en
[`aur/PKGBUILD`](aur/PKGBUILD) y se publicará en cuanto se reabra.

> El paquete del AUR instala el binario y la entrada de menú, pero **no** crea el
> acceso directo del escritorio ni el autostart: eso lo gestiona cada usuario con
> `install.sh`, porque son preferencias de la sesión y no del sistema.

## Solución de problemas

- **No aparece el icono en la bandeja**: asegúrate de tener un *host* de bandeja.
  En Plasma viene de serie; en GNOME instala la extensión *AppIndicator and
  KStatusNotifierItem Support*.
- **`dockctl: command not found`**: añade `~/.local/bin` al `PATH` (ver Paso 3).
- **`docker: permission denied`**: tu usuario no está en el grupo `docker`
  (ver Paso 0) y hay que volver a iniciar sesión.
- **`module "org.kde.kirigami" is not installed`**: instala el paquete de QML de
  Kirigami (`kirigami` en Arch/Fedora, `qml-module-org-kde-kirigami` en Debian).
- **La ventana no se levanta al relanzar en Wayland**: algunos compositores
  limitan el foco; haz clic directamente en el icono de la bandeja.
- **Cierro la X y sigue en la bandeja**: es el comportamiento esperado; usa
  **Salir** en el menú de la bandeja para terminar la app.
- **La página de Análisis tarda**: `docker system df` puede tardar 5-8 s; usa el
  botón de refresco solo cuando lo necesites (hay caché de 5 min).

## Licencia

GPL-3.0 — ver [LICENSE](LICENSE).
