/*
 !              NAME  :    customDialog
 !            AUTHOR  :    OWHS (Improved)
 !           VERSION  :    1.8
 !       DESCRIPTION  :        
 :                        Creates a highly customizable, non-native GUI dialog box.
 :                        This function allows for extensive control over appearance, layout, and behavior,
 :                        making it a versatile replacement for standard message boxes.
 :                        It returns an object containing the user's choice, input values, and methods to update the dialog.
*/

darkPreset := {
	background: "1A1A1A",
	backgroundAlt: "0e0e0e",
	fontColor: "FFFFFF",
	detailBorder: "333333",
	titlebarBG: "0e0e0e",
	width: 400,
	popupAltSound: true,
	forceParent: true,
	alwaysOnTop: true,
    modal: true,
	icon: "✋",
	title: "Stop!",
}
errorPreset := {
	background: "1A1A1A",
	backgroundAlt: "0e0e0e",
	fontColor: "ff8585",
	detailBorder: "333333",
	titlebarBG: "0e0e0e",
	width: 400,
	popupAltSound: true,
	forceParent: true,
	alwaysOnTop: true,
    modal: true,
	icon: "⚠️",
	title: "Stop!",
	iconColor: "ffa600",
}

criticalErrorDetailPreset := {
	icon: "⚠️",
	width: 400,
	background: "1A1A1A",
	backgroundAlt: "0e0e0e",
	titlebarBG: "290909",
	fontColor: "ff8585",
	detailBorder: "750404",
	exitBG: "410606",
	popupAltSound: true,
	icon: "🚫",
	iconColor: "ff3300",
	title: "Critical Error",
	height: 400,
	detailRows: 14,
	width: 600,
    modal: true,
	buttons: ["&Close"],
}
confirmPreset := {
	icon: "❓",
	align: "Center",
	messageTop: 9,
	iconColor: "66A3FF",
	width: 430,
    modal: true,
	buttons: ["&Yes", "&No"]
}

inputPreset := {
    icon: "✏️",
    iconColor: "66A3FF",
    width: 450,
    input: true, ; Enables input mode
    placeholder: "Type here...",
    buttons: ["&OK", "&Cancel"]
}

progressPreset := {
    title: "Working...",
    width: 500,
    icon: "⏳",
    iconColor: "00CCFF",
    progress: 0,
    progressText: "Initializing...",
    progressColor: "00CCFF",
    buttons: ["&Cancel"]
}

; ==============================================================================
; Direct Open Protection:
; ==============================================================================
global isGUI
checkUI(){
    if not IsSet(isGUI){
        customDialog({
            title: "Error!",
            message: "Should not be opened directly!",
            noAltF4: true,
        }, errorPreset)
         ExitApp()
    }
}
checkUI()


