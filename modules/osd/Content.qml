pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import QtQuick.Controls

Item {
    id: root

    required property Brightness.Monitor monitor
    required property ScreenState screenState

    required property real volume
    required property bool muted
    required property real sourceVolume
    required property bool sourceMuted
    required property real brightness

    // The TV is a different physical display: expose its brightness as a
    // shortcut on the other monitors' OSDs (hidden on the TV's own OSD).
    readonly property Brightness.Monitor tvMonitor: Brightness.monitors.find(m =>
        m.modelData.description?.includes("Panasonic") || m.modelData.name === "HDMI-A-1")
    readonly property bool showTvBrightness: !!root.tvMonitor && root.tvMonitor !== root.monitor

    function sinkKind(node: PwNode): string {
        const identity = `${node?.name ?? ""} ${node?.description ?? ""} ${node?.nickname ?? ""}`.toLowerCase();
        if (identity.includes("hdmi") || identity.includes("panasonic") || identity.includes("tv"))
            return "tv";
        if (identity.includes("headset") || identity.includes("headphone") || identity.includes("logitech"))
            return "headphones";
        return "speaker";
    }

    function sinkLabel(node: PwNode): string {
        const kind = sinkKind(node);
        return kind === "tv" ? qsTr("TV") : kind === "headphones" ? qsTr("Phone") : qsTr("Speakers");
    }

    implicitWidth: layout.implicitWidth + Tokens.padding.large + layout.anchors.horizontalCenterOffset * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: CUtils.clamp(Tokens.padding.large - Config.border.thickness, 0, Tokens.padding.large) / 2
        spacing: Tokens.spacing.medium

        // Audio Sinks Selection Row
        WrappedLoader {
            shouldBeActive: Config.osd.enableAudioOutputs && Audio.sinks.length > 1

            sourceComponent: RowLayout {
                spacing: Tokens.spacing.medium

                Repeater {
                    model: Audio.sinks

                    delegate: ColumnLayout {
                        id: outputDevice

                        required property var modelData

                        spacing: Tokens.spacing.extraSmall

                        IconButton {
                            Layout.alignment: Qt.AlignHCenter
                            checked: Audio.sink?.id === outputDevice.modelData.id
                            icon: root.sinkKind(outputDevice.modelData)

                            ToolTip.delay: 350
                            ToolTip.visible: hovered
                            ToolTip.text: outputDevice.modelData.description || outputDevice.modelData.name

                            onClicked: Audio.setAudioSink(outputDevice.modelData)
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.sinkLabel(outputDevice.modelData)
                            font: Tokens.font.label.small
                            color: Audio.sink?.id === outputDevice.modelData.id ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
        }

        // Speaker volume
        CustomMouseArea {
            function onWheel(event: WheelEvent) {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            implicitWidth: Tokens.sizes.osd.sliderWidth
            implicitHeight: Tokens.sizes.osd.sliderHeight

            FilledSlider {
                anchors.fill: parent

                icon: Icons.getVolumeIcon(value, root.muted)
                value: root.volume
                to: GlobalConfig.services.maxVolume
                onMoved: Audio.setVolume(value)
            }
        }

        // Microphone volume
        WrappedLoader {
            shouldBeActive: Config.osd.enableMicrophone && (!Config.osd.enableBrightness || !root.screenState.session)

            sourceComponent: CustomMouseArea {
                function onWheel(event: WheelEvent) {
                    if (event.angleDelta.y > 0)
                        Audio.incrementSourceVolume();
                    else if (event.angleDelta.y < 0)
                        Audio.decrementSourceVolume();
                }

                implicitWidth: Tokens.sizes.osd.sliderWidth
                implicitHeight: Tokens.sizes.osd.sliderHeight

                FilledSlider {
                    anchors.fill: parent

                    icon: Icons.getMicVolumeIcon(value, root.sourceMuted)
                    value: root.sourceVolume
                    to: GlobalConfig.services.maxVolume
                    onMoved: Audio.setSourceVolume(value)
                }
            }
        }

        // Brightness and Color Filters
        WrappedLoader {
            shouldBeActive: Config.osd.enableBrightness

            sourceComponent: RowLayout {
                spacing: Tokens.spacing.small

                CustomMouseArea {
                    function onWheel(event: WheelEvent) {
                        if (event.angleDelta.y > 0)
                            Nightlight.setIntensity(root.monitor?.modelData?.name ?? "DP-2",
                                Nightlight.intensityFor(root.monitor?.modelData?.name ?? "DP-2") + GlobalConfig.services.brightnessIncrement);
                        else if (event.angleDelta.y < 0)
                            Nightlight.setIntensity(root.monitor?.modelData?.name ?? "DP-2",
                                Nightlight.intensityFor(root.monitor?.modelData?.name ?? "DP-2") - GlobalConfig.services.brightnessIncrement);
                    }

                    implicitWidth: Tokens.sizes.osd.sliderWidth
                    implicitHeight: Tokens.sizes.osd.sliderHeight

                    FilledSlider {
                        anchors.fill: parent

                        icon: "dark_mode"
                        value: Nightlight.intensityFor(root.monitor?.modelData?.name ?? "DP-2")
                        to: 1
                        onMoved: Nightlight.setIntensity(root.monitor?.modelData?.name ?? "DP-2", value)
                    }
                }

                CustomMouseArea {
                    function onWheel(event: WheelEvent) {
                        if (event.angleDelta.y > 0)
                            Saturation.setLevel(root.monitor?.modelData?.name ?? "DP-2",
                                Saturation.levelFor(root.monitor?.modelData?.name ?? "DP-2") + GlobalConfig.services.brightnessIncrement);
                        else if (event.angleDelta.y < 0)
                            Saturation.setLevel(root.monitor?.modelData?.name ?? "DP-2",
                                Saturation.levelFor(root.monitor?.modelData?.name ?? "DP-2") - GlobalConfig.services.brightnessIncrement);
                    }

                    implicitWidth: Tokens.sizes.osd.sliderWidth
                    implicitHeight: Tokens.sizes.osd.sliderHeight

                    FilledSlider {
                        anchors.fill: parent

                        icon: "contrast"
                        value: Saturation.levelFor(root.monitor?.modelData?.name ?? "DP-2")
                        to: 1
                        onMoved: Saturation.setLevel(root.monitor?.modelData?.name ?? "DP-2", value)
                    }
                }

                CustomMouseArea {
                    function onWheel(event: WheelEvent) {
                        const monitor = root.monitor;
                        if (!monitor)
                            return;
                        if (event.angleDelta.y > 0)
                            monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
                        else if (event.angleDelta.y < 0)
                            monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
                    }

                    implicitWidth: Tokens.sizes.osd.sliderWidth
                    implicitHeight: Tokens.sizes.osd.sliderHeight

                    FilledSlider {
                        anchors.fill: parent

                        icon: `brightness_${(Math.round(value * 6) + 1)}`
                        value: root.brightness
                        onMoved: root.monitor?.setBrightness(value)
                    }
                }

                // TV brightness fallback slider for other monitors
                CustomMouseArea {
                    function onWheel(event: WheelEvent) {
                        const monitor = root.tvMonitor;
                        if (!monitor)
                            return;
                        if (event.angleDelta.y > 0)
                            monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
                        else if (event.angleDelta.y < 0)
                            monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
                    }

                    visible: root.showTvBrightness
                    implicitWidth: Tokens.sizes.osd.sliderWidth
                    implicitHeight: Tokens.sizes.osd.sliderHeight

                    FilledSlider {
                        anchors.fill: parent

                        icon: "tv"
                        value: root.tvMonitor?.brightness ?? 0
                        onMoved: root.tvMonitor?.setBrightness(value)
                    }
                }
            }
        }
    }

    component WrappedLoader: Loader {
        required property bool shouldBeActive

        asynchronous: true
        Layout.preferredHeight: shouldBeActive ? Tokens.sizes.osd.sliderHeight : 0
        opacity: shouldBeActive ? 1 : 0
        active: opacity > 0
        visible: active

        Behavior on Layout.preferredHeight {
            Anim {
                type: Anim.Emphasized
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
