
#Requires AutoHotkey v2.0
#Include customDialog.ahk
#Warn All, Off

;checkUI()

; ==============================================================================
; THEME SETTINGS (Global so Main can access colors)
; ==============================================================================
global Theme := {}
Theme.Bg          := "181818"        ; Deep background
Theme.Panel       := "1E1E1E"        ; Slightly lighter (Dropdown Lists, Edit boxes)
Theme.Text        := "DDDDDD"        ; Main text
Theme.Accent      := "00FF99"        ; Bright Green Highlight
Theme.AltAccent   := "EE2211"        ; Red/Orange Highlight
Theme.Button      := "1e1e1e"        ; Button/Dropdown Background
Theme.Border      := "646464"        ; Dark borders
Theme.BtnHover    := "232323"        ; Hover color (Lighter)
Theme.StatusBg    := "0a0a0a"        ; Status bar
Theme.TabInactive := Theme.Button    ; Inactive Tab color
Theme.DarkPanel   := "121212"        ; Inactive Tab color
Theme.DropdownHover := "2E7D32"      ; A nice Dark Green
Theme.DropdownSelected := "353535"   ; Background for the item currently active


global fontOptions := ["Arial", "Calibri", "Comic Sans MS", "Consolas", "Corbel", "Courier New", "Franklin Gothic Medium", "Impact", "Lucida Sans", "NSimSun", "Segoe UI", "Tahoma", "Times New Roman", "Trebuchet MS", "Verdana"]
; ==============================================================================
; WINDOW & SYSTEM UTILS
; ==============================================================================

global AppMonitorStarted := false

/**
* Applies Dark Mode window attributes and sets up global message handlers.
* @param {Gui} guiObj The main GUI object
*/
InitWindowUtils(guiObj) {
    global AppMonitorStarted

    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 19, "Int*", 1, "Int", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 20, "Int*", 1, "Int", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 35, "Int*", 0x121212, "Int", 4)
    }
    
    ; Global Event Handlers for Custom Controls
    OnMessage(0x0201, WM_LBUTTONDOWN)   ; Click (Close dropdowns)
    OnMessage(0x00A1, WM_NCLBUTTONDOWN) ; Title Bar Click (Close dropdowns)
    OnMessage(0x0020, WM_SETCURSOR)     ; Hand Cursor
    OnMessage(0x0200, WM_MOUSEMOVE)     ; Hover Effects
    OnMessage(0x00A0, WM_NCMOUSEMOVE)   ; Hover Off (TitleBar)
    OnMessage(0x0100, WM_KEYDOWN)       ; Keyboard Navigation
    OnMessage(0x020A, WM_MOUSEWHEEL)    ; Mouse Wheel (For custom dropdown scroll)

    ; Close window with Ctrl+W (Protected)
    HotIfWinActive("ahk_id " guiObj.Hwnd)
    Hotkey("^w", (*) => TryCloseWindow(guiObj))
    HotIfWinActive()
    
    ; Start Global Monitor to exit app if no windows are visible
    ; (Since OnMessage makes script persistent)
    if (!AppMonitorStarted) {
        SetTimer(CheckAppWindows, 1000)
        AppMonitorStarted := true
    }
}

/**
* Attempts to close the window, checking for active jobs first.
* Requires `guiObj.FFJob` to be set to the active FFmpegJob instance.
*/
TryCloseWindow(guiObj) {
    if (guiObj.HasProp("FFJob") && guiObj.FFJob && guiObj.FFJob.IsRunning()) {
        res := customDialog({
            title: "Task Running",
            message: "A task is currently active.",
            detail: "Closing this window will stop the process.",
            buttons: ["&Stop && Close", "&Cancel"],
            icon: "⚠️",
            width: 450,
            modal: true
        }, errorPreset)
        
        if (res.value != "Stop & Close")
            return
            
        guiObj.FFJob.Stop()
    }
    
    ; Custom callback support if tools need extra cleanup
    if (guiObj.HasProp("OnCloseCheck") && guiObj.OnCloseCheck) {
        if (!guiObj.OnCloseCheck.Call())
            return
    }

    guiObj.Destroy()
}

CheckAppWindows() {
    ; Get list of visible windows owned by this script
    ; DetectHiddenWindows is Off by default, so this gets only visible ones
    try {
        id := WinGetList("ahk_pid " ProcessExist())
        if (id.Length == 0)
            ExitApp()
    } catch {
        ; Safety catch
    }
}

SetDarkControl(ctrl) {
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        try DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    }
}

AddFlatEdit(parentGui, opt, txt := "") {
    ctl := parentGui.Add("Edit", opt " -E0x200 +Border Background" Theme.Panel " c" Theme.Text, txt)
    return ctl
}

FormatSeconds(s) {
    time := Integer(s)
    m := Floor(time / 60)
    s := Mod(time, 60)
    return Format("{:02}m {:02}s", m, s)
}

RunColorPicker(targetEditCtrl, parentHwnd) {
    static CustColors := Buffer(16 * 4, 0)
    CC := Buffer((A_PtrSize = 8) ? 72 : 36, 0) 
    NumPut("UInt", CC.Size, CC, 0)
    NumPut("Ptr", parentHwnd, CC, A_PtrSize)
    offRGB := 3 * A_PtrSize
    offCustColors := (A_PtrSize = 8) ? 32 : 16
    offFlags := offCustColors + A_PtrSize
    NumPut("Ptr", CustColors.Ptr, CC, offCustColors)
    NumPut("UInt", 0x103, CC, offFlags)
    
    currentHex := targetEditCtrl.Value
    if RegExMatch(currentHex, "^[0-9A-Fa-f]{6}$") {
        R := Integer("0x" SubStr(currentHex, 1, 2))
        G := Integer("0x" SubStr(currentHex, 3, 2))
        B := Integer("0x" SubStr(currentHex, 5, 2))
        NumPut("UInt", (B << 16) | (G << 8) | R, CC, offRGB)
    }
    
    if DllCall("comdlg32\ChooseColor", "Ptr", CC.Ptr) {
        color := NumGet(CC, offRGB, "UInt")
        R := color & 0xFF
        G := (color >> 8) & 0xFF
        B := (color >> 16) & 0xFF
        targetEditCtrl.Value := Format("{:02X}{:02X}{:02X}", R, G, B)
    }
}

