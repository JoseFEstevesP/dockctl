import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "DockStyle.js" as DS

ApplicationWindow {
    id: root

    visible: !dockctlStartHidden
    title: qsTr("Contenedores Docker")
    width: 430
    height: 560
    minimumWidth: 360
    minimumHeight: 300
    color: DS.cardBg

    property int runningCount: 0
    property int stoppedCount: 0
    property int unhealthyCount: 0
    property var containers: []
    property var stacks: []
    property bool loading: true
    property bool busy: false
    property var pendingConfirm: null
    property string lastError: ""
    property string backendUrl: dockctlBackendUrl

    property int currentPage: 0
    property var currentContainer: null
    property var currentStack: null
    property var detailData: null
    property bool detailLoading: false
    property string detailError: ""
    property string logs: ""
    property bool logsLoading: false
    property string logsError: ""

    property var statsMeta: null
    property var statsList: []
    property bool statsLoading: false
    property string statsError: ""
    property var analysis: null
    property bool analysisLoading: false
    property string analysisError: ""
    property var topData: null
    property bool topLoading: false
    property string topError: ""

    SettingsDialog {
        id: settingsDialog
        objectName: "settingsDialog"
    }

    onClosing: function(close) {
        if (dockctlTrayAvailable) {
            close.accepted = false;
            root.hide();
        } else {
            Qt.quit();
        }
    }

    Component.onCompleted: {
        root.fetchContainers();
        root.fetchStats(false);
    }

    Rectangle {
        id: popupBody
        anchors.fill: parent
        clip: true
        color: DS.cardBg

        ColumnLayout {
            id: bodyLayout
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: headerRow.implicitHeight + Kirigami.Units.smallSpacing
                color: DS.headerBg
                radius: 4

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        source: Qt.resolvedUrl("../images/docker.svg")
                    }

                    Text {
                        text: root.headerTitle()
                        font.bold: true
                        color: DS.text
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: 13
                    }

                    ChipButton {
                        id: statsChip
                        visible: config.showStatsChip !== false
                            && root.currentPage === 0 && root.statsMeta !== null
                            && root.statsMeta.available === true
                            && root.statsList.length > 0
                        text: root.statsChipText()
                        accent: true
                        maxTextWidth: 130
                        onClicked: root.openStats()
                    }

                    IconButton {
                        icon: Qt.resolvedUrl("../images/icons/chart.svg")
                        tooltip: qsTr("Consumo")
                        onClicked: root.openStats()
                    }

                    IconButton {
                        icon: Qt.resolvedUrl("../images/icons/sparkle.svg")
                        tooltip: qsTr("Análisis")
                        onClicked: root.openAnalysis()
                    }

                    IconButton {
                        icon: Qt.resolvedUrl("../images/icons/gear.svg")
                        tooltip: qsTr("Configurar")
                        onClicked: settingsDialog.open()
                    }

                    IconButton {
                        icon: Qt.resolvedUrl("../images/icons/refresh.svg")
                        tooltip: qsTr("Actualizar")
                        onClicked: root.fetchContainers()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: DS.divider
            }

            Item {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: listScroll
                    anchors.fill: parent
                    visible: root.currentPage === 0
                    clip: true
                    contentWidth: width
                    contentHeight: rowsCol.implicitHeight
                    interactive: rowsCol.implicitHeight > height

                    ColumnLayout {
                        id: rowsCol
                        width: listScroll.width
                        spacing: 4

                        Repeater {
                            model: root.stacks

                            delegate: StackSection {
                                stack: modelData
                                onOpenStack: function(key) { root.openStack(key); }
                            }
                        }

                        Item {
                            visible: root.loading
                            Layout.preferredHeight: Kirigami.Units.smallSpacing * 8
                            Layout.fillWidth: true
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Cargando contenedores…")
                                color: DS.subText
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                            }
                        }

                        Item {
                            visible: !root.loading && !root.lastError && root.containers.length === 0
                            Layout.preferredHeight: Kirigami.Units.smallSpacing * 8
                            Layout.fillWidth: true
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Sin contenedores")
                                color: DS.subText
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                            }
                        }

                        Item {
                            visible: !root.loading && !root.lastError && root.stacks.length === 0 && root.containers.length > 0
                            Layout.preferredHeight: Kirigami.Units.smallSpacing * 8
                            Layout.fillWidth: true
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Ninguno en marcha")
                                color: DS.subText
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                            }
                        }
                    }
                }

                ContainerDetail {
                    anchors.fill: parent
                    visible: root.currentPage === 1
                    container: root.currentContainer
                    detailData: root.detailData
                    loading: root.detailLoading
                    error: root.detailError
                    onBack: root.currentPage = 0
                    onRefreshRequested: root.fetchDetail(root.currentContainer ? root.currentContainer.name : "")
                    onRequestAction: function(name, action) { root.requestAction(name, action); }
                    onOpenLogs: function(name) { root.openLogs(name); }
                    onTopRequested: root.openTop()
                }

                LogsView {
                    id: logsView
                    anchors.fill: parent
                    visible: root.currentPage === 2
                    containerName: root.currentContainer ? root.currentContainer.name : ""
                    logs: root.logs
                    loading: root.logsLoading
                    error: root.logsError
                    onBack: root.currentPage = 1
                    onRefreshRequested: root.fetchLogs(root.currentContainer ? root.currentContainer.name : "")
                }

                StackDetail {
                    anchors.fill: parent
                    visible: root.currentPage === 3
                    stack: root.currentStack
                    onBack: root.currentPage = 0
                    onRefreshRequested: root.fetchContainers()
                    onOpenDetail: function(name) { root.openDetail(name); }
                    onRequestAction: function(name, action) { root.requestAction(name, action); }
                    onRestartAll: root.requestRestartAll()
                }

                StatsView {
                    anchors.fill: parent
                    visible: root.currentPage === 4
                    stats: root.statsList
                    meta: root.statsMeta
                    loading: root.statsLoading
                    error: root.statsError
                    onBack: root.currentPage = 0
                    onRefreshRequested: root.fetchStats(true)
                    onOpenDetail: function(name) { root.openDetail(name); }
                }

                AnalysisView {
                    anchors.fill: parent
                    visible: root.currentPage === 5
                    analysis: root.analysis
                    loading: root.analysisLoading
                    error: root.analysisError
                    onBack: root.currentPage = 0
                    onRefreshRequested: root.fetchAnalysis(true)
                    onRequestMaintain: function(target, title, subtitle, confirmText) {
                        root.requestMaintain(target, title, subtitle, confirmText);
                    }
                }

                TopView {
                    anchors.fill: parent
                    visible: root.currentPage === 6
                    containerName: root.currentContainer ? root.currentContainer.name : ""
                    processData: root.topData
                    loading: root.topLoading
                    error: root.topError
                    onBack: root.currentPage = 1
                    onRefreshRequested: root.fetchTop(true)
                }
            }

            RowLayout {
                id: errRow
                visible: root.lastError !== ""
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: "dialog-error"
                    color: DS.danger
                }

                Text {
                    text: root.lastError
                    color: DS.danger
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                ChipButton {
                    text: qsTr("Reintentar")
                    accent: true
                    onClicked: root.fetchContainers()
                }
            }
        }

        Rectangle {
            id: busyOverlay
            anchors.fill: parent
            visible: root.busy
            color: Qt.rgba(0.082, 0.082, 0.086, 0.72)
            z: 10

            Text {
                anchors.centerIn: parent
                text: qsTr("Ejecutando…")
                color: DS.text
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            }
        }

        Rectangle {
            id: confirmOverlay
            anchors.fill: parent
            visible: root.pendingConfirm !== null
            color: Qt.rgba(0.082, 0.082, 0.086, 0.96)
            z: 11

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width * 0.85
                spacing: Kirigami.Units.largeSpacing

                Text {
                    text: root.pendingConfirm ? root.pendingConfirm.title : ""
                    color: DS.text
                    font.bold: true
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                }

                Text {
                    text: root.pendingConfirm ? root.pendingConfirm.subtitle : ""
                    color: DS.danger
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Kirigami.Units.smallSpacing

                    ChipButton {
                        text: qsTr("Cancelar")
                        onClicked: root.pendingConfirm = null
                    }

                    ChipButton {
                        text: root.pendingConfirm ? root.pendingConfirm.confirmText : ""
                        accent: true
                        onClicked: {
                            var pc = root.pendingConfirm;
                            root.pendingConfirm = null;
                            if (pc && pc.run) {
                                pc.run();
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: pollTimer
        interval: Math.max(1, (config.refreshInterval || 5)) * 1000
        repeat: true
        running: root.visible
        onTriggered: root.fetchContainers()
    }

    // `docker stats` tarda ~2s: solo se mide con la página de consumo abierta
    // y el backend cachea 10s para que pulsar a la vez no dispare dos procesos.
    Timer {
        id: statsTimer
        interval: Math.max(5, Math.min(120, config.statsInterval || 10)) * 1000
        repeat: true
        running: root.visible && root.currentPage === 4
        onTriggered: root.fetchStats(false)
    }

    Connections {
        target: config
        function onShowStoppedChanged() {
            root.buildStacks();
        }
        function onStatsIntervalChanged() {
            statsTimer.restart();
        }
    }

    onVisibleChanged: {
        if (root.visible) {
            root.fetchContainers();
            root.fetchStats(false);
        }
    }

    function buildStacks() {
        var showStopped = config.showStopped !== false;
        var groups = {};
        var order = [];
        for (var i = 0; i < root.containers.length; i++) {
            var c = root.containers[i];
            if (!showStopped && !c.running) {
                continue;
            }
            var key = c.stack || "";
            if (!groups[key]) {
                groups[key] = { containers: [], running: 0 };
                order.push(key);
            }
            groups[key].containers.push(c);
            if (c.running) {
                groups[key].running++;
            }
        }
        var arr = [];
        for (var j = 0; j < order.length; j++) {
            var k = order[j];
            var g = groups[k];
            arr.push({
                key: k,
                title: k ? k : qsTr("Otros"),
                containers: g.containers,
                running: g.running,
                total: g.containers.length
            });
        }
        arr.sort(function(a, b) {
            if (a.key === "") {
                return 1;
            }
            if (b.key === "") {
                return -1;
            }
            return a.key.localeCompare(b.key);
        });
        root.stacks = arr;
        if (root.currentStack) {
            for (var f = 0; f < root.stacks.length; f++) {
                if (root.stacks[f].key === root.currentStack.key) {
                    root.currentStack = root.stacks[f];
                    break;
                }
            }
        }
    }

    function openStack(key) {
        for (var i = 0; i < root.stacks.length; i++) {
            if (root.stacks[i].key === key) {
                root.currentStack = root.stacks[i];
                break;
            }
        }
        root.currentPage = 3;
    }

    function openDetail(name) {
        var c = null;
        for (var i = 0; i < root.containers.length; i++) {
            if (root.containers[i].name === name) {
                c = root.containers[i];
                break;
            }
        }
        root.currentContainer = c;
        root.currentPage = 1;
        root.fetchDetail(name);
    }

    function fetchDetail(name) {
        if (!name) {
            return;
        }
        root.detailLoading = true;
        root.detailError = "";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.backendUrl + "/api/containers/" + encodeURIComponent(name));
        xhr.timeout = 20000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            root.detailLoading = false;
            if (xhr.status !== 200) {
                root.detailError = qsTr("No se pudo obtener el detalle");
                return;
            }
            var d;
            try {
                d = JSON.parse(xhr.responseText);
            } catch (err) {
                root.detailError = qsTr("Respuesta inválida");
                return;
            }
            if (d.ok) {
                root.detailData = d.detail;
            } else {
                root.detailError = d.error || qsTr("Error del backend");
            }
        };
        xhr.ontimeout = function() {
            root.detailLoading = false;
            root.detailError = qsTr("Tiempo de espera agotado");
        };
        xhr.onerror = function() {
            root.detailLoading = false;
            root.detailError = qsTr("Sin conexión con el backend");
        };
        xhr.send();
    }

    function openLogs(name) {
        root.logs = "";
        root.logsError = "";
        root.currentPage = 2;
        root.fetchLogs(name);
    }

    function fetchLogs(name) {
        if (!name) {
            return;
        }
        root.logsLoading = true;
        root.logsError = "";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.backendUrl + "/api/containers/" + encodeURIComponent(name) + "/logs?lines=300");
        xhr.timeout = 30000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            root.logsLoading = false;
            if (xhr.status !== 200) {
                root.logsError = qsTr("No se pudieron leer los logs");
                return;
            }
            var d;
            try {
                d = JSON.parse(xhr.responseText);
            } catch (err) {
                root.logsError = qsTr("Respuesta inválida");
                return;
            }
            if (d.ok) {
                root.logs = d.logs || "";
            } else {
                root.logsError = d.error || qsTr("Error del backend");
            }
        };
        xhr.ontimeout = function() {
            root.logsLoading = false;
            root.logsError = qsTr("Tiempo de espera agotado");
        };
        xhr.onerror = function() {
            root.logsLoading = false;
            root.logsError = qsTr("Sin conexión con el backend");
        };
        xhr.send();
    }

    function fetchContainers() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.backendUrl + "/api/containers");
        // `docker ps -a` puede tardar 1-3 s si el dockerd va cargado: con 3 s de
        // margen el widget se quedaba vacío sin avisar.
        xhr.timeout = 15000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            root.loading = false;
            if (xhr.status !== 200) {
                root.lastError = qsTr("Servicio backend no disponible");
                return;
            }
            var d = JSON.parse(xhr.responseText);
            if (!d.ok) {
                root.lastError = d.error || qsTr("Error del backend");
                return;
            }
            root.lastError = "";
            root.containers = d.containers;
            root.buildStacks();
            var run = 0;
            var stop = 0;
            var degrade = 0;
            for (var i = 0; i < d.containers.length; i++) {
                var c = d.containers[i];
                if (c.running) {
                    run++;
                    if (c.health && c.health !== "healthy") {
                        degrade++;
                    }
                } else {
                    stop++;
                }
            }
            root.runningCount = run;
            root.stoppedCount = stop;
            root.unhealthyCount = degrade;
        };
        xhr.ontimeout = function() {
            root.loading = false;
            root.lastError = qsTr("Tiempo de espera agotado");
        };
        xhr.onerror = function() {
            root.loading = false;
            root.lastError = qsTr("Sin conexión con el backend");
        };
        xhr.send();
    }

    function headerTitle() {
        if (root.currentPage === 4) {
            return qsTr("Consumo");
        }
        if (root.currentPage === 5) {
            return qsTr("Análisis");
        }
        if (root.currentPage === 3 && root.currentStack) {
            return root.currentStack.title;
        }
        if ((root.currentPage === 1 || root.currentPage === 2 || root.currentPage === 6)
                && root.currentContainer) {
            return root.currentContainer.name;
        }
        return qsTr("Contenedores");
    }

    function statsChipText() {
        if (!root.statsList || root.statsList.length === 0) {
            return "";
        }
        var top = root.statsList[0];
        var name = top.name || "";
        if (name.length > 16) {
            name = name.substring(0, 15) + "…";
        }
        return name + " " + (top.cpu || 0).toFixed(1) + " %";
    }

    function openStats() {
        root.currentPage = 4;
        root.fetchStats(false);
    }

    function openAnalysis() {
        root.currentPage = 5;
        root.fetchAnalysis(false);
    }

    function openTop() {
        root.topData = null;
        root.topError = "";
        root.currentPage = 6;
        root.fetchTop(false);
    }

    function fetchStats(force) {
        if (root.statsLoading) {
            return;
        }
        root.statsLoading = true;
        var url = root.backendUrl + "/api/stats" + (force ? "?refresh=1" : "");
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.timeout = 35000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            root.statsLoading = false;
            if (xhr.status !== 200) {
                root.statsError = qsTr("No se pudo medir el consumo");
                return;
            }
            var d;
            try {
                d = JSON.parse(xhr.responseText);
            } catch (err) {
                root.statsError = qsTr("Respuesta inválida");
                return;
            }
            if (d.ok === false) {
                root.statsError = d.error || qsTr("Error del backend");
                return;
            }
            root.statsError = "";
            root.statsMeta = d;
            root.statsList = d.stats || [];
        };
        xhr.ontimeout = function() {
            root.statsLoading = false;
            root.statsError = qsTr("Tiempo de espera agotado");
        };
        xhr.onerror = function() {
            root.statsLoading = false;
            root.statsError = qsTr("Sin conexión con el backend");
        };
        xhr.send();
    }

    function fetchAnalysis(force) {
        if (root.analysisLoading) {
            return;
        }
        root.analysisLoading = true;
        var url = root.backendUrl + "/api/analysis" + (force ? "?refresh=1" : "");
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.timeout = 90000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            root.analysisLoading = false;
            if (xhr.status !== 200) {
                root.analysisError = qsTr("No se pudo completar el análisis");
                return;
            }
            var d;
            try {
                d = JSON.parse(xhr.responseText);
            } catch (err) {
                root.analysisError = qsTr("Respuesta inválida");
                return;
            }
            if (d.ok === false) {
                root.analysisError = d.error || qsTr("Error del backend");
                return;
            }
            root.analysisError = "";
            root.analysis = d;
        };
        xhr.ontimeout = function() {
            root.analysisLoading = false;
            root.analysisError = qsTr("Tiempo de espera agotado");
        };
        xhr.onerror = function() {
            root.analysisLoading = false;
            root.analysisError = qsTr("Sin conexión con el backend");
        };
        xhr.send();
    }

    function fetchTop(force) {
        var name = root.currentContainer ? root.currentContainer.name : "";
        if (!name) {
            return;
        }
        root.topLoading = true;
        root.topError = "";
        var url = root.backendUrl + "/api/containers/" + encodeURIComponent(name) + "/top"
            + (force ? "?refresh=1" : "");
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.timeout = 20000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            root.topLoading = false;
            if (xhr.status !== 200) {
                root.topError = qsTr("No se pudieron leer los procesos");
                return;
            }
            var d;
            try {
                d = JSON.parse(xhr.responseText);
            } catch (err) {
                root.topError = qsTr("Respuesta inválida");
                return;
            }
            if (d.ok === false) {
                root.topError = d.error || qsTr("Error del backend");
                return;
            }
            root.topData = d.top || null;
        };
        xhr.ontimeout = function() {
            root.topLoading = false;
            root.topError = qsTr("Tiempo de espera agotado");
        };
        xhr.onerror = function() {
            root.topLoading = false;
            root.topError = qsTr("Sin conexión con el backend");
        };
        xhr.send();
    }

    function requestMaintain(target, title, subtitle, confirmText) {
        if (root.busy) {
            return;
        }
        root.pendingConfirm = {
            title: title,
            subtitle: subtitle,
            confirmText: confirmText,
            run: function() { root.doMaintain(target); }
        };
    }

    function doMaintain(target) {
        root.busy = true;
        root.lastError = "";
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.backendUrl + "/api/maintain/" + encodeURIComponent(target));
        xhr.timeout = 300000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            root.busy = false;
            var d = null;
            try {
                d = JSON.parse(xhr.responseText);
            } catch (e) {}
            if (xhr.status !== 200 || !d || d.ok === false) {
                root.lastError = (d && d.error) || qsTr("No se pudo completar la limpieza");
            } else {
                root.lastError = "";
            }
            root.fetchAnalysis(true);
            root.fetchStats(true);
        };
        xhr.ontimeout = function() {
            root.busy = false;
            root.lastError = qsTr("Tiempo de espera agotado");
        };
        xhr.onerror = function() {
            root.busy = false;
            root.lastError = qsTr("Sin conexión con el backend");
        };
        xhr.send();
    }

    function requestAction(name, action) {
        if (root.busy) {
            return;
        }
        if (action === "remove" && config.confirmRemove) {
            root.pendingConfirm = {
                title: qsTr("¿Eliminar el contenedor «%1»?").arg(name),
                subtitle: qsTr("Esta acción es irreversible."),
                confirmText: qsTr("Eliminar"),
                run: function() { root.doAction(name, "remove"); }
            };
            return;
        }
        doAction(name, action);
    }

    function requestRestartAll() {
        if (root.busy || !root.currentStack) {
            return;
        }
        var st = root.currentStack;
        root.pendingConfirm = {
            title: qsTr("¿Reiniciar todos los contenedores de «%1»?").arg(st.title),
            subtitle: qsTr("Se reiniciarán %1 contenedores del stack.").arg(st.containers.length),
            confirmText: qsTr("Reiniciar"),
            run: function() { root.doRestartAll(st.key); }
        };
    }

    function doRestartAll(key) {
        root.busy = true;
        root.lastError = "";
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.backendUrl + "/api/stacks/" + encodeURIComponent(key) + "/restart");
        xhr.timeout = 60000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            root.busy = false;
            if (xhr.status !== 200) {
                root.lastError = qsTr("No se pudo reiniciar el stack");
            } else {
                try {
                    var d = JSON.parse(xhr.responseText);
                    if (d.failed && d.failed.length > 0) {
                        root.lastError = qsTr("%1 contenedores fallaron al reiniciar").arg(d.failed.length);
                    }
                } catch (e) {}
            }
            root.fetchContainers();
        };
        xhr.ontimeout = function() {
            root.busy = false;
            root.lastError = qsTr("Tiempo de espera agotado");
        };
        xhr.onerror = function() {
            root.busy = false;
            root.lastError = qsTr("Sin conexión con el backend");
        };
        xhr.send();
    }

    function doAction(name, action) {
        root.busy = true;
        root.lastError = "";
        var xhr = new XMLHttpRequest();
        xhr.open("POST", root.backendUrl + "/api/containers/" + encodeURIComponent(name) + "/" + action);
        xhr.timeout = 15000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            root.busy = false;
            if (xhr.status !== 200) {
                var parsed = {};
                try {
                    parsed = JSON.parse(xhr.responseText);
                } catch (e) {}
                root.lastError = parsed.error || qsTr("No se pudo %1 «%2»").arg(action).arg(name);
            } else {
                if (action === "remove" && root.currentPage === 1) {
                    root.currentPage = 0;
                } else if (root.currentPage === 1 && root.currentContainer && root.currentContainer.name === name) {
                    root.fetchDetail(name);
                }
            }
            root.fetchContainers();
        };
        xhr.ontimeout = function() {
            root.busy = false;
            root.lastError = qsTr("Tiempo de espera agotado");
        };
        xhr.onerror = function() {
            root.busy = false;
            root.lastError = qsTr("Sin conexión con el backend");
        };
        xhr.send();
    }
}
