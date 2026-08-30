function ConvertFrom-SetupCmMarkerEvidenceJsonStrict {
    [CmdletBinding()]
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $contract = Get-SetupCmMarkerFixedContract
    if ($Bytes.Count -gt [int]$contract.EvidenceChannel.MaximumBytes) {
        throw 'Marker evidence exceeds the 2,048-byte limit.'
    }
    if (@($Bytes | Where-Object { $_ -gt 0x7f }).Count -gt 0) {
        throw 'Marker evidence must contain only ASCII-compatible JSON.'
    }

    $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    $document = [System.Text.Json.JsonDocument]::Parse($text)
    try {
        $expectedNames = @(
            'schemaVersion',
            'computerName',
            'markerPath',
            'markerSha256',
            'markerLength',
            'verificationMethod'
        )
        $properties = @($document.RootElement.EnumerateObject())
        $propertyNames = @($properties | ForEach-Object Name)
        $uniqueNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::Ordinal
        )
        foreach ($propertyName in $propertyNames) {
            [void]$uniqueNames.Add($propertyName)
        }
        if ($propertyNames.Count -ne $expectedNames.Count -or
            $uniqueNames.Count -ne $expectedNames.Count -or
            @($propertyNames | Where-Object { $_ -cnotin $expectedNames }).Count -gt 0) {
            throw 'Marker evidence properties are not exact.'
        }
        foreach ($property in $properties) {
            $expectedKind = if ($property.Name -in 'schemaVersion', 'markerLength') {
                [System.Text.Json.JsonValueKind]::Number
            }
            else {
                [System.Text.Json.JsonValueKind]::String
            }
            if ($property.Value.ValueKind -ne $expectedKind) {
                throw 'Marker evidence property types are not exact.'
            }
        }

        [pscustomobject][ordered]@{
            schemaVersion = $document.RootElement.GetProperty('schemaVersion').GetInt32()
            computerName = $document.RootElement.GetProperty('computerName').GetString()
            markerPath = $document.RootElement.GetProperty('markerPath').GetString()
            markerSha256 = $document.RootElement.GetProperty('markerSha256').GetString()
            markerLength = $document.RootElement.GetProperty('markerLength').GetInt64()
            verificationMethod = $document.RootElement.GetProperty('verificationMethod').GetString()
        }
    }
    finally {
        $document.Dispose()
    }
}

function Get-SetupCmMarkerPublishedEvidenceAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Contract,
        [Parameter(Mandatory)]$Inventory,
        [datetime]$NowUtc = (Get-Date).ToUniversalTime(),
        [Nullable[datetime]]$MinimumReceiptUtc
    )

    $evidence = Get-SetupCmMarkerValue -InputObject $Inventory -Name Evidence
    if ($null -eq $evidence -or
        -not [bool](Get-SetupCmMarkerValue -InputObject $evidence -Name Exists -DefaultValue $false)) {
        return [pscustomobject][ordered]@{
            State = 'NotCompliant'
            Reason = 'ClientEvidencePending'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'ClientEvidencePending'
            ReceiptTimeUtc = $null
            OwnerSid = ''
        }
    }
    if (-not [string]::IsNullOrWhiteSpace([string](Get-SetupCmMarkerValue `
                -InputObject $evidence -Name ReadError))) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceReadUnavailable'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'ProbeUnavailable'
            ReceiptTimeUtc = $null
            OwnerSid = ''
        }
    }

    $ownerSid = [string](Get-SetupCmMarkerValue -InputObject $evidence -Name OwnerSid)
    if ([bool](Get-SetupCmMarkerValue `
            -InputObject $evidence -Name IsReparsePoint -DefaultValue $false)) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceReparsePoint'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }
    $targetComputerSid = [string](Get-SetupCmMarkerValue `
        -InputObject $Inventory -Name TargetComputerSid)
    if ([string]::IsNullOrWhiteSpace($ownerSid) -or
        [string]::IsNullOrWhiteSpace($targetComputerSid) -or
        $ownerSid -cne $targetComputerSid) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceOwnerMismatch'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }
    if (-not [bool](Get-SetupCmMarkerValue `
            -InputObject $evidence -Name AclExact -DefaultValue $false)) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceAclMismatch'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }

    $bytes = [byte[]](Get-SetupCmMarkerValue -InputObject $evidence -Name Bytes)
    $evidenceLength = [long](Get-SetupCmMarkerValue `
        -InputObject $evidence -Name Length -DefaultValue -1)
    if ($evidenceLength -ne $bytes.Count -or
        $evidenceLength -gt [long]$Contract.EvidenceChannel.MaximumBytes) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceLengthMismatch'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }

    try {
        $record = ConvertFrom-SetupCmMarkerEvidenceJsonStrict `
            -Bytes $bytes
    }
    catch {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceMalformed'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }
    $recordExact =
        [int]$record.schemaVersion -eq [int]$Contract.EvidenceChannel.SchemaVersion -and
        [string]$record.computerName -ieq [string]$Contract.TargetName -and
        [string]$record.markerPath -ceq [string]$Contract.MarkerPath -and
        [string]$record.markerSha256 -ceq [string]$Contract.MarkerHash -and
        [long]$record.markerLength -eq [long]$Contract.MarkerLength -and
        [string]$record.verificationMethod -ceq [string]$Contract.EvidenceChannel.VerificationMethod
    if (-not $recordExact) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceRecordMismatch'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
            OwnerSid = $ownerSid
        }
    }

    $receiptValue = Get-SetupCmMarkerValue -InputObject $evidence -Name LastWriteTimeUtc
    if ($receiptValue -isnot [datetime]) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceReceiptUnavailable'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = $null
            OwnerSid = $ownerSid
        }
    }
    $receiptTimeUtc = ([datetime]$receiptValue).ToUniversalTime()
    if ($receiptTimeUtc -gt $NowUtc.ToUniversalTime().AddMinutes(
            [int]$Contract.EvidenceChannel.FutureToleranceMinutes)) {
        return [pscustomobject][ordered]@{
            State = 'Conflict'
            Reason = 'EvidenceReceiptInFuture'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'EvidenceConflict'
            ReceiptTimeUtc = $receiptTimeUtc
            OwnerSid = $ownerSid
        }
    }
    if ($receiptTimeUtc -lt $NowUtc.ToUniversalTime().AddMinutes(
            -[int]$Contract.EvidenceChannel.FreshnessMinutes)) {
        return [pscustomobject][ordered]@{
            State = 'NotCompliant'
            Reason = 'ClientEvidencePending'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'ClientEvidencePending'
            ReceiptTimeUtc = $receiptTimeUtc
            OwnerSid = $ownerSid
        }
    }
    if ($null -ne $MinimumReceiptUtc -and
        $receiptTimeUtc -lt ([datetime]$MinimumReceiptUtc).ToUniversalTime()) {
        return [pscustomobject][ordered]@{
            State = 'NotCompliant'
            Reason = 'ClientEvidencePending'
            MarkerHash = ''
            MarkerLength = 0L
            MarkerHashVerification = 'ClientEvidencePending'
            ReceiptTimeUtc = $receiptTimeUtc
            OwnerSid = $ownerSid
        }
    }

    [pscustomobject][ordered]@{
        State = 'Compliant'
        Reason = 'Exact'
        MarkerHash = [string]$record.markerSha256
        MarkerLength = [long]$record.markerLength
        MarkerHashVerification = 'DirectAuthenticatedClientEvidence'
        ReceiptTimeUtc = $receiptTimeUtc
        OwnerSid = $ownerSid
    }
}
