import QtQuick

QtObject {
    id: root

    // Panel surface constants
    readonly property color panelBackground: "#e0181825"
    readonly property color panelBorder: "#30ffffff"
    readonly property int panelBorderWidth: 1
    readonly property int panelCornerRadius: 12

    // Layout and spacing constants
    readonly property int panelPadding: 16
    readonly property int itemSpacing: 12

    // Typography constants
    readonly property color primaryTextColor: "#ffffff"
    readonly property color secondaryTextColor: "#a0ffffff"
    readonly property color mutedTextColor: secondaryTextColor

    // Animation constants
    readonly property int animDurationOpen: 200
    readonly property int animDurationClose: 160

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
    readonly property color workspaceFocusedBackground: "#2800bfff"  // Translucent cyan wash
    readonly property color workspaceFocusedBorder: "#00bfff"          // High-contrast neon cyan
    readonly property color workspaceFocusedText: "#ffffff"
    readonly property color workspaceFocusedPip: "#00e5ff"

    // =========================================================================
    // Workspace State Tokens: Occupied
    // =========================================================================
    readonly property color workspaceOccupiedBackground: "#18ffffff" // Translucent white wash
    readonly property color workspaceOccupiedBorder: "#38ffffff"     // Soft white outline
    readonly property color workspaceOccupiedText: "#e0ffffff"
    readonly property color workspaceOccupiedPip: "#80ffffff"

    // =========================================================================
    // Workspace State Tokens: Empty
    // =========================================================================
    readonly property color workspaceEmptyBackground: "#08ffffff"    // Faint translucent tint
    readonly property color workspaceEmptyBorder: "#18ffffff"        // Muted hairline outline
    readonly property color workspaceEmptyText: "#60ffffff"

    // =========================================================================
    // Workspace State Tokens: Urgent
    // =========================================================================
    readonly property color workspaceUrgentBackground: "#30ff3366"   // Crimson warning wash
    readonly property color workspaceUrgentBorder: "#ff3366"         // Neon crimson border
    readonly property color workspaceUrgentText: "#ffffff"
    readonly property color workspaceUrgentPip: "#ff3366"

    // =========================================================================
    // Workspace State Tokens: Passive Hover & Multi-Monitor
    // =========================================================================
    readonly property color workspaceHoverBackground: "#20ffffff"
    readonly property color workspaceHoverBorder: "#50ffffff"
    readonly property color workspaceOtherMonitorText: "#80ffffff"

    // =========================================================================
    // Spatial Workspace HUD & Transition Tokens (Task 23)
    // =========================================================================
    readonly property int workspaceHudWidth: 148
    readonly property int workspaceHudSpacing: 10
    readonly property int workspaceHudCornerRadius: 6
    readonly property int workspaceTransitionDuration: 180
    readonly property int workspaceTransitionDistance: 20

    // Context HUD Palette
    readonly property color workspaceHudBackground: "#0affffff"
    readonly property color workspaceHudBorder: "#1affffff"
    readonly property color workspaceHudLabelText: "#7000bfff"
    readonly property color workspaceHudValueText: "#ffffff"
    readonly property color workspaceHudMutedText: "#60ffffff"
    readonly property color workspaceHudFullscreenBadge: "#ffb700"
    readonly property color workspaceHudFullscreenBackground: "#24ffb700"
    readonly property color workspaceHudUrgentBadge: "#ff3366"
    readonly property color workspaceHudUrgentBackground: "#30ff3366"
    readonly property color workspaceHudMonitorBadge: "#00e5ff"

    // Sliding Reticle / Focal Cursor
    readonly property color workspaceFocalCursorBorder: "#00bfff"
    readonly property color workspaceFocalCursorGlow: "#1800bfff"

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
    readonly property color surfaceCardBackground: "#12ffffff"          // Subtle card wash
    readonly property color surfaceCardBorder: "#20ffffff"              // Soft boundary outline
    readonly property color surfaceCardHoverBackground: "#1cffffff"     // Interactive card hover
    readonly property color surfaceCardHoverBorder: "#38ffffff"

    // =========================================================================
    // Application Overview Card Tokens (Focused State)
    // =========================================================================
    readonly property color surfaceCardFocusedBackground: "#2000bfff"   // Translucent neon cyan wash
    readonly property color surfaceCardFocusedBorder: "#00bfff"         // High-contrast neon cyan outline
    readonly property color surfaceCardFocusedPip: "#00e5ff"            // Bright status indicator
    readonly property color surfaceCardFocusedText: "#ffffff"

    // =========================================================================
    // Application Overview Card Tokens (Urgent State)
    // =========================================================================
    readonly property color surfaceCardUrgentBackground: "#28ff3366"    // Translucent crimson wash
    readonly property color surfaceCardUrgentBorder: "#ff3366"          // Neon crimson boundary outline
    readonly property color surfaceCardUrgentPip: "#ff3366"             // Warning pip
    readonly property color surfaceCardUrgentText: "#ffffff"

    // =========================================================================
    // Window Item Row Tokens (Child Surfaces)
    // =========================================================================
    readonly property color surfaceItemBackground: "#0affffff"          // Ultra-subtle row surface
    readonly property color surfaceItemHoverBackground: "#20ffffff"     // Passive hover highlight
    readonly property color surfaceItemFocusedBackground: "#2400bfff"   // Active surface row highlight
    readonly property color surfaceItemFocusedBorder: "#4000bfff"
    readonly property color surfaceItemUrgentBackground: "#30ff3366"    // Urgent surface row highlight
    readonly property color surfaceItemUrgentBorder: "#ff3366"

    // =========================================================================
    // HUD Badge, Tag, and Divider Tokens
    // =========================================================================
    readonly property color surfaceBadgeBackground: "#1affffff"
    readonly property color surfaceBadgeBorder: "#30ffffff"
    readonly property color surfaceBadgeUrgentBackground: "#ff3366"
    readonly property color surfaceBadgeUrgentText: "#ffffff"
    readonly property color surfaceTagBackground: "#18ffffff"
    readonly property color surfaceTagBorder: "#28ffffff"
    readonly property color surfaceTagText: "#a0ffffff"
    readonly property color surfaceTagFocusedBackground: "#3000bfff"
    readonly property color surfaceTagFocusedText: "#00e5ff"
    readonly property color surfaceDividerColor: "#20ffffff"

    // =========================================================================
    // Scrollbar Tokens
    // =========================================================================
    readonly property int scrollbarWidth: 3
    readonly property color scrollbarTrackColor: "#0affffff"
    readonly property color scrollbarThumbColor: "#38ffffff"
    readonly property color scrollbarThumbActiveColor: "#80ffffff"

    // =========================================================================
    // Interaction Affordance & Action Tokens (Task 20)
    // =========================================================================
    readonly property color actionFocusPromptColor: "#00bfff"         // Neon cyan focus prompt
    readonly property color actionFocusPromptMuted: "#80ffffff"        // Passive prompt
    readonly property color actionCloseBackground: "#0affffff"
    readonly property color actionCloseHoverBackground: "#30ff3366"    // Crimson warning wash
    readonly property color actionCloseBorder: "#18ffffff"
    readonly property color actionCloseHoverBorder: "#ff3366"          // Neon crimson border
    readonly property color actionCloseText: "#80ffffff"
    readonly property color actionCloseHoverText: "#ff3366"            // Illuminated crimson cross
    readonly property int actionButtonSize: 18
    readonly property int actionButtonCornerRadius: 4
    readonly property real actionAffordanceOpacityRest: 0.0            // Hidden at rest
    readonly property real actionAffordanceOpacityHover: 1.0           // Revealed on hover
    readonly property int animDurationAffordance: 120                  // Responsive reveal
    readonly property color workspaceHoverBracketColor: "#00bfff"     // Tactical jump brackets

    // =========================================================================
    // Action Toggle & Drawer Tokens (Task 22)
    // =========================================================================
    readonly property color actionActiveBackground: "#2400bfff"
    readonly property color actionActiveBorder: "#00bfff"
    readonly property color actionActiveText: "#00e5ff"
    readonly property color actionDrawerBackground: "#14ffffff"
    readonly property color actionDrawerBorder: "#24ffffff"
}

