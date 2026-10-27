<#
.SYNOPSIS
    Windows Speech Recognition & Action Assistant using Spacebar hold-to-talk.
.DESCRIPTION
    Uses System.Speech.Recognition and Win32 API to listen while Spacebar is held,
    transcribes speech, and executes corresponding actions (e.g., telling time, opening apps, searching web).
#>

# Load necessary assemblies and Win32 API for global key state detection
Add-Type -AssemblyName System.Speech
Add-Type -AssemblyName System.Windows.Forms

$sig = '[DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);'
$api = Add-Type -MemberDefinition $sig -Name "KeyboardUtils" -Namespace "Win32" -PassThru

# Initialize Speech Engine & Synthesizer
$recognizer = New-Object System.Speech.Recognition.SpeechRecognitionEngine
$recognizer.SetInputToDefaultAudioDevice()
$grammar = New-Object System.Speech.Recognition.DictationGrammar
$recognizer.LoadGrammar($grammar)

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.Speak("Voice assistant is ready.")

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   Windows Voice Action Assistant        " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Press and HOLD the [SPACEBAR] to speak  " -ForegroundColor Yellow
Write-Host " Release [SPACEBAR] to process action    " -ForegroundColor Yellow
Write-Host " Press Ctrl+C in console to exit.        " -ForegroundColor Gray
Write-Host "-----------------------------------------" -ForegroundColor Cyan

$global:recognizedText = ""

# Event handler to capture transcribed speech
Register-ObjectEvent -InputObject $recognizer -EventName SpeechRecognized -Action {
    if ($EventArgs.Result) {
        $global:recognizedText = $EventArgs.Result.Text
    }
} | Out-Null

try {
    while ($true) {
        # Check if Spacebar (Virtual Key 0x20) is currently held down
        $isPressed = ($api::GetAsyncKeyState(0x20) -band 0x8000) -ne 0

        if ($isPressed) {
            Write-Host "`n[Listening... Speak your command]" -ForegroundColor Green
            $global:recognizedText = ""
            $recognizer.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)

            # Loop while user keeps holding Spacebar
            while (($api::GetAsyncKeyState(0x20) -band 0x8000) -ne 0) {
                Start-Sleep -Milliseconds 50
            }

            Write-Host "[Processing...]" -ForegroundColor Yellow
            $recognizer.RecognizeAsyncStop()
            Start-Sleep -Milliseconds 400 # Allow final recognition events to flush

            $text = $global:recognizedText.Trim()
            if ($text) {
                Write-Host "You said: '$text'" -ForegroundColor Cyan
                
                # --- ACTION INTERPRETATION & DISPATCH ---
                switch -Wildcard ($text.ToLower()) {
                    '*time*' {
                        $time = (Get-Date).ToString("hh:mm tt")
                        Write-Host "Action: Telling current time ($time)" -ForegroundColor Magenta
                        $synth.Speak("The current time is $time")
                    }
                    '*browser*' {
                        Write-Host "Action: Opening web browser..." -ForegroundColor Magenta
                        $synth.Speak("Opening browser")
                        Start-Process "https://www.google.com"
                    }
                    '*notepad*' {
                        Write-Host "Action: Opening Notepad..." -ForegroundColor Magenta
                        $synth.Speak("Opening Notepad")
                        notepad.exe
                    }
                    default {
                        Write-Host "Action: Searching web for '$text'..." -ForegroundColor Magenta
                        $synth.Speak("Searching for $text")
                        Start-Process "https://www.google.com/search?q=$([uri]::EscapeDataString($text))"
                    }
                }
            } else {
                Write-Host "No speech detected." -ForegroundColor DarkYellow
                $synth.Speak("I didn't catch that.")
            }
            Write-Host "`nReady. Press and HOLD [SPACEBAR] to speak..." -ForegroundColor Yellow
        }

        Start-Sleep -Milliseconds 100
    }
}
finally {
    $recognizer.Dispose()
}