import QtQuick
import "../island" as Island

QtObject {
    id: root

    // Master Smoked Glass Surface Constants (bound directly to Island.Theme)
    readonly property color panelBackground: Island.Theme.glassBackground
    readonly property color panelBorder: Island.Theme.glassBorder
    readonly property int panelBorderWidth: Island.Theme.glassBorderWidth
    readonly property int panelCornerRadius: Island.Theme.radiusWindow
    readonly property color glassCard: Island.Theme.glassCard
    readonly property color glassCardHover: Island.Theme.glassCardHover
    readonly property color glassBorderSubtle: Island.Theme.glassBorderSubtle
    readonly property color glassBorderActive: Island.Theme.glassBorderActive
    readonly property int radiusCard: Island.Theme.radiusCard
    readonly property int radiusSquircle: Island.Theme.radiusSquircle
    readonly property int radiusPill: Island.Theme.radiusPill

    // Layout and spacing constants
    readonly property int panelPadding: 16
    readonly property int itemSpacing: 12

    // Typography constants
    readonly property color primaryTextColor: Island.Theme.foreground
    readonly property color secondaryTextColor: Island.Theme.muted
    readonly property color mutedTextColor: secondaryTextColor

    // Animation constants
    readonly property int animDurationOpen: Island.Theme.animationFast + 60
    readonly property int animDurationClose: Island.Theme.animationFast + 20

    // =========================================================================
    // Workspace Navigator Metrics
    // =========================================================================
    readonly property int workspaceItemHeight: 32
    readonly property int workspaceItemMinWidth: 38
    readonly property int workspaceCornerRadius: 8
    readonly property int workspaceSpacing: 6
    readonly property int workspacePaddingHorizontal: 8

    // =========================================================================
    // Workspace State Tokens: Focused / Active
    // =========================================================================
    readonly property color workspaceFocusedBackground: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.16)
    readonly property color workspaceFocusedBorder: Island.Theme.primary
    readonly property color workspaceFocusedText: Island.Theme.foreground
    readonly property color workspaceFocusedPip: Island.Theme.primary

    // =========================================================================
    // Workspace State Tokens: Occupied
    // =========================================================================
    readonly property color workspaceOccupiedBackground: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.09)
    readonly property color workspaceOccupiedBorder: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.22)
    readonly property color workspaceOccupiedText: Island.Theme.foreground
    readonly property color workspaceOccupiedPip: Island.Theme.muted

    // =========================================================================
    // Workspace State Tokens: Empty
    // =========================================================================
    readonly property color workspaceEmptyBackground: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.03)
    readonly property color workspaceEmptyBorder: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.09)
    readonly property color workspaceEmptyText: Island.Theme.mutedDark

    // =========================================================================
    // Workspace State Tokens: Urgent
    // =========================================================================
    readonly property color workspaceUrgentBackground: Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.2)
    readonly property color workspaceUrgentBorder: Island.Theme.red
    readonly property color workspaceUrgentText: Island.Theme.foreground
    readonly property color workspaceUrgentPip: Island.Theme.red

    // =========================================================================
    // Workspace State Tokens: Passive Hover & Multi-Monitor
    // =========================================================================
    readonly property color workspaceHoverBackground: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.12)
    readonly property color workspaceHoverBorder: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.3)
    readonly property color workspaceOtherMonitorText: Island.Theme.muted

    // =========================================================================
    // Spatial Workspace HUD & Transition Tokens (Task 23)
    // =========================================================================
    readonly property int workspaceHudWidth: 148
    readonly property int workspaceHudSpacing: 10
    readonly property int workspaceHudCornerRadius: 6
    readonly property int workspaceTransitionDuration: 180
    readonly property int workspaceTransitionDistance: 20

    // Context HUD Palette
    readonly property color workspaceHudBackground: Qt.rgba(Island.Theme.bg0.r, Island.Theme.bg0.g, Island.Theme.bg0.b, 0.85)
    readonly property color workspaceHudBorder: Qt.rgba(Island.Theme.muted.r, Island.Theme.muted.g, Island.Theme.muted.b, 0.2)
    readonly property color workspaceHudLabelText: Island.Theme.muted
    readonly property color workspaceHudValueText: Island.Theme.foreground
    readonly property color workspaceHudMutedText: Island.Theme.mutedDark
    readonly property color workspaceHudFullscreenBadge: Island.Theme.yellow
    readonly property color workspaceHudFullscreenBackground: Qt.rgba(Island.Theme.yellow.r, Island.Theme.yellow.g, Island.Theme.yellow.b, 0.15)
    readonly property color workspaceHudUrgentBadge: Island.Theme.red
    readonly property color workspaceHudUrgentBackground: Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.2)
    readonly property color workspaceHudMonitorBadge: Island.Theme.blue

    // Sliding Reticle / Focal Cursor
    readonly property color workspaceFocalCursorBorder: Island.Theme.primary
    readonly property color workspaceFocalCursorGlow: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)

    // =========================================================================
    // Application Overview Layout & Spacing Metrics
    // =========================================================================
    readonly property int surfaceHeaderHeight: 38
    readonly property int surfaceCardSpacing: 10
    readonly property int surfaceCardPadding: 10
    readonly property int surfaceCardCornerRadius: 8
    readonly property int surfaceItemHeight: 24
    readonly property int surfaceItemSpacing: 4
    readonly property int surfaceItemCornerRadius: 4
    readonly property int surfaceTagCornerRadius: 4

    // =========================================================================
    // Application Overview Card Tokens (Normal State)
    // =========================================================================
    readonly property color surfaceCardBackground: Qt.rgba(Island.Theme.bg1.r, Island.Theme.bg1.g, Island.Theme.bg1.b, 0.5)
    readonly property color surfaceCardBorder: Qt.rgba(Island.Theme.muted.r, Island.Theme.muted.g, Island.Theme.muted.b, 0.15)
    readonly property color surfaceCardHoverBackground: Qt.rgba(Island.Theme.bg2.r, Island.Theme.bg2.g, Island.Theme.bg2.b, 0.7)
    readonly property color surfaceCardHoverBorder: Qt.rgba(Island.Theme.muted.r, Island.Theme.muted.g, Island.Theme.muted.b, 0.3)

    // =========================================================================
    // Application Overview Card Tokens (Focused State)
    // =========================================================================
    readonly property color surfaceCardFocusedBackground: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)
    readonly property color surfaceCardFocusedBorder: Island.Theme.primary
    readonly property color surfaceCardFocusedPip: Island.Theme.primary
    readonly property color surfaceCardFocusedText: Island.Theme.foreground

    // =========================================================================
    // Application Overview Card Tokens (Urgent State)
    // =========================================================================
    readonly property color surfaceCardUrgentBackground: Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.2)
    readonly property color surfaceCardUrgentBorder: Island.Theme.red
    readonly property color surfaceCardUrgentPip: Island.Theme.red
    readonly property color surfaceCardUrgentText: Island.Theme.foreground

    // =========================================================================
    // Window Item Row Tokens (Child Surfaces)
    // =========================================================================
    readonly property color surfaceItemBackground: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.04)
    readonly property color surfaceItemHoverBackground: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.12)
    readonly property color surfaceItemFocusedBackground: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)
    readonly property color surfaceItemFocusedBorder: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.35)
    readonly property color surfaceItemUrgentBackground: Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.2)
    readonly property color surfaceItemUrgentBorder: Island.Theme.red

    // =========================================================================
    // HUD Badge, Tag, and Divider Tokens
    // =========================================================================
    readonly property color surfaceBadgeBackground: Qt.rgba(Island.Theme.bg2.r, Island.Theme.bg2.g, Island.Theme.bg2.b, 0.7)
    readonly property color surfaceBadgeBorder: Qt.rgba(Island.Theme.muted.r, Island.Theme.muted.g, Island.Theme.muted.b, 0.2)
    readonly property color surfaceBadgeUrgentBackground: Island.Theme.red
    readonly property color surfaceBadgeUrgentText: Island.Theme.foreground
    readonly property color surfaceTagBackground: Qt.rgba(Island.Theme.bg1.r, Island.Theme.bg1.g, Island.Theme.bg1.b, 0.6)
    readonly property color surfaceTagBorder: Qt.rgba(Island.Theme.muted.r, Island.Theme.muted.g, Island.Theme.muted.b, 0.15)
    readonly property color surfaceTagText: Island.Theme.muted
    readonly property color surfaceTagFocusedBackground: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.2)
    readonly property color surfaceTagFocusedText: Island.Theme.primary
    readonly property color surfaceDividerColor: Qt.rgba(Island.Theme.muted.r, Island.Theme.muted.g, Island.Theme.muted.b, 0.15)

    // =========================================================================
    // Scrollbar Tokens
    // =========================================================================
    readonly property int scrollbarWidth: 3
    readonly property color scrollbarTrackColor: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.04)
    readonly property color scrollbarThumbColor: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.22)
    readonly property color scrollbarThumbActiveColor: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.5)

    // =========================================================================
    // Interaction Affordance & Action Tokens (Task 20)
    // =========================================================================
    readonly property color actionFocusPromptColor: Island.Theme.primary
    readonly property color actionFocusPromptMuted: Island.Theme.muted
    readonly property color actionCloseBackground: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.04)
    readonly property color actionCloseHoverBackground: Qt.rgba(Island.Theme.red.r, Island.Theme.red.g, Island.Theme.red.b, 0.2)
    readonly property color actionCloseBorder: Qt.rgba(Island.Theme.muted.r, Island.Theme.muted.g, Island.Theme.muted.b, 0.15)
    readonly property color actionCloseHoverBorder: Island.Theme.red
    readonly property color actionCloseText: Island.Theme.muted
    readonly property color actionCloseHoverText: Island.Theme.red
    readonly property int actionButtonSize: 18
    readonly property int actionButtonCornerRadius: 4
    readonly property real actionAffordanceOpacityRest: 0.0
    readonly property real actionAffordanceOpacityHover: 1.0
    readonly property int animDurationAffordance: 120
    readonly property color workspaceHoverBracketColor: Island.Theme.primary

    // =========================================================================
    // Action Toggle & Drawer Tokens (Task 22)
    // =========================================================================
    readonly property color actionActiveBackground: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)
    readonly property color actionActiveBorder: Island.Theme.primary
    readonly property color actionActiveText: Island.Theme.primary
    readonly property color actionDrawerBackground: Qt.rgba(Island.Theme.bg1.r, Island.Theme.bg1.g, Island.Theme.bg1.b, 0.6)
    readonly property color actionDrawerBorder: Qt.rgba(Island.Theme.muted.r, Island.Theme.muted.g, Island.Theme.muted.b, 0.2)

    // =========================================================================
    // Desktop Ambient & Idle State Tokens (Task 24)
    // =========================================================================
    readonly property int ambientFadeInDuration: 1000
    readonly property int ambientFadeOutDuration: 180
    readonly property color ambientHudPrimary: Island.Theme.primary
    readonly property color ambientHudSecondary: Island.Theme.aqua
    readonly property color ambientHudFaint: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.1)
    readonly property color ambientHudMuted: Qt.rgba(Island.Theme.muted.r, Island.Theme.muted.g, Island.Theme.muted.b, 0.2)
    readonly property color ambientHudSubtle: Qt.rgba(Island.Theme.foreground.r, Island.Theme.foreground.g, Island.Theme.foreground.b, 0.08)
    readonly property color ambientHudText: Island.Theme.muted
    readonly property color ambientHudAccentText: Island.Theme.primary
    readonly property color ambientHudDarkFill: Qt.rgba(Island.Theme.bgDim.r, Island.Theme.bgDim.g, Island.Theme.bgDim.b, 0.5)
    readonly property int ambientReticleSize: 240
    readonly property int ambientBracketSize: 48
    readonly property int ambientLineWidth: 1
    readonly property int ambientCornerOffset: 36

    // =========================================================================
    // Spatial Workspace Transition Tokens (Task 25)
    // =========================================================================
    readonly property int spatialTransitionDuration: 280
    readonly property int spatialTransitionReticleWidth: 260
    readonly property int spatialTransitionReticleHeight: 48
    readonly property int spatialTransitionOffset: 36
    readonly property color spatialTransitionBorder: Island.Theme.primary
    readonly property color spatialTransitionGlow: Qt.rgba(Island.Theme.primary.r, Island.Theme.primary.g, Island.Theme.primary.b, 0.15)
}