/**
 *
 * @param {Object} info An object containing properties to configure the dialog.
 * @param {Object} defaults An optional object with default properties. This allows you to define "presets"
 * and then override specific properties with the `info` object for cleaner calls.
 *
 * --------------------------------
 * ----- SETUP PROPERTIES -----
 * --------------------------------
 * * -----------------------
 * -- Window & Layout --
 * -----------------------
 * -----------------------
 * * @property {Integer} width            - The total width of the dialog window in pixels. Default: 600.
 * @property {Integer} height           - A fixed height for the dialog. If 0 or omitted, height is calculated automatically based on content. Default: 0.
 * @property {Boolean} forceLegacyRadius- If true, forces the use of legacy (GDI) rounded corners even on Windows 11. Default: false.
 * @property {Integer} win11Radius      - The corner roundness value for Windows 11's DWM attribute. Default: 3.
 * @property {Integer} legacyRadius     - The corner roundness for legacy windows (GDI region). Default: 5.
 * @property {String}  align            - Alignment for the main message text. Can be "Left", "Center", or "Right". Default: "" (Left).
 * @property {Integer} messageTop       - Adds extra vertical padding (in pixels) above the main message text. Default: 0.
 *
 * -----------------------
 * -- Content & Text --
 * -----------------------
 * -----------------------
 * * @property {String}  title            - The text displayed in the dialog's title bar. Default: "Alert".
 * @property {String}  message          - The main message/text content of the dialog. Default: "Message".
 * @property {String}  detail           - Optional supplementary text displayed in a read-only, scrollable box. Default: "".
 * @property {Integer} detailRows       - The number of visible text rows for the `detail` box. Default: 9.
 * @property {String}  icon             - A single character/emoji to display as an icon to the left of the message. Default: "".
 *
 * -----------------------
 * -- Input Mode --
 * -----------------------
 * -----------------------
 * @property {Boolean|String} input     - If set to true or a string, enables Input Mode. If a string, it sets the default value.
 * @property {String}  placeholder      - Placeholder text (ghost text) for the input box.
 * @property {Boolean} maskInput        - If true, masks the input characters (for passwords).
 *
 * -----------------------
 * -- Progress Bars (New) --
 * -----------------------
 * -----------------------
 * @property {Integer} progress         - Set to a number (0-100) to enable the main progress bar.
 * @property {String}  progressText     - Status text displayed above the main progress bar.
 * @property {String}  progressSubText  - Smaller sub-status text displayed above the main progress bar (below status).
 * @property {String}  progressColor    - Hex color for the main progress bar. Default: Matches `iconColor` or `fontColor`.
 * @property {Integer} progress2        - Set to a number (0-100) to enable the secondary (sub) progress bar.
 * @property {String}  progress2Text    - Status text displayed above the secondary progress bar.
 * @property {String}  progress2SubText - Smaller sub-status text displayed above the secondary progress bar.
 * @property {String}  progress2Color   - Hex color for the secondary progress bar. Default: "888888".
 *
 * -----------------------
 * -- Buttons --
 * -----------------------
 * -----------------------
 * @property {Array}   buttons          - An array of strings for the button labels (e.g., ["&Yes", "&No", "&Cancel"]). The '&' creates a keyboard shortcut. Default: ["&OK"].
 * @property {String}  button           - A shorthand property to create a single button. Overridden by `buttons` if both are present.
 * @property {Integer} btn_w            - The width of each button in pixels. Default: 80.
 * @property {Integer} btn_h            - The height of each button in pixels. Default: 30.
 * @property {Integer} btn_margin       - The horizontal margin between buttons in pixels. Default: 10.
 *
 * -----------------------
 * -- Color Properties --
 * -----------------------
 * - (Accepts 6-digit hex strings, e.g., "RRGGBB")
 * -----------------------
 * * @property {String}  background       - The main background color of the dialog. Default: "1A1A1A".
 * @property {String}  backgroundAlt    - The background color for buttons, input, and the `detail` box. Default: "0e0e0e".
 * @property {String}  fontColor        - The default color for all text elements. Can be overridden by specific color properties. Default: "FFFFFF".
 * @property {String}  titleColor       - The color of the `title` text. Inherits `fontColor` if not set.
 * @property {String}  titlebarBG       - The background color of the title bar. Default: "0e0e0e".
 * @property {String}  messageColor     - The color of the `message` text. Inherits `fontColor` if not set.
 * @property {String}  detailColor      - The color of the `detail` text. Inherits `fontColor` if not set.
 * @property {String}  detailBorder     - The color of the border around the boxes. Default: "333333".
 * @property {String}  focusBorderColor - The color of the border when an input/detail box is focused. Default: Matches `iconColor` or `fontColor`.
 * @property {String}  iconColor        - The color of the `icon` character. Default: "FF4C4C".
 * @property {String}  buttonColor      - The color of the button text. Inherits `fontColor` if not set.
 * @property {String}  buttonHoverColor - The background color of a button when hovered. Default: "333333".
 * @property {String}  exitColor        - The color of the 'x' close button text. Inherits `fontColor` if not set.
 * @property {String}  exitBG           - The background color of the 'x' close button. Default: "250d0d".
 *
 * -----------------------
 * -- Behavior & Functionality --
 * -----------------------
 * -----------------------
 * @property {Boolean} exitEnabled      - If true, displays a custom 'x' button to close the dialog. Default: true.
 * @property {Integer} exitWidth        - The width of the 'x' close button area. Default: 40.
 * @property {Boolean} popupSound       - If true, plays a system sound when the dialog appears. Default: true.
 * @property {Boolean} popupAltSound    - If true, plays the "Asterisk" sound (0x10); if false, plays "Exclamation" (0x30). Default: false (plays 0x30).
 * @property {Integer} ownerHwnd        - The HWND of a window to own this dialog. Makes the dialog modal to its owner. Default: 0.
 * @property {Boolean} forceParent      - If true and `ownerHwnd` is 0, automatically sets the active window as the owner. Default: true.
 * @property {Boolean} waitForResponse  - If true, the script will pause until the dialog is closed. If false, the script continues, and the dialog runs asynchronously. NOTE: Defaults to false if progress bars are present.
 * @property {Boolean} alwaysOnTop      - If true, the dialog stays on top of other non-topmost windows. Default: true.
 * @property {Boolean} noAltF4          - If true, disables the Alt+F4 hotkey for closing the window. Default: false.
 * @property {Boolean} modal            - If true, disables the parent window while the dialog is open. This enforces focus, sounds, and flashing if the parent is clicked. Default: true.
 *
 * -----------------------
 * -- RETURN --
 * -----------------------
 * -----------------------
 * @returns {Object} An object with properties:
 * - `value`: The text of the button clicked by the user.
 * - `input`: The text entered in the input box.
 * - `gui`: The AHK Gui object.
 * - `Update(percent, text, subText, barIndex)`: Method to update progress bars dynamically. `barIndex` 1 is main, 2 is sub.
 */