; GetFontFile(fontName) {
;     if InStr(fontName, "\")
;         return fontName
    
;     ; Basic mapping, extend as needed
;     switch fontName {
;         case "Arial": return "C:/Windows/Fonts/arial.ttf"
;         case "Calibri": return "C:/Windows/Fonts/calibri.ttf"
;         case "Courier New": return "C:/Windows/Fonts/cour.ttf"
;         case "Impact": return "C:/Windows/Fonts/impact.ttf"
;         case "Segoe UI": return "C:/Windows/Fonts/segoeui.ttf"
;         case "Tahoma": return "C:/Windows/Fonts/tahoma.ttf"
;         case "Times New Roman": return "C:/Windows/Fonts/times.ttf"
;         case "Verdana": return "C:/Windows/Fonts/verdana.ttf"
;         default: return "C:/Windows/Fonts/arial.ttf"
;     }
; }

GetFontFile(fontName) {
    if InStr(fontName, "\")
        return fontName

    ; Standard Windows font registry locations
    regPaths := [
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    ]
    
    ; 1. First Pass: Look for an EXACT match (prevents "Arial" -> "Arial Rounded")
    for regPath in regPaths {
        Loop Reg, regPath, "V" {
            ; Remove suffixes like (TrueType), (VGA), (8514), etc.
            cleanName := RegExReplace(A_LoopRegName, " \((TrueType|OpenType|VGA|850|8514|Set #\d)\)$", "")
            
            if (cleanName = fontName)
                return BuildFullPath(RegRead())
        }
    }

    ; 2. Second Pass: Fuzzy match for complex names (e.g., "NSimSun & SimSun")
    for regPath in regPaths {
        Loop Reg, regPath, "V" {
            if InStr(A_LoopRegName, fontName)
                return BuildFullPath(RegRead())
        }
    }

    ; Fallback to Arial if all else fails
    return A_WinDir "\Fonts\arial.ttf"
}

/**
 * Helper to ensure we return a full path.
 * Windows stores system fonts as filenames, but user fonts as full paths.
 */
BuildFullPath(path) {
    if InStr(path, "\") ; Already a full path (User font)
        return path
    
    fullPath := A_WinDir "\Fonts\" path
    if FileExist(fullPath)
        return fullPath
        
    return path ; Return original if we can't verify
}

; ==============================================================================
; CUSTOM UI CLASSES (TabManager, SexyButton, DarkDropdown, ScrollableList)
; ==============================================================================

class TabManager {
    __New(guiObj, themeObj, onSwitchCallback := "") {
        this.Gui := guiObj
        this.Theme := themeObj
        this.Buttons := Map()
        this.Controls := Map()
        this.Current := ""
        this.OnSwitch := onSwitchCallback
    }

    Add(label, x, y, w, h, tabName) {
        btn := SexyButton(this.Gui, x, y, w, h, label, (*) => this.Switch(tabName))
        this.Buttons[tabName] := btn
        this.Controls[tabName] := []
        btn.isTab := true
        return btn
    }

    Register(tabName, ctrl) {
        if !this.Controls.Has(tabName)
            this.Controls[tabName] := []
        this.Controls[tabName].Push(ctrl)
        return ctrl
    }

    Switch(newTab) {
        this.Current := newTab
        
        ; Update Buttons
        for name, btn in this.Buttons
            btn.SetToggleState(name == newTab)
            
        ; Update Controls
        for name, ctrlList in this.Controls {
            show := (name == newTab)
            for ctrl in ctrlList {
                try {
                    if HasProp(ctrl, "SetVisible")
                        ctrl.SetVisible(show)
                    else
                        ctrl.Visible := show
                }
            }
        }
        
        if (this.OnSwitch)
            this.OnSwitch.Call(newTab)
    }
}

global LastHoveredBtn := ""
global ActiveDropdown := "" 

class SexyButton {
    static HwndMap := Map(), Instances := []
    __New(parentGui, x, y, w, h, text, callback, isDefault := false) {
        this.Controls := [], this.Borders := [], this.IsHovered := false, this.IsActiveTab := false, this.isTab := false
        borderColor := isDefault ? Theme.Accent : Theme.Border
        this.DefBorderColor := borderColor
        this.FocusProxy := parentGui.Add("Button", Format("x{} y{} w{} h{} Hidden", x, y, w, h), "")
        this.FocusProxy.OnEvent("Focus", (*) => this.SetFocus(true))
        this.FocusProxy.OnEvent("LoseFocus", (*) => this.SetFocus(false))
        
        b1 := parentGui.Add("Text", Format("x{} y{} w{} h1 Background{}", x, y, w, borderColor), "")
        b2 := parentGui.Add("Text", Format("x{} y{} w{} h1 Background{}", x, y+h-1, w, borderColor), "")
        b3 := parentGui.Add("Text", Format("x{} y{} w1 h{} Background{}", x, y, h, borderColor), "")
        b4 := parentGui.Add("Text", Format("x{} y{} w1 h{} Background{}", x+w-1, y, h, borderColor), "")
        
        for b in [b1, b2, b3, b4] {
            b.OnEvent("Click", (*) => this.OnClick())
            this.Controls.Push(b), this.Borders.Push(b), SexyButton.HwndMap[b.Hwnd] := this
        }
        
        this.Btn := parentGui.Add("Text", Format("x{} y{} w{} h{} Background{} c{} +0x200 Center", x+1, y+1, w-2, h-2, Theme.Button, Theme.Text), text)
        this.Btn.SetFont(isDefault ? "bold s11" : "s10")
        this.Btn.OnEvent("Click", (*) => this.OnClick())
        this.Controls.Push(this.Btn), SexyButton.HwndMap[this.Btn.Hwnd] := this
        this.Callback := callback, SexyButton.Instances.Push(this)
    }
    
    RegisterToTab(manager, tabName) {
        manager.Register(tabName, this)
        return this
    }

    OnClick() {
        this.FocusProxy.Focus()
        if (this.Callback)
            this.Callback.Call()
    }

    SetToggleState(active) {
        this.IsActiveTab := active
        if (active) {
            for b in this.Borders 
                b.Opt("Background" Theme.TabInactive), b.Redraw()
            this.Borders[2].Opt("Background" Theme.Accent), this.Borders[2].Redraw()
            this.Btn.Opt("Background" Theme.Panel), this.Btn.Opt("c" Theme.Accent)
        } else {
            for b in this.Borders {
                b.Opt("Background" Theme.DarkPanel), b.Redraw()
            }
            this.Btn.Opt("Background" Theme.DarkPanel), this.Btn.Opt("c" Theme.Text)
        }
        this.Btn.Redraw()
    }
    Beautify(colour:="default") {
        for b in this.Borders 
                b.Opt("Background" Theme.Border)
        colour := (colour=="default" ? Theme.Accent : colour)
        this.Borders[1].Opt("Background" colour), this.Borders[1].Redraw()
        this.Borders[2].Opt("Background" colour), this.Borders[2].Redraw()
        this.Btn.Opt("Background" Theme.Panel), this.Btn.Opt("c" colour)
            
        this.Btn.Redraw()
    }
    setBorders(borders) {       
        this.Borders[1].Opt("Background" borders[1]), this.Borders[1].Redraw()
        this.Borders[2].Opt("Background" borders[2]), this.Borders[2].Redraw()
        this.Borders[3].Opt("Background" borders[3]), this.Borders[3].Redraw()
        this.Borders[4].Opt("Background" borders[4]), this.Borders[4].Redraw()
        this.Btn.Redraw()
    }
    SetTextColour(colour:="default") {
        colour := (colour=="default" ? Theme.Accent : colour)
        this.Btn.Opt("c" colour)
        this.Btn.Redraw()
    }

    SetText(txt) {
        this.Btn.Text := txt
    }
    SetFocus(focused) {
        ; Intentionally left empty per user preference
    }

    SetHover(active) {
        this.IsHovered := active
        if (this.IsActiveTab)
            return 
        color := active ? Theme.BtnHover : this.isTab ? Theme.DarkPanel : Theme.Button
        try this.Btn.Opt("Background" color)
        try this.Btn.Redraw()
    }

    Visible {
        set {
            for ctrl in this.Controls
                ctrl.Visible := value
            this.FocusProxy.Visible := false
        }
        get => this.Btn.Visible
    }
    SetVisible(val) => this.Visible := val

    Enabled {
        set {
            this.Btn.Opt("Redraw"), this.Btn.Opt(value ? "c" Theme.Text : "c555555")
            this.Btn.Enabled := value
        }
        get => this.Btn.Enabled
    }
}

class DropdownItem {
    static HwndMap := Map()
    
    __New(guiObj, x, y, w, h, text, index, selectCallback) {
        this.Index := index
        this.IsSelected := false
        this.IsHovered := false
        this.Callback := selectCallback
        this.Gui := guiObj
        
        ; Create a Text control that looks like a list item
        ; +0x200 = SS_CENTERIMAGE (Vertically center text)
        this.Ctrl := guiObj.Add("Text", Format("x{} y{} w{} h{} +0x200 Background{} c{}", x, y, w, h, Theme.Panel, Theme.Text), "  " text)
        this.Ctrl.SetFont("s10", "Segoe UI")
        this.Ctrl.OnEvent("Click", (*) => this.OnClick())
        
        DropdownItem.HwndMap[this.Ctrl.Hwnd] := this
    }
    
    OnClick() {
        if this.Callback
            this.Callback.Call(this.Index)
    }
    
    SetHover(state) {
        if (this.IsSelected)
            return ; Don't remove selection color on hover out
            
        this.IsHovered := state
        bg := state ? Theme.DropdownSelected : Theme.Panel
        ;bg := state ? Theme.DropdownHover : Theme.Panel
        try {
            this.Ctrl.Opt("Background" bg)
            this.Ctrl.Redraw()
        }
    }
    
    SetSelected(state) {
        this.IsSelected := state
        bg := state ? Theme.DropdownSelected : Theme.Panel
        txt := state ? Theme.Accent : Theme.Text
        try {
            this.Ctrl.Opt("Background" bg)
            this.Ctrl.Opt("c" txt)
            this.Ctrl.Redraw()
        }
    }
    
    Move(y) {
        try this.Ctrl.Move(,, , y)
    }
}


class DarkDropdown {
    static HwndMap := Map(), Instances := []
    __New(parentGui, x, y, w, items, varName, changeCallback := "", defaultIndex := 1) {
        this.Parent := parentGui, this.Items := items, this.Callback := changeCallback, this.VarName := varName
        this.Width := w, this.Controls := [], this.Borders := [], this.IsOpen := false
        this.Index := defaultIndex, this.Value := items.Has(defaultIndex) ? items[defaultIndex] : "", this.H := 26 
        this.ListItems := []
        this.ScrollY := 0
        this.ContentHeight := 0
        this.MaxHeight := 300
        this.CheckTimer := ObjBindMethod(this, "CheckFocusState")
        
        this.HiddenInput := parentGui.Add("Edit", "Hidden v" varName, this.Value)
        
        this.FocusProxy := parentGui.Add("Button", Format("x{} y{} w{} h{} Hidden", x, y, w, this.H), "")
        this.FocusProxy.OnEvent("Focus", (*) => this.SetFocus(true))
        this.FocusProxy.OnEvent("LoseFocus", (*) => this.SetFocus(false))
        
        this.Bg := parentGui.Add("Text", Format("x{} y{} w{} h{} Background{}", x, y, w, this.H, Theme.Button), "")
        this.Bg.OnEvent("Click", (*) => this.OnClick())
        this.Controls.Push(this.Bg), DarkDropdown.HwndMap[this.Bg.Hwnd] := this
        
        b1 := parentGui.Add("Text", Format("x{} y{} w{} h1 Background{}", x, y, w, Theme.Border), "")
        b2 := parentGui.Add("Text", Format("x{} y{} w{} h1 Background{}", x, y+this.H-1, w, Theme.Border), "")
        b3 := parentGui.Add("Text", Format("x{} y{} w1 h{} Background{}", x, y, this.H, Theme.Border), "")
        b4 := parentGui.Add("Text", Format("x{} y{} w1 h{} Background{}", x+w-1, y, this.H, Theme.Border), "")
        
        for b in [b1, b2, b3, b4] {
            b.OnEvent("Click", (*) => this.OnClick())
            this.Borders.Push(b), this.Controls.Push(b), DarkDropdown.HwndMap[b.Hwnd] := this
        }
        
        arrow := parentGui.Add("Text", Format("x{} y{} w20 h{} Background{} c{} +0x200 Center", x+w-22, y+1, this.H-2, Theme.Button, Theme.Accent), "▼")
        arrow.SetFont("s8"), arrow.OnEvent("Click", (*) => this.OnClick())
        this.Controls.Push(arrow), DarkDropdown.HwndMap[arrow.Hwnd] := this
        
        this.Label := parentGui.Add("Text", Format("x{} y{} w{} h{} Background{} c{} +0x200", x+5, y+1, w-28, this.H-2, Theme.Button, Theme.Text), this.Value)
        this.Label.SetFont("s9"), this.Label.OnEvent("Click", (*) => this.OnClick())
        this.Controls.Push(this.Label), DarkDropdown.HwndMap[this.Label.Hwnd] := this
        
        DarkDropdown.Instances.Push(this)
    }
    
    RegisterToTab(manager, tabName) {
        manager.Register(tabName, this)
        return this
    }

    OnClick() {
        this.FocusProxy.Focus()
        this.Toggle()
    }

    SetFocus(focused) {
        color := focused ? Theme.Accent : Theme.Border
        for b in this.Borders
            b.Opt("Background" color)
        ; CheckTabAway removed here, we use a timer in Toggle now
    }

    CheckFocusState() {
        if (!this.IsOpen) {
            SetTimer(this.CheckTimer, 0)
            return
        }
        ; Close if neither parent nor popup is active
        ; We check IsWindow to ensure controls still exist
        try {
            if (!WinActive(this.Parent.Hwnd) && !WinActive(this.Popup.Hwnd)) {
                this.ClosePopup()
            }
        } catch {
            this.ClosePopup()
        }
    }

    Toggle() {
        global ActiveDropdown
        if (this.IsOpen) {
            this.ClosePopup()
            return
        }
        if (ActiveDropdown && ActiveDropdown != this)
            try ActiveDropdown.ClosePopup()
        ActiveDropdown := this
        
        this.Bg.GetPos(&lx, &ly, &lw, &lh)
        POINT := Buffer(8, 0)
        NumPut("int", lx, POINT, 0), NumPut("int", ly + lh, POINT, 4)
        DllCall("User32.dll\ClientToScreen", "Ptr", this.Parent.Hwnd, "Ptr", POINT)
        screenX := NumGet(POINT, 0, "int"), screenY := NumGet(POINT, 4, "int")
        
        this.Popup := Gui("-Caption +ToolWindow +AlwaysOnTop +Owner" this.Parent.Hwnd)
        this.Popup.BackColor := Theme.Panel
        this.Popup.MarginX := 0, this.Popup.MarginY := 0
        
        ; Ensure DWM Dark Mode on the popup window frame (scrollbars)
        InitWindowUtils(this.Popup)
        SetDarkControl(this.Popup) 
        
        itemH := 26
        this.ContentHeight := this.Items.Length * itemH
        this.MaxHeight := 300
        
        finalH := Min(this.ContentHeight, this.MaxHeight) + 2 ; +2 for borders
        
        ; Enable scrolling if content exceeds max height
        if (this.ContentHeight > this.MaxHeight) {
            this.Popup.Opt("+0x200000") ; WS_VSCROLL
            OnMessage(0x115, WM_VSCROLL) ; Handle scroll bar interactions
        }

        this.ListItems := []
        this.ScrollY := 0
        
        Loop this.Items.Length {
            i := A_Index
            itemText := this.Items[i]
            
            ; Create Custom Dropdown Item
            wAdj := (this.ContentHeight > this.MaxHeight) ? (this.Width - 20) : (this.Width - 2)
            
            ddItem := DropdownItem(this.Popup, 1, ((i-1)*itemH) + 1, wAdj, itemH, itemText, i, (idx) => this.OnSelect(idx))
            
            if (i == this.Index)
                ddItem.SetSelected(true)
                
            this.ListItems.Push(ddItem)
        }
        
        ; Borders
        this.Popup.Add("Text", Format("x0 y{} w{} h1 Background{}", finalH-1, this.Width, Theme.Border), "")
        this.Popup.Add("Text", Format("x0 y0 w1 h{} Background{}", finalH, Theme.Border), "")
        
        ; Right border position depends on scrollbar presence
        rBorderX := (this.ContentHeight > this.MaxHeight) ? this.Width - 1 : this.Width - 1
        this.Popup.Add("Text", Format("x{} y0 w1 h{} Background{}", rBorderX, finalH, Theme.Border), "")

        this.Popup.Show(Format("x{} y{} w{} h{} NoActivate", screenX, screenY, this.Width, finalH))
        
        if (this.ContentHeight > this.MaxHeight)
            this.UpdateScrollbar()
            
        this.IsOpen := true
        this.EnsureVisible(this.Index)
        SetTimer(this.CheckTimer, 100) ; Start focus monitoring
    }
    
    EnsureVisible(index) {
        if (!this.IsOpen || !this.ContentHeight || this.ContentHeight <= this.MaxHeight)
            return

        itemH := 26
        itemTop := (index - 1) * itemH
        itemBottom := itemTop + itemH
        
        scrollTop := this.ScrollY
        scrollBottom := scrollTop + this.MaxHeight
        
        if (itemTop < scrollTop) {
            ; Scroll Up to align top
            this.Scroll(itemTop - scrollTop)
        } else if (itemBottom > scrollBottom) {
            ; Scroll Down to align bottom
            this.Scroll(itemBottom - scrollBottom)
        }
    }
    
    UpdateScrollbar() {
        if (!this.Popup || !this.Popup.Hwnd)
            return
            
        ; SCROLLINFO structure
        SI := Buffer(28, 0) 
        NumPut("UInt", 28, SI, 0) ; cbSize
        NumPut("UInt", 0x17, SI, 4) ; fMask = SIF_ALL (RANGE|PAGE|POS|TRACKPOS)
        NumPut("Int", 0, SI, 8) ; nMin
        NumPut("Int", this.ContentHeight - 1, SI, 12) ; nMax
        NumPut("UInt", this.MaxHeight, SI, 16) ; nPage
        NumPut("Int", this.ScrollY, SI, 20) ; nPos
        
        DllCall("SetScrollInfo", "Ptr", this.Popup.Hwnd, "Int", 1, "Ptr", SI.Ptr, "Int", 1) ; SB_VERT=1, bRedraw=1
    }

    OnSelect(index) {
        this.Index := index
        this.Value := this.Items[index]
        this.Label.Text := this.Value
        this.HiddenInput.Value := this.Value
        if (this.Callback)
            this.Callback.Call()
        this.ClosePopup()
    }

    ClosePopup() {
        global ActiveDropdown
        SetTimer(this.CheckTimer, 0) ; Stop timer
        if (this.IsOpen && this.Popup) {
            this.Popup.Destroy()
            this.Popup := ""
            this.ListItems := []
        }
        this.IsOpen := false
        if (ActiveDropdown == this)
            ActiveDropdown := ""
    }

    Cycle(direction, wrap := true) {
        newIndex := this.Index + direction
        if (wrap) {
            if (newIndex < 1)
                newIndex := this.Items.Length
            if (newIndex > this.Items.Length)
                newIndex := 1
        } else {
            newIndex := Max(1, Min(this.Items.Length, newIndex))
        }
        if (newIndex == this.Index)
            return
        
        this.Index := newIndex
        this.Value := this.Items[newIndex]
        this.Label.Text := this.Value
        this.HiddenInput.Value := this.Value
        
        if (this.IsOpen) {
            for item in this.ListItems
                item.SetSelected(item.Index == this.Index)
            this.EnsureVisible(this.Index)
        }
        
        if (this.Callback)
            this.Callback.Call()
    }
    
    SetVisible(visible) {
        for ctrl in this.Controls
            ctrl.Visible := visible
        this.FocusProxy.Visible := false 
    }
    
    Text {
        get => this.Value
        set {
            this.Value := value, this.Label.Text := value, this.HiddenInput.Value := value
            Loop this.Items.Length {
                if (this.Items[A_Index] == value) {
                    this.Index := A_Index
                    break
                }
            }
        }
    }
    
    Add(items) {
        for i in items
            this.Items.Push(i)
    }
    
    ; Called by scroll handler to move items. Amount is additive.
    Scroll(amount) {
        if (!this.IsOpen || this.ContentHeight <= this.MaxHeight)
            return
            
        maxScroll := this.ContentHeight - this.MaxHeight
        prevY := this.ScrollY
        
        this.ScrollY += amount
        
        ; Clamp
        if (this.ScrollY < 0)
            this.ScrollY := 0
        if (this.ScrollY > maxScroll)
            this.ScrollY := maxScroll
            
        if (this.ScrollY != prevY) {
            this.UpdateScrollbar() ; Sync scrollbar thumb
            
            ; Move controls
            for item in this.ListItems {
                ; Calculate visual Y based on scroll
                ; +1 Offset for Top Border
                visY := ((item.Index - 1) * 26) - this.ScrollY + 1
                item.Ctrl.Move(, visY)
            }
            ; Force repaint of the popup to cleanup moving artifacts
            DllCall("User32\InvalidateRect", "Ptr", this.Popup.Hwnd, "Ptr", 0, "Int", 1) 
            ; DllCall("User32\UpdateWindow", "Ptr", this.Popup.Hwnd)
        }
    }
}


/**
 * ScrollableList - A reusable vertical list with row recycling.
 * 
 * @param parent {Gui} The parent GUI object.
 * @param x, y, w, h {Integer} Dimensions.
 * @param rowHeight {Integer} Height of each row.
 * @param renderRowCb {Function} Callback(gui, rowIndex, itemData, isSelected, existingCtrls).
 *        Should return a Map/Object of controls created for that row.
 * @param selectCb {Function} Callback(rowIndex) when selection changes.
 */
class ScrollableList {
    static HwndMap := Map()
    static FocusMap := Map() ; Map of FocusTrap HWNDs to Instances

    __New(parent, x, y, w, h, rowHeight, renderRowCb, selectCb := "") {
        this.Parent := parent
        this.X := x, this.Y := y, this.W := w, this.H := h
        this.RowHeight := rowHeight
        this.RenderRow := renderRowCb
        this.OnSelect := selectCb
        
        this.Items := []
        this.RowsCache := [] ; Array of Maps: [ {ctrls: Map, y: int}, ... ]
        this.ScrollY := 0
        this.SelectedIndex := 0
        this.ContentH := 0
        
        ; Container GUI
        this.Gui := Gui("-Caption +Parent" parent.Hwnd)
        this.Gui.BackColor := Theme.Panel
        this.Gui.SetFont("s9 c" Theme.Text, "Segoe UI")
        SetDarkControl(this.Gui)
        
        ; Focus Trap (Hidden button to capture keyboard input)
        ;this.FocusTrap := this.Gui.Add("Button", "x0 y0 w0 h0 Hidden", "")
        this.FocusTrap := parent.Add("Button", "x0 y0 w0 h0 Hidden vCustomListFocus_" this.Gui.Hwnd, "")
        
        this.Gui.Show(Format("x{} y{} w{} h{}", x, y, w, h))
        
        ScrollableList.HwndMap[this.Gui.Hwnd] := this
        ScrollableList.FocusMap[this.FocusTrap.Hwnd] := this
    }
    
    SetItems(data) {
        this.Items := data
        this.ContentH := (this.Items.Length * this.RowHeight) + ((this.Items.Length + 1) * 5) ; 5px gap
        
        ; If list shrinks, remove excess controls
        if (this.RowsCache.Length > this.Items.Length) {
            loopStart := this.Items.Length + 1
            loopEnd := this.RowsCache.Length
            Loop (loopEnd - loopStart + 1) {
                idx := loopEnd - A_Index + 1
                row := this.RowsCache[idx]
                if (row && row.ctrls) {
                    for k, ctrl in row.ctrls {
                        try {
                            ; Clean up hand cursor map in Main if generic
                            if (HasProp(SexyButton, "HwndMap") && SexyButton.HwndMap.Has(ctrl.Hwnd))
                                SexyButton.HwndMap.Delete(ctrl.Hwnd)
                            ctrl.Visible := false
                            DllCall("DestroyWindow", "Ptr", ctrl.Hwnd)
                        }
                    }
                }
                this.RowsCache.RemoveAt(idx)
            }
        }
        
        this.Scroll(0) ; Clamp and Redraw
    }
    
    ;Select(index) {
    ;    if (index < 1 || index > this.Items.Length)
    ;        index := 0
    ;    this.SelectedIndex := index
    ;    this.Redraw()
    ;    if (this.OnSelect)
    ;        this.OnSelect.Call(index)
    ;}
    
    Select(index) {
        if (index < 1 || index > this.Items.Length)
            return
        this.SelectedIndex := index
        this.FocusTrap.Focus()
        if (this.OnSelect)
            this.OnSelect.Call(index)
        this.Refresh() ; Rebuild to update selection styles
        this.EnsureVisible(index)
    }
    
    RefreshRow(index) {
        if (index > 0 && index <= this.RowsCache.Length) {
            this.RedrawRow(index)
        }
    }
    
    Refresh() {
        this.Redraw()
    }
    
    GetRowAt(yPos) {
        ; Calculate index based on Y click relative to scroll
        ; y + ScrollY
        totalY := yPos + this.ScrollY
        gap := 5
        rowTotal := this.RowHeight + gap
        
        ; approximate
        idx := Floor((totalY - gap) / rowTotal) + 1
        if (idx >= 1 && idx <= this.Items.Length)
            return idx
        return 0
    }

    ; Internal Redraw
    Redraw() {
        gap := 5
        
        ; Manage Scrollbar visibility
        if (this.ContentH > this.H) {
            this.Gui.Opt("+0x200000") ; WS_VSCROLL
        } else {
            this.Gui.Opt("-0x200000")
            this.ScrollY := 0
        }
        this.UpdateScrollInfo()
        
        ; Render Visible Rows
        ; We actually iterate all items for simplicity in V2 unless list is huge.
        ; For < 100 items, moving controls is fine.
        
        Loop this.Items.Length {
            i := A_Index
            item := this.Items[i]
            
            yPos := (gap + ((i-1) * (this.RowHeight + gap))) - this.ScrollY
            
            ; Culling
            if (yPos + this.RowHeight < 0 || yPos > this.H) {
                ; Off screen
                if (i <= this.RowsCache.Length && this.RowsCache[i].ctrls) {
                    for k, c in this.RowsCache[i].ctrls {
                        try c.Move(,,,0) ; Hide by zero height or move offscreen?
                        try c.Move(,-200)
                    }
                }
                continue
            }
            
            this.RedrawRow(i, yPos)
        }
        
        ; Force repaint
        DllCall("RedrawWindow", "Ptr", this.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0105)
    }
    
    RedrawRow(i, yPos := "") {
        gap := 5
        if (yPos == "")
            yPos := (gap + ((i-1) * (this.RowHeight + gap))) - this.ScrollY
            
        item := this.Items[i]
        isSel := (i == this.SelectedIndex)
        
        ; Ensure Cache Entry
        while (this.RowsCache.Length < i)
            this.RowsCache.Push({ctrls: "", y: 0})
            
        existing := this.RowsCache[i].ctrls
        
        ; Width adjustment for scrollbar
        rowW := (this.ContentH > this.H) ? (this.W - 20) : (this.W - 5)
        
        ; Call User Renderer
        ; renderRowCb(gui, rowIndex, itemData, isSelected, y, w, h, existingCtrls)
        newCtrls := this.RenderRow.Call(this.Gui, i, item, isSel, yPos, rowW, this.RowHeight, existing)
        
        this.RowsCache[i].ctrls := newCtrls
        this.RowsCache[i].y := yPos
        
        ; Helper to bind clicks for selection
        if (newCtrls && !existing) {
            for k, c in newCtrls {
                c.OnEvent("Click", (*) => (this.FocusTrap.Focus(), this.Select(i)))
                ; Optional: Bind Wheel/Scroll on children if needed, but handled globally via parent logic usually
            }
        }
    }
    
    Scroll(amount) {
        maxScroll := Max(0, this.ContentH - this.H)
        this.ScrollY += amount
        this.ScrollY := Max(0, Min(this.ScrollY, maxScroll))
        this.Redraw()
    }
    
    UpdateScrollInfo() {
        SI := Buffer(28, 0)
        NumPut("UInt", 28, SI, 0)
        NumPut("UInt", 0x17, SI, 4)
        NumPut("Int", 0, SI, 8) 
        NumPut("Int", this.ContentH, SI, 12) 
        NumPut("UInt", this.H, SI, 16) 
        NumPut("Int", this.ScrollY, SI, 20)
        DllCall("SetScrollInfo", "Ptr", this.Gui.Hwnd, "Int", 1, "Ptr", SI.Ptr, "Int", 1)
    }
    
    EnsureVisible(index) {
        if (index < 1 || index > this.Items.Length)
            return
        gap := 5
        blockH := this.RowHeight + gap
        itemTop := gap + ((index-1) * blockH)
        itemBottom := itemTop + blockH
        
        if (itemTop < this.ScrollY) {
            this.Scroll(itemTop - this.ScrollY)
        } else if (itemBottom > (this.ScrollY + this.H)) {
            this.Scroll(itemBottom - (this.ScrollY + this.H))
        }
    }
    
    ; Global Handlers routed to instance
    HandleWheel(wParam) {
        delta := (wParam >> 16)
        if (delta > 32767)
            delta -= 65536
        amount := (delta > 0) ? -40 : 40 
        this.Scroll(amount)
    }
    
    HandleVScroll(wParam) {
        action := wParam & 0xFFFF
        switch action {
            case 0: this.Scroll(-40) ; LINEUP
            case 1: this.Scroll(40)  ; LINEDOWN
            case 2: this.Scroll(-this.H) ; PAGEUP
            case 3: this.Scroll(this.H)  ; PAGEDOWN
            case 5, 4: ; THUMBTRACK
                SI := Buffer(28, 0)
                NumPut("UInt", 28, SI, 0)
                NumPut("UInt", 0x17, SI, 4)
                DllCall("GetScrollInfo", "Ptr", this.Gui.Hwnd, "Int", 1, "Ptr", SI.Ptr)
                trackPos := NumGet(SI, 24, "Int")
                this.Scroll(trackPos - this.ScrollY)
        }
    }
    
    HandleKeyDown(wParam) {
        if (wParam == 36) { ; Home
            this.Select(1), this.EnsureVisible(1)
        } else if (wParam == 35) { ; End
            this.Select(this.Items.Length), this.EnsureVisible(this.Items.Length)
        } else if (wParam == 38) { ; Up
            this.Select(Max(1, this.SelectedIndex - 1)), this.EnsureVisible(this.SelectedIndex)
        } else if (wParam == 40) { ; Down
            this.Select(Min(this.Items.Length, this.SelectedIndex + 1)), this.EnsureVisible(this.SelectedIndex)
        }
    }
}







; Global Router for ScrollableList
WM_MOUSEWHEEL(wParam, lParam, msg, hwnd) {
    global ActiveDropdown
    ; 1. Dropdown Check
    if (ActiveDropdown && ActiveDropdown.IsOpen) {
        MouseGetPos(,, &hoverHwnd)
        if (hoverHwnd == ActiveDropdown.Popup.Hwnd) {
            delta := (wParam >> 16)
            if (delta > 32767)
                delta -= 65536
            ActiveDropdown.Scroll((delta > 0) ? -26 : 26)
            return 0 
        }
    }
    
    ; 2. ScrollableList Check
    ; Logic: Check if hovered window is a ScrollableList or child of one
    MouseGetPos(,,, &hCtrl, 2) ; Get HWND of control under mouse
    
    ; Walk up parent chain to find if we are inside a ScrollableList GUI
    curr := hCtrl
    Loop 3 {
        if (ScrollableList.HwndMap.Has(curr)) {
            ScrollableList.HwndMap[curr].HandleWheel(wParam)
            return 0
        }
        try curr := DllCall("GetParent", "Ptr", curr, "Ptr")
        catch
            break
        if (!curr)
            break
    }
}

WM_VSCROLL(wParam, lParam, msg, hwnd) {
    global ActiveDropdown
    if (ActiveDropdown && ActiveDropdown.IsOpen && hwnd == ActiveDropdown.Popup.Hwnd) {
        ; ... existing dropdown logic ... (copied from previous)
        action := wParam & 0xFFFF
        switch action {
            case 0: ActiveDropdown.Scroll(-26)
            case 1: ActiveDropdown.Scroll(26)
            case 2: ActiveDropdown.Scroll(-ActiveDropdown.MaxHeight)
            case 3: ActiveDropdown.Scroll(ActiveDropdown.MaxHeight)
            case 5, 4:
                SI := Buffer(28, 0), NumPut("UInt", 28, SI, 0), NumPut("UInt", 0x17, SI, 4)
                DllCall("GetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", SI.Ptr)
                ActiveDropdown.Scroll(NumGet(SI, 24, "Int") - ActiveDropdown.ScrollY)
        }
        return 0
    }
    
    if (ScrollableList.HwndMap.Has(hwnd)) {
        ScrollableList.HwndMap[hwnd].HandleVScroll(wParam)
        return 0
    }
}

WM_KEYDOWN(wParam, lParam, msg, hwnd) {
    ; Existing Dropdown/Button logic...
    try {
        focusedHwnd := ControlGetFocus("A")
    } catch {
        return
    }
    
    if (!focusedHwnd)
        return

    ; Check ScrollableLists
    ; We check if the FOCUSED control is the FocusTrap of a list
    ;parent := DllCall("GetParent", "Ptr", focusedHwnd, "Ptr")
    ;if (ScrollableList.HwndMap.Has(parent)) {
    ;    list := ScrollableList.HwndMap[parent]
    ;    if (list.FocusTrap.Hwnd == focusedHwnd) {
    ;        list.HandleKeyDown(wParam)
    ;        return 0
    ;    }
    ;}
    if (ScrollableList.FocusMap.Has(focusedHwnd)) {
        listInstance := ScrollableList.FocusMap[focusedHwnd]
        listInstance.HandleKeyDown(wParam)
        return 0
    }

    if (focusedHwnd) {
        for dd in DarkDropdown.Instances {
            try {
                if (dd.FocusProxy.Hwnd == focusedHwnd) {
                    if (wParam == 27) { ; ESC
                        dd.ClosePopup()
                        return 0
                    }
                    if (wParam == 32 || wParam == 13) { ; Space/Enter
                        dd.Toggle()
                        return 0
                    }
                    if (wParam == 38) { ; Up
                        dd.Cycle(-1, !dd.IsOpen)
                        return 0
                    }
                    if (wParam == 40) { ; Down
                        dd.Cycle(1, !dd.IsOpen)
                        return 0
                    }
                }
            } catch {
                continue
            }
        }
        for btn in SexyButton.Instances {
            try {
                if (btn.FocusProxy.Hwnd == focusedHwnd) {
                    if (wParam == 32 || wParam == 13) {
                        btn.OnClick()
                        return 0
                    }
                }
            } catch {
                continue
            }
        }
    }
}






class FFmpegJob {
    __New(providedPath := "") {
        this.ffmpegPath := ""
        this.CurrentPID := 0
        this.IsCancelled := false
        this.FindFFmpeg(providedPath)
    }

    FindFFmpeg(providedPath) {
        if (providedPath && FileExist(providedPath)) {
            this.ffmpegPath := providedPath
            return
        }
        
        ; Check System Path
        try {
            RunWait("ffmpeg -version", , "Hide")
            this.ffmpegPath := "ffmpeg" 
            return
        }
        
        ; Check Script Directory
        if FileExist(A_ScriptDir "\ffmpeg.exe") {
            this.ffmpegPath := A_ScriptDir "\ffmpeg.exe"
            return
        }
        
        throw Error("FFmpeg executable not found.`nPlease install, or place ffmpeg.exe in the app folder.")
    }
    
    IsRunning() {
        return (this.CurrentPID != 0 && ProcessExist(this.CurrentPID))
    }

    /**
    * Probes a file using ffprobe and returns an object with metadata.
    * @param {String} filePath
    * @returns {Object} {format: Map, streams: Array[Map]}
    */
    Probe(filePath) {
        if !this.ffmpegPath
            throw Error("FFmpeg not found")
        
        ; Locate ffprobe (usually next to ffmpeg)
        probePath := "ffprobe.exe"
        SplitPath(this.ffmpegPath, , &dir)
        if (dir && FileExist(dir "\ffprobe.exe"))
            probePath := dir "\ffprobe.exe"
        else {
            ; Check system path as fallback
            try {
                RunWait("ffprobe -version", , "Hide")
            } catch {
                throw Error("FFprobe not found. Please install or place ffprobe.exe next to ffmpeg.")
            }
        }
            
        tempOut := A_Temp "\probe_out_" A_TickCount ".txt"
        tempErr := A_Temp "\probe_err_" A_TickCount ".txt"
        try FileDelete(tempOut)
        try FileDelete(tempErr)
        
        ; 1. Prepare safe versions of paths (stripped of quotes if any)
        safeProbe := StrReplace(probePath, '"', '')
        safeFile := StrReplace(filePath, '"', '')
        
        ; 2. Construct command using cmd /s /c for reliable quoting behavior
        ; Structure: cmd /s /c " "PROBE" ARGS "FILE" > "OUT" 2> "ERR" "
        ; The outer quotes ensure cmd treats the entire block as one command, 
        ; while inner quotes handle paths with spaces.
        
        ; FIX: noprint_wrappers=0 to ensure [STREAM] tags are present for parser
        fullCmd := Format('{1} /s /c " "{2}" -v error -show_format -show_streams -of default=noprint_wrappers=0:nokey=0 "{3}" > "{4}" 2> "{5}" "', A_ComSpec, safeProbe, safeFile, tempOut, tempErr)
        
        try {
            RunWait(fullCmd, , "Hide")
        } catch as e {
            throw Error("Failed to execute probe command: " e.Message)
        }
        
        if !FileExist(tempOut) {
            errInfo := ""
            if FileExist(tempErr) {
                errInfo := FileRead(tempErr)
                FileDelete(tempErr)
            }
            if (errInfo == "")
                errInfo := "No stderr output captured. Command likely failed to start."
                
            throw Error("Probe failed to generate output.`n`nDEBUG INFO:`nCMD: " fullCmd "`n`nFFprobe STDERR: " errInfo)
        }
        
        content := FileRead(tempOut)
        FileDelete(tempOut)
        if FileExist(tempErr)
            FileDelete(tempErr)
            
        if (content == "")
             throw Error("Probe returned empty data (file might be invalid or 0 bytes).")
        
        data := {format: Map(), streams: []}
        currentStream := ""
        
        Loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line == "[STREAM]") {
                currentStream := Map()
                continue
            }
            if (line == "[/STREAM]") {
                if (currentStream)
                    data.streams.Push(currentStream)
                currentStream := ""
                continue
            }
            if (line == "[FORMAT]") {
                currentStream := "FORMAT" ; Marker
                continue
            }
            if (line == "[/FORMAT]") {
                currentStream := ""
                continue
            }
            
            if (InStr(line, "=")) {
                parts := StrSplit(line, "=", , 2)
                key := parts[1]
                val := (parts.Length > 1) ? parts[2] : ""
                
                if (currentStream == "FORMAT")
                    data.format[key] := val
                else if IsObject(currentStream)
                    currentStream[key] := val
            }
        }
        return data
    }

    /**
    * Generates a single frame preview.
    * @param {Array} cmdArgs - The input/filter arguments (excluding ffmpeg exe and output)
    * @param {String} outputImage - Path to save image
    */
    GeneratePreview(cmdArgs, outputImage) {
        if !this.ffmpegPath
            throw Error("FFmpeg not found")

        previewArgs := []
        previewArgs.Push("-y")
        
        ; Add inputs provided by caller
        for arg in cmdArgs
            previewArgs.Push(arg)
            
        previewArgs.Push("-frames:v", "1")
        previewArgs.Push("-update", "1")
        previewArgs.Push(Format('"{1}"', outputImage))
        
        cmdStr := this.BuildCommand(previewArgs)
        RunWait(cmdStr, , "Hide")
        
        if !FileExist(outputImage)
            ;customDialog({title:"Preview Generation Failed",message: "Command execution failed.`nCommand Operation:", detail: cmdStr}, errorPreset)
            throw Error("Command execution failed.`nCommand Operation:`n`n" cmdStr) ;Error("Preview generation failed.")
    }

    /**
    * Runs a conversion job with progress tracking.
    * @param {Array} cmdArgs - List of arguments
    * @param {String} outputFile - Final output path
    * @param {Function} onProgress - Callback(percent, statusText)
    * @param {Function} onFinish - Callback(success, messageOrLog)
    */
    Run(cmdArgs, outputFile, onProgress, onFinish) {
        if !this.ffmpegPath {
            onFinish.Call(false, "FFmpeg path not set")
            return
        }

        this.IsCancelled := false
        
        ; Construct Command
        params := ""
        for arg in cmdArgs
            params .= " " . arg
        params .= " " . Format('"{1}"', outputFile)

        logFile := A_Temp "\ffmpeg_log_" A_TickCount ".txt"
        ; Using 2> to capture stderr where FFmpeg prints progress
        fullCmd := A_ComSpec ' /c ""' this.ffmpegPath '" ' params ' 2> "' logFile '""'
        
        try {
            Run(fullCmd, , "Hide", &pid)
            this.CurrentPID := pid
        } catch as e {
            onFinish.Call(false, "Failed to start process: " e.Message)
            return
        }

        startTime := A_TickCount
        totalDuration := 0
        
        ; Monitor Loop
        SetTimer(Monitor, 500)
        
        Monitor() {
            if (this.IsCancelled) {
                SetTimer(Monitor, 0)
                this.Cleanup(pid, outputFile, logFile)
                onFinish.Call(false, "Cancelled by user.")
                return
            }

            if (!ProcessExist(pid)) {
                SetTimer(Monitor, 0)
                this.CurrentPID := 0
                
                ; Check result
                if FileExist(outputFile) {
                    if FileExist(logFile)
                        FileDelete(logFile)
                    onFinish.Call(true, outputFile)
                } else {
                    fullLog := FileExist(logFile) ? FileRead(logFile) : "No log generated."
                    if FileExist(logFile)
                        FileDelete(logFile)
                    onFinish.Call(false, fullLog)
                }
                return
            }

            ; Parse Log for Progress
            if FileExist(logFile) {
                try {
                    logContent := FileRead(logFile)
                    
                    ; 1. Find Total Duration (only once)
                    if (totalDuration == 0) {
                        if RegExMatch(logContent, "Duration:\s+(\d{2}):(\d{2}):(\d{2}\.\d+)", &m) {
                            totalDuration := (m[1]*3600) + (m[2]*60) + m[3]
                        }
                    }

                    ; 2. Find Current Time
                    if (totalDuration > 0) {
                        lastChunk := SubStr(logContent, -250)
                        if RegExMatch(lastChunk, "time=(\d{2}):(\d{2}):(\d{2}\.\d+)", &t) {
                            currentPos := (t[1]*3600) + (t[2]*60) + t[3]
                            percent := (currentPos / totalDuration) * 100
                            
                            currSpeed := "N/A"
                            if RegExMatch(lastChunk, "speed=\s*(\d+\.?\d*x)", &sp)
                                currSpeed := sp[1]
                            
                            elapsed := (A_TickCount - startTime) / 1000
                            statusText := ""
                            
                            if (currentPos > 1 && elapsed > 1) {
                                speed := currentPos / elapsed
                                remaining := (totalDuration - currentPos) / speed
                                etaStr := FormatSeconds(remaining) ; Util function
                                statusText := Format(" Converting: {:.1f}% - ETA: {} - Speed: {}", percent, etaStr, currSpeed)
                            } else {
                                statusText := Format(" Converting: {:.1f}% - Calc ETA... ({})", percent, currSpeed)
                            }
                            
                            onProgress.Call(percent, statusText)
                        }
                    }
                }
            }
        }
    }

    Stop() {
        if (this.CurrentPID > 0 && ProcessExist(this.CurrentPID)) {
            RunWait("taskkill /F /PID " this.CurrentPID " /T", , "Hide")
            this.IsCancelled := true
        }
    }

    Cleanup(pid, outputFile, logFile) {
        if FileExist(outputFile) {
            Loop 5 { 
                try {
                    FileDelete(outputFile)
                    break 
                } catch {
                    Sleep(200) 
                }
            }
        }
        if FileExist(logFile)
            FileDelete(logFile)
        this.CurrentPID := 0
    }

    BuildCommand(args) {
        params := ""
        for arg in args
            params .= " " . arg
        return A_ComSpec ' /c ""' this.ffmpegPath '" ' params '"'
    }
}

WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global LastHoveredBtn
    MouseGetPos(,,, &hCtrl, 2)
    
    ; Case 1: SexyButtons
    if (SexyButton.HwndMap.Has(hCtrl)) {
        btn := SexyButton.HwndMap[hCtrl]
        if (LastHoveredBtn != btn) {
            if (LastHoveredBtn && HasProp(LastHoveredBtn, "SetHover")) 
                LastHoveredBtn.SetHover(false)
            btn.SetHover(true)
            LastHoveredBtn := btn
        }
        return
    }
    
    ; Case 2: Dropdown Items (The Custom List Component)
    if (DropdownItem.HwndMap.Has(hCtrl)) {
        item := DropdownItem.HwndMap[hCtrl]
        if (LastHoveredBtn != item) {
            if (LastHoveredBtn && HasProp(LastHoveredBtn, "SetHover"))
                LastHoveredBtn.SetHover(false)
            item.SetHover(true)
            LastHoveredBtn := item
        }
        return
    }

    ; Case 3: Mouse moved off everything
    if (LastHoveredBtn) {
        if (HasProp(LastHoveredBtn, "SetHover"))
            LastHoveredBtn.SetHover(false)
        LastHoveredBtn := ""
    }
}

