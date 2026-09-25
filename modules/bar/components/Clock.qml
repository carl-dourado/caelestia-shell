pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import Quickshell
import qs.components.controls

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    readonly property var font: Tokens.font.body.builders.small.scale(1.1)

    function fontFor(text: string, metricWidth: int): font {
        // We don't count seconds for the max width because it changes too often
        const scale = text === "11" ? 1.15 : Math.min(1.05, Math.max(hourMetrics.width, minMetrics.width) / metricWidth);
        return root.font.width(scale * 100).letterSpacing(scale).build();
    }


    required property var bar
    readonly property var popouts: root.bar?.popouts ?? null
    readonly property var calendar: (popouts?.currentName === "clock") ? (popouts.current ?? null) : null

    property bool menuOpen: false
    property int hoverOpenDelay: 350
    property int hoverCloseDelay: 250

// --- Date helpers ----------------------------------------------------

    // Auxiliary PT-BR weekday translation (English stays the main display).
    function weekdayPt(d: date): string {
        return ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"][d.getDay()];
    }

    function timeStr(): string {
        return Units.twelveHourClock ? `${Time.hourStr}:${Time.minuteStr} ${Time.amPmStr}` : Time.format("HH:mm");
    }

    function dateIso(): string {
        return Time.format("yyyy-MM-dd");
    }

    function dateTimeIso(): string {
        return Time.format("yyyy-MM-dd HH:mm");
    }

    function timestamp(): string {
        return String(Math.floor(Time.date.getTime() / 1000));
    }

    function copyTime(): void {
        Quickshell.clipboardText = timeStr();
        Toaster.toast(qsTr("Time copied"), timeStr(), "schedule");
    }

    function copyDate(): void {
        Quickshell.clipboardText = dateIso();
        Toaster.toast(qsTr("Date copied"), dateIso(), "calendar_today");
    }

    function copyDateTime(): void {
        Quickshell.clipboardText = dateTimeIso();
        Toaster.toast(qsTr("Date & time copied"), dateTimeIso(), "event");
    }

    function copyTimestamp(): void {
        Quickshell.clipboardText = timestamp();
        Toaster.toast(qsTr("Timestamp copied"), timestamp(), "timer");
    }

    // --- Popout control ----------------------------------------------------------

    function openPopout(mode: string): void {
        if (!root.popouts)
            return;

        root.popouts.currentName = "clock";
        root.popouts.currentCenter = root.mapToItem(root.bar, 0, root.implicitHeight / 2).y;
        root.popouts.hasCurrent = true;

        // The popout item is created on the same frame the state flips; defer the
        // mode switch one tick so the item is guaranteed to exist.
        Qt.callLater(() => {
            const cal = root.popouts?.current;
            if (cal && cal.mode !== mode)
                cal.mode = mode;
        });
    }

    function toggleCalendar(): void {
        if (!root.popouts)
            return;

        hoverOpenTimer.stop();
        hoverCloseTimer.stop();

        const cal = (root.popouts.currentName === "clock") ? (root.popouts.current ?? null) : null;
        if (root.popouts.hasCurrent && cal) {
            if (cal.mode === "calendar") {
                // Second click closes the calendar popout.
                root.popouts.hasCurrent = false;
            } else {
                // Upgrade the hover popout into the full calendar.
                cal.mode = "calendar";
            }
        } else {
            root.openPopout("calendar");
        }
    }

    
    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        Loader {
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        Loader {
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: Config.bar.clock.showDate
            visible: active

            sourceComponent: ColumnLayout {
                spacing: layout.spacing - 4

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Time.format("ddd")
                    font: Tokens.font.body.builders.small.scale(0.9).build()
                    color: root.colour
                }

                // PT-BR auxiliary weekday translation: secondary and discreet.
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.weekdayPt(Time.date)
                    font: Tokens.font.body.builders.small.scale(0.75).build()
                    color: root.colour
                    opacity: 0.55
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Time.format("d")
                    font: root.font.scale(1.1).build()
                    color: root.colour
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.leftMargin: -Tokens.padding.extraSmall
                    Layout.rightMargin: -Tokens.padding.extraSmall
                    Layout.topMargin: 4
                    Layout.bottomMargin: Tokens.padding.extraSmall / 2
                    implicitHeight: 1
                    color: Colours.palette.m3outlineVariant
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.hourStr
            font: root.fontFor(text, hourMetrics.width)
            color: root.colour

            TextMetrics {
                id: hourMetrics

                font: root.font.build()
                text: Time.hourStr
            }
        }

        StyledText {
            Layout.topMargin: -parent.spacing - 4
            Layout.alignment: Qt.AlignHCenter
            text: Time.minuteStr
            font: root.fontFor(text, minMetrics.width)
            color: root.colour

            TextMetrics {
                id: minMetrics

                font: root.font.build()
                text: Time.minuteStr
            }
        }

        Loader {
            Layout.topMargin: -parent.spacing - 4
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: Config.bar.clock.showSeconds
            visible: active

            sourceComponent: StyledText {
                text: Time.format("ss")
                font: root.fontFor(text, secMetrics.width)
                color: root.colour

                TextMetrics {
                    id: secMetrics

                    font: root.font.build()
                    text: Time.format("ss")
                }
            }
        }

        Loader {
            Layout.topMargin: -parent.spacing - 4
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: Units.twelveHourClock
            visible: active

            sourceComponent: StyledText {
                text: Time.amPmStr.toLowerCase()
                font: Tokens.font.body.builders.small.scale(0.9).build()
                color: root.colour
            }
        }
    }

    // --- Interactions ------------------------------------------------------------

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            hoverCloseTimer.stop();
            if (!root.popouts?.hasCurrent || root.popouts?.currentName !== "clock")
                hoverOpenTimer.start();
        }

        onExited: {
            hoverOpenTimer.stop();
            hoverCloseTimer.start();
        }

        onClicked: e => {
            if (e.button === Qt.LeftButton)
                root.toggleCalendar();
            else if (e.button === Qt.RightButton)
                root.openMenu();
            else if (e.button === Qt.MiddleButton)
                root.copyDateTime();
        }
    }

    // Small delay so a quick crossing of the cursor does not pop anything up.
    Timer {
        id: hoverOpenTimer

        interval: root.hoverOpenDelay
        onTriggered: {
            if (!root.popouts?.hasCurrent || root.popouts?.currentName !== "clock")
                root.openPopout("compact");
        }
    }

    Timer {
        id: hoverCloseTimer

        interval: root.hoverCloseDelay
        onTriggered: {
            // Only auto-close the passive hover popout, never the calendar.
            const cal = root.calendar;
            if (cal && cal.mode === "compact" && !cal.hovered)
                root.popouts.hasCurrent = false;
        }
    }

    Menu {
        id: menu

        attachTo: root
        attachSideX: Menu.Right
        thisSideX: Menu.Left
        attachSideY: Menu.Top
        thisSideY: Menu.Top
        marginX: Tokens.spacing.small
        marginY: root.height / 2

        expanded: root.menuOpen
        onExpandedChanged: {
            if (!expanded)
                root.menuOpen = false;
        }

        items: [
            MenuItem {
                text: qsTr("Copy time")
                icon: "schedule"
                onClicked: root.copyTime()
            },
            MenuItem {
                text: qsTr("Copy date")
                icon: "calendar_today"
                onClicked: root.copyDate()
            },
            MenuItem {
                text: qsTr("Copy date & time")
                icon: "event"
                onClicked: root.copyDateTime()
            },
            MenuItem {
                text: qsTr("Copy timestamp")
                icon: "timer"
                onClicked: root.copyTimestamp()
            }
        ]
    }
}