customDialog(info := {}, defaults := {}) {

    ;#region 0. Initialize Default Properties
    ; This section establishes the base values for every property.
    ; It checks if a property exists in the `defaults` object first, otherwise it uses a hardcoded fallback.
    defaultProperties := {
        width: defaults.HasProp("width") && defaults.width ? defaults.width : 600,
        height: defaults.HasProp("height") && defaults.height ? defaults.height : 0,

        forceLegacyRadius: defaults.HasProp("forceLegacyRadius") && defaults.forceLegacyRadius ? true : false,
        win11Radius: defaults.HasProp("win11Radius") && defaults.win11Radius ? defaults.win11Radius : 3,
        legacyRadius: defaults.HasProp("legacyRadius") && (defaults.legacyRadius || defaults.legacyRadius == 0) ? defaults.legacyRadius : 5,

        background: defaults.HasProp("background") && defaults.background ? defaults.background : "1A1A1A",
        backgroundAlt: defaults.HasProp("backgroundAlt") && (defaults.backgroundAlt || defaults.backgroundAlt == "000000") ? defaults.backgroundAlt : "0e0e0e",
        fontColor: defaults.HasProp("fontColor") && (defaults.fontColor || defaults.fontColor == "000000") ? defaults.fontColor : "FFFFFF",
        detailBorder: defaults.HasProp("detailBorder") && (defaults.detailBorder || defaults.detailBorder == "000000") ? defaults.detailBorder : "333333",

        title: defaults.HasProp("title") && defaults.title ? defaults.title : "Alert",
        titleColor: defaults.HasProp("titleColor") && (defaults.titleColor || defaults.titleColor == "000000") ? defaults.titleColor : "",
        titlebarHeight: defaults.HasProp("titlebarHeight") && defaults.titlebarHeight ? defaults.titlebarHeight : 30,
        titlebarBG: defaults.HasProp("titlebarBG") && defaults.titlebarBG ? defaults.titlebarBG : "0e0e0e",

        message: defaults.HasProp("message") && defaults.message ? defaults.message : "Message",
        messageColor: defaults.HasProp("messageColor") && (defaults.messageColor || defaults.messageColor == "000000") ? defaults.messageColor : "",
        align: defaults.HasProp("align") && defaults.align ? defaults.align : "",
        messageTop: defaults.HasProp("messageTop") && (defaults.messageTop) ? defaults.messageTop : 0,

        detail: defaults.HasProp("detail") && defaults.detail ? defaults.detail : "",
        detailColor: defaults.HasProp("detailColor") && (defaults.detailColor || defaults.detailColor == "000000") ? defaults.detailColor : "",
        detailRows: defaults.HasProp("detailRows") && (defaults.detailRows || defaults.detailRows == 0) ? defaults.detailRows : 9,

        ; Input Defaults
        input: defaults.HasProp("input") ? defaults.input : false,
        placeholder: defaults.HasProp("placeholder") ? defaults.placeholder : "",
        maskInput: defaults.HasProp("maskInput") ? defaults.maskInput : false,

        ; Progress Defaults
        progress: defaults.HasProp("progress") && (Type(defaults.progress) == "Integer") ? defaults.progress : -1,
        progressText: defaults.HasProp("progressText") ? defaults.progressText : "",
        progressSubText: defaults.HasProp("progressSubText") ? defaults.progressSubText : "",
        progressColor: defaults.HasProp("progressColor") ? defaults.progressColor : "",
        progress2: defaults.HasProp("progress2") && (Type(defaults.progress2) == "Integer") ? defaults.progress2 : -1,
        progress2Text: defaults.HasProp("progress2Text") ? defaults.progress2Text : "",
        progress2SubText: defaults.HasProp("progress2SubText") ? defaults.progress2SubText : "",
        progress2Color: defaults.HasProp("progress2Color") ? defaults.progress2Color : "",

        icon: defaults.HasProp("icon") && defaults.icon ? defaults.icon : "",
        iconColor: defaults.HasProp("iconColor") && (defaults.iconColor || defaults.iconColor == "000000") ? defaults.iconColor : "FF4C4C",

        buttons: defaults.HasProp("buttons") && defaults.buttons ? defaults.buttons : ["&OK"],
        buttonColor: defaults.HasProp("buttonColor") && (defaults.buttonColor || defaults.buttonColor == "000000") ? defaults.buttonColor : "",
        buttonHoverColor: defaults.HasProp("buttonHoverColor") && (defaults.buttonHoverColor || defaults.buttonHoverColor == "000000") ? defaults.buttonHoverColor : "",

        exitEnabled: defaults.HasProp("exitEnabled") && defaults.exitEnabled == false ? false : true,
        exitWidth: defaults.HasProp("exitWidth") && defaults.exitWidth ? defaults.exitWidth : 40,
        exitBG: defaults.HasProp("exitBG") && defaults.exitBG ? defaults.exitBG : "250d0d",
        exitBGHover: defaults.HasProp("exitBGHover") && defaults.exitBGHover ? defaults.exitBGHover : "701c1c",
        exitColor: defaults.HasProp("exitColor") && (defaults.exitColor || defaults.exitColor == "000000") ? defaults.exitColor : "",

        popupSound: defaults.HasProp("popupSound") && defaults.popupSound == false ? false : true,
        popupAltSound: defaults.HasProp("popupAltSound") && defaults.popupAltSound ? 0x10 : 0x30,

        ownerHwnd: defaults.HasProp("ownerHwnd") && defaults.ownerHwnd ? defaults.ownerHwnd : 0,
        waitForResponse: defaults.HasProp("waitForResponse") ? defaults.waitForResponse : -1, ; -1 indicates "Auto"
        alwaysOnTop: defaults.HasProp("alwaysOnTop") && defaults.alwaysOnTop == false ? false : true,
        forceParent: defaults.HasProp("forceParent") && defaults.forceParent == false ? false : true,
        noAltF4: defaults.HasProp("noAltF4") && defaults.noAltF4 ? true : false,
        modal: defaults.HasProp("modal") && defaults.modal == false ? false : true,
    }
    ;#endregion

    ;#region 1. Initialize Properties
    ; This section resolves the final properties by checking the `info` object first,
    ; and falling back to the `defaultProperties` map if a property isn't provided.
    width := info.HasProp("width") && info.width ? info.width : defaultProperties.width
    height := info.HasProp("height") && info.height ? info.height : defaultProperties.height
    forceLegacyRadius := info.HasProp("forceLegacyRadius") && info.forceLegacyRadius ? true : defaultProperties.forceLegacyRadius
    win11Radius := info.HasProp("win11Radius") && info.win11Radius ? info.win11Radius : defaultProperties.win11Radius
    legacyRadius := info.HasProp("legacyRadius") && (info.legacyRadius || info.legacyRadius == 0) ? info.legacyRadius : defaultProperties.legacyRadius

    background := info.HasProp("background") && info.background ? info.background : defaultProperties.background
    backgroundAlt := info.HasProp("backgroundAlt") && (info.backgroundAlt || info.backgroundAlt == "000000") ? info.backgroundAlt : defaultProperties.backgroundAlt
    fontColor := info.HasProp("fontColor") && (info.fontColor || info.fontColor == "000000") ? info.fontColor : defaultProperties.fontColor
    detailBorder := info.HasProp("detailBorder") && (info.detailBorder || info.detailBorder == "000000") ? info.detailBorder : defaultProperties.detailBorder

    title := info.HasProp("title") && info.title ? info.title : defaultProperties.title
    titleColor := info.HasProp("titleColor") && (info.titleColor || info.titleColor == "000000") ? info.titleColor : defaultProperties.titleColor ? defaultProperties.titleColor : fontColor
    titlebarHeight := info.HasProp("titlebarHeight") && info.titlebarHeight ? info.titlebarHeight : defaultProperties.titlebarHeight
    titlebarBG := info.HasProp("titlebarBG") && info.titlebarBG ? info.titlebarBG : defaultProperties.titlebarBG

    message := info.HasProp("message") && info.message ? info.message : defaultProperties.message
    messageColor := info.HasProp("messageColor") && (info.messageColor || info.messageColor == "000000") ? info.messageColor : defaultProperties.messageColor ? defaultProperties.messageColor : fontColor
    align := info.HasProp("align") && info.align ? info.align : defaultProperties.align
    messageTop := info.HasProp("messageTop") && (info.messageTop) ? info.messageTop : defaultProperties.messageTop

    detail := info.HasProp("detail") && info.detail ? info.detail : defaultProperties.detail
    detailColor := info.HasProp("detailColor") && (info.detailColor || info.detailColor == "000000") ? info.detailColor : defaultProperties.detailColor ? defaultProperties.detailColor : fontColor
    detailRows := info.HasProp("detailRows") && (info.detailRows || info.detailRows == 0) ? info.detailRows : defaultProperties.detailRows

    ; Input Properties
    hasInput := info.HasProp("input") ? true : (defaultProperties.input != false)
    inputDefault := info.HasProp("input") && Type(info.input) == "String" ? info.input : (Type(defaultProperties.input) == "String" ? defaultProperties.input : "")
    placeholder := info.HasProp("placeholder") ? info.placeholder : defaultProperties.placeholder
    maskInput := info.HasProp("maskInput") ? info.maskInput : defaultProperties.maskInput

    icon := info.HasProp("icon") ? info.icon : defaultProperties.icon
    iconColor := info.HasProp("iconColor") && (info.iconColor || info.iconColor == "000000") ? info.iconColor : defaultProperties.iconColor
    
    ; Focus Color: Defaults to Icon Color if available, otherwise Font Color
    focusBorderColor := info.HasProp("focusBorderColor") ? info.focusBorderColor : (iconColor != "000000" && iconColor != "" ? iconColor : fontColor)

    ; Progress Properties
    prog1Val := info.HasProp("progress") && (Type(info.progress) == "Integer") ? info.progress : defaultProperties.progress
    prog1Text := info.HasProp("progressText") ? info.progressText : defaultProperties.progressText
    prog1SubText := info.HasProp("progressSubText") ? info.progressSubText : defaultProperties.progressSubText
    prog1Color := info.HasProp("progressColor") ? info.progressColor : (defaultProperties.progressColor ? defaultProperties.progressColor : iconColor)
    
    prog2Val := info.HasProp("progress2") && (Type(info.progress2) == "Integer") ? info.progress2 : defaultProperties.progress2
    prog2Text := info.HasProp("progress2Text") ? info.progress2Text : defaultProperties.progress2Text
    prog2SubText := info.HasProp("progress2SubText") ? info.progress2SubText : defaultProperties.progress2SubText
    prog2Color := info.HasProp("progress2Color") ? info.progress2Color : (defaultProperties.progress2Color ? defaultProperties.progress2Color : "888888")

    hasProgress := (prog1Val != -1)

    buttons := info.HasProp("buttons") && info.buttons ? info.buttons : defaultProperties.buttons
    buttonColor := info.HasProp("buttonColor") && (info.buttonColor || info.buttonColor == "000000") ? info.buttonColor : defaultProperties.buttonColor ? defaultProperties.buttonColor : fontColor
    buttonHoverColor := info.HasProp("buttonHoverColor") && (info.buttonHoverColor || info.buttonHoverColor == "000000") ? info.buttonHoverColor : defaultProperties.buttonHoverColor ? defaultProperties.buttonHoverColor : detailBorder

    exitEnabled := info.HasProp("exitEnabled") && info.exitEnabled == false ? false : defaultProperties.exitEnabled
    exitWidth := info.HasProp("exitWidth") && info.exitWidth ? info.exitWidth : defaultProperties.exitWidth
    exitBG := info.HasProp("exitBG") && info.exitBG ? info.exitBG : defaultProperties.exitBG
    exitBGHover := info.HasProp("exitBGHover") && info.exitBGHover ? info.exitBGHover : defaultProperties.exitBGHover
    exitColor := info.HasProp("exitColor") && (info.exitColor || info.exitColor == "000000") ? info.exitColor : defaultProperties.exitColor ? defaultProperties.exitColor : fontColor

    popupSound := info.HasProp("popupSound") && info.popupSound == false ? false : defaultProperties.popupSound
    popupAltSound := info.HasProp("popupAltSound") && info.popupAltSound ? 0x10 : defaultProperties.popupAltSound

    ownerHwnd := info.HasProp("ownerHwnd") && info.ownerHwnd ? info.ownerHwnd : defaultProperties.ownerHwnd
    
    ; Logic for WaitForResponse: If not explicitly set by user, default to TRUE normally, but FALSE if progress bars are active.
    if (info.HasProp("waitForResponse")) {
        waitForResponse := info.waitForResponse
    } else if (defaultProperties.waitForResponse != -1) {
        waitForResponse := defaultProperties.waitForResponse
    } else {
        waitForResponse := hasProgress ? false : true
    }
    
    alwaysOnTop := info.HasProp("alwaysOnTop") && info.alwaysOnTop == false ? false : defaultProperties.alwaysOnTop
    forceParent := info.HasProp("forceParent") && info.forceParent == false ? false : defaultProperties.forceParent
    noAltF4 := info.HasProp("noAltF4") && info.noAltF4 ? true : defaultProperties.noAltF4
    modal := info.HasProp("modal") && info.modal == false ? false : defaultProperties.modal

    ; Handles the `button` shorthand property for creating a single button.
    if info.HasProp("button") && !info.HasProp("buttons") {
        buttons := [info.button]
    }
    ;#endregion

    ;#region 2. Initialize GUI
    ; Configures and creates the main GUI window object.

    if (popupSound == true) {
        DllCall("user32\MessageBeep", "uint", popupAltSound)
    }

    ; Base GUI options: no caption, tool window style (no taskbar icon), and a system menu.
    guiOptions := (alwaysOnTop == true ? "+AlwaysOnTop " : "") "-Caption +ToolWindow +SysMenu"

    ; Set window ownership to create a modal dialog experience.
    if (forceParent || ownerHwnd != 0) {
        if (ownerHwnd == 0)
            ownerHwnd := WinExist("A") ; Get the active window if no owner is specified.

        if (ownerHwnd && DllCall("IsWindow", "Ptr", ownerHwnd)) {
            try guiOptions .= " +Owner" ownerHwnd
        }
    }

    dlg := Gui(guiOptions, title)
    dlg.BackColor := "0x" background
    dlg.SetFont("s10 c" fontColor, "Segoe UI")
    
    ; Map to track which controls have hover effects
    hoverControls := Map()
    lastHovered := 0
    
    ; Map to track Focus effects for Inputs/Detail
    focusMap := Map()
    ;#endregion

    ;#region 3. Build Layout
    ; This section dynamically builds the dialog's content from top to bottom.

    ; Button dimensions
    btn_w := info.HasProp("btn_w") && info.btn_w ? info.btn_w : 80
    btn_h := info.HasProp("btn_h") && info.btn_h ? info.btn_h : 30
    btn_margin := info.HasProp("btn_margin") && info.btn_margin ? info.btn_margin : 10

    dialogReturn := "" ; This will store the clicked button's text upon closing.
    inputReturn := ""

    currentY := 0
    dlg.SetFont("s10 c" titleColor, "Segoe UI")

    ; Title Bar (a styled Text control)
    titlebar := dlg.AddText("x0 y0 w" width " h" titlebarHeight " Background" titlebarBG " Center +0x200", title)
    currentY := titlebarHeight + 15 + messageTop ; Set base Y position for content below the title bar.

    ; Custom 'x' close button in the top-right corner.
    if (exitEnabled) {
        dlg.SetFont("s13 c" exitColor, "Segoe UI")
        exitBtn := dlg.AddText("x" width - exitWidth " y0 w" exitWidth " h" titlebarHeight " Background" exitBG " Center +0x200", "x")
        exitBtn.OnEvent("click", ButtonClick.Bind("")) ; Clicking it returns an empty string.
        hoverControls[exitBtn.Hwnd] := {type: "btn", def: exitBG, hov: exitBGHover} ; Add to hover map (just for cursor mainly, exit usually has hardcoded hover logic in some frameworks, but here we can rely on cursor)
        dlg.SetFont("s10", "Segoe UI") ; Reset font for other controls.
    }

    ; --- Icon and Message Area ---
    iconWidth := icon ? 40 : 0
    iconMargin := icon ? 10 : 0
    contentX := 15 ; Left padding

    ; Add the icon if one is specified.
    if icon {
        dlg.SetFont("s20", "Segoe UI Symbol") ; Use a font that supports emoji/symbols.
        dlg.AddText("x" contentX " y" currentY " w" iconWidth " h40 Center c" iconColor " +0x200", icon)
        contentX += iconWidth + iconMargin ; Indent the message text to make room for the icon.
        dlg.SetFont("s10", "Segoe UI") ; Reset font.
    }

    dlg.SetFont("c" messageColor)
    ; Calculate message width based on alignment and presence of an icon.
    messageW := align = "Center" && icon ? (width - contentX - 65) : (width - contentX - 15)
    messageX := align = "Center" && !icon ? 0 : contentX
    messageW := align = "Center" && !icon ? width : messageW
    currentY += messageTop

    ; Add the main message text. It will auto-size vertically.
    msgCtrl := dlg.AddText("x" messageX " y" currentY " w" messageW " " align, message)
    msgCtrl.GetPos(,,, &msgH) ; Get its rendered height.

    ; Update currentY to be below the taller of the icon or the message text.
    contentHeight := Max(msgH, (icon ? 40 : 0))
    currentY += contentHeight + 15

    ; --- Input Area (New Mode) ---
    if hasInput {
        inputW := width - 30
        inputX := 15
        inputH := 36 ; Fixed visual height (increased slightly for breathing room)
        textH := 22  ; Actual text edit height (fits s10 font)
        padY := (inputH - textH) // 2

        inputOptions := " -VScroll Background" backgroundAlt " c" detailColor " -E0x200"
        if maskInput
            inputOptions .= " Password"

        ; 1. Add Decorative Border (Bottom Layer)
        inputBorder := dlg.AddText("x" (inputX - 1) " y" (currentY - 1) " w" (inputW + 2) " h" (inputH+2) " Background" detailBorder " -E0x200")

        ; 2. Add Background Fill (Middle Layer) - Prevents border color from showing through top/bottom gaps
        dlg.AddText("x" inputX " y" currentY " w" inputW " h" inputH " Background" backgroundAlt " -E0x200")

        ; 3. Add The Input Control (Top Layer) - Vertically centered
        inputCtrl := dlg.AddEdit("x" inputX " y" (currentY + padY) " w" inputW " h" textH " " inputOptions)
        inputCtrl.Value := inputDefault
        
        ; Placeholder Text (Cue Banner)
        if (placeholder != "") {
             SendMessage(0x1501, 1, StrPtr(placeholder), inputCtrl.Hwnd) ; EM_SETCUEBANNER
        }
        
        ; Register for Focus Highlight
        focusMap[inputCtrl.Hwnd] := inputBorder

        currentY += inputH + 15
    }

    ; --- Progress Bars (New Mode) ---
    if hasProgress {
        progW := width - 30
        progX := 15
        
        ; Main Status Text
        if (prog1Text != "") {
            progTextCtrl1 := dlg.AddText("x" progX " y" currentY " w" progW " c" messageColor, prog1Text)
            currentY += 20
        }

        ; Main Sub Status Text
        if (prog1SubText != "") {
            dlg.SetFont("s9 c999999")
            progSubTextCtrl1 := dlg.AddText("x" progX " y" currentY " w" progW, prog1SubText)
            dlg.SetFont("s10 c" fontColor)
            currentY += 20
        }
        
        ; Main Progress Bar
        ; Note: cColor controls bar color, BackgroundColor controls empty space.
        progCtrl1 := dlg.AddProgress("x" progX " y" currentY " w" progW " h10 c" prog1Color " Background" backgroundAlt, prog1Val)
        currentY += 20
        
        ; Secondary Progress Bar
        if (prog2Val != -1) {
            currentY += 10 ; Gap between bars
            
            ; Secondary Status Text
            if (prog2Text != "") {
                progTextCtrl2 := dlg.AddText("x" progX " y" currentY " w" progW " c" messageColor, prog2Text)
                currentY += 20
            }

            ; Secondary Sub Status Text
            if (prog2SubText != "") {
                dlg.SetFont("s9 c999999")
                progSubTextCtrl2 := dlg.AddText("x" progX " y" currentY " w" progW, prog2SubText)
                dlg.SetFont("s10 c" fontColor)
                currentY += 20
            }
            
            progCtrl2 := dlg.AddProgress("x" progX " y" currentY " w" progW " h8 c" prog2Color " Background" backgroundAlt, prog2Val)
            currentY += 15
        }
        currentY += 10 ; Bottom padding
    }

    ; --- Detail Text Area (if specified) ---
    if detail {
        detailW := width - 30
        detailX := 15
        
        ; Create a temporary dummy edit to get exact height calculation
        dummyEdit := dlg.AddEdit("x" detailX " y" currentY " w" detailW " r" detailRows " ReadOnly -TabStop -VScroll Background" backgroundAlt " c" detailColor " -E0x200 Hidden")
        dummyEdit.GetPos(,,, &editH)
        DllCall("DestroyWindow", "Ptr", dummyEdit.Hwnd)

        ; 1. Add Decorative Border (Bottom Layer)
        detailBorderCtrl := dlg.AddText("x" (detailX - 1) " y" (currentY - 1) " w" (detailW + 2) " h" (editH+2) " Background" detailBorder " -E0x200")

        ; 2. Add The Edit Control (Top Layer)
        editCtrl := dlg.AddEdit("x" detailX " y" currentY " w" detailW " r" detailRows " ReadOnly -TabStop -VScroll Background" backgroundAlt " c" detailColor " -E0x200")
        editCtrl.Value := detail
        
        ; Register for Focus Highlight
        focusMap[editCtrl.Hwnd] := detailBorderCtrl
        
        currentY += editH + 15
    }
    ;#endregion

    ;#region 4. Build Buttons
    ; This section lays out the buttons, centering them horizontally.

    btnY := currentY
    finalHeight := btnY + btn_h + 15 ; Calculate final dialog height based on content.

    ; If a fixed height is specified, override auto-calculation and anchor buttons to the bottom.
    if height > 0 {
        finalHeight := height
        btnY := finalHeight - btn_h - 15
    }

    ; Calculate the starting X position to center the block of buttons.
    totalButtonsWidth := (buttons.Length * btn_w) + ((buttons.Length - 1) * btn_margin)
    currentX := Floor((width - totalButtonsWidth) / 2)
    firstBtnCtrl := ""

    dlg.SetFont("c" buttonColor)
    for i, btnText in buttons {
        returnValue := StrReplace(btnText, "&") ; The return value is the text without the accelerator key marker.

        ; Border (a Text control placed behind the button for a "faux border" effect).
        btnBorder := dlg.AddText("x" (currentX - 1) " y" (btnY - 1) " w" (btn_w + 2) " h" (btn_h + 2) " +Background" detailBorder)

        ; Button (a styled, clickable Text control).
        btnCtrl := dlg.AddText("x" currentX " y" btnY " w" btn_w " h" btn_h " +Tabstop Background" backgroundAlt " Center 0x8000 +0x200", btnText)
        btnCtrl.OnEvent("Click", ButtonClick.Bind(returnValue))
        
        ; Add to hover map
        hoverControls[btnCtrl.Hwnd] := {type: "btn", def: backgroundAlt, hov: buttonHoverColor}

        ; The first button is the default action for the "Enter" key.
        if (i = 1) {
            firstBtnCtrl := btnCtrl ; Save first button to set focus later.
            defaultReturnValue := returnValue
        }

        currentX += btn_w + btn_margin
    }
    ;#endregion

    ;#region 5. Event Functions
    ; These are the callback functions that handle GUI events and hotkeys.

    ; This message handler allows the GUI to be dragged by its custom title bar.
    HandleNCHitTest(wParam, lParam, msg, hwnd) {
        try{
            if (hwnd != dlg.Hwnd) {
                return ; Message is not for this GUI.
            }
            lParamY := lParam >> 16
            dlg.GetPos(,&winY)
            ; Check if the cursor is within the title bar's vertical area.
            if (lParamY >= winY && lParamY < winY + (titlebarHeight - 1)) {
                PostMessage(0x00A1, 2) ; WM_NCLBUTTONDOWN, HTCAPTION (tells Windows to treat it as a click on the caption bar).
            }
        }
    }
    
    ; Handles MouseMove for Hover Effects and Cursors
    HandleMouseMove(wParam, lParam, msg, hwnd) {
        MouseGetPos(,, &id, &controlHwnd, 2)
        
        if (hoverControls.Has(controlHwnd)) {
            ; Set Hand Cursor
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr")) ; IDC_HAND = 32649
            
            ; Handle Color Change
            if (lastHovered != controlHwnd) {
                ; Restore previous if needed
                if (lastHovered && hoverControls.Has(lastHovered) && hoverControls[lastHovered].type != "exit") {
                     GuiCtrlFromHwnd(lastHovered).Opt("Background" hoverControls[lastHovered].def)
                     GuiCtrlFromHwnd(lastHovered).Redraw()
                }
                
                ; Highlight current
                if (hoverControls[controlHwnd].type != "exit") {
                    GuiCtrlFromHwnd(controlHwnd).Opt("Background" hoverControls[controlHwnd].hov)
                    GuiCtrlFromHwnd(controlHwnd).Redraw()
                }
                
                lastHovered := controlHwnd
            }
        } else {
            ; Reset if we moved off a button
            if (lastHovered) {
                if (hoverControls.Has(lastHovered) && hoverControls[lastHovered].type != "exit") {
                    GuiCtrlFromHwnd(lastHovered).Opt("Background" hoverControls[lastHovered].def)
                    GuiCtrlFromHwnd(lastHovered).Redraw()
                }
                lastHovered := 0
            }
        }
    }

    ; Handle Focus Events (Highlight Border)
    OnCtrlFocus(ctrl, *) {
        if focusMap.Has(ctrl.Hwnd) {
            focusMap[ctrl.Hwnd].Opt("Background" focusBorderColor)
            focusMap[ctrl.Hwnd].Redraw()
        }
    }

    OnCtrlLoseFocus(ctrl, *) {
        if focusMap.Has(ctrl.Hwnd) {
            focusMap[ctrl.Hwnd].Opt("Background" detailBorder)
            focusMap[ctrl.Hwnd].Redraw()
        }
    }

    ; Function to update progress bars/text from the return object
    UpdateProgress(percent := "", text := "", subText := "", bar := 1) {
        if (bar == 1) {
            if (percent != "") && IsSet(progCtrl1)
                progCtrl1.Value := percent
            if (text != "") && IsSet(progTextCtrl1)
                progTextCtrl1.Text := text
            if (subText != "") && IsSet(progSubTextCtrl1)
                progSubTextCtrl1.Text := subText
        } else if (bar == 2) {
            if (percent != "") && IsSet(progCtrl2)
                progCtrl2.Value := percent
            if (text != "") && IsSet(progTextCtrl2)
                progTextCtrl2.Text := text
            if (subText != "") && IsSet(progSubTextCtrl2)
                progSubTextCtrl2.Text := subText
        }
    }

    ; Central cleanup function to destroy hotkeys, message handlers, and the GUI.
    CleanupAndDestroy(*) {
        try{
            Hotkey("Enter", "Off")
        }
        try{
            if (exitEnabled == true)
                Hotkey("Escape", "Off")
        }
        try{
            if (noAltF4 == true)
                Hotkey("!F4", "Off")
        }
        ; Re-enable parent window if it was disabled (Modal behavior cleanup)
        if (ownerHwnd && modal && DllCall("IsWindow", "Ptr", ownerHwnd)) {
            try WinSetEnabled(true, ownerHwnd)
            try WinActivate(ownerHwnd)
        }
        OnMessage(0x84, HandleNCHitTest, 0) ; Turn off message handler.
        OnMessage(0x0200, HandleMouseMove, 0) ; Turn off hover handler
        dlg.Destroy()
    }

    ; Handles clicks on any button.
    ButtonClick(returnValue, *) {
        dialogReturn := returnValue
        
        ; Capture Input Value
        if (IsSet(inputCtrl) && inputCtrl) {
            inputReturn := inputCtrl.Value
        }
        
        CleanupAndDestroy()
    }

    ; Handles the Enter key, triggering the first button's action.
    DefaultButtonAction(key) {
        try ButtonClick(defaultReturnValue)
    }

    ; Handles the Escape key, simulating a click on the 'x' button.
    ExitButtonAction(key) {
        ButtonClick("")
    }

    ; Register the message handler and GUI events.
    OnMessage(0x84, HandleNCHitTest) ; WM_NCHITTEST for draggable title bar.
    OnMessage(0x0200, HandleMouseMove) ; WM_MOUSEMOVE for hover effects
    dlg.OnEvent("Close", CleanupAndDestroy) ; Handles closing via system menu, Alt+F4 (if enabled), etc.
    
    ; Bind Focus Events if we have inputs
    if (focusMap.Count > 0) {
        for ctrlHwnd, border in focusMap {
            ctrl := GuiCtrlFromHwnd(ctrlHwnd)
            ctrl.OnEvent("Focus", OnCtrlFocus)
            ctrl.OnEvent("LoseFocus", OnCtrlLoseFocus)
        }
    }
    ;#endregion

    ;#region 6. Show & Configure Focused Control
    ; Final steps before the dialog is displayed.

    ; Disable parent window if modal
    if (ownerHwnd && modal && DllCall("IsWindow", "Ptr", ownerHwnd)) {
        WinSetEnabled(false, ownerHwnd)
    }

    dlg.Show("w" width " h" finalHeight " Center")
    ; If a detail box exists, its Z-order needs to be managed to appear on top of its border.
    ; Focusing it and then focusing the button seems to be a reliable way to do this.
    if (IsSet(editCtrl) && IsObject(editCtrl)) {
        ControlFocus(editCtrl.Hwnd, dlg.Hwnd)
        ControlFocus(firstBtnCtrl.Hwnd, dlg.Hwnd)
    }
    
    ; If input exists, focus it by default (standard behavior for input boxes)
    if (IsSet(inputCtrl) && IsObject(inputCtrl)) {
        ControlFocus(inputCtrl.Hwnd, dlg.Hwnd)
    } else if (IsSet(firstBtnCtrl) && IsObject(firstBtnCtrl)) {
        ControlFocus(firstBtnCtrl.Hwnd, dlg.Hwnd)
    }
    ;#endregion

    ;#region 7. Catch Keys & Final Borders
    ; Set up context-sensitive hotkeys and apply window border radius.

    HotIfWinActive "ahk_id " dlg.Hwnd
    Hotkey("Enter", DefaultButtonAction)
    if (exitEnabled == true) {
        HotIfWinActive "ahk_id " dlg.Hwnd
        Hotkey("Escape", ExitButtonAction)
    }

    if (noAltF4 == true) {
        HotIfWinActive "ahk_id " dlg.Hwnd
        Hotkey("!F4", (*)=>{}) ; Intercept and do nothing.
    }

    ; Apply border radius. Uses the modern DWM attribute on Win11+ unless forced to use legacy.
    static ver := DllCall("GetVersion", "UInt")
    build := (ver >> 16) & 0xFFFF
    if (build >= 22000 && forceLegacyRadius == false) {
        DllCall("Dwmapi.dll\DwmSetWindowAttribute", "Ptr", dlg.Hwnd, "UInt", 33, "Ptr*", win11Radius, "UInt", 4)
    } else {
        if (legacyRadius > 0) {
            hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", width, "Int", finalHeight, "Int", legacyRadius, "Int", legacyRadius, "Ptr")
            DllCall("SetWindowRgn", "Ptr", dlg.Hwnd, "Ptr", hRgn, "Int", true)
        }
    }
    ;#endregion

    ;#region 8. Wait for Close & Return
    ; Pauses script execution if required and returns the result.

    if (waitForResponse == true)
        WinWaitClose(dlg.Hwnd)

    return {
        value: dialogReturn,
        input: inputReturn,
        gui: dlg,
        Update: UpdateProgress
    }
    ;#endregion

}