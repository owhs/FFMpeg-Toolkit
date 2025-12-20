#SingleInstance Force

;#region        Config
    ;! Main Config:
        SCRIPT_TO_COMPILE := "launcher.ahk"
        OUTPUT_EXE_NAME := "FFMpeg Toolkit.exe"
        BUILD_DIRECTORY_NAME := "build"
        SUB_BUILD_DIRECTORY_NAME := "tool"
        build_tools_dir := "C:\projects\ahk\build_tools"

    ;! EXE Properties:
        EXE_VERSION := "2.2.0.1"
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
            ["MusicVisualizer"]
        ]

    ;! Fixed locations:
        ahk2exe := build_tools_dir "\Ahk2Exe.exe"
        upxPatcher := build_tools_dir "\UPX-Patcher.exe"
        upx := build_tools_dir "\upx.exe"
        verpatch := build_tools_dir "\verpatch.exe"
        baseExe := EnvGet("ProgramFiles") . "\AutoHotkey\v2\AutoHotkey64.exe"
        scriptDir := A_ScriptDir
        buildDir := scriptDir . "\" . BUILD_DIRECTORY_NAME
        subBuildDir := buildDir . (SUB_BUILD_DIRECTORY_NAME!="" ? "\" . SUB_BUILD_DIRECTORY_NAME : "")

    ;! Build Files:
        srcFile := scriptDir . "\" .  SCRIPT_TO_COMPILE
        interExe := buildDir . "\" . OUTPUT_EXE_NAME
        finalExe := subBuildDir . "\" . OUTPUT_EXE_NAME
        
    ; AHK REPLACE Data:
        AHK_COMPANY_NAME := "Indie"
        AHK_PRODUCT_NAME := "executable"
        AHK_APP_CLASS := "Native Window"
        AHK_REMINANCE := "program"
        AHK_INTERP_NAME := "______" OUTPUT_EXE_NAME

    ; Gui colours
        bg_color := "f0f0f0"
;#endregion

;#region        Build
    build(){
        ;#region - Clear the build directory
            progColor("Red")
            prepFolder(buildDir)
            prepFolder(subBuildDir)
            Chk(step1)
            Sleep 600
        ;#endregion

        ;#region - Create custom AHK BIN
            progColor("FF6000")
            targetExe := buildDir "\" AHK_INTERP_NAME
            jobList := [
                ["AutoHotkeyGUI", AHK_APP_CLASS],
                ["AutoHotkey 64-bit", AHK_PRODUCT_NAME],
                ["AutoHotkey Foundation LLC", AHK_COMPANY_NAME],
                ["AutoHotkey", AHK_REMINANCE]
            ]
            replacedCount := binPatcher(baseExe, jobList, targetExe)
            Chk(step2)
            
            Sleep 600
        ;#endregion

        ;#region - Build
            progColor("ffa600")
            RunWait(Format('"{1}" /in "{2}" /out "{3}" /base "{4}"', ahk2exe, srcFile, interExe, targetExe),, "Hide")
            Chk(step3)
            
            Sleep 250
            try FileDelete(targetExe)
        ;#endregion

        ;#region - Modify Properties
            progColor("fbff00")
            meta := Map(
                "Version",     EXE_VERSION,
                "description", EXE_DESCRIPTION, "product",     EXE_PRODUCT,
                "company",     EXE_COMPANY, "copyright",   EXE_COPYRIGHT
            )
            try UpdateExeMetadata(interExe, meta)
            catch Error as e 
                MsgBox e.Message
            
            Chk(step4)
            
            Sleep 600
        ;#endregion

        ;#region - First patches
            progColor("b3ff00")
            jobList := [["AutoHotkey", AHK_REMINANCE]]
            replacedCount := binPatcher(interExe, jobList,,,"CP0")
            Chk(step5)
            
            Sleep 600
        ;#endregion

        ;#region - UPX
            progColor("51ff00")
            RunWait(Format('"{1}" {2} "{3}"', upx, "-9", interExe),, "Hide")
            Chk(step6)
            
            Sleep 600
        ;#endregion

        ;#region - UPX-Patcher
            progColor("00ff22")
            RunWait(Format('"{1}" "{2}"', upxPatcher, interExe),, "Hide")
            Chk(step61)
            
            Sleep 600
        ;#endregion

        ;#region - Final patches
            progColor("00ff95")
            jobList := [
                ["!https://github.com/DosX-dev/UPX-Patcher", DOS_TEXT],
                ["!This program cannot be run in DOS mode.", DOS_TEXT],
                ["fish", "fmpg"],
                ["dosx", "ffmp"],
                ["rsrc", "ffpg"]
            ]
            replacedCount := binPatcher(interExe, jobList,,,"CP0")
            Chk(step7)
            Sleep 600
        ;#endregion

        ;#region - Final Move
            if (SUB_BUILD_DIRECTORY_NAME != ""){
                FileMove(interExe, finalExe, 1)
            }
        ;#endregion

        ;#region - Shortcuts
            if (MAKE_SHORTCUTS) {
                for arr in SHORTCUTS {
                    name := buildDir . "\" arr[1] ".lnk"
                    args := (arr.Length>1 ? arr[2] : arr[1])
                    desc := (arr.Length>2 ? arr[3] : EXE_DESCRIPTION . ":`n   '" . arr[1] . "'")
                    try FileCreateShortcut(finalExe,name,,args,desc)
                }
                Chk(step8)
            }
        ;#endregion
    }
;#endregion

;#region        GUI
    global MyGui     :=     Gui()
                            MyGui.Title := "Build Process"
                            MyGui.SetFont("s10", "Segoe UI")
                            MyGui.Opt("+AlwaysOnTop -MinimizeBox")
    global startBtn  :=     MyGui.Add("Button", "x5 y5 w240", "Start")
                            MyGui.Add("Text", "x10 y40", "Status:")
    global step1     :=     MyGui.Add("Checkbox", "x20 yp+20 Disabled", "1. Clearing build directory")
    global step2     :=     MyGui.Add("Checkbox", "x20 yp+20 Disabled", "2. Creating custom ahk binary")
    global step3     :=     MyGui.Add("Checkbox", "x20 yp+20 Disabled", "3. Compilation")
    global step4     :=     MyGui.Add("Checkbox", "x20 yp+20 Disabled", "4. Modify properties")
    global step5     :=     MyGui.Add("Checkbox", "x20 yp+20 Disabled", "5. First patches")
    global step6     :=     MyGui.Add("Checkbox", "x20 yp+20 Disabled", "6. UPX")
    global step61    :=     MyGui.Add("Checkbox", "x35 yp+20 Disabled", "6.1 UPX-Patcher")
    global step7     :=     MyGui.Add("Checkbox", "x20 yp+20 Disabled", "7. Final binary patches")
    global step8     :=     MyGui.Add("Checkbox", "x20 yp+20 Disabled", "8. Generating shortcut")
    global progBar   :=     MyGui.Add("Progress", "x20 yp+30 w210 -Smooth +0x8",0)
                            startBtn.OnEvent("Click", (*) => StartJob())
                            MyGui.OnEvent("Close", (*) => ExitApp())
                            MyGui.Show("w250 h40")
    SendMessage(0x040A, 1, 50, progBar.Hwnd)
;#endregion

;#region        GUI Tools
    MoveWin(byX:=0,byY:=0){
    }
    StartJob(){
        MyGui.Opt("-SysMenu")
        MyGui.GetPos(,&Y)
        MyGui.Move(,Y-150)
        MyGui.Move(,,,320)
        MyGui.Title := "Building"
        startBtn.Opt("Disabled")
        build()
        progColor(bg_color)
        MyGui.Title := "Done, auto closing in 3 seconds..."
        MyGui.Move(,,,285)
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
                    ExitApp
                }
            }
    }
