import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components.misc
import qs.services

Scope {
    id: root

    // Índice determinístico da aba "Transfer" no dashboardTabs do Content.qml.
    // Ordem fixa [Dashboard, Media, Performance, Weather, Data Link, Transfer];
    // Data Link e Transfer estão sempre habilitadas.
    function transferTabIndex() {
        let idx = 0;
        if (Config.dashboard.showDashboard) idx++;
        if (Config.dashboard.showMedia) idx++;
        if (Config.dashboard.showPerformance) idx++;
        if (Config.dashboard.showWeather) idx++;
        idx++; // Data Link
        return idx;
    }

    function openTransfer() {
        const st = ShellState.forActive();
        if (!st)
            return;
        st.dashboard = true;
        let live = -1;
        const comps = ShellState.componentsForActive();
        if (comps) {
            const content = comps.find("dashboardContent", comps.rootWindow ? comps.rootWindow.contentItem : null);
            if (content && content.dashboardTabs)
                live = content.dashboardTabs.findIndex(t => t.id === "transfer");
        }
        st.dashboardTab = live >= 0 ? live : root.transferTabIndex();
    }

    IpcHandler {
        function open() {
            root.openTransfer();
        }

        function addUrl(url: string) {
            MediaData.pendingUrl = url;
            root.openTransfer();
        }

        target: "media"
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.media"
        defaultLogLevel: LoggingCategory.Info
    }
}