WM_NCMOUSEMOVE(wParam, lParam, msg, hwnd) {
    global LastHoveredBtn
    if (LastHoveredBtn) {
        if (HasProp(LastHoveredBtn, "SetHover"))
            LastHoveredBtn.SetHover(false)
        LastHoveredBtn := ""
    }
}

WM_SETCURSOR(wParam, lParam, msg, hwnd) {
    MouseGetPos(,,, &hCtrl, 2)
    if (SexyButton.HwndMap.Has(hCtrl) || DarkDropdown.HwndMap.Has(hCtrl) || DropdownItem.HwndMap.Has(hCtrl)) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
        return true
    }
}

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) => CloseDropdownIfClickedOutside(hwnd)
WM_NCLBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global ActiveDropdown
    if (ActiveDropdown && ActiveDropdown.IsOpen) {
        ; Check if the click was on the active popup's non-client area (scrollbar)
        ; HTVSCROLL = 7. If matching popup HWND and hit-test is VSCROLL, do not close.
        if (hwnd == ActiveDropdown.Popup.Hwnd && (wParam == 7))
            return
        ActiveDropdown.ClosePopup()
    }
}
CloseDropdownIfClickedOutside(hwnd) {
    global ActiveDropdown
    if (ActiveDropdown && ActiveDropdown.IsOpen) {
        MouseGetPos(,, &win_id)
        if (win_id != ActiveDropdown.Popup.Hwnd) {
            clickedOwnControl := false
            for c in ActiveDropdown.Controls {
                if (c.Hwnd == hwnd)
                    clickedOwnControl := true
            }
            if (!clickedOwnControl)
                ActiveDropdown.ClosePopup()
        }
    }
}

