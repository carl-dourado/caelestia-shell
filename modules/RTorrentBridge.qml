import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.components.misc
import qs.services

Scope {
    id: root

    // Índice determinístico da aba "Data Link" no dashboardTabs do Content.qml.
    // A ordem é fixa [Dashboard, Media, Performance, Weather, Data Link],
    // filtrada pelos mesmos Config.dashboard.show* usados no Content.qml.
    // A aba Data Link está sempre habilitada (enabled: true no overlay).
    // Quando o dashboard já está instanciado, o índice real é lido do modelo
    // vivo via objectName "dashboardContent" (ID estável "dataLink").
    function dataLinkTabIndex() {
        let idx = 0;
        if (Config.dashboard.showDashboard) idx++;
        if (Config.dashboard.showMedia) idx++;
        if (Config.dashboard.showPerformance) idx++;
        if (Config.dashboard.showWeather) idx++;
        return idx;
    }

    function openDataLink() {
        const st = ShellState.forActive();
        if (!st)
            return;
        // Abre o dashboard (nunca o fecha se já estiver aberto).
        st.dashboard = true;

        // Seleciona a aba Data Link: índice real do modelo vivo quando
        // disponível; senão, índice determinístico calculado acima.
        let live = -1;
        const comps = ShellState.componentsForActive();
        if (comps) {
            const content = comps.find("dashboardContent", comps.rootWindow ? comps.rootWindow.contentItem : null);
            if (content && content.dashboardTabs)
                live = content.dashboardTabs.findIndex(t => t.id === "dataLink");
        }
        st.dashboardTab = live >= 0 ? live : root.dataLinkTabIndex();
    }

    IpcHandler {
        function open() {
            root.openDataLink();
        }

        target: "rtorrent"
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.rtorrent"
        defaultLogLevel: LoggingCategory.Info
    }
}
