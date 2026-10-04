#!/usr/bin/env python3
"""App de bandeja para gestionar contenedores Docker.

Arranca el backend HTTP en un hilo dentro del propio proceso y sirve la
interfaz QML (Kirigami) a través de QSystemTrayIcon.
"""
import os
import sys
import threading
from pathlib import Path

from PySide6.QtCore import (
    QLockFile, QObject, Property, QSettings, QStandardPaths, QTimer, QUrl, Signal, Slot,
)
from PySide6.QtGui import QAction, QIcon
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

HERE = Path(__file__).resolve().parent
for _cand in (HERE, HERE.parent / "backend"):
    if (_cand / "backend.py").is_file():
        sys.path.insert(0, str(_cand))
        break
import backend  # noqa: E402

QML_DIR = HERE / "qml"
ICON_PATH = HERE / "images" / "docker.svg"


class _SilentHandler(backend.Handler):
    def log_message(self, fmt, *args):
        pass


class Settings(QObject):
    refreshIntervalChanged = Signal()
    statsIntervalChanged = Signal()
    showStoppedChanged = Signal()
    showStatsChipChanged = Signal()
    confirmRemoveChanged = Signal()

    def __init__(self):
        super().__init__()
        self._s = QSettings("dockctl", "dockctl")

    def _int(self, key, default):
        try:
            return int(self._s.value(key, default))
        except (TypeError, ValueError):
            return default

    def _bool(self, key, default):
        return self._s.value(key, default, type=bool)

    @Property(int, notify=refreshIntervalChanged)
    def refreshInterval(self):
        return self._int("refreshInterval", 5)

    @refreshInterval.setter
    def refreshInterval(self, value):
        self._s.setValue("refreshInterval", int(value))
        self.refreshIntervalChanged.emit()

    @Property(int, notify=statsIntervalChanged)
    def statsInterval(self):
        return self._int("statsInterval", 10)

    @statsInterval.setter
    def statsInterval(self, value):
        self._s.setValue("statsInterval", int(value))
        self.statsIntervalChanged.emit()

    @Property(bool, notify=showStoppedChanged)
    def showStopped(self):
        return self._bool("showStopped", True)

    @showStopped.setter
    def showStopped(self, value):
        self._s.setValue("showStopped", bool(value))
        self.showStoppedChanged.emit()

    @Property(bool, notify=showStatsChipChanged)
    def showStatsChip(self):
        return self._bool("showStatsChip", True)

    @showStatsChip.setter
    def showStatsChip(self, value):
        self._s.setValue("showStatsChip", bool(value))
        self.showStatsChipChanged.emit()

    @Property(bool, notify=confirmRemoveChanged)
    def confirmRemove(self):
        return self._bool("confirmRemove", True)

    @confirmRemove.setter
    def confirmRemove(self, value):
        self._s.setValue("confirmRemove", bool(value))
        self.confirmRemoveChanged.emit()


class Controller(QObject):
    """Puente entre la app de bandeja y la ventana QML."""

    def __init__(self, app, engine, backend_url):
        super().__init__()
        self._app = app
        self._engine = engine
        self._backend_url = backend_url
        self._tray = None

    def _window(self):
        roots = self._engine.rootObjects()
        return roots[0] if roots else None

    @Slot()
    def showWindow(self):
        window = self._window()
        if window is None:
            return
        window.show()
        window.raise_()
        window.requestActivate()

    @Slot()
    def hideWindow(self):
        window = self._window()
        if window is not None:
            window.hide()

    @Slot()
    def toggleWindow(self):
        window = self._window()
        if window is None:
            return
        if window.isVisible():
            window.hide()
        else:
            self.showWindow()

    @Slot()
    def quit(self):
        self._app.quit()

    def _on_tray_activated(self, reason):
        if reason in (QSystemTrayIcon.Trigger, QSystemTrayIcon.MiddleClick):
            self.toggleWindow()

    def install_tray(self):
        if not QSystemTrayIcon.isSystemTrayAvailable():
            return
        tray = QSystemTrayIcon(QIcon(str(ICON_PATH)))
        tray.setToolTip("Contenedores Docker")
        menu = QMenu()

        show_action = QAction("Mostrar / ocultar", menu)
        show_action.triggered.connect(self.toggleWindow)
        quit_action = QAction("Salir", menu)
        quit_action.triggered.connect(self._app.quit)

        menu.addAction(show_action)
        menu.addSeparator()
        menu.addAction(quit_action)
        tray.setContextMenu(menu)
        tray.activated.connect(self._on_tray_activated)
        tray.show()
        self._tray = tray


class Server:
    def __init__(self):
        self._server = backend.ThreadingHTTPServer(("127.0.0.1", 0), _SilentHandler)
        self._server.daemon_threads = True
        self.port = self._server.server_address[1]
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)

    @property
    def url(self):
        return "http://127.0.0.1:%d" % self.port

    def start(self):
        self._thread.start()

    def stop(self):
        self._server.shutdown()
        self._server.server_close()


def _instance_lock():
    runtime = QStandardPaths.writableLocation(QStandardPaths.RuntimeLocation)
    if not runtime:
        runtime = QStandardPaths.writableLocation(QStandardPaths.TempLocation)
    path = Path(runtime or ".")
    path.mkdir(parents=True, exist_ok=True)
    lock = QLockFile(str(path / "dockctl.lock"))
    if not lock.tryLock(100):
        return None
    return lock


def _activate_existing(name):
    socket = QLocalSocket()
    socket.connectToServer(name)
    if socket.waitForConnected(300):
        socket.write(b"show\n")
        socket.waitForBytesWritten(300)
        socket.disconnectFromServer()


def _on_activation(server, controller):
    conn = server.nextPendingConnection()
    if conn is None:
        return
    conn.waitForReadyRead(100)
    conn.readAll()
    controller.showWindow()
    conn.disconnectFromServer()


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("dockctl")
    app.setApplicationDisplayName("Contenedores Docker")
    app.setOrganizationName("dockctl")
    app.setQuitOnLastWindowClosed(False)
    app.setWindowIcon(QIcon(str(ICON_PATH)))

    local_name = "dockctl-%d" % os.getuid()
    lock = _instance_lock()
    if lock is None:
        _activate_existing(local_name)
        return 0

    tray_available = QSystemTrayIcon.isSystemTrayAvailable()
    start_hidden = tray_available and "--hidden" in sys.argv[1:]

    server = Server()
    server.start()

    settings = Settings()
    engine = QQmlApplicationEngine()
    controller = Controller(app, engine, server.url)

    engine.rootContext().setContextProperty("config", settings)
    engine.rootContext().setContextProperty("dockctlBackendUrl", server.url)
    engine.rootContext().setContextProperty("dockctlTrayAvailable", tray_available)
    engine.rootContext().setContextProperty("dockctlStartHidden", start_hidden)

    engine.load(QUrl.fromLocalFile(str(QML_DIR / "main.qml")))
    if not engine.rootObjects():
        server.stop()
        return 1

    controller.install_tray()
    if not start_hidden:
        QTimer.singleShot(0, controller.showWindow)

    local_server = QLocalServer()
    QLocalServer.removeServer(local_name)
    if local_server.listen(local_name):
        local_server.newConnection.connect(
            lambda: _on_activation(local_server, controller)
        )

    app.aboutToQuit.connect(server.stop)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