;#endregion

;#region        Patching Tools:
    ;#region - binPatcher:
        /**
         * binPatcher - Professional Binary Search & Replace
         * @param {String} targetPath - Source file path
         * @param {Array} jobs - [["Search", "Replace", isHex?], ...]
         * @param {String} outputPath - Optional output path
         * @param {Boolean} allowPadding - If true, shorter replacements are padded with 00.
         * @param {String} encoding - Default string encoding
         */
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
                    ; --- HEX MODE ---
                    searchVal  := RegExReplace(searchVal, "i)[^0-9A-F]") ; Clean hex string
                    replaceVal := RegExReplace(replaceVal, "i)[^0-9A-F]")
                    
                    sLen := StrLen(searchVal) // 2
                    rLen := StrLen(replaceVal) // 2
                    
                    sBuf := Buffer(sLen)
                    rBuf := Buffer(sLen, 0) ; Pre-fill with nulls
                    
                    Loop sLen
                        NumPut("UChar", "0x" . SubStr(searchVal, (A_Index-1)*2+1, 2), sBuf, A_Index-1)
                    Loop rLen
                        NumPut("UChar", "0x" . SubStr(replaceVal, (A_Index-1)*2+1, 2), rBuf, A_Index-1)
                } else {
                    ; --- STRING MODE ---
                    sLen := StrPut(searchVal, encoding) - nullSize
                    rLen := StrPut(replaceVal, encoding) - nullSize
                    
                    sBuf := Buffer(sLen)
                    StrPut(searchVal, sBuf.Ptr, sLen, encoding)
                    
                    rBuf := Buffer(sLen, 0) ; Pre-fill with nulls
                    StrPut(replaceVal, rBuf.Ptr, rLen, encoding)
                }

                ; --- Validation ---
                if (rLen > sLen)
                    throw Error("Length Mismatch: Replacement is too long.`nSearch: " sLen " bytes`nReplace: " rLen " bytes")
                
                if (!allowPadding && rLen != sLen)
                    throw Error("Strict Length Error: Padding is disabled and lengths do not match.")

                ; --- Search Loop ---
                offset := 0
                while (offset <= fileData.Size - sLen) {
                    if (DllCall("msvcrt\memcmp", "Ptr", fileData.Ptr + offset, "Ptr", sBuf.Ptr, "UPtr", sLen, "Cdecl") == 0) {
                        DllCall("RtlMoveMemory", "Ptr", fileData.Ptr + offset, "Ptr", rBuf.Ptr, "UPtr", sLen)
                        totalFound++
                        offset += sLen 
                    } else {
                        offset++
                    }
                }
            }

            if (totalFound > 0) {
                if (outputPath != "" && FileExist(outputPath))
                    FileDelete(outputPath)
                fileObj := FileOpen(saveTo, "w")
                fileObj.RawWrite(fileData)
                fileObj.Close()
            }
            return totalFound
        }
    ;#endregion
    ;#region - verpatch Wrapper:
    /**
     * UpdateExeMetadata - Highly reliable metadata updater
     * Requires 'verpatch.exe' in the script directory.
     * @param {String} targetExe - Path to the EXE to modify
     * @param {Map} info - Map of metadata keys and values
     */
    UpdateExeMetadata(targetExe, info) {
        if !FileExist(verpatch)
            throw Error("verpatch.exe not found at: " verpatch)

        ; Basic command: verpatch "file" "version"
        versionStr := info.Has("Version") ? info["Version"] : "/vo"
        cmd := '""' verpatch '" "' targetExe '" "' versionStr '"'

        for key, value in info {
            if (key = "Version")
                continue
            ; Verpatch syntax: /s key "value"
            cmd .= ' /s ' key ' "' value '"'
        }
        
        cmd .= '"' ; Close the outer quote for A_ComSpec
        
        ; Run via ComSpec to handle nested quotes correctly
        return RunWait(A_ComSpec ' /c ' cmd, , "Hide")
    }
    ;#endregion  
;#endregion