Option Explicit

Const ExpectedHash = "3F44AA70B40C9E9095E69F1C57E98F6ACC06900788A2054E251BCC58179B6254"
Const ExpectedComputerName = "RING0IVY24-01"
Const ProductionMarkerRoot = "C:\ProgramData\SetupCm\Phase1"
Const ProductionEvidencePath = "\\LABZ1-CM01.test.gell.one\SetupCmMarkerEvidence$\marker-evidence.json"

Dim fileSystem
Dim markerRoot
Dim markerPath
Dim evidencePath
Dim publicationEnabled
Dim shell
Dim process
Dim hashOutput
Dim hashLines
Dim hashLine
Dim normalizedLine

Set fileSystem = CreateObject("Scripting.FileSystemObject")

If WScript.Arguments.Count > 2 Then
    WScript.Quit 0
ElseIf WScript.Arguments.Count = 2 Then
    markerRoot = WScript.Arguments(0)
    evidencePath = WScript.Arguments(1)
    publicationEnabled = True
ElseIf WScript.Arguments.Count = 1 Then
    markerRoot = WScript.Arguments(0)
    evidencePath = ""
    publicationEnabled = False
Else
    markerRoot = ProductionMarkerRoot
    evidencePath = ProductionEvidencePath
    publicationEnabled = True
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

hashLines = Split(Replace(hashOutput, vbCr, ""), vbLf)
For Each hashLine In hashLines
    normalizedLine = Replace(hashLine, " ", "")
    normalizedLine = Replace(normalizedLine, vbTab, "")
    If StrComp(UCase(normalizedLine), ExpectedHash, vbBinaryCompare) = 0 Then
        If publicationEnabled Then
            PublishEvidence evidencePath
        End If
        WScript.Echo "Installed"
        WScript.Quit 0
    End If
Next

WScript.Quit 0

Function QuoteArgument(ByVal value)
    QuoteArgument = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function

Sub PublishEvidence(ByVal targetPath)
    Dim network
    Dim parentFolder
    Dim temporaryPath
    Dim writer
    Dim evidenceJson

    On Error Resume Next
    Set network = CreateObject("WScript.Network")
    If Err.Number <> 0 Then
        Err.Clear
        On Error GoTo 0
        Exit Sub
    End If
    If StrComp(network.ComputerName, ExpectedComputerName, vbTextCompare) <> 0 Then
        On Error GoTo 0
        Exit Sub
    End If

    parentFolder = fileSystem.GetParentFolderName(targetPath)
    If Err.Number <> 0 Or Len(parentFolder) = 0 Then
        Err.Clear
        On Error GoTo 0
        Exit Sub
    End If
    If Not fileSystem.FolderExists(parentFolder) Then
        On Error GoTo 0
        Exit Sub
    End If

    temporaryPath = fileSystem.BuildPath(parentFolder, fileSystem.GetTempName())
    If Err.Number <> 0 Then
        Err.Clear
        On Error GoTo 0
        Exit Sub
    End If
    evidenceJson = "{""schemaVersion"":1,""computerName"":""RING0IVY24-01""," & _
        """markerPath"":""C:\\ProgramData\\SetupCm\\Phase1\\marker.json""," & _
        """markerSha256"":""" & ExpectedHash & """," & _
        """markerLength"":78,""verificationMethod"":""CertUtilSha256Exact""}"
    Set writer = fileSystem.CreateTextFile(temporaryPath, True, False)
    If Err.Number = 0 Then
        writer.Write evidenceJson
        writer.Close
    End If
    If Err.Number <> 0 Then
        Err.Clear
        RemoveTemporaryEvidence temporaryPath
        On Error GoTo 0
        Exit Sub
    End If

    If fileSystem.FileExists(targetPath) Then
        fileSystem.DeleteFile targetPath, True
    End If
    If Err.Number = 0 Then
        fileSystem.MoveFile temporaryPath, targetPath
    End If
    If Err.Number <> 0 Then
        Err.Clear
        RemoveTemporaryEvidence temporaryPath
    End If
    On Error GoTo 0
End Sub

Sub RemoveTemporaryEvidence(ByVal temporaryPath)
    On Error Resume Next
    If Len(temporaryPath) > 0 And fileSystem.FileExists(temporaryPath) Then
        fileSystem.DeleteFile temporaryPath, True
    End If
    Err.Clear
    On Error GoTo 0
End Sub
