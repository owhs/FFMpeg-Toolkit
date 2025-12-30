#SingleInstance Force

;#region         Config
    ;! Main Config:
        SCRIPT_TO_COMPILE := "Launcher.ahk"
        OUTPUT_EXE_NAME := "FFMpeg Toolkit.exe"
        BUILD_DIRECTORY_NAME := "build"
        SUB_BUILD_DIRECTORY_NAME := "tool"
        build_tools_dir := "C:\projects\ahk\build_tools"

    ;! EXE Properties:
        EXE_VERSION := "2.2.0.2"
        EXE_DESCRIPTION := "FFMpeg Toolkit"
        EXE_COMPANY := "owhs"
        EXE_COPYRIGHT := "Copyright (c) 2025"
        EXE_PRODUCT := "FFMpeg Toolkit"
        DOS_TEXT := " FFMpeg Toolkit; small but mighty! "

    ;! Build Options
        MAKE_SHORTCUTS := true
        SHORTCUTS := [
            ["Launcher",""],
            ["AudioTool"],
            ["AudioToVideo"],
            ["ContactSheetMaker"],
            ["FilterTool"],
            ["MediaInfoTool"],
            ["MotionInterpolationTool"],
            ["RecognitionTool"],
            ["ScreenRecorder"],
            ["SimpleConverter"],
            ["StabilizerTool"],
            ["StreamChunker"],
            ["SubtitleTool"],
            ["TimeLapseTool"],
            ["VideoJoinerSplitter"],
            ["WatermarkTool"],
            ["CropTool"],
            ["MusicVisualizer"],
            ["FFmpegManager"]
        ]

    ;! Fixed locations:
        ahk2exe := "Ahk2Exe.exe"
        upxPatcher := "UPX-Patcher.exe"
        upx := "upx.exe"
        fatpack := "FatPack.exe"
        mpress := "mpress.exe"
        verpatch := "verpatch.exe"
        modbin := "BinMod.exe"
        scriptguard := "ScriptGuard1.ahk"
        baseExe := EnvGet("ProgramFiles") . "\AutoHotkey\v2\AutoHotkey64.exe"
        targetExe := baseExe
        TEMP_SCRIPT_NAME := "temp.build.ahk"
        scriptDir := A_ScriptDir
        buildDir := scriptDir . "\" . BUILD_DIRECTORY_NAME
        subBuildDir := buildDir . (SUB_BUILD_DIRECTORY_NAME!="" ? "\" . SUB_BUILD_DIRECTORY_NAME : "")

    ;! Build Files:
        srcFile := scriptDir . "\" .  TEMP_SCRIPT_NAME 
        interExe := buildDir . "\" . OUTPUT_EXE_NAME
        finalExe := subBuildDir . "\" . OUTPUT_EXE_NAME
    
    ; AHK REPLACE Data:
        AHK_COMPANY_NAME := "Indie"
        AHK_PRODUCT_NAME := "executable"
        AHK_APP_CLASS := "FFMpeg Tool" ; "Native Window"
        AHK_REMINANCE := "IME"
        AHK_INTERP_NAME := "_interpreter.exe" ; OUTPUT_EXE_NAME

    ; Gui colours
        bg_color := "f0f0f0"
;#endregion

checkBaseBinary()
checkBuildEnv()

;#region         Build
    build(){
        ; Retrieve values from GUI controls
        doCompress := optCompress.Value
        doPatches := optPatch.Value
        doShortcuts := optShorts.Value

        useUpx := optUpx.Value ; Radio 1 (UPX)
        useFatpack := optFatpack.Value ; Radio 2 (Fatpack)
        upxLevel := upxSlider.Value ; Get slider value (1-9)
    

        ;#region - Clear the build directory
            progColor("Red")
            prepFolder(buildDir)
            prepFolder(subBuildDir)
            Chk(step1)
            setupBuildScript()
            Sleep 100
        ;#endregion

        ;#region - Build
            progColor("ffa600")
            RunWait(Format('"{1}" /in "{2}" /out "{3}" /base "{4}"', build_tools_dir "\" ahk2exe, srcFile, interExe, targetExe),, "Hide")
            Chk(step3)
            Sleep 200
            clearFiles()
        ;#endregion

        ;#region - ScriptGuard, Modify Properties
            progColor("fbff00")
            RunWait(Format('"{1}" "{2}" /ScriptGuard2', build_tools_dir "\" modbin, interExe),, "Hide")
            Chk(step4)
            Sleep 200
        ;#endregion

        ;#region - Binary Patches (Conditional)
            if (doPatches) {
                progColor("ff0000")
                jobList := [
                    ["AutoHotkeyGUI", "Window"],
                    ['"AutoHotkey"', '"XC-Z30-ACQ"'],
                    ['AutoHotkey v2.0.19', 'XC-Z30-ACQ v1.0.01'],
                    ["AutoHotkey.chm", "http://owhs.uk"],
                    ["\AutoHotkey", "\ZZZZZZZZZZ"],
                    ["https://autohotkey.com", "https://owhs.uk/"],
                    ["AutoHotkey", "IME"]
                ]
                binPatcher(interExe, jobList)
                Chk(step7)
                Sleep 200
            }
        ;#endregion

        ;#region - Compression (UPX vs FatPack)
            if (doCompress){
                progColor("51ff00")
                if (useFatpack) {
                    ; Fatpack: Input and Output
                    RunWait(Format('"{1}" "{2}" "{3}"', build_tools_dir "\" fatpack, interExe, finalExe),, "Hide")
                    Sleep 500
                    try FileDelete(interExe)
                } else {
                    ; UPX: Overwrites Input - Using chosen compression level
                    RunWait(Format('"{1}" -{2} "{3}"', build_tools_dir "\" upx, upxLevel, interExe),, "Hide")
                    Sleep 500
                    FileMove(interExe, finalExe, 1)
                }
                Chk(step6)
                Sleep 200
            }
        ;#endregion

        ;#region - Final Patches (Conditional)
            if (!doCompress){
                FileMove(interExe, finalExe, 1)
                Sleep 200
            }
            if (doPatches) {
                jobList := [
                    ['"AutoHotkey"', '"XC-Z30-ACQ"'],
                    ['AutoHot', ''],
                    ["UPX!", "ZZZ0"],
                    ["UPX0", "dat1"],
                    ["UPX1", "dat2"],
                    ["upX", "zzz"],
                    ["!This program cannot be run in DOS mode.", DOS_TEXT],
                    ["2.0.00.00", "0.0.00.01"],
                    ["2.0.19","0.0.01"]
                ]
                binPatcher(finalExe, jobList,,,"CP0")
                Chk(step61)
                Sleep 200
            }
        ;#endregion

        ;#region - Shortcuts
            if (doShortcuts) {
                for arr in SHORTCUTS {
                    name := buildDir . "\" arr[1] ".lnk"
                    args := (arr.Length>1 ? arr[2] : arr[1])
                    desc := (arr.Length>2 ? arr[3] : EXE_DESCRIPTION . ":`n   '" . arr[1] . "'")
                    try FileCreateShortcut(finalExe,name,,args,desc)
                }
                Chk(step8)
            }
            Sleep 200
        ;#endregion
    }
;#endregion

;#region         GUI
    global MyGui     :=     Gui()
                            MyGui.Title := "Build Process"
                            MyGui.SetFont("s10", "Segoe UI")
                            MyGui.Opt("+AlwaysOnTop -MinimizeBox")

    ; Options Section
    MyGui.Add("GroupBox", "x5 y5 w240 h175", "Build Options")
    global optShorts     :=  MyGui.Add("Checkbox", "x15 y25 Checked", "Make Shortcuts")
    global optPatch     :=  MyGui.Add("Checkbox", "x15 y45 Checked", "Enable Binary Mods")
    global optCompress  :=  MyGui.Add("Checkbox", "x15 y65 Checked", "Enable Compression")
    
    ; Compression Radios (Linked automatically because they are sequential)
    global optUpx       :=  MyGui.Add("Radio", "x15 y85 Checked", "Compression: UPX")
    global optFatpack   :=  MyGui.Add("Radio", "x15 y155", "Compression: FatPack (Strips meta)")
    
    ; UPX Level Slider & Text
    MyGui.Add("Text", "x30 y105", "UPX Level:")
    global upxValText   :=  MyGui.Add("Text", "x100 y105 w30", "9")
    global upxSlider    :=  MyGui.Add("Slider", "x30 y125 w200 h25 Range1-9 ToolTip", 9)

    global startBtn     :=  MyGui.Add("Button", "x5 y185 w240 h30 Default", "Start Build")
    
    ; Progress Tracker Section
                            MyGui.Add("Text", "x10 y220", "Status:")
    global step1        :=  MyGui.Add("Checkbox", "x20 yp+20 Disabled", "1. Clearing build directory")
    global step3        :=  MyGui.Add("Checkbox", "x20 yp+20 Disabled", "2. Compilation")
    global step4        :=  MyGui.Add("Checkbox", "x35 yp+20 Disabled", "2.1. ScriptGuard")
    global step7        :=  MyGui.Add("Checkbox", "x20 yp+20 Disabled", "3. Binary patches")
    global step6        :=  MyGui.Add("Checkbox", "x20 yp+20 Disabled", "4. Compression (UPX/Fat)")
    global step61       :=  MyGui.Add("Checkbox", "x35 yp+20 Disabled", "4.1 Final patches")
    global step8        :=  MyGui.Add("Checkbox", "x20 yp+20 Disabled", "5. Generating shortcuts")
    global progBar      :=  MyGui.Add("Progress", "x20 yp+30 w210 -Smooth +0x8",0)

                            startBtn.OnEvent("Click", (*) => StartJob())
                            optCompress.OnEvent("Click", (*) => toggleCompressOpts())
                            optUpx.OnEvent("Click", (*) => toggleCompressOpts())
                            optFatpack.OnEvent("Click", (*) => toggleCompressOpts())
                            upxSlider.OnEvent("Change", (ctrl, *) => upxValText.Value := ctrl.Value)
                            MyGui.OnEvent("Close", (*) => ExitApp())
                            
                            ; Initial Show
                            MyGui.Show("w250 h225")
                            SendMessage(0x040A, 1, 50, progBar.Hwnd)
                            startBtn.Focus()
;#endregion

;#region         GUI Utils:
    toggleCompressOpts(){
        ; Check main compression checkbox
        compEnabled := optCompress.Value
        
        ; Check if UPX radio is selected
        isUpx := optUpx.Value

        ; Enable/Disable the radio choices based on the main checkbox
        optUpx.Enabled := compEnabled
        optFatpack.Enabled := compEnabled
        
        ; Enable slider ONLY if compression is active AND UPX is the chosen method
        upxSlider.Enabled := (compEnabled && isUpx)
        
        ; Dim/Hide text to give visual feedback
        upxValText.Visible := (compEnabled && isUpx)
    }
    
    StartJob(){
        ; Disable option controls during build
        optPatch.Enabled := False
        optUpx.Enabled := False
        optFatpack.Enabled := False
        optCompress.Enabled := False
        upxSlider.Enabled := False
        optShorts.Enabled := False

        MyGui.Opt("-SysMenu")
        MyGui.GetPos(,&Y)
        MyGui.Move(,Max(0, Y-100))
        MyGui.Move(,,,455) ; Expand for steps
        MyGui.Title := "Building..."
        startBtn.Opt("Disabled")
        
        build()
        MyGui.Move(,,,425)
        
        progColor(bg_color)
        MyGui.Opt("+SysMenu")
        MyGui.Title := "Done! Auto closing..."
        Sleep 3000
        ExitApp()
    }
    progColor(col){
        progBar.Opt("c" col)
    }
    Chk(ctrl,checked:=1){
        ctrl.Enabled := True
        ctrl.Value := checked
        ctrl.Enabled := False
    }
    FailMsg(msg){
        return MsgBox("Error deleting file:`n     " A_LoopFilePath "`n`nReason:`n     "  msg "`n`n The build will now exit.", "Build Failed!", "Iconx 0x5 0x40000")
    }
    prepFolder(dir){
        Clear:
        if !DirExist(dir)
            DirCreate(dir)
        else
            Loop Files, dir . "\*", "F"
            {
                try FileDelete(A_LoopFilePath)
                catch Error as e {
                    if (FailMsg(e.Message)=="Retry")
                        goto Clear
                }
            }
    }
;#endregion

;#region         Enviroment Checkers Utils:
    checkBaseBinary(){
        global baseExe
        if (baseExe=="" || !FileExist(baseExe)){
            selected := FileSelect("1", EnvGet("ProgramFiles") . "\AutoHotkey", "Select a ahk binary")
            if (selected != "")
                baseExe := selected
        }
    }
    checkBuildEnv(){
        global build_tools_dir
        if (build_tools_dir=="" || !DirExist(build_tools_dir)){
            selected := FileSelect("D", A_ScriptDir, "Select Build Tools Folder")
            if (selected != "")
                build_tools_dir := selected
        }
    }
;#endregion

;#region         Build Utils (Binary Patcher, etc):
    binPatcher(targetPath, jobs, outputPath := "", allowPadding := true, encoding := "UTF-16") {
        if !FileExist(targetPath)
            throw Error("Source file not found: " targetPath)
        
        saveTo := (outputPath == "") ? targetPath : outputPath
        fileData := FileRead(targetPath, "RAW")
        nullSize := StrPut("", encoding) 
        totalFound := 0

        for job in jobs {
            searchVal  := job[1]
            replaceVal := job[2]
            isHex      := (job.Length > 2) ? job[3] : false
            local sBuf, rBuf, sLen, rLen

            if (isHex) {
                searchVal  := RegExReplace(searchVal, "i)[^0-9A-F]")
                replaceVal := RegExReplace(replaceVal, "i)[^0-9A-F]")
                sLen := StrLen(searchVal) // 2
                rLen := StrLen(replaceVal) // 2
                sBuf := Buffer(sLen), rBuf := Buffer(sLen, 0)
                Loop sLen
                    NumPut("UChar", "0x" . SubStr(searchVal, (A_Index-1)*2+1, 2), sBuf, A_Index-1)
                Loop rLen
                    NumPut("UChar", "0x" . SubStr(replaceVal, (A_Index-1)*2+1, 2), rBuf, A_Index-1)
            } else {
                sLen := StrPut(searchVal, encoding) - nullSize
                rLen := StrPut(replaceVal, encoding) - nullSize
                sBuf := Buffer(sLen), rBuf := Buffer(sLen, 0)
                StrPut(searchVal, sBuf, encoding)
                StrPut(replaceVal, rBuf, encoding)
            }

            if (rLen > sLen)
                continue ; Skip if replacement too long

            offset := 0
            while (offset <= fileData.Size - sLen) {
                if (DllCall("msvcrt\memcmp", "Ptr", fileData.Ptr + offset, "Ptr", sBuf.Ptr, "UPtr", sLen, "Cdecl") == 0) {
                    DllCall("RtlMoveMemory", "Ptr", fileData.Ptr + offset, "Ptr", rBuf.Ptr, "UPtr", sLen)
                    totalFound++, offset += sLen 
                } else offset++
            }
        }

        if (totalFound > 0) {
            fileObj := FileOpen(saveTo, "w")
            fileObj.RawWrite(fileData)
            fileObj.Close()
        }
        return totalFound
    }
    setupBuildScript(){
        fileObj := FileOpen(TEMP_SCRIPT_NAME, "w", "UTF-16")
        fileObj.WriteLine("#Warn All, Off")
        fileObj.WriteLine('#Include "' build_tools_dir '\' scriptguard '"')
        fileObj.WriteLine('#Include "' SCRIPT_TO_COMPILE '"')
        fileObj.Close()
    }
    clearFiles(){
        if FileExist(TEMP_SCRIPT_NAME)
            try FileDelete(TEMP_SCRIPT_NAME)
    }
;#endregion