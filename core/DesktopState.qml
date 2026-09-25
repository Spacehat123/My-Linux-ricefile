import QtQuick
import Quickshell
import "../theme"

QtObject {
    id: root

    // =========================================================================
    // Injected Upstream Authorities (Compositor Singletons)
    // =========================================================================
    property var desktopModel: null
    property var idleManager: null
    property bool ambientEnabled: true

    property Theme theme: Theme {
        id: theme
    }

    // =========================================================================
    // Authoritative Presentation State Projections (Single Source of Truth)
    // =========================================================================
    readonly property var currentWorkspace: desktopModel ? desktopModel.focusedWorkspace : null
    readonly property int currentWorkspaceId: desktopModel ? desktopModel.focusedWorkspaceId : -1
    readonly property int currentSurfaceCount: currentWorkspace ? (currentWorkspace.surfaceCount || 0) : 0
    readonly property bool currentWorkspaceHasFullscreen: currentWorkspace ? Boolean(currentWorkspace.hasFullscreen) : false
    readonly property bool currentWorkspaceIsUrgent: currentWorkspace ? Boolean(currentWorkspace.urgent) : false
    readonly property bool ambientActive: Boolean(ambientEnabled && idleManager && idleManager.idle)

    // Shell Panel UI Presentation States
    property bool leftSidebarOpen: false
    property bool rightSidebarOpen: false
    property bool bottomBarOpen: false

    function setLeftSidebarOpen(val: bool) { leftSidebarOpen = val; }
    function setRightSidebarOpen(val: bool) { rightSidebarOpen = val; }
    function setBottomBarOpen(val: bool) { bottomBarOpen = val; }

    // =========================================================================
    // Spatial Workspace Transition Presentation State
    // =========================================================================
    property int previousWorkspaceId: -1
    property string workspaceTransitionDirection: "none" // "forward" | "backward" | "none"
    property int workspaceTransitionDirectionSign: 0     // 1 | -1 | 0
    readonly property bool workspaceTransitioning: _transitionAnim.running
    readonly property real workspaceTransitionProgress: _progress

    // Internal state tracking
    property int _lastActiveWorkspaceId: -1
    property bool _initialized: false
    property real _progress: 0.0

    // Declarative Transition Lifetime Driver (Driven purely by Scene Graph VSync)
    property NumberAnimation transitionAnim: NumberAnimation {
        id: _transitionAnim
        target: root
        property: "_progress"
        from: 0.0
        to: 1.0
        duration: theme.workspaceTransitionDuration > 0 ? (theme.workspaceTransitionDuration + 100) : 280
        easing.type: Easing.OutCubic
    }

    // Direction calculation helper
    function _computeDirection(newId, oldId) {
        if (oldId === -1 || newId === oldId) {
            return { name: "none", sign: 0 };
        }

        if (desktopModel && desktopModel.workspaces) {
            const list = desktopModel.workspaces;
            let newIdx = -1;
            let oldIdx = -1;
            for (let i = 0; i < list.length; ++i) {
                if (list[i].id === newId) newIdx = i;
                if (list[i].id === oldId) oldIdx = i;
            }
            if (newIdx !== -1 && oldIdx !== -1) {
                if (newIdx > oldIdx) return { name: "forward", sign: 1 };
                if (newIdx < oldIdx) return { name: "backward", sign: -1 };
                return { name: "none", sign: 0 };
            }
        }

        if (newId > oldId) return { name: "forward", sign: 1 };
        if (newId < oldId) return { name: "backward", sign: -1 };
        return { name: "none", sign: 0 };
    }

    // Reactive listener driving spatial handoff
    onCurrentWorkspaceIdChanged: {
        const curId = currentWorkspaceId;
        if (curId === -1) return;

        if (!_initialized) {
            previousWorkspaceId = curId;
            _lastActiveWorkspaceId = curId;
            workspaceTransitionDirection = "none";
            workspaceTransitionDirectionSign = 0;
            _initialized = true;
            return;
        }

        if (curId === _lastActiveWorkspaceId) return;

        const oldId = _lastActiveWorkspaceId;
        previousWorkspaceId = oldId;
        _lastActiveWorkspaceId = curId;

        const dir = _computeDirection(curId, oldId);
        workspaceTransitionDirection = dir.name;
        workspaceTransitionDirectionSign = dir.sign;

        _transitionAnim.restart();
    }
}