WM_NCHITTEST(wParam, lParam, msg, hwnd) {
    ; Add global handling if needed, currently CustomDialog has its own.
}

GetResourceText(resName) {
    hMod := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
    hRes := DllCall("FindResource", "Ptr", hMod, "Str", resName, "Ptr", 10, "Ptr") ; 10 = RT_RCDATA
    if !hRes
        throw Error("Resource not found: " resName)
        
    hData := DllCall("LoadResource", "Ptr", hMod, "Ptr", hRes, "Ptr")
    pData := DllCall("LockResource", "Ptr", hData, "Ptr")
    sData := DllCall("SizeofResource", "Ptr", hMod, "Ptr", hRes, "UInt")
    
    if !pData || !sData
        throw Error("Empty resource.")

    ; FIX: Copy to a new buffer and Null-Terminate it to prevent crashes
    safeBuf := Buffer(sData + 2, 0) ; +2 for double null terminator safety
    DllCall("RtlMoveMemory", "Ptr", safeBuf.Ptr, "Ptr", pData, "UPtr", sData)
    
    ; Now we read from our SAFE buffer, letting AHK find the end naturally
    return StrGet(safeBuf, "UTF-8")
}

RunPipe(scriptText) {
    shell := ComObject("WScript.Shell")
    
    ; START THE CHILD PROCESS
    if A_IsCompiled {
        ; We are a compiled EXE. We need the /script switch to act as an interpreter.
        ; We use A_ScriptFullPath because A_AhkPath might not point where we expect in some compiled setups.
        exec := shell.Exec(Format('"{1}" /script /CP65001 "*"', A_ScriptFullPath))
    } else {
        ; We are testing uncompiled (in VSCode/SciTE). 
        ; We do NOT use /script. We just call the interpreter directly.
        exec := shell.Exec(Format('"{1}" /CP65001 "*"', A_AhkPath))
    }
    
    ; FEED THE CODE
    try {
        exec.StdIn.Write(scriptText)
        exec.StdIn.Close()
    } catch {
        ; If this fails, the child process died before we could give it code.
        ; This usually means the resource text was empty or invalid.
        MsgBox("The child process closed unexpectedly. Check that your Resource Name matches exactly.")
    }
}




;@Ahk2Exe-SetMainIcon lib/icon.ico

I_Icon := "lib/icon.ico"
if FileExist(I_Icon)
TraySetIcon(I_Icon)
Tray := A_TrayMenu
Tray.Delete() 
;Tray.Add("About MOSK", (*) => MsgBox("MOSK Version: " MOSK_Version MOSK_Revision "`nBy: owhs","About MOSK"))
;Tray.Add()
Tray.Add("Show Launcher", (*) => LauncherGUI())
;Tray.Add("Restart", (*) => FN_Reload())
;Tray.Add()
Tray.Add("Exit", (*) => ExitApp())
Tray.Default := "Show Launcher"
