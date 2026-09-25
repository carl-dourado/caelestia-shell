pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    function finite(value, fallback = 0): real {
        return Number.isFinite(value) ? value : fallback;
    }

    function nonNegative(value): real {
        return Math.max(0, finite(value));
    }

    readonly property real borderThickness: nonNegative(win?.contentItem?.Config?.border?.thickness ?? 0)
    readonly property real clampedThickness: nonNegative(win?.contentItem?.Config?.border?.clampedThickness ?? 0)
    readonly property bool validGeometry: Number.isFinite(x)
        && Number.isFinite(y)
        && Number.isFinite(width)
        && Number.isFinite(height)
        && width > 0
        && height > 0

    x: nonNegative((bar?.clampedWidth ?? 0) + (win?.dragMaskPadding ?? 0))
    y: nonNegative(clampedThickness + (win?.dragMaskPadding ?? 0))
    width: nonNegative((win?.width ?? 0) - (bar?.clampedWidth ?? 0) - clampedThickness - (win?.dragMaskPadding ?? 0) * 2)
    height: nonNegative((win?.height ?? 0) - clampedThickness * 2 - (win?.dragMaskPadding ?? 0) * 2)
    intersection: Intersection.Xor

    R {
        panel: root.panels.dashboard
        y: 0
        height: root.nonNegative(panel.height * (1 - root.panels.dashboard.offsetScale) + root.borderThickness)
    }

    R {
        panel: root.panels.launcher
        y: root.nonNegative((root.win?.height ?? 0) - height)
        height: root.nonNegative(panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness)
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.nonNegative((root.win?.width ?? 0) - width)
        width: root.nonNegative(panel.width * (1 - root.panels.session.offsetScale) + root.borderThickness + sidebarRegion.width)
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.nonNegative((root.win?.width ?? 0) - width)
        width: root.nonNegative(panel.width * (1 - root.panels.sidebar.offsetScale) + root.borderThickness)
    }

    R {
        panel: root.panels.osdWrapper
        x: root.nonNegative((root.win?.width ?? 0) - width)
        width: root.nonNegative(panel.width * (1 - root.panels.osd.offsetScale) + root.borderThickness + sessionRegion.width)
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: root.nonNegative(panel.height + root.borderThickness)
    }

    R {
        panel: root.panels.utilities
        y: root.nonNegative((root.win?.height ?? 0) - height)
        height: root.nonNegative(panel.height * (1 - root.panels.utilities.offsetScale) + root.borderThickness)
    }

    R {
        panel: root.panels.popoutsWrapper
        width: root.nonNegative(panel.width * (1 - root.panels.popoutsWrapper.offsetScale))
    }

    component R: Region {
        required property Item panel

        x: root.nonNegative((panel?.x ?? 0) + (root.bar?.implicitWidth ?? 0))
        y: root.nonNegative((panel?.y ?? 0) + root.borderThickness)
        width: root.nonNegative(panel?.width ?? 0)
        height: root.nonNegative(panel?.height ?? 0)
        intersection: Intersection.Subtract
    }
}
