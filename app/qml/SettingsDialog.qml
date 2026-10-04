import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: dialog

    title: qsTr("Configuración")
    preferredWidth: Kirigami.Units.gridUnit * 22
    // Se fija la posición para romper el bucle `y` ↔ `opacity` de Kirigami.
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: qsTr("Actualizar cada")
                Layout.fillWidth: true
            }

            SpinBox {
                from: 1
                to: 120
                value: config.refreshInterval
                onValueModified: config.refreshInterval = value
            }

            Label {
                text: qsTr("s")
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: qsTr("Medir consumo cada")
                Layout.fillWidth: true
            }

            SpinBox {
                from: 5
                to: 120
                value: config.statsInterval
                onValueModified: config.statsInterval = value
            }

            Label {
                text: qsTr("s")
            }
        }

        CheckBox {
            Layout.fillWidth: true
            text: qsTr("Mostrar contenedores detenidos")
            checked: config.showStopped
            onToggled: config.showStopped = checked
        }

        CheckBox {
            Layout.fillWidth: true
            text: qsTr("Mostrar chip de consumo")
            checked: config.showStatsChip
            onToggled: config.showStatsChip = checked
        }

        CheckBox {
            Layout.fillWidth: true
            text: qsTr("Confirmar antes de eliminar")
            checked: config.confirmRemove
            onToggled: config.confirmRemove = checked
        }
    }
}
