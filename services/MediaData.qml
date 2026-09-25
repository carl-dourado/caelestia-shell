pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

Singleton {
    id: root

    readonly property string helper: `${Paths.home}/.local/bin/caelestia-media`
    readonly property string stateDir: `${Paths.state}/media`
    readonly property string statePath: `${stateDir}/state.json`
    readonly property int maxRunning: 3
    readonly property int maxHistory: 8

    property var jobs: []
    property var history: []
    property string lastDownloadDir: ""
    property string lastConvertDir: ""
    property string pendingUrl: ""

    property bool identifyBusy: false
    property string identifyTitle: ""
    property string identifyUploader: ""
    property string identifyDuration: ""
    property string identifyError: ""
    property int _seq: 0

    // ---------------------------------------------------------------- format

    function formatBytes(bytes) {
        if (bytes === null || bytes === undefined || isNaN(bytes) || !isFinite(bytes) || bytes <= 0) return "--";
        if (bytes < 1024) return `${Math.round(bytes)} B`;
        if (bytes < 1048576) return `${(bytes / 1024).toFixed(0)} KiB`;
        if (bytes < 1073741824) return `${(bytes / 1048576).toFixed(1)} MiB`;
        return `${(bytes / 1073741824).toFixed(2)} GiB`;
    }

    function formatSpeed(bps) {
        if (bps === null || bps === undefined || isNaN(bps) || !isFinite(bps) || bps <= 0) return "--";
        if (bps < 1048576) return `${(bps / 1024).toFixed(0)} KiB/s`;
        return `${(bps / 1048576).toFixed(1)} MiB/s`;
    }

    function formatEta(secs) {
        if (secs === null || secs === undefined || isNaN(secs) || !isFinite(secs) || secs <= 0) return "--";
        const s = Math.round(secs);
        if (s < 60) return `${s}s`;
        const m = Math.floor(s / 60);
        if (m < 60) return `${m}m ${s % 60}s`;
        const h = Math.floor(m / 60);
        return `${h}h ${String(m % 60).padStart(2, "0")}m`;
    }

    function formatDuration(secs) {
        if (secs === null || secs === undefined || isNaN(secs) || !isFinite(secs) || secs <= 0) return "--";
        const s = Math.round(secs);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const ss = s % 60;
        if (h > 0) return `${h}:${String(m).padStart(2, "0")}:${String(ss).padStart(2, "0")}`;
        return `${m}:${String(ss).padStart(2, "0")}`;
    }

    function shortPath(path) {
        if (!path) return "";
        const p = String(path);
        return p.length > 46 ? `…${p.slice(-45)}` : p;
    }

    // ---------------------------------------------------------------- helpers

    function isValidUrl(url) {
        return typeof url === "string" && /^https?:\/\/[^\s]+$/.test(url.trim());
    }

    function sanitizeDir(dir) {
        if (typeof dir !== "string") return "";
        let d = dir.trim();
        if (d.startsWith("~/")) d = `${Paths.home}/${d.slice(2)}`;
        if (!d.startsWith("/")) return "";
        if (/[\x00\n\r]/.test(d)) return "";
        return d;
    }

    function openPath(path) {
        if (!path) return;
        Quickshell.execDetached([root.helper, "open", String(path)]);
    }

    function removePartial(path) {
        if (!path) return;
        Quickshell.execDetached([root.helper, "remove", String(path)]);
    }

    // ---------------------------------------------------------------- state

    FileView {
        id: stateView

        path: root.statePath
        atomicWrites: true
        watchChanges: false
        __printErrors: false
        onFileChanged: root.loadState()
    }

    Timer {
        interval: 600
        running: true
        repeat: false
        triggeredOnStart: true

        onTriggered: {
            Quickshell.execDetached([root.helper, "ensure-dir", root.stateDir]);
            Quickshell.execDetached([root.helper, "init-state", root.statePath]);
            stateView.reload();
        }
    }

    function loadState() {
        if (root.stateLoaded) return;
        const raw = stateView.text();
        if (!raw || !raw.startsWith("{")) return;
        try {
            const obj = JSON.parse(raw);
            root.history = Array.isArray(obj.history) ? obj.history.filter(h => h && h.status) : [];
            if (obj.lastDownloadDir) root.lastDownloadDir = String(obj.lastDownloadDir);
            if (obj.lastConvertDir) root.lastConvertDir = String(obj.lastConvertDir);
            root.stateLoaded = true;
        } catch (e) {
            console.warn(lc, `MediaData: state invalido: ${e}`);
        }
    }

    Timer {
        id: saveTimer

        interval: 300
        repeat: false

        onTriggered: {
            const obj = {
                version: 1,
                lastDownloadDir: root.lastDownloadDir,
                lastConvertDir: root.lastConvertDir,
                history: root.history.slice(0, root.maxHistory)
            };
            stateView.setText(JSON.stringify(obj));
            stateView.writeAdapter();
            stateView.waitForJob();
        }
    }

    function saveState() {
        saveTimer.restart();
    }

    // ---------------------------------------------------------------- jobs

    function jobById(id) {
        for (const j of root.jobs)
            if (j.id === id)
                return j;
        return null;
    }

    function pushJob(job) {
        root._seq += 1;
        job.id = root._seq;
        root.jobs = root.jobs.concat([job]);
        root.tryStartNext();
        return job;
    }

    function runningCount() {
        return root.jobs.filter(j => j.status === "running" || j.status === "processing" || j.status === "cancelling").length;
    }

    function commitJobs() {
        // Reatribui o array para os bindings (ScriptModel) reavaliarem.
        root.jobs = root.jobs.slice();
    }

    function tryStartNext() {
        for (const j of root.jobs) {
            if (j.status !== "queued")
                continue;
            if (root.runningCount() >= root.maxRunning)
                return;
            root.startJob(j);
        }
    }

    function startJob(job) {
        let command;
        if (job.kind === "download") {
            command = root.downloadCommand(job);
        } else {
            const built = root.convertCommand(job);
            if (!built) {
                job.status = "error";
                job.error = "Falha ao montar o comando de conversão";
                root.pushHistory(job);
                root.commitJobs();
                return;
            }
            command = built.args;
            job.finalPath = built.finalPath;
            job.tmpPath = built.tmpPath;
        }
        if (!command || command.length === 0) {
            job.status = "error";
            job.error = "Falha ao montar o comando";
            root.pushHistory(job);
            root.commitJobs();
            return;
        }
        job.status = "running";
        job.progress = 0;
        job.startedAt = Date.now();
        root.spawnProcess(job, command);
        root.commitJobs();
    }

    function spawnProcess(job, command) {
        const comp = Qt.createComponent(Qt.resolvedUrl("../modules/dashboard/transfer/MediaProcess.qml"));
        const created = () => {
            const proc = comp.createObject(root, {
                jobId: job.id,
                command: command
            });
            if (!proc) {
                job.status = "error";
                job.error = "Falha ao criar o processo";
                root.pushHistory(job);
                root.commitJobs();
                return;
            }
            proc.onLine = (line) => root.handleLine(job, line);
            proc.onErrLine = (line) => root.handleErrLine(job, line);
            proc.onExit = (code) => root.handleExit(job, code);
            job.process = proc;
            proc.start();
        };
        if (comp.status === Component.Ready)
            created();
        else if (comp.status === Component.Error) {
            job.status = "error";
            job.error = `Falha ao criar o processo: ${comp.errorString()}`.slice(0, 300);
            root.pushHistory(job);
            root.commitJobs();
        } else
            comp.statusChanged.connect(() => {
                if (comp.status === Component.Ready)
                    created();
                else if (comp.status === Component.Error) {
                    job.status = "error";
                    job.error = `Falha ao criar o processo: ${comp.errorString()}`.slice(0, 300);
                    root.pushHistory(job);
                    root.commitJobs();
                }
            });
    }

    function handleLine(job, raw) {
        const line = raw.trim();
        if (job.kind === "convert") {
            // ffmpeg -progress key=value
            const idx = line.indexOf("=");
            if (idx < 0)
                return;
            const key = line.slice(0, idx).trim();
            const val = line.slice(idx + 1).trim();
            if (key === "out_time_ms") {
                const ms = parseFloat(val);
                if (isFinite(ms) && ms >= 0) {
                    job.outMs = ms;
                    if (job.duration && job.duration > 0)
                        job.progress = Math.min(ms / (job.duration * 1000000), 1);
                }
            } else if (key === "total_size") {
                const sz = parseFloat(val);
                if (isFinite(sz) && sz >= 0)
                    job.downloaded = sz;
            } else if (key === "speed") {
                const sp = parseFloat(val);
                if (isFinite(sp) && sp > 0)
                    job.speed = sp;
            }
            root.touchJob(job);
            return;
        }
        if (!line.startsWith("{")) {
            if (job.kind === "download" && line.startsWith("FILEPATH:")) {
                const path = line.slice(9).trim();
                if (path.length > 0)
                    job.finalPath = path;
            }
            return;
        }
        let o;
        try {
            o = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (o.s === "dl" || o.s === "pp") {
            if (o.s === "pp") {
                job.status = "processing";
                job.speed = null;
                job.eta = null;
            }
            const p = parseFloat(o.p);
            if (isFinite(p))
                job.progress = Math.min(p / 100, 1);
            const b = parseFloat(o.b);
            const t = parseFloat(o.t);
            const te = parseFloat(o.te);
            if (isFinite(b))
                job.downloaded = b;
            if (isFinite(t))
                job.total = t;
            else if (isFinite(te))
                job.total = te;
            // percentual ausente (downloads fragmentados): calcula de b/t
            if ((!isFinite(p) || p === 0) && isFinite(job.total) && job.total > 0 && isFinite(job.downloaded))
                job.progress = Math.min(job.downloaded / job.total, 1);
            const sp = parseFloat(o.sp);
            if (isFinite(sp) && sp > 0)
                job.speed = sp;
            const e = parseFloat(o.e);
            if (isFinite(e))
                job.eta = e;
            root.touchJob(job);
        }
    }

    function handleErrLine(job, line) {
        const t = line.trim();
        if (!t || /^frame=|^size=|^bitrate=|^speed=/i.test(t))
            return;
        job.logLines = job.logLines ?? [];
        if (job.logLines.length >= 25)
            job.logLines.shift();
        job.logLines.push(t);
        if (t.length <= 300)
            job.error = t;
        root.touchJob(job);
    }

    function touchJob(job) {
        if (!job._lastTouch || Date.now() - job._lastTouch > 200) {
            job._lastTouch = Date.now();
            root.commitJobs();
        }
    }

    function handleExit(job, code) {
        job.process = null;
        if (job.status === "cancelling") {
            job.status = "cancelled";
            if (job.kind === "convert" && job.tmpPath)
                root.removePartial(job.tmpPath);
            root.pushHistory(job);
            root.tryStartNext();
            root.commitJobs();
            return;
        }
        if (code === 0) {
            if (job.kind === "convert") {
                root.finishJob(job);
                job.status = "done";
            } else {
                job.status = "done";
                if (job.finalPath && job.finalPath.length > 0) {
                    const parts = job.finalPath.split("/");
                    job.title = parts[parts.length - 1];
                }
            }
            job.progress = 1;
            job.eta = null;
            job.speed = null;
            job.error = "";
            job.finishedAt = Date.now();
            root.pushHistory(job);
            root.tryStartNext();
            root.commitJobs();
            return;
        }
        job.status = "error";
        if (!job.error || job.error.length === 0)
            job.error = job.logLines && job.logLines.length > 0 ? job.logLines[job.logLines.length - 1] : `Falha (exit ${code})`;
        job.error = String(job.error).slice(0, 300);
        if (job.kind === "convert" && job.tmpPath)
            root.removePartial(job.tmpPath);
        job.finishedAt = Date.now();
        root.pushHistory(job);
        root.tryStartNext();
        root.commitJobs();
    }

    function pushHistory(job) {
        const entry = {
            kind: job.kind,
            title: job.title,
            url: job.url ?? "",
            input: job.input ?? "",
            preset: job.preset ?? "",
            destDir: job.destDir ?? "",
            outPath: job.finalPath ?? "",
            status: job.status,
            error: job.error ?? "",
            ts: Math.floor((job.finishedAt ?? Date.now()) / 1000)
        };
        root.history = root.history.filter(h => !(h.kind === entry.kind && h.url === entry.url && h.input === entry.input && h.status === entry.status && h.ts === entry.ts));
        root.history = [entry].concat(root.history).slice(0, root.maxHistory);
        root.saveState();
    }

    function cancelJob(id) {
        const job = root.jobById(id);
        if (!job)
            return;
        if (job.status === "queued") {
            job.status = "cancelled";
            job.finishedAt = Date.now();
            root.pushHistory(job);
            root.commitJobs();
            return;
        }
        if (job.status !== "running" && job.status !== "processing")
            return;
        job.status = "cancelling";
        if (job.process)
            job.process.cancel();
        root.commitJobs();
    }

    // ---------------------------------------------------------------- download

    function addDownload(url, preset, destDir) {
        const cleanUrl = url.trim();
        if (!root.isValidUrl(cleanUrl)) {
            return { ok: false, error: "URL inválida (deve começar com http:// ou https://)" };
        }
        const dir = root.sanitizeDir(destDir);
        if (!dir) {
            return { ok: false, error: "Pasta de destino inválida" };
        }
        if (!root.downloadPresets[preset]) {
            return { ok: false, error: "Formato inválido" };
        }
        root.lastDownloadDir = dir;
        root.saveState();
        const job = root.pushJob({
            kind: "download",
            title: cleanUrl,
            url: cleanUrl,
            preset: preset,
            destDir: dir,
            status: "queued",
            progress: 0,
            downloaded: null,
            total: null,
            speed: null,
            eta: null,
            error: "",
            logLines: [],
            finalPath: ""
        });
        return { ok: true, id: job.id };
    }

    readonly property var downloadPresets: {
        "mp4": { label: "MP4", icon: "movie" },
        "webm": { label: "WebM", icon: "movie" },
        "best": { label: "BEST", icon: "high_quality" },
        "mp3": { label: "MP3", icon: "music_note" },
        "flac": { label: "FLAC", icon: "music_note" },
        "opus": { label: "OPUS", icon: "music_note" }
    }

    function downloadCommand(job) {
        // Valores sempre entre aspas: ausentes viram "NA" (JSON sempre válido).
        const dlTpl = `{"s":"dl","p":"%(progress.percent)s","b":"%(progress.downloaded_bytes)s","t":"%(progress.total_bytes)s","te":"%(progress.total_bytes_estimate)s","sp":"%(progress.speed)s","e":"%(progress.eta)s"}`;
        const ppTpl = `{"s":"pp","p":"%(progress.percent)s"}`;
        const args = [
            "yt-dlp",
            "--newline",
            "--progress",
            "--quiet",
            "--no-warnings",
            "--no-playlist",
            "--no-overwrites",
            "--progress-template", `download:${dlTpl}`,
            "--progress-template", `postprocess:${ppTpl}`,
            "--print", "after_move:FILEPATH:%(filepath)s",
            "--paths", job.destDir,
            "-o", "%(title).200B [%(id)s].%(ext)s"
        ];
        if (job.destDir.startsWith("/mnt/"))
            args.push("--restrict-filenames");
        switch (job.preset) {
            case "mp4":
                args.push("-f", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba", "--merge-output-format", "mp4");
                break;
            case "webm":
                args.push("-f", "bv*[ext=webm]+ba[ext=webm]/b[ext=webm]/bv*+ba", "--merge-output-format", "webm");
                break;
            case "best":
                args.push("-f", "bv*+ba/b");
                break;
            case "mp3":
                args.push("-x", "--audio-format", "mp3", "--audio-quality", "0");
                break;
            case "flac":
                args.push("-x", "--audio-format", "flac");
                break;
            case "opus":
                args.push("-x", "--audio-format", "opus");
                break;
            default:
                return [];
        }
        args.push("--", job.url);
        return args;
    }

    // ---------------------------------------------------------------- identify

    Process {
        id: identifyProc

        stdout: StdioCollector {
            id: identifyOut
        }
        stderr: StdioCollector {
            id: identifyErr
        }
        onExited: (code, status) => root.onIdentifyExited(code)
    }

    Timer {
        id: identifyTimeout

        interval: 30000
        repeat: false

        onTriggered: {
            if (root.identifyBusy) {
                identifyProc.signal(9);
                root.identifyBusy = false;
                root.identifyError = "Tempo esgotado identificando a URL";
                root.identifyDone();
            }
        }
    }

    function identify(url) {
        if (root.identifyBusy)
            return;
        const cleanUrl = url.trim();
        if (!root.isValidUrl(cleanUrl)) {
            root.identifyError = "URL inválida (deve começar com http:// ou https://)";
            root.identifyDone();
            return;
        }
        root.identifyBusy = true;
        root.identifyTitle = "";
        root.identifyUploader = "";
        root.identifyDuration = "";
        root.identifyError = "";
        identifyProc.exec(["yt-dlp", "--no-playlist", "--no-warnings", "--quiet", "-J", "--", cleanUrl]);
        identifyTimeout.restart();
    }

    function onIdentifyExited(code) {
        if (!root.identifyBusy)
            return;
        identifyTimeout.stop();
        root.identifyBusy = false;
        if (code !== 0) {
            const err = identifyErr.text.trim();
            root.identifyError = (err || "Falha ao identificar a URL").slice(0, 300);
            root.identifyDone();
            return;
        }
        try {
            const o = JSON.parse(identifyOut.text);
            root.identifyTitle = String(o.title ?? "");
            root.identifyUploader = String(o.uploader ?? o.channel ?? o.uploader_id ?? "");
            const dur = o.duration;
            if (typeof dur === "number" && isFinite(dur) && dur > 0)
                root.identifyDuration = root.formatDuration(dur);
            else
                root.identifyDuration = "";
        } catch (e) {
            root.identifyError = "Resposta inesperada ao identificar a URL";
        }
        root.identifyDone();
    }

    signal identifyDone()

    // ---------------------------------------------------------------- convert

    readonly property var convertPresets: {
        "mp4": { label: "MP4", ext: "mp4", icon: "movie" },
        "webm": { label: "WebM", ext: "webm", icon: "movie" },
        "mp3": { label: "MP3", ext: "mp3", icon: "music_note" },
        "flac": { label: "FLAC", ext: "flac", icon: "music_note" },
        "opus": { label: "OPUS", ext: "opus", icon: "music_note" },
        "wav": { label: "WAV", ext: "wav", icon: "graphic_eq" },
        "extract": { label: "AUDIO COPY", ext: "mka", icon: "content_copy" },
        "copy": { label: "STREAM COPY", ext: "", icon: "content_copy" },
        "reduce": { label: "REDUCE", ext: "mp4", icon: "compress" },
        "custom": { label: "CUSTOM", ext: "mp4", icon: "tune" }
    }

    property var probe: null
    property bool probeBusy: false
    property string probeError: ""

    Process {
        id: probeProc

        stdout: StdioCollector {
            id: probeOut
        }
        stderr: StdioCollector {
            id: probeErr
        }
        onExited: (code, status) => root.onProbeExited(code)
    }

    function probeFile(path) {
        if (root.probeBusy)
            return;
        root.probeBusy = true;
        root.probeError = "";
        probeProc.exec(["ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams", path]);
    }

    function onProbeExited(code) {
        root.probeBusy = false;
        if (code !== 0) {
            root.probe = null;
            root.probeError = (probeErr.text.trim() || "ffprobe não conseguiu ler o arquivo").slice(0, 300);
            return;
        }
        try {
            const o = JSON.parse(probeOut.text);
            const fmt = o.format ?? {};
            const streams = o.streams ?? [];
            const v = streams.find(s => s.codec_type === "video") ?? null;
            const a = streams.find(s => s.codec_type === "audio") ?? null;
            let duration = null;
            try {
                duration = parseFloat(fmt.duration) > 0 ? parseFloat(fmt.duration) : null;
            } catch (e) {}
            root.probe = {
                duration: duration,
                hasVideo: v !== null,
                hasAudio: a !== null,
                vcodec: v ? String(v.codec_name ?? "") : "",
                acodec: a ? String(a.codec_name ?? "") : "",
                container: String(fmt.format_name ?? "").split(",")[0],
                size: fmt.size ? parseFloat(fmt.size) : null
            };
        } catch (e) {
            root.probe = null;
            root.probeError = "ffprobe retornou dados inválidos";
        }
    }

    function stemOf(path) {
        const base = String(path).split("/").pop();
        const dot = base.lastIndexOf(".");
        return dot > 0 ? base.slice(0, dot) : base;
    }

    function extOf(path) {
        const base = String(path).split("/").pop();
        const dot = base.lastIndexOf(".");
        return dot > 0 ? base.slice(dot + 1) : "";
    }

    function addConvert(inputPath, preset, destDir, custom) {
        if (!inputPath || !inputPath.startsWith("/")) {
            return { ok: false, error: "Arquivo de entrada inválido" };
        }
        const dir = root.sanitizeDir(destDir);
        if (!dir) {
            return { ok: false, error: "Pasta de destino inválida" };
        }
        const p = root.convertPresets[preset];
        if (!p) {
            return { ok: false, error: "Preset inválido" };
        }
        if (preset === "custom" && !root.validateCustom(custom)) {
            return { ok: false, error: "Parâmetros customizados inválidos" };
        }
        root.lastConvertDir = dir;
        root.saveState();
        const job = root.pushJob({
            kind: "convert",
            title: String(inputPath).split("/").pop(),
            input: inputPath,
            preset: preset,
            destDir: dir,
            custom: custom ?? null,
            status: "queued",
            progress: 0,
            downloaded: null,
            speed: null,
            eta: null,
            outMs: 0,
            duration: null,
            error: "",
            logLines: [],
            finalPath: "",
            tmpPath: ""
        });
        return { ok: true, id: job.id };
    }

    function validateCustom(c) {
        if (!c || typeof c !== "object")
            return false;
        const vcodecs = ["libx264", "libx265", "libvpx-vp9", "none"];
        const acodecs = ["aac", "libopus", "libmp3lame", "copy", "none"];
        const vpresets = ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"];
        const exts = ["mp4", "webm", "mkv", "mka", "opus", "flac"];
        if (!vcodecs.includes(c.vcodec))
            return false;
        if (!vpresets.includes(c.vpreset))
            return false;
        if (!acodecs.includes(c.acodec))
            return false;
        if (!exts.includes(c.ext))
            return false;
        const crf = parseInt(c.crf);
        if (isNaN(crf) || crf < 0 || crf > 51)
            return false;
        const br = parseInt(c.abitrate);
        if (isNaN(br) || br < 32 || br > 512)
            return false;
        return true;
    }

    readonly property var containerFormats: {
        "mp4": "mp4", "m4v": "mp4", "m4a": "mp4",
        "webm": "webm",
        "mkv": "matroska", "mka": "matroska",
        "mov": "mov", "avi": "avi", "mpg": "mpeg", "mpeg": "mpeg",
        "mp3": "mp3", "flac": "flac", "opus": "opus",
        "ogg": "ogg", "oga": "ogg", "wav": "wav", "aac": "adts"
    }

    function convertCommand(job) {
        const preset = job.preset;
        const args = [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-nostats",
            "-y", "-progress", "pipe:1", "-i", job.input
        ];
        switch (preset) {
            case "mp4":
                args.push("-map", "0:v:0", "-map", "0:a:0?", "-c:v", "libx264", "-preset", "medium", "-crf", "23", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart");
                break;
            case "webm":
                args.push("-map", "0:v:0", "-map", "0:a:0?", "-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus", "-b:a", "128k");
                break;
            case "mp3":
                args.push("-map", "0:a:0", "-vn", "-c:a", "libmp3lame", "-q:a", "2");
                break;
            case "flac":
                args.push("-map", "0:a:0", "-vn", "-c:a", "flac");
                break;
            case "opus":
                args.push("-map", "0:a:0", "-vn", "-c:a", "libopus", "-b:a", "160k");
                break;
            case "wav":
                args.push("-map", "0:a:0", "-vn", "-c:a", "pcm_s16le");
                break;
            case "extract":
                args.push("-map", "0:a:0", "-vn", "-c:a", "copy");
                break;
            case "copy":
                args.push("-map", "0", "-c", "copy");
                break;
            case "reduce":
                args.push("-map", "0:v:0", "-map", "0:a:0?", "-c:v", "libx264", "-preset", "slower", "-crf", "28", "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart");
                break;
            case "custom":
                if (!root.validateCustom(job.custom))
                    return null;
                if (job.custom.vcodec !== "none")
                    args.push("-c:v", job.custom.vcodec, "-preset", job.custom.vpreset, "-crf", String(parseInt(job.custom.crf)));
                else
                    args.push("-vn");
                if (job.custom.acodec !== "none")
                    args.push("-c:a", job.custom.acodec, "-b:a", `${parseInt(job.custom.abitrate)}k`);
                else
                    args.push("-an");
                break;
            default:
                return null;
        }
        const stem = root.stemOf(job.input);
        const outExt = preset === "copy" ? root.extOf(job.input) : preset === "custom" ? job.custom.ext : root.convertPresets[preset].ext;
        const outName = `${stem}.${outExt}`;
        const finalPath = `${job.destDir}/${outName}`;
        const tmpPath = `${job.destDir}/.${outName}.part`;
        // Extensao .part nao e reconhecida pelo ffmpeg: formato explicito por preset.
        const container = root.containerFormats[outExt.toLowerCase()] ?? "matroska";
        args.push("-f", container);
        args.push(tmpPath);
        return { args: args, finalPath: finalPath, tmpPath: tmpPath };
    }

    // ---------------------------------------------------------------- retry

    function retry(entry) {
        if (entry.kind === "download") {
            return root.addDownload(entry.url, entry.preset, entry.destDir);
        }
        return root.addConvert(entry.input, entry.preset, entry.destDir, entry.custom ?? null);
    }

    function clearHistory() {
        root.history = [];
        root.saveState();
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.media"
        defaultLogLevel: LoggingCategory.Info
    }
}
