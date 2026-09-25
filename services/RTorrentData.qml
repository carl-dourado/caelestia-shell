pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Quickshell.Io
import Caelestia
import Caelestia.Config

Singleton {
    id: root

    property int refCount: 0

    readonly property bool online: _online
    readonly property bool mounted: _mounted
    readonly property bool clientAvailable: _client
    readonly property bool apiAvailable: _api
    readonly property bool rpcAvailable: _api
    readonly property string state: _state
    readonly property string connectionStatus: _connectionStatus
    readonly property var downloadBps: _downloadBps
    readonly property var uploadBps: _uploadBps
    readonly property var active: _active
    readonly property var downloading: _downloading
    readonly property var seeding: _seeding
    readonly property var pausedCount: _paused
    readonly property var completed: _completed
    readonly property var total: _total
    readonly property var stalled: _stalled
    readonly property var issues: _issues
    readonly property var peers: _peers
    readonly property var dhtNodes: _dhtNodes
    readonly property var watchPending: _watchPending
    readonly property var diskFreeBytes: _diskFree
    readonly property var diskUsedPercent: _diskUsed
    readonly property string error: _error
    readonly property string lastCompleted: _lastCompleted
    readonly property string currentName: _currentName
    readonly property string currentHash: _currentHash
    readonly property string currentState: _currentState
    readonly property bool currentPaused: _currentPaused
    readonly property var currentProgress: _currentProgress
    readonly property var currentRemainingBytes: _currentRemainingBytes
    readonly property var currentEta: _currentEta
    readonly property var currentRatio: _currentRatio
    readonly property var currentPeers: _currentPeers
    readonly property var currentSeeds: _currentSeeds
    readonly property var currentLeechers: _currentLeechers
    readonly property bool currentMetadataPending: _currentMetadataPending
    readonly property alias downloadBuffer: downloadHistory
    readonly property alias uploadBuffer: uploadHistory
    readonly property int historyLength: 30

    property bool _online: false
    property bool _mounted: false
    property bool _client: false
    property bool _api: false
    property string _state: "OFFLINE"
    property string _connectionStatus: "disconnected"
    property var _downloadBps: null
    property var _uploadBps: null
    property var _active: null
    property var _downloading: null
    property var _seeding: null
    property var _paused: null
    property var _completed: null
    property var _total: null
    property var _stalled: null
    property var _issues: null
    property var _peers: null
    property var _dhtNodes: null
    property var _watchPending: null
    property var _diskFree: null
    property var _diskUsed: null
    property string _error: ""
    property string _lastCompleted: ""
    property string _currentName: ""
    property string _currentHash: ""
    property string _currentState: ""
    property bool _currentPaused: false
    property var _currentProgress: null
    property var _currentRemainingBytes: null
    property var _currentEta: null
    property var _currentRatio: null
    property var _currentPeers: null
    property var _currentSeeds: null
    property var _currentLeechers: null
    property bool _currentMetadataPending: false

    function formatSpeed(bps) {
        if (bps === null || bps === undefined || isNaN(bps) || !isFinite(bps)) return "--"
        if (bps <= 0) return "0 B/s"
        if (bps < 1024) return Math.round(bps) + " B/s"
        if (bps < 1048576) return (bps / 1024).toFixed(0) + " KiB/s"
        if (bps < 1073741824) return (bps / 1048576).toFixed(1) + " MiB/s"
        return (bps / 1073741824).toFixed(1) + " GiB/s"
    }

    function formatDisk(bytes) {
        if (bytes === null || bytes === undefined || isNaN(bytes) || !isFinite(bytes)) return "--"
        if (bytes < 1048576) return (bytes / 1024).toFixed(0) + " KiB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MiB"
        return (bytes / 1073741824).toFixed(2) + " GiB"
    }

    function formatProgress(value) {
        if (value === null || value === undefined || isNaN(value) || !isFinite(value)) return "--"
        return (value >= 100 ? value.toFixed(0) : value.toFixed(1)) + "%"
    }

    function formatDuration(seconds) {
        if (seconds === null || seconds === undefined || isNaN(seconds) || !isFinite(seconds) || seconds < 0) return "--"
        if (seconds === 0) return qsTr("done")
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        if (days > 0) return `${days}d ${hours}h`
        if (hours > 0) return `${hours}h ${minutes}m`
        return `${Math.max(1, minutes)}m`
    }

    function formatRatio(value) {
        if (value === null || value === undefined || isNaN(value) || !isFinite(value)) return "--"
        return Number(value).toFixed(2)
    }

    function count(value) {
        if (value === null || value === undefined || isNaN(value)) return "--"
        return value.toString()
    }

    function stateColor() {
        switch (root._state) {
            case "DOWNLOADING": return Colours.palette.m3primary
            case "SEEDING": return Colours.palette.m3secondary
            case "PAUSED": return Colours.palette.m3tertiary
            case "IDLE": return Colours.palette.m3onSurface
            case "DISCONNECTED": return Colours.palette.m3error
            case "ERROR": return Colours.palette.m3error
            case "OFFLINE": return Colours.palette.m3outlineVariant
            default: return Colours.palette.m3onSurfaceVariant
        }
    }

    function statusIcon() {
        switch (root._state) {
            case "DOWNLOADING": return "download"
            case "SEEDING": return "upload"
            case "PAUSED": return "pause_circle"
            case "IDLE": return "check_circle"
            case "DISCONNECTED": return "link_off"
            case "ERROR": return "error"
            case "OFFLINE": return "cancel"
            default: return "help"
        }
    }

    function indicatorColor(name) {
        switch (name) {
            case "STORAGE": return root._mounted ? Colours.palette.m3primary : Colours.palette.m3error
            case "CLIENT": return root._client ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
            case "API": return root._api ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
            default: return Colours.palette.m3onSurfaceVariant
        }
    }

    function parseStatus(raw) {
        if (!raw || !raw.startsWith("{")) return
        try {
            const obj = JSON.parse(raw)
            _online = obj.online === true
            _mounted = obj.mounted === true
            _client = obj.client === true
            _api = obj.api === true
            _state = obj.state || "OFFLINE"
            _connectionStatus = obj.connection_status || "disconnected"
            _downloadBps = obj.download_bps ?? null
            _uploadBps = obj.upload_bps ?? null
            _active = obj.active ?? null
            _downloading = obj.downloading ?? null
            _seeding = obj.seeding ?? null
            _paused = obj.paused ?? null
            _completed = obj.completed ?? null
            _total = obj.total ?? null
            _stalled = obj.stalled ?? null
            _issues = obj.issues ?? null
            _peers = obj.peers ?? null
            _dhtNodes = obj.dht_nodes ?? null
            _watchPending = obj.watch_pending ?? null
            _diskFree = obj.disk_free_bytes ?? null
            _diskUsed = obj.disk_used_percent ?? null
            _error = obj.error ?? ""
            _lastCompleted = obj.last_completed ?? ""
            _currentName = obj.current_name ?? ""
            _currentHash = obj.current_hash ?? ""
            _currentState = obj.current_state ?? ""
            _currentPaused = obj.current_paused === true
            _currentProgress = obj.current_progress ?? null
            _currentRemainingBytes = obj.current_remaining_bytes ?? null
            _currentEta = obj.current_eta ?? null
            _currentRatio = obj.current_ratio ?? null
            _currentPeers = obj.current_peers ?? null
            _currentSeeds = obj.current_seeds ?? null
            _currentLeechers = obj.current_leechers ?? null
            _currentMetadataPending = obj.current_metadata_pending === true
            if (typeof _downloadBps === "number" && isFinite(_downloadBps) && _downloadBps >= 0) downloadHistory.push(_downloadBps)
            if (typeof _uploadBps === "number" && isFinite(_uploadBps) && _uploadBps >= 0) uploadHistory.push(_uploadBps)
        } catch (e) {}
    }

    CircularBuffer {
        id: downloadHistory

        capacity: root.historyLength + 1
    }

    CircularBuffer {
        id: uploadHistory

        capacity: root.historyLength + 1
    }

    FileView {
        id: dataFile

        path: "/dev/shm/qbittorrent-data.json"
    }

    Timer {
        interval: GlobalConfig.dashboard.resourceUpdateInterval
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            dataFile.reload()
            root.parseStatus(dataFile.text())
        }
    }
}
