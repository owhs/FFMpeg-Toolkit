
/*
    FFmpeg Manager (AHK v2)
    -----------------------
    Download, Install, Update, and Locate FFmpeg binaries.
    Supports Local installation, System PATH integration, and Package Managers.
*/
#Requires AutoHotkey v2.0

FFmpegManager(ismissing:=false) {
    global AppName := "FFMpeg Manager & Installer"
    global DetectedFF := {Path: "", ProbePath: "", Version: "Not Found", Config: ""}
    global LatestVersion := "Checking..."
    global LogControl := ""
    global CancelDownload := false

    ; ==============================================================================
    ; GUI SETUP
    ; ==============================================================================
    myGui := Gui("-Resize -MaximizeBox", AppName)
    myGui.SetFont("s9 c" Theme.Text, "Segoe UI")
    myGui.BackColor := Theme.Bg

    InitWindowUtils(myGui)
    myGui.OnEvent("Close", (*) => myGui.Destroy())

    GuiWidth := 600
    GuiHeight := 620 ; Increased height for flags

    ; --- HEADER ---
    myGui.Add("Text", Format("x0 y0 w{} h50 Background{}", GuiWidth, Theme.DarkPanel), "")
    myGui.SetFont("s12 w600")
    myGui.Add("Text", "x20 y10 w400 h30 BackgroundTrans c" Theme.Accent, "FFmpeg Environment Manager")
    myGui.SetFont("s9 w400")

    ; --- TABS ---
    Tabs := TabManager(myGui, Theme)
    tW := GuiWidth / 2
    Tabs.Add("1. Local System", 0, 50, tW, 40, "Local")
    Tabs.Add("2. Install / Update", tW, 50, tW, 40, "Install")

    ; ==============================================================================
    ; TAB 1: LOCAL SYSTEM
    ; ==============================================================================
    yStart := 110
    xLabel := 20
    xVal   := 110
    wVal   := 450
    
    ; Detection Info
    AddTabControl("Local", "Text", Format("x{} y{} w80 h24 c{}", xLabel, yStart, Theme.Accent), "Detected:")
    
    ; FFmpeg Path
    AddTabControl("Local", "Text", Format("x{} y{} w80 h24", xLabel, yStart+30), "FFmpeg:")
    edtPath := AddTabControl("Local", "Edit", Format("x{} y{} w{} h24 ReadOnly vLocalPath", xVal, yStart+27, wVal), (!ismissing ? "Initializing..." : "Missing"))
    
    ; FFprobe Path (New)
    AddTabControl("Local", "Text", Format("x{} y{} w80 h24", xLabel, yStart+60), "FFprobe:")
    edtProbePath := AddTabControl("Local", "Edit", Format("x{} y{} w{} h24 ReadOnly vProbePath", xVal, yStart+57, wVal), (!ismissing ? "Scanning..." : "Missing"))

    ; Version
    AddTabControl("Local", "Text", Format("x{} y{} w80 h24", xLabel, yStart+90), "Version:")
    edtVer := AddTabControl("Local", "Edit", Format("x{} y{} w{} h24 ReadOnly vLocalVer", xVal, yStart+87, wVal), (!ismissing ? "Waiting for scan..." : "Missing"))

    ; Build Flags (New)
    yFlags := yStart + 120
    AddTabControl("Local", "Text", Format("x{} y{} w150 h24", xLabel, yFlags), "Build Configuration:")
    edtFlags := AddTabControl("Local", "Edit", Format("x{} y{} w{} h100 ReadOnly vBuildFlags -E0x200", xLabel, yFlags+25, GuiWidth-40), "...")

    ; Actions
    yActs := yFlags + 140
    btnScan := SexyButton(myGui, xLabel, yActs, 120, 30, "Rescan System", ScanSystem)
    btnScan.RegisterToTab(Tabs, "Local")
    
    btnTest := SexyButton(myGui, xLabel+130, yActs, 120, 30, "Test Run", TestBinary)
    btnTest.RegisterToTab(Tabs, "Local")
    
    btnOpen := SexyButton(myGui, xLabel+260, yActs, 120, 30, "Open Folder", OpenBinFolder)
    btnOpen.RegisterToTab(Tabs, "Local")

    ; Path Env Info
    tEnvInfo := AddTabControl("Local", "Text", Format("x{} y{} w{} h40 c888888 Background{}", xLabel, yActs+45, GuiWidth-40, Theme.Bg), "Note: Ensure 'ffmpeg.exe' is in your System PATH or in the 'bin' folder.")


    ; ==============================================================================
    ; TAB 2: INSTALL / UPDATE
    ; ==============================================================================
    yInst := 110
    xVal2 := 120
    
    ; --- Common Settings ---
    AddTabControl("Install", "Text", Format("x{} y{} w80 h24 +0x200", xLabel, yInst), "Build Type:")
    ; Generic Build Names
    ddlBuild := DarkDropdown(myGui, xVal2, yInst, 250, ["Release Essentials", "Release Full", "Git Master (Latest)"], "DlBuild")
    ddlBuild.RegisterToTab(Tabs, "Install")
    
    AddTabControl("Install", "Text", Format("x380 y{} w200 h24 +0x200 c888888", yInst), "(Applies to both methods)")

    yInst += 40

    ; --- Method 1: Direct Download ---
    AddTabControl("Install", "Text", Format("x{} y{} w400 h24 c{}", xLabel, yInst, Theme.Accent), "Method A: Direct Download (Gyan.dev)")
    
    yInst += 30
    AddTabControl("Install", "Text", Format("x{} y{} w80 h24 +0x200", xLabel, yInst), "Install To:")
    ddlLoc := DarkDropdown(myGui, xVal2, yInst, 200, ["Script Folder (Portable)", "C:\FFmpeg (System)"], "DlLoc")
    ddlLoc.RegisterToTab(Tabs, "Install")
    
    chkPath := myGui.Add("Checkbox", Format("x{} y{} w200 h24 vAddToPath c{} Background{}", xVal2+220, yInst, Theme.Text, Theme.Bg), "Add to User PATH")
    SetDarkControl(chkPath)
    Tabs.Register("Install", chkPath)
    
    yInst += 45
    btnDl := SexyButton(myGui, xLabel, yInst, 160, 35, "Download && Install", StartDownload)
    btnDl.RegisterToTab(Tabs, "Install")
    btnDl.Beautify()

    ; --- Method 2: Package Managers ---
    yInst += 60
    AddTabControl("Install", "Text", Format("x{} y{} w400 h24 c{}", xLabel, yInst, Theme.Accent), "Method B: Package Managers (Auto-Elevate)")
    
    yInst += 30
    btnChoco := SexyButton(myGui, xLabel, yInst, 160, 30, "Choco Install/Upgrade", (*) => RunPackageManager("choco"))
    btnChoco.RegisterToTab(Tabs, "Install")
    
    btnScoop := SexyButton(myGui, xLabel+170, yInst, 160, 30, "Scoop Install/Update", (*) => RunPackageManager("scoop"))
    btnScoop.RegisterToTab(Tabs, "Install")
    
    btnWinget := SexyButton(myGui, xLabel+340, yInst, 160, 30, "Winget Install", (*) => RunPackageManager("winget"))
    btnWinget.RegisterToTab(Tabs, "Install")


    ; ==============================================================================
    ; CONSOLE / LOG
    ; ==============================================================================
    yLog := 440
    hLog := GuiHeight - yLog - 15
    
    myGui.Add("Text", Format("x0 y{} w{} h1 Background{}", yLog, GuiWidth, Theme.Border), "")
    myGui.Add("Text", Format("x10 y{} w100 h20 c888888 BackgroundTrans", yLog+5), "Status Log:")
    
    LogControl := myGui.Add("Edit", Format("x10 y{} w{} h{} ReadOnly -E0x200 Background{} c{}", yLog+25, GuiWidth-20, hLog-35, "101010", "00FF00"), (!ismissing ? "Waiting to scan...`n" : "Install missing, or not found`n"))
    SetDarkControl(LogControl)

    ; GUI must show FIRST before scanning to prevent lag
    
    if (ismissing==false)
        Tabs.Switch("Local")
    else
        Tabs.Switch("Install")
    myGui.Show(Format("w{} h{}", GuiWidth, GuiHeight))
    
    if (ismissing==false)
        SetTimer(ScanSystem, -100) ; Async Scan
    


    ; ==============================================================================
    ; HELPERS
    ; ==============================================================================
    
    AddTabControl(tabName, ctrlType, options, text := "") {
        if (ctrlType == "Edit")
            c := AddFlatEdit(myGui, options, text)
        else
            c := myGui.Add(ctrlType, options " Background" Theme.Bg, text)
        Tabs.Register(tabName, c)
        return c
    }

    ; ==============================================================================
    ; LOGIC: DETECTION
    ; ==============================================================================
    
    ScanSystem(*) {
        Log("Scanning system for FFmpeg...")
        edtPath.Value := "Scanning..."
        edtProbePath.Value := "Scanning..."
        edtVer.Value := "Scanning..."
        edtFlags.Value := ""
        
        path := ""
        
        ; 1. Check Script Bin
        localBin := A_ScriptDir "\bin\ffmpeg.exe"
        if FileExist(localBin) {
            path := localBin
            Log("Found in Script Directory: " path)
        }
        
        ; 2. Check Standard C:\FFmpeg
        if (path == "" && FileExist("C:\FFmpeg\bin\ffmpeg.exe")) {
            path := "C:\FFmpeg\bin\ffmpeg.exe"
            Log("Found in C:\FFmpeg: " path)
        }
        
        ; 3. Check System PATH via Where.exe
        if (path == "") {
            try {
                shell := ComObject("WScript.Shell")
                exec := shell.Exec(A_ComSpec " /c where ffmpeg")
                out := exec.StdOut.ReadAll()
                if (out != "") {
                    path := StrSplit(Trim(out), "`n", "`r")[1]
                    Log("Found in PATH: " path)
                }
            }
        }
        
        if (path != "") {
            DetectedFF.Path := path
            edtPath.Value := path
            
            ; Check for FFprobe in same dir
            SplitPath(path, , &dir)
            probePath := dir "\ffprobe.exe"
            if FileExist(probePath) {
                DetectedFF.ProbePath := probePath
                edtProbePath.Value := probePath
                Log("FFprobe found: " probePath)
            } else {
                ; Try finding in path if not in same dir
                try {
                    shell := ComObject("WScript.Shell")
                    exec := shell.Exec(A_ComSpec " /c where ffprobe")
                    out := exec.StdOut.ReadAll()
                    if (out != "") {
                        probePath := StrSplit(Trim(out), "`n", "`r")[1]
                        DetectedFF.ProbePath := probePath
                        edtProbePath.Value := probePath
                        Log("FFprobe found in PATH: " probePath)
                    } else {
                        DetectedFF.ProbePath := "Not Found"
                        edtProbePath.Value := "Not Found"
                        Log("FFprobe not found.")
                    }
                }
            }
            
            ; Get Version & Flags
            try {
                shell := ComObject("WScript.Shell")
                ; Capturing full output to get configuration flags
                exec := shell.Exec(Format('"{1}" -version', path))
                fullOut := exec.StdOut.ReadAll()
                
                ; 1. Extract Version
                if RegExMatch(fullOut, "ffmpeg version\s+([a-zA-Z0-9\-\._]+)", &m) {
                    rawVer := m[1]
                    DetectedFF.Version := rawVer
                    
                    ; Smart Clean: Remove suffixes like -essentials, -full, _build for comparison
                    DetectedFF.CleanVersion := rawVer
                    if RegExMatch(rawVer, "^(\d+\.\d+(\.\d+)?)", &cleanM) {
                        DetectedFF.CleanVersion := cleanM[1]
                    }
                    
                    edtVer.Value := rawVer
                    Log("Version Detected: " rawVer)
                } else {
                    DetectedFF.Version := "Unknown"
                    edtVer.Value := "Unknown"
                }
                
                ; 2. Extract Configuration Flags
                if RegExMatch(fullOut, "configuration:\s*(.*)", &confMatch) {
                    configStr := confMatch[1]
                    ; Format nicely: replace " --" with "`r`n--" for readabilty
                    cleanConfig := StrReplace(configStr, " --", "`r`n--")
                    DetectedFF.Config := cleanConfig
                    edtFlags.Value := cleanConfig
                } else {
                    edtFlags.Value := "No configuration flags found in output."
                }
                
            } catch as e {
                edtVer.Value := "Error reading version"
                Log("Error extracting version info: " e.Message)
            }
            
            CheckOnlineVersion()
            
        } else {
            DetectedFF.Path := ""
            DetectedFF.Version := "Not Found"
            edtPath.Value := "Not Found"
            edtProbePath.Value := "Not Found"
            edtVer.Value := "N/A"
            Log("FFmpeg not found on this system.")
        }
    }
    
    TestBinary(*) {
        if (DetectedFF.Path == "")
            return customDialog({message:"No FFmpeg detected to test."}, darkPreset)
            
        RunWait(A_ComSpec ' /k ""' DetectedFF.Path '" -version"', , "Max")
    }
    
    OpenBinFolder(*) {
        if (DetectedFF.Path != "") {
            SplitPath(DetectedFF.Path, , &dir)
            Run(dir)
        } else {
            binDir := A_ScriptDir "\bin"
            if !DirExist(binDir)
                DirCreate(binDir)
            Run(binDir)
        }
    }
    
    CheckOnlineVersion() {
        Log("Checking latest release version from gyan.dev...")
        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("GET", "https://www.gyan.dev/ffmpeg/builds/release-version", true)
            whr.Send()
            whr.WaitForResponse()
            LatestVersion := Trim(whr.ResponseText)
            Log("Latest Online Version: " LatestVersion)
            
            if (DetectedFF.Version == "Not Found")
                return

            localClean := DetectedFF.HasOwnProp("CleanVersion") ? DetectedFF.CleanVersion : DetectedFF.Version
            
            if (localClean == LatestVersion) {
                Log("You have the latest release version (" LatestVersion ").")
            } else {
                ; If mismatch, analyze why
                if (InStr(DetectedFF.Version, "git") || InStr(DetectedFF.Version, "N-") || RegExMatch(DetectedFF.Version, "^\d{4}-\d{2}-\d{2}")) {
                    Log("Local is a Git/Snapshot build. Latest Release: " LatestVersion)
                } else {
                    Log("Update Available! (Local: " localClean " vs Online: " LatestVersion ")")
                }
            }
        } catch as e {
            Log("Failed to check online version: " e.Message)
        }
    }

    ; ==============================================================================
    ; LOGIC: DOWNLOAD & INSTALL
    ; ==============================================================================
    
    StartDownload(*) {
        saved := myGui.Submit(0)
        CancelDownload := false
        
        ; Determine URL based on Generic Dropdown
        url := ""
        if InStr(saved.DlBuild, "Essentials")
            url := "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
        else if InStr(saved.DlBuild, "Full")
            url := "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full.zip"
        else {
            url := "https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-full.7z"
            if !FileExist(A_ScriptDir "\bin\7za.exe") && !FileExist("C:\Program Files\7-Zip\7z.exe") {
                if MsgBox("Git builds are .7z files. You need 7-Zip installed or 7za.exe in bin folder.`nContinue anyway (might fail if no extractor found)?", "Warning", "YesNo") == "No"
                    return
            }
        }
        
        ; Determine Locations
        destDir := ""
        if InStr(saved.DlLoc, "Script")
            destDir := A_ScriptDir "\bin"
        else
            destDir := "C:\FFmpeg"
            
        if (destDir == "C:\FFmpeg" && !A_IsAdmin) {
            customDialog({message:"Writing to C:\FFmpeg requires Admin privileges.`nPlease restart script as Admin."}, errorPreset)
            return
        }
        
        if !DirExist(destDir)
            try DirCreate(destDir)
            
        ; Download
        zipFile := A_Temp "\ffmpeg_dl.archive"
        Log("Downloading from: " url)
        Log("Target: " destDir)
        
        btnDl.Enabled := false
        SetTimer(DoDownload, 10)
        
        DoDownload() {
            SetTimer(DoDownload, 0) ; Run once
            try {
                Download(url, zipFile)
                Log("Download Complete.")
                ExtractAndInstall(zipFile, destDir, saved.AddToPath)
            } catch as e {
                Log("Download Failed: " e.Message)
                btnDl.Enabled := true
            }
        }
    }
    
    ExtractAndInstall(archivePath, targetDir, addToPath) {
        Log("Extracting...")
        
        ; Create a temp extraction folder
        tempExt := A_Temp "\ffmpeg_extract_" A_TickCount
        DirCreate(tempExt)
        
        ; Extraction Logic
        ; Try native tar (Windows 10/11) which handles zip
        ; Tar on windows creates a folder structure usually
        runCmd := ""
        
        try {
            ; Check if 7z needed
            is7z := false
            f := FileOpen(archivePath, "r")
            sig := f.Read(2)
            f.Close()
            if (sig == "7z")
                is7z := true
                
            if (is7z) {
                exe7z := ""
                if FileExist("C:\Program Files\7-Zip\7z.exe")
                    exe7z := "C:\Program Files\7-Zip\7z.exe"
                else if FileExist(A_ScriptDir "\bin\7za.exe")
                    exe7z := A_ScriptDir "\bin\7za.exe"
                    
                if (exe7z == "")
                    throw Error("7z archive detected but no 7z.exe found.")
                    
                runCmd := Format('"{1}" x "{2}" -o"{3}" -y', exe7z, archivePath, tempExt)
            } else {
                ; Assume Zip, use tar
                runCmd := Format('tar -xf "{1}" -C "{2}"', archivePath, tempExt)
            }
            
            Log("Running extractor...")
            RunWait(A_ComSpec " /c " runCmd, , "Hide")
            
            ; Move Files
            ; Structure is usually ffmpeg-version-build/bin/ffmpeg.exe
            foundBin := false
            Loop Files, tempExt "\ffmpeg.exe", "R" 
            {
                foundBin := true
                FileMove(A_LoopFileFullPath, targetDir "\ffmpeg.exe", 1)
                Log("Moved ffmpeg.exe")
            }
            if (!foundBin) {
                 ; Try again
                 Loop Files, tempExt "\bin\ffmpeg.exe", "R"
                 {
                    foundBin := true
                    FileMove(A_LoopFileFullPath, targetDir "\ffmpeg.exe", 1)
                    Log("Moved ffmpeg.exe")
                 }
            }
            
            Loop Files, tempExt "\bin\ffprobe.exe", "R"
                FileMove(A_LoopFileFullPath, targetDir "\ffprobe.exe", 1)
            Loop Files, tempExt "\bin\ffplay.exe", "R"
                FileMove(A_LoopFileFullPath, targetDir "\ffplay.exe", 1)
                
            ; Cleanup
            DirDelete(tempExt, true)
            FileDelete(archivePath)
            
            Log("Installation Finished.")
            
            if (addToPath)
                UpdateSystemPath(targetDir)
                
            btnDl.Enabled := true
            ScanSystem() ; Refresh
            
        } catch as e {
            Log("Extraction Error: " e.Message)
            btnDl.Enabled := true
        }
    }
    
    UpdateSystemPath(binDir) {
        if !A_IsAdmin {
            Log("Skipping PATH update (Requires Admin).")
            return
        }
        
        try {
            path := RegRead("HKEY_CURRENT_USER\Environment", "Path")
            if !InStr(path, binDir) {
                if (SubStr(path, -1) != ";")
                    path .= ";"
                path .= binDir
                RegWrite(path, "REG_EXPAND_SZ", "HKEY_CURRENT_USER\Environment", "Path")
                Log("Added to User PATH. Restart Script/Apps to detect.")
                
                ; Broadcast change (HWND_BROADCAST, WM_SETTINGCHANGE)
                SendMessage(0x1A, 0, StrPtr("Environment"), 0xFFFF)
            } else {
                Log("Path already present in Environment.")
            }
        } catch as e {
            Log("Registry Update Failed: " e.Message)
        }
    }
    
    RunPackageManager(mgr) {
        if !A_IsAdmin {
            ; Ask for elevation
            res := customDialog({
                title: "Admin Required",
                message: "Package managers require Admin privileges.",
                detail: "Do you want to run this command as Administrator?",
                buttons: ["&Yes", "&No"],
                icon: "🛡️"
            }, darkPreset)
            
            if (res.value != "Yes") {
                Log("Operation cancelled by user.")
                return
            }
        }
        
        ; Force read current selection
        build := ddlBuild.Text
        Log("Debug: Build Selection -> " build)
        
        cmd := ""
        
        if (mgr == "choco") {
            ; Chocolatey usually has 'ffmpeg' and 'ffmpeg-full'. 
            ; Often 'ffmpeg' defaults to full in some repos, but 'ffmpeg-full' is explicit.
            if InStr(build, "Full")
                cmd := "choco upgrade ffmpeg-full -y"
            else
                cmd := "choco upgrade ffmpeg -y"
                
        } else if (mgr == "scoop") {
            ; Scoop main bucket is typically essentials.
            ; 'ffmpeg-full' often exists in other buckets, but standard is 'ffmpeg'.
            cmd := "scoop update ffmpeg"
            if InStr(build, "Full")
                Log("Note: Scoop default 'ffmpeg' is usually Essentials. You may need to add a bucket for full build manually.")
                
        } else if (mgr == "winget") {
            ; Winget: Gyan.FFmpeg (Full) vs Gyan.FFmpeg.Essentials
            if InStr(build, "Essentials") {
                cmd := "winget install Gyan.FFmpeg.Essentials"
                Log("Winget: Installing Essentials...")
            } else if InStr(build, "Full") {
                cmd := "winget install Gyan.FFmpeg"
                Log("Winget: Installing Full...")
            } else if InStr(build, "Git") {
                cmd := "winget install Gyan.FFmpeg.Git" 
                Log("Winget: Installing Git Master...")
            } else {
                ; Fallback (Full)
                cmd := "winget install Gyan.FFmpeg" 
                Log("Winget: Defaulting to Full...")
            }
        }
            
        try {
            if A_IsAdmin {
                Run(A_ComSpec ' /k "' cmd '"')
            } else {
                ; RunAs Admin
                Run('*RunAs ' A_ComSpec ' /k "' cmd '"')
            }
            Log("Launched Package Manager: " mgr " (" build ")")
        } catch as e {
            Log("Failed to launch command: " e.Message)
        }
    }

    Log(text) {
        timestamp := FormatTime(, "HH:mm:ss")
        LogControl.Value .= "[" timestamp "] " text "`r`n"
        SendMessage(0x0115, 7, 0, LogControl.Hwnd) ; Scroll to bottom
    }
}
