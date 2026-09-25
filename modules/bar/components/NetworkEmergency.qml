import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property string connectionState: "checking"
    property string actionOutput: ""
    property string currentAction: ""
    property bool busy: false
    readonly property bool emergency: connectionState === "emergency" || connectionState === "emergency-offline"
    readonly property string iconName: {
        if (busy || connectionState === "checking")
            return "sync";
        if (connectionState === "protected")
            return "verified_user";
        if (connectionState === "emergency")
            return "gpp_maybe";
        if (connectionState === "emergency-offline")
            return "wifi_off";
        if (connectionState === "unprotected")
            return "shield_question";
        return "signal_wifi_off";
    }
    readonly property color iconColour: {
        if (connectionState === "protected")
            return Colours.palette.m3primary;
        if (emergency || connectionState === "offline")
            return Colours.palette.m3error;
        return Colours.palette.m3tertiary;
    }

    function refresh(): void {
        if (!statusProc.running && !busy)
            statusProc.running = true;
    }

    function runAction(action: string): void {
        busy = true;
        actionOutput = "";
        currentAction = action;
        connectionState = "checking";
        actionProc.exec(["/usr/bin/sudo", "-n", "/usr/local/sbin/network-fallback", action]);
    }

    function handleClick(): void {
        if (busy)
            return;

        if (connectionState !== "protected") {
            activationArm.stop();
            runAction("off");
            Toaster.toast(qsTr("Restaurando proteção"), qsTr("Testando o WARP; se ele falhar, a internet direta será mantida."), "shield_lock");
            return;
        }

        if (activationArm.running) {
            activationArm.stop();
            runAction("on");
            return;
        }

        activationArm.restart();
        Toaster.toast(qsTr("Confirmar modo de emergência"), qsTr("Clique novamente no escudo em até 5 segundos. Seu IP ficará visível, mas o firewall continuará ativo."), "warning");
    }

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        disabled: root.busy
        onClicked: root.handleClick()
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        text: root.iconName
        color: root.iconColour
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()

        RotationAnimation on rotation {
            running: root.busy
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
        }
    }

    Timer {
        id: activationArm
        interval: 5000
    }

    Timer {
        interval: 15000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProc

        command: ["/usr/bin/sudo", "-n", "/usr/local/sbin/network-fallback", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text.trim());
                    root.connectionState = value.state ?? "offline";
                } catch (error) {
                    root.connectionState = "offline";
                }
            }
        }
    }

    Process {
        id: actionProc

        stdout: StdioCollector {
            onStreamFinished: root.actionOutput = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.actionOutput = text.trim();
            }
        }
        onExited: exitCode => {
            root.busy = false;
            root.refresh();
            if (exitCode === 0) {
                if (root.currentAction === "on")
                    Toaster.toast(qsTr("Modo de emergência ativo"), qsTr("Internet direta com firewall local. O IP não está oculto pelo WARP."), "gpp_maybe");
                else
                    Toaster.toast(qsTr("Comando concluído"), root.actionOutput || qsTr("Estado da conexão atualizado."), "verified_user");
            } else {
                Toaster.toast(qsTr("Falha ao mudar a conexão"), root.actionOutput || qsTr("A internet direta foi preservada; confira o estado do WARP."), "error");
            }
        }
    }
}
