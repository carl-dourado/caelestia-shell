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

    readonly property var presetKeys: ["mp4", "webm", "mp3", "flac", "opus", "wav", "extract", "copy", "reduce", "custom"]

    property string selectedPreset: "mp4"
    property string inputPath: ""
    property string destDir: ""
    property string startError: ""

    // custom preset state
    property string customVcodec: "libx264"
    property string customVpreset: "medium"
    property int customCrf: 23
    property string customAcodec: "aac"
    property int customAbitrate: 192
    property string customExt: "mp4"

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    FileDialog {
        id: picker

        title: qsTr("Select a media file")
        filterLabel: qsTr("Media files")
        filters: ["*.mp4", "*.mkv", "*.webm", "*.mov", "*.avi", "*.flv", "*.m4a", "*.mp3", "*.flac", "*.opus", "*.ogg", "*.wav", "*.aac", "*.mka"]
        onAccepted: path => {
            root.inputPath = path;
            root.startError = "";
            MediaData.probeFile(path);
        }
    }

    FileDialog {
        id: destPicker

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

    readonly property string outName: {
        if (root.inputPath.length === 0)
            return "";
        const stem = MediaData.stemOf(root.inputPath);
        if (root.selectedPreset === "copy")
            return `${stem}.${MediaData.extOf(root.inputPath)}`;
        return `${stem}.${MediaData.convertPresets[root.selectedPreset].ext}`;
    }

    Component.onCompleted: {
        root.destDir = MediaData.lastConvertDir || `${Paths.home}/Downloads`;
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        RowLayout {
            spacing: Tokens.spacing.small

            StyledTextField {
                id: inputField

                Layout.fillWidth: true
                type: StyledTextField.Filled
                text: root.inputPath
                placeholderText: qsTr("Select an input file…")
                leadingIcon: "video_file"
                onTextEdited: {
                    root.inputPath = text;
                    if (text.length > 0)
                        MediaData.probeFile(text);
                }
            }

            IconTextButton {
                icon: "folder"
                text: qsTr("BROWSE")
                onClicked: picker.open()
            }
        }

        Loader {
            active: MediaData.probeBusy || MediaData.probe || MediaData.probeError.length > 0 || root.startError.length > 0
            visible: active
            Layout.fillWidth: true

            sourceComponent: RowLayout {
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: MediaData.probeBusy ? "hourglass_top" : (MediaData.probeError.length > 0 || root.startError.length > 0) ? "error" : "verified"
                    color: MediaData.probeBusy ? Colours.palette.m3secondary : (MediaData.probeError.length > 0 || root.startError.length > 0) ? Colours.palette.m3error : Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: MediaData.probeBusy
                        ? qsTr("Analyzing file…")
                        : root.startError.length > 0
                            ? root.startError
                            : MediaData.probeError.length > 0
                                ? MediaData.probeError
                                : [
                                MediaData.probe.hasVideo ? `Video: ${MediaData.probe.vcodec}` : "",
                                MediaData.probe.hasAudio ? `Audio: ${MediaData.probe.acodec}` : "",
                                MediaData.probe.duration ? `Duration: ${MediaData.formatDuration(MediaData.probe.duration)}` : "",
                                MediaData.probe.container ? MediaData.probe.container.toUpperCase() : ""
                            ].filter(s => s.length > 0).join(" · ")
                    font: Tokens.font.body.builders.small.scale(0.9).build()
                    color: MediaData.probeError.length > 0 || root.startError.length > 0 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        RowLayout {
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("PRESET")
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                color: Colours.palette.m3onSurfaceVariant
            }

            Repeater {
                id: presetRepeater

                model: ScriptModel {
                    values: Object.values(MediaData.convertPresets)
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
        }

        // Modo customizado (estruturado, sem entrada livre de comandos)
        Loader {
            active: root.selectedPreset === "custom"
            visible: active
            Layout.fillWidth: true

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.small

                RowLayout {
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("VIDEO")
                        font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Repeater {
                        model: ["libx264", "libx265", "libvpx-vp9", "none"]

                        delegate: StyledRect {
                            required property string modelData

                            readonly property bool selected: root.customVcodec === modelData

                            radius: Tokens.rounding.full
                            color: selected ? Qt.alpha(Colours.palette.m3tertiary, 0.18) : Qt.alpha(Colours.palette.m3onSurface, 0.06)
                            implicitWidth: lbl.implicitWidth + Tokens.padding.medium
                            implicitHeight: lbl.implicitHeight + Tokens.padding.small

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.customVcodec = modelData
                            }

                            StyledText {
                                id: lbl

                                anchors.centerIn: parent
                                text: modelData === "none" ? "NO VIDEO" : modelData
                                font: Tokens.font.body.builders.small.scale(0.85).weight(selected ? Font.Medium : Font.Normal).build()
                                color: selected ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        visible: root.customVcodec !== "none"
                        text: qsTr("CRF")
                        font: Tokens.font.body.builders.small.scale(0.85).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledSpinBox {
                        visible: root.customVcodec !== "none"
                        from: 0
                        to: 51
                        stepSize: 1
                        value: root.customCrf
                        onValueModified: root.customCrf = value
                    }

                    StyledText {
                        visible: root.customVcodec !== "none"
                        text: qsTr("PRESET")
                        font: Tokens.font.body.builders.small.scale(0.85).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Repeater {
                        visible: root.customVcodec !== "none"
                        model: ["fast", "medium", "slow"]

                        delegate: StyledRect {
                            required property string modelData

                            readonly property bool selected: root.customVpreset === modelData

                            radius: Tokens.rounding.full
                            color: selected ? Qt.alpha(Colours.palette.m3tertiary, 0.18) : Qt.alpha(Colours.palette.m3onSurface, 0.06)
                            implicitWidth: lbl.implicitWidth + Tokens.padding.medium
                            implicitHeight: lbl.implicitHeight + Tokens.padding.small

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.customVpreset = modelData
                            }

                            StyledText {
                                id: lbl

                                anchors.centerIn: parent
                                text: modelData
                                font: Tokens.font.body.builders.small.scale(0.85).weight(selected ? Font.Medium : Font.Normal).build()
                                color: selected ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }

                RowLayout {
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("AUDIO")
                        font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Repeater {
                        model: ["aac", "libopus", "libmp3lame", "copy", "none"]

                        delegate: StyledRect {
                            required property string modelData

                            readonly property bool selected: root.customAcodec === modelData

                            radius: Tokens.rounding.full
                            color: selected ? Qt.alpha(Colours.palette.m3tertiary, 0.18) : Qt.alpha(Colours.palette.m3onSurface, 0.06)
                            implicitWidth: lbl.implicitWidth + Tokens.padding.medium
                            implicitHeight: lbl.implicitHeight + Tokens.padding.small

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.customAcodec = modelData
                            }

                            StyledText {
                                id: lbl

                                anchors.centerIn: parent
                                text: modelData === "none" ? "NO AUDIO" : modelData
                                font: Tokens.font.body.builders.small.scale(0.85).weight(selected ? Font.Medium : Font.Normal).build()
                                color: selected ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        visible: root.customAcodec !== "none" && root.customAcodec !== "copy"
                        text: qsTr("BITRATE")
                        font: Tokens.font.body.builders.small.scale(0.85).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledSpinBox {
                        visible: root.customAcodec !== "none" && root.customAcodec !== "copy"
                        from: 64
                        to: 512
                        stepSize: 32
                        value: root.customAbitrate
                        onValueModified: root.customAbitrate = value
                    }

                    StyledText {
                        text: qsTr("EXT")
                        font: Tokens.font.body.builders.small.scale(0.85).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Repeater {
                        model: ["mp4", "webm", "mkv"]

                        delegate: StyledRect {
                            required property string modelData

                            readonly property bool selected: root.customExt === modelData

                            radius: Tokens.rounding.full
                            color: selected ? Qt.alpha(Colours.palette.m3tertiary, 0.18) : Qt.alpha(Colours.palette.m3onSurface, 0.06)
                            implicitWidth: lbl.implicitWidth + Tokens.padding.medium
                            implicitHeight: lbl.implicitHeight + Tokens.padding.small

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.customExt = modelData
                            }

                            StyledText {
                                id: lbl

                                anchors.centerIn: parent
                                text: modelData
                                font: Tokens.font.body.builders.small.scale(0.85).weight(selected ? Font.Medium : Font.Normal).build()
                                color: selected ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }
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
                onClicked: destPicker.open()
            }
        }

        StyledText {
            visible: root.outName.length > 0
            text: qsTr("Output: ") + root.outName
            font: Tokens.font.body.builders.small.scale(0.9).build()
            color: Colours.palette.m3onSurfaceVariant
            elide: Text.ElideMiddle
            maximumLineCount: 1
        }

        StyledText {
            visible: root.inputPath.length > 0 && !MediaData.probeError.length && MediaData.probe && !MediaData.probe.hasAudio && ["mp3", "flac", "opus", "wav", "extract"].includes(root.selectedPreset)
            text: qsTr("Este arquivo não parece ter faixa de áudio.")
            font: Tokens.font.body.builders.small.scale(0.9).build()
            color: Colours.palette.m3error
        }

        StyledText {
            visible: destField.text.length > 0 && !MediaData.sanitizeDir(destField.text)
            text: qsTr("Pasta de destino inválida (use um caminho absoluto)")
            font: Tokens.font.body.builders.small.scale(0.9).build()
            color: Colours.palette.m3error
        }

        IconTextButton {
            icon: "swap_vert"
            text: qsTr("START CONVERT")
            Layout.preferredWidth: implicitWidth
            disabled: root.inputPath.length === 0
            onClicked: {
                root.startError = "";
                const custom = {
                    vcodec: root.customVcodec,
                    vpreset: root.customVpreset,
                    crf: String(root.customCrf),
                    acodec: root.customAcodec,
                    abitrate: String(root.customAbitrate),
                    ext: root.customExt
                };
                const r = MediaData.addConvert(root.inputPath, root.selectedPreset, destField.text, root.selectedPreset === "custom" ? custom : null);
                if (!r.ok)
                    root.startError = r.error;
            }
        }
    }
}
