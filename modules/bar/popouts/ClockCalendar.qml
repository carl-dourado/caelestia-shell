pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import M3Shapes
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    required property PopoutState popouts

    // Display mode: "compact" (hover popout) or "calendar" (full calendar).
    property string mode: "compact"
    // Whether the pointer is currently over the popout (keeps the compact
    // popout alive while the cursor travels from the clock into it).
    property bool hovered: false

    // Calendar state. Independent from the dashboard calendar.
    property date viewDate: new Date()
    property var selectedDate: null
    // 0 = days, 1 = months, 2 = years
    property int view: 0

    readonly property int cellW: 36
    readonly property int gridSpacing: 3
    readonly property int gridW: root.cellW * 7 + root.gridSpacing * 6
    readonly property int viewYear: root.viewDate.getFullYear()
    readonly property int viewMonth: root.viewDate.getMonth()
    readonly property int nowMonth: Time.date.getMonth()
    readonly property int nowYear: Time.date.getFullYear()
    readonly property int decadeStart: Math.floor(root.viewYear / 10) * 10
    readonly property bool twelveHour: Units.twelveHourClock

    // Header strings are refreshed by the tick timer only while the popout is
    // visible, so idle operation stays as cheap as the rest of the bar.
    property string weekdayName: ""
    property string fullDate: ""
    property string secondsStr: "00"

    readonly property string timeMainStr: `${Time.hourStr}:${Time.minuteStr}`
    readonly property string viewTitle: {
        if (root.view === 1)
            return String(root.viewYear);
        if (root.view === 2)
            return `${root.decadeStart - 1} – ${root.decadeStart + 10}`;
        return Qt.locale().toString(root.viewDate, "MMMM yyyy");
    }

    implicitWidth: rootCol.implicitWidth
    implicitHeight: rootCol.implicitHeight

    focus: root.mode === "calendar"

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.popouts.hasCurrent = false;
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_PageUp) {
            root.prev();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_PageDown) {
            root.next();
            event.accepted = true;
            return;
        }
        if (root.view !== 0)
            return;

        let delta = 0;
        switch (event.key) {
        case Qt.Key_Left: delta = -1; break;
        case Qt.Key_Right: delta = 1; break;
        case Qt.Key_Up: delta = -7; break;
        case Qt.Key_Down: delta = 7; break;
        default: return;
        }
        event.accepted = true;
        root.moveDay(delta);
    }

    // --- Weekday helpers (English main, PT-BR secondary) --------------------------

    readonly property var enWeekdays: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var ptWeekdays: ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]

    // Full weekday names shown in the hover tooltip (English only).
    readonly property var enFullWeekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    // Weekday-row hover tooltip state. Hover events in QtQuick only reach the
    // topmost MouseArea under the cursor (the popout overlay), so the overlay
    // hit-tests the weekday row and drives the tooltip from the column index.
    property int hoveredDayIndex: -1
    property string hoveredDayName: ""
    property bool dayTooltipVisible: false

    // --- Navigation ---------------------------------------------------------------

    function prev(): void {
        if (root.view === 0)
            root.viewDate = new Date(root.viewYear, root.viewMonth - 1, 1);
        else if (root.view === 1)
            root.viewDate = new Date(root.viewYear - 1, root.viewMonth, 1);
        else
            root.viewDate = new Date(root.viewYear - 10, root.viewMonth, 1);
    }

    function next(): void {
        if (root.view === 0)
            root.viewDate = new Date(root.viewYear, root.viewMonth + 1, 1);
        else if (root.view === 1)
            root.viewDate = new Date(root.viewYear + 1, root.viewMonth, 1);
        else
            root.viewDate = new Date(root.viewYear + 10, root.viewMonth, 1);
    }

    function cycleView(): void {
        root.hideDayTooltip();
        root.view = (root.view + 1) % 3;
    }

    function updateDayHover(x: real, y: real): void {
        if (root.mode !== "calendar" || root.view !== 0 || !daysPage.visible || daysPage.weekRow.width <= 0) {
            root.hideDayTooltip();
            return;
        }

        const row = daysPage.weekRow;
        const p = row.mapToItem(root, 0, 0);
        if (y >= p.y && y < p.y + row.height && x >= p.x && x < p.x + row.width) {
            const pitch = row.width / 7;
            const col = Math.floor((x - p.x) / pitch);
            if (col >= 0 && col < 7) {
                if (root.hoveredDayIndex !== col) {
                    root.hoveredDayIndex = col;
                    root.hoveredDayName = root.enFullWeekdays[col];
                    dayTooltipTimer.restart();
                }
                return;
            }
        }
        root.hideDayTooltip();
    }

    function hideDayTooltip(): void {
        root.hoveredDayIndex = -1;
        root.dayTooltipVisible = false;
        dayTooltipTimer.stop();
    }

    function moveDay(delta: int): void {
        const base = root.selectedDate ?? new Date();
        const next = new Date(base.getFullYear(), base.getMonth(), base.getDate() + delta);
        root.selectedDate = new Date(next.getFullYear(), next.getMonth(), next.getDate());
        if (next.getMonth() !== root.viewMonth || next.getFullYear() !== root.viewYear)
            root.viewDate = new Date(next.getFullYear(), next.getMonth(), 1);
    }

    function selectDate(d: date): void {
        root.selectedDate = new Date(d.getFullYear(), d.getMonth(), d.getDate());
    }

    function goToday(): void {
        const now = new Date();
        root.viewDate = now;
        root.selectedDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        root.view = 0;
    }

    function refresh(): void {
        root.weekdayName = Time.format("dddd");
        root.fullDate = Time.format("MMMM d, yyyy");
        root.secondsStr = Time.format("ss");
    }

    ColumnLayout {
        id: rootCol

        anchors.fill: parent
        spacing: Tokens.spacing.small

        // --- Header (shared by both modes) ---------------------------------------------

        ColumnLayout {
            id: headerCol

        Layout.alignment: Qt.AlignHCenter
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.weekdayName
            font: Tokens.font.title.builders.small.build()
            color: Colours.palette.m3onSurface
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.fullDate
            font: Tokens.font.body.builders.small.scale(1.1).build()
            color: Colours.palette.m3onSurfaceVariant
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0

            StyledText {
                text: root.timeMainStr
                font: Tokens.font.body.builders.small.scale(1.4).build()
                color: Colours.palette.m3tertiary
            }

            // Seconds are visibly smaller / less prominent than hour:minute.
            StyledText {
                text: `:${root.secondsStr}`
                font: Tokens.font.body.builders.small.scale(0.9).build()
                color: Colours.palette.m3tertiary
                opacity: 0.65
            }

            Loader {
                asynchronous: true
                active: root.twelveHour
                visible: active

                sourceComponent: StyledText {
                    text: ` ${Time.amPmStr}`
                    font: Tokens.font.body.builders.small.scale(1.1).build()
                    color: Colours.palette.m3tertiary
                }
            }
        }
    }

    // --- Calendar area (only in calendar mode) --------------------------------------

    Item {
        id: pageItem

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: root.gridW
        Layout.preferredHeight: daysPage.implicitHeight

        visible: root.mode === "calendar"
        opacity: root.mode === "calendar" ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        DaysPage {
            id: daysPage

            anchors.fill: parent
            shouldBeActive: root.view === 0
        }

        MonthsPage {
            id: monthsPage

            anchors.fill: parent
            shouldBeActive: root.view === 1
        }

        YearsPage {
            id: yearsPage

            anchors.fill: parent
            shouldBeActive: root.view === 2
        }
    }
    }

    // --- Overlay: hover tracking, wheel month navigation, middle-click Today --------

    CustomMouseArea {
        id: overlay

        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        hoverEnabled: true

        onEntered: {
            root.hovered = true;
            root.updateDayHover(mouseX, mouseY);
        }
        onExited: {
            root.hovered = false;
            root.hideDayTooltip();
        }

        onPositionChanged: root.updateDayHover(mouseX, mouseY)

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                root.goToday();
        }

        // Wheel direction matches the dashboard calendar: up = previous month.
        function onWheel(event: WheelEvent): void {
            if (event.angleDelta.y > 0)
                root.prev();
            else if (event.angleDelta.y < 0)
                root.next();
        }
    }

    // Small delay before showing the weekday tooltip.
    Timer {
        id: dayTooltipTimer

        interval: 300
        onTriggered: root.dayTooltipVisible = true
    }

    // --- Tick timer: only runs while the popout is visible ---------------------------

    Timer {
        id: tick

        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }

    onVisibleChanged: {
        if (visible)
            root.refresh();
    }

    Component.onCompleted: root.refresh()

    // --- Pages ----------------------------------------------------------------------

    component Page: Item {
        id: page

        property bool shouldBeActive: false

        opacity: 0
        visible: false

        states: State {
            name: "active"
            when: page.shouldBeActive

            PropertyChanges {
                page.opacity: 1
                page.visible: true
            }
        }

        transitions: [
            Transition {
                from: "active"
                to: ""

                SequentialAnimation {
                    Anim {
                        property: "opacity"
                        type: Anim.DefaultEffects
                    }
                    PropertyAction {
                        property: "visible"
                    }
                }
            },
            Transition {
                from: ""
                to: "active"

                SequentialAnimation {
                    PropertyAction {
                        property: "visible"
                    }
                    Anim {
                        property: "opacity"
                        type: Anim.DefaultEffects
                    }
                }
            }
        ]
    }

    component NavRow: RowLayout {
        id: navRow

        property string title: ""
        signal prevClicked
        signal nextClicked
        signal titleClicked

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        IconButton {
            isRound: true
            icon: "chevron_left"
            type: IconButton.Text
            font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
            padding: Tokens.padding.small
            onClicked: navRow.prevClicked()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            implicitWidth: titleText.implicitWidth + Tokens.padding.large * 2
            implicitHeight: titleText.implicitHeight + Tokens.padding.extraSmall * 2

            StateLayer {
                color: Colours.palette.m3primary
                radius: pressed ? Tokens.rounding.small : height / 2
                onClicked: navRow.titleClicked()

                Behavior on radius {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            StyledText {
                id: titleText

                anchors.centerIn: parent
                text: navRow.title
                color: Colours.palette.m3primary
                font: Tokens.font.title.builders.small.capitalisation(Font.Capitalize).build()
            }
        }

        IconButton {
            isRound: true
            icon: "chevron_right"
            type: IconButton.Text
            font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
            padding: Tokens.padding.small
            onClicked: navRow.nextClicked()
        }
    }

    component DaysPage: Page {
        // The page content is anchored, so it would not contribute to the
        // implicit size; propagate the content column's implicit size so the
        // popout wrapper can size itself to the full calendar.
        implicitWidth: daysCol.implicitWidth
        implicitHeight: daysCol.implicitHeight

        // Exposed for the overlay's hover hit-testing (hover events only reach
        // the topmost MouseArea, which is the popout overlay).
        readonly property alias weekRow: weekdayRow

        ColumnLayout {
            id: daysCol

            anchors.fill: parent
            spacing: Tokens.spacing.extraSmall

            NavRow {
                title: root.viewTitle
                onPrevClicked: root.prev()
                onNextClicked: root.next()
                onTitleClicked: root.cycleView()
            }

            // Weekday header: English main, PT-BR auxiliary translation secondary.
            Row {
                id: weekdayRow

                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall

                Repeater {
                    model: 7

                    Column {
                        required property int index

                        width: weekdayRow.width / 7
                        spacing: 0

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.enWeekdays[index]
                            font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                            color: (index === 0 || index === 6) ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.ptWeekdays[index]
                            font: Tokens.font.body.builders.small.scale(0.8).build()
                            color: Colours.palette.m3onSurfaceVariant
                            opacity: 0.6
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall

                implicitHeight: grid.implicitHeight

                MonthGrid {
                    id: grid

                    anchors.fill: parent

                    month: root.viewMonth
                    year: root.viewYear
                    // en_US keeps the month/day names in English while starting
                    // the week on Sunday, matching the weekday row above.
                    locale: Qt.locale("en_US")
                    spacing: root.gridSpacing

                    delegate: Item {
                        id: dayItem

                        required property var model

                        readonly property bool isWeekend: {
                            const d = dayItem.model.date.getDay();
                            return d === 0 || d === 6;
                        }
                        readonly property bool isSelected: root.selectedDate !== null && dayItem.model.date.getTime() === root.selectedDate.getTime()
                        readonly property bool inMonth: dayItem.model.month === grid.month

                        implicitWidth: root.cellW
                        implicitHeight: dayText.implicitHeight + Tokens.padding.small

                        StateLayer {
                            anchors.fill: parent
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3primary
                            onClicked: root.selectDate(dayItem.model.date)
                        }

                        StyledRect {
                            id: pill

                            anchors.fill: parent
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3primary
                            visible: dayItem.isSelected
                        }

                        StyledText {
                            id: dayText

                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            text: grid.locale.toString(dayItem.model.day)
                            color: dayItem.isSelected ? Colours.palette.m3onPrimary : dayItem.isWeekend ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                            opacity: dayItem.inMonth ? 1 : 0.4
                            font: Tokens.font.body.small
                        }
                    }
                }

                // "Today" indicator, same idiom as the dashboard calendar.
                MaterialShape {
                    id: todayIndicator

                    readonly property Item todayItem: grid.contentItem.children.find(c => c.model.today) ?? null
                    property Item today

                    onTodayItemChanged: {
                        if (todayItem)
                            today = todayItem;
                    }

                    x: today ? today.x + (today.width - implicitWidth) / 2 : 0
                    y: today ? today.y - Tokens.padding.extraSmall - 1 : 0

                    implicitSize: today ? Math.max(today.implicitWidth, today.implicitHeight) + Tokens.padding.extraSmall * 2 : 0
                    shape: MaterialShape.Sunny

                    clip: true
                    color: Colours.palette.m3primary

                    opacity: todayItem ? 1 : 0

                    Colouriser {
                        x: -todayIndicator.x
                        y: -todayIndicator.y

                        implicitWidth: grid.width
                        implicitHeight: grid.height

                        source: grid
                        sourceColor: Colours.palette.m3onSurface
                        colorizationColor: Colours.palette.m3onPrimary
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    type: TextButton.Text
                    text: qsTr("Today")
                    font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                    disabled: root.view === 0 && root.viewMonth === root.nowMonth && root.viewYear === root.nowYear
                    onClicked: root.goToday()
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }

        // Native-styled tooltip with the full weekday name (English only).
        StyledRect {
            id: dayTooltip

            x: {
                if (root.hoveredDayIndex < 0)
                    return 0;
                const p = weekRow.mapToItem(parent, 0, 0);
                const pitch = weekRow.width / 7;
                const cx = p.x + root.hoveredDayIndex * pitch + pitch / 2 - width / 2;
                return Math.max(Tokens.padding.extraSmall, Math.min(cx, parent.width - width - Tokens.padding.extraSmall));
            }
            y: {
                if (root.hoveredDayIndex < 0)
                    return 0;
                const p = weekRow.mapToItem(parent, 0, 0);
                return p.y - height - Tokens.spacing.small;
            }

            radius: Tokens.rounding.small
            color: Colours.tPalette.m3surfaceContainerHighest
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)

            visible: opacity > 0.01
            opacity: root.dayTooltipVisible ? 1 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            // A bare item's rendered size comes from width/height, not
            // the implicit sizes (those are only used by layouts).
            width: dayTooltipLabel.implicitWidth + Tokens.padding.medium * 2
            height: dayTooltipLabel.implicitHeight + Tokens.padding.small

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                opacity: parent.opacity
                z: -1
                level: 2
            }

            StyledText {
                id: dayTooltipLabel

                anchors.centerIn: parent
                text: root.hoveredDayName
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                color: Colours.palette.m3onSurface
            }
        }
    }

    component MonthsPage: Page {
        implicitWidth: monthsCol.implicitWidth
        implicitHeight: monthsCol.implicitHeight

        ColumnLayout {
            id: monthsCol

            anchors.fill: parent
            spacing: Tokens.spacing.extraSmall

            NavRow {
                title: root.viewTitle
                onPrevClicked: root.prev()
                onNextClicked: root.next()
                onTitleClicked: root.cycleView()
            }

            Grid {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Tokens.spacing.small

                columns: 3
                spacing: Tokens.spacing.small

                Repeater {
                    model: 12

                    MonthCell {}
                }
            }
        }
    }

    component YearsPage: Page {
        implicitWidth: yearsCol.implicitWidth
        implicitHeight: yearsCol.implicitHeight

        ColumnLayout {
            id: yearsCol

            anchors.fill: parent
            spacing: Tokens.spacing.extraSmall

            NavRow {
                title: root.viewTitle
                onPrevClicked: root.prev()
                onNextClicked: root.next()
                onTitleClicked: root.cycleView()
            }

            Grid {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Tokens.spacing.small

                columns: 3
                spacing: Tokens.spacing.small

                Repeater {
                    model: 12

                    YearCell {}
                }
            }
        }
    }

    component MonthCell: Item {
        required property int index

        readonly property bool isCurrent: root.nowMonth === index && root.viewYear === root.nowYear

        implicitWidth: (root.gridW - Tokens.spacing.small * 2) / 3
        implicitHeight: label.implicitHeight + Tokens.padding.medium

        StateLayer {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: Colours.palette.m3primary
            onClicked: {
                root.viewDate = new Date(root.viewYear, index, 1);
                root.view = 0;
            }
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            text: Qt.locale().toString(new Date(2000, index, 1), "MMMM")
            font: Tokens.font.body.builders.small.weight(isCurrent ? Font.Medium : Font.Normal).build()
            color: isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        }
    }

    component YearCell: Item {
        required property int index

        readonly property int year: root.decadeStart - 1 + index
        readonly property bool isCurrent: year === root.nowYear

        implicitWidth: (root.gridW - Tokens.spacing.small * 2) / 3
        implicitHeight: label.implicitHeight + Tokens.padding.medium

        StateLayer {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: Colours.palette.m3primary
            onClicked: {
                root.viewDate = new Date(year, root.viewMonth, 1);
                root.view = 1;
            }
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            text: String(year)
            font: Tokens.font.body.builders.small.weight(isCurrent ? Font.Medium : Font.Normal).build()
            color: isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        }
    }
}
