import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Components
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services

StyledRect {
    id: root

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge

    implicitWidth: Tokens.sizes.dashboard.perfHeroCardWidth * 0.7
    implicitHeight: col.implicitHeight + Tokens.padding.large * 2

    Ref {
        service: RTorrentData
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["/home/carl/.local/bin/qbittorrent-action", "open"])
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: RTorrentData.statusIcon()
                color: RTorrentData.stateColor()
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                text: qsTr("Data Link")
                font: Tokens.font.title.medium
                color: Colours.palette.m3onSurface
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: RTorrentData.state
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                color: RTorrentData.stateColor()
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: RTorrentData.currentName.length > 0 ? RTorrentData.currentName : qsTr("No torrents")
            elide: Text.ElideRight
            font: Tokens.font.body.builders.small.weight(Font.Medium).build()
            color: Colours.palette.m3onSurface
        }

        StyledProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.padding.small
            value: (RTorrentData.currentProgress ?? 0) / 100
            indeterminate: RTorrentData.currentProgress === null
            fgColour: RTorrentData.stateColor()
        }

        StyledText {
            text: RTorrentData.currentMetadataPending
                ? qsTr("%1 · Waiting for metadata · R %2")
                    .arg(RTorrentData.formatProgress(RTorrentData.currentProgress))
                    .arg(RTorrentData.formatRatio(RTorrentData.currentRatio))
                : qsTr("%1 · ETA %2 · R %3")
                .arg(RTorrentData.formatProgress(RTorrentData.currentProgress))
                .arg(RTorrentData.formatDuration(RTorrentData.currentEta))
                .arg(RTorrentData.formatRatio(RTorrentData.currentRatio))
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
        }

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "download"
                color: Colours.palette.m3tertiary
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                text: qsTr("Down")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: RTorrentData.formatSpeed(RTorrentData.downloadBps)
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                color: Colours.palette.m3tertiary
            }
        }

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "upload"
                color: Colours.palette.m3secondary
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                text: qsTr("Up")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: RTorrentData.formatSpeed(RTorrentData.uploadBps)
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                color: Colours.palette.m3secondary
            }
        }

        StyledText {
            text: qsTr("Active %1 · DL %2 · SE %3 · PA %4")
                .arg(RTorrentData.count(RTorrentData.active))
                .arg(RTorrentData.count(RTorrentData.downloading))
                .arg(RTorrentData.count(RTorrentData.seeding))
                .arg(RTorrentData.count(RTorrentData.pausedCount))
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
