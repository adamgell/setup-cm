Option Explicit

Const ExpectedHash = "3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254"

Dim fileSystem
Dim markerRoot
Dim markerPath
Dim shell
Dim process
Dim hashOutput
Dim compactOutput

Set fileSystem = CreateObject("Scripting.FileSystemObject")

If WScript.Arguments.Count > 0 Then
    markerRoot = WScript.Arguments(0)
Else
    markerRoot = "C:\ProgramData\SetupCm\Phase1"
End If

markerPath = fileSystem.BuildPath(markerRoot, "marker.json")
If Not fileSystem.FileExists(markerPath) Then
    WScript.Quit 0
End If

Set shell = CreateObject("WScript.Shell")
Set process = shell.Exec("certutil.exe -hashfile " & QuoteArgument(markerPath) & " SHA256")
hashOutput = process.StdOut.ReadAll()
process.StdErr.ReadAll()

If process.ExitCode <> 0 Then
    WScript.Quit 0
End If

compactOutput = Replace(hashOutput, " ", "")
compactOutput = Replace(compactOutput, vbTab, "")
compactOutput = Replace(compactOutput, vbCr, "")
compactOutput = Replace(compactOutput, vbLf, "")

If InStr(1, UCase(compactOutput), ExpectedHash, vbBinaryCompare) > 0 Then
    WScript.Echo "Installed"
End If

WScript.Quit 0

Function QuoteArgument(ByVal value)
    QuoteArgument = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function
