import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils

Item {
    id: root

    readonly property var presetKeys: ["mp4", "webm", "best", "mp3", "flac", "opus"]

    property string selectedPreset: "mp4"
    property string destDir: ""
    property string startError: ""

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    FileDialog {
        id: picker

        title: qsTr("Select a file inside the destination folder")
        filters: ["*"]
        onAccepted: path => {
            const idx = path.lastIndexOf("/");
            const dir = idx > 0 ? path.slice(0, idx) : path;
            if (dir.length > 1) {
                root.destDir = dir;
                destField.text = dir;
            }
        }
    }

    function applyPendingUrl() {
        if (MediaData.pendingUrl && MediaData.pendingUrl.length > 0) {
            urlField.text = MediaData.pendingUrl;
            MediaData.pendingUrl = "";
        }
    }

    function focusUrl() {
        urlField.forceActiveFocus();
        urlField.cursorPosition = urlField.text.length;
    }

    onVisibleChanged: {
        if (root.visible) {
            root.applyPendingUrl();
            root.focusUrl();
        }
    }

    Component.onCompleted: {
        root.destDir = MediaData.lastDownloadDir || `${Paths.home}/Downloads`;
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        RowLayout {
            spacing: Tokens.spacing.small

            StyledTextField {
                id: urlField

                Layout.fillWidth: true
                type: StyledTextField.Outlined
                placeholderText: qsTr("https://…")
                leadingIcon: "link"
                validate: /^https?:\/\/\S+$/
            }

            IconTextButton {
                icon: "search"
                text: qsTr("IDENTIFY")
                disabled: urlField.text.length === 0 || MediaData.identifyBusy
                onClicked: {
                    root.startError = "";
                    MediaData.identify(urlField.text);
                }
            }
        }

        Loader {
            active: MediaData.identifyBusy || MediaData.identifyTitle.length > 0 || MediaData.identifyError.length > 0 || root.startError.length > 0
            visible: active
            Layout.fillWidth: true

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: MediaData.identifyBusy ? "hourglass_top" : (MediaData.identifyError.length > 0 || root.startError.length > 0) ? "error" : "verified"
                        color: MediaData.identifyBusy ? Colours.palette.m3secondary : (MediaData.identifyError.length > 0 || root.startError.length > 0) ? Colours.palette.m3error : Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: MediaData.identifyBusy
                            ? qsTr("Identifying media…")
                            : MediaData.identifyError.length > 0
                                ? MediaData.identifyError
                                : root.startError.length > 0
                                    ? root.startError
                                    : MediaData.identifyTitle
                        font: (MediaData.identifyError.length > 0 || root.startError.length > 0)
                            ? Tokens.font.body.small
                            : Tokens.font.body.builders.small.weight(Font.Medium).build()
                        color: (MediaData.identifyError.length > 0 || root.startError.length > 0) ? Colours.palette.m3error : Colours.palette.m3onSurface
                        elide: Text.ElideMiddle
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }
                }

                StyledText {
                    visible: !MediaData.identifyBusy && MediaData.identifyTitle.length > 0
                    text: [MediaData.identifyUploader, MediaData.identifyDuration].filter(s => s && s.length > 0).join(" · ")
                    font: Tokens.font.body.builders.small.scale(0.9).build()
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        RowLayout {
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("FORMAT")
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                color: Colours.palette.m3onSurfaceVariant
            }

            Repeater {
                id: presetRepeater

                model: ScriptModel {
                    values: Object.values(MediaData.downloadPresets)
                }

                delegate: StyledRect {
                    required property int index
                    required property var modelData

                    readonly property bool selected: root.selectedPreset === root.presetKeys[index]

                    radius: Tokens.rounding.full
                    color: selected ? Qt.alpha(Colours.palette.m3primary, 0.18) : Qt.alpha(Colours.palette.m3onSurface, 0.06)
                    implicitWidth: chipLabel.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: chipLabel.implicitHeight + Tokens.padding.small * 2

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedPreset = root.presetKeys[index]
                    }

                    StyledText {
                        id: chipLabel

                        anchors.centerIn: parent
                        text: modelData.label
                        font: Tokens.font.body.builders.small.weight(selected ? Font.Medium : Font.Normal).build()
                        color: selected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "folder_open"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            StyledTextField {
                id: destField

                Layout.fillWidth: true
                type: StyledTextField.Filled
                text: root.destDir
                placeholderText: qsTr("Destination folder")
                onTextEdited: root.destDir = text
            }

            IconTextButton {
                icon: "folder"
                text: qsTr("CHANGE")
                onClicked: picker.open()
            }
        }

        StyledText {
            visible: destField.text.length > 0 && !MediaData.sanitizeDir(destField.text)
            text: qsTr("Pasta de destino inválida (use um caminho absoluto)")
            font: Tokens.font.body.builders.small.scale(0.9).build()
            color: Colours.palette.m3error
        }

        IconTextButton {
            icon: "play_arrow"
            text: qsTr("START DOWNLOAD")
            Layout.preferredWidth: implicitWidth
            onClicked: {
                root.startError = "";
                const r = MediaData.addDownload(urlField.text, root.selectedPreset, destField.text);
                if (!r.ok)
                    root.startError = r.error;
            }
        }
    }
}
