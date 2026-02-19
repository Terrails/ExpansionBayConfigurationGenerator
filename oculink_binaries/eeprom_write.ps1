param(
    [Parameter(Mandatory=$false)]
    [string]$binFile = "eeprom.bin",
    [Parameter(Mandatory=$false)]
    [Switch]$verifyOnly = $false
)

# === PARAMETERS ===
$exePath = Resolve-Path "ectool.exe"
$binFile = Resolve-Path $binFile
# The port that the EEPROM is on (for FW16 it's 5)
$port = 5
# The "slave address" of the EEPROM
$addr = 0x50
# ectool has issues with writing too many bytes at once, so split into specified chunks
# How many bytes to write at once
$chunkSize = 8
# How much to wait between each write (just so it doesn't spam the EC at once)
$writeDelayMs = 20

# === READ FILE ===
$data = [System.IO.File]::ReadAllBytes($binFile)
$totalBytes = $data.Length

# === WRITE (write in chunks) ===
if (-not $verifyOnly) {
    Write-Host ("Flashing EEPROM: {0} bytes from {1}" -f $totalBytes, $binFile)

    for ($offset = 0; $offset -lt $totalBytes; $offset += $chunkSize) {

        $currentChunk = $data[$offset..([math]::Min($offset + $chunkSize - 1, $totalBytes - 1))]

        # Convert bytes to hex strings
        $hexBytes = $currentChunk | ForEach-Object { "0x{0:X2}" -f $_ }

        # i2cxfer args: port, addr, read=0, write=0, offset, then chunk bytes
        $cmdArgs = @("i2cxfer", $port, $addr, 0, 0, $offset) + $hexBytes

        Write-Verbose ("Writing {0} bytes at EEPROM offset 0x{1:X4}" -f $hexBytes.Count, $offset)
        & $exePath @cmdArgs | Write-Verbose

        Start-Sleep -Milliseconds $writeDelayMs
    }

    Write-Host "EEPROM write complete!"
}

# === VERIFY ===
$cmdArgs = @("i2cxfer", $port, $addr, $totalBytes, 0, 0)
$output = & $exePath @cmdArgs 2>&1 | Out-String

# Parse hex bytes (handles 0xNN and NN formats)
$readBytes = @()
foreach ($tok in $output -split '\s+') {
    if ($tok -match '^0x([0-9A-Fa-f]{1,2})$') {
        $readBytes += [Convert]::ToByte($matches[1],16)
    } elseif ($tok -match '^[0-9A-Fa-f]{2}$') {
        $readBytes += [Convert]::ToByte($tok,16)
    }
}

# Compare expected vs read
$errors = @()
for ($i = 0; $i -lt $totalBytes; $i++) {
    if ($i -ge $readBytes.Count -or $readBytes[$i] -ne $data[$i]) {
        $errors += [PSCustomObject]@{
            Offset = $i
            Expected = $data[$i]
            Read = if ($i -ge $readBytes.Count) { 0xFF } else { $readBytes[$i] }
        }
    }
}

if ($errors.Count -eq 0) {
    Write-Host "EEPROM verification PASSED! All bytes match."
} else {
    Write-Host ("EEPROM verification FAILED: {0} mismatched bytes!" -f $errors.Count)
    foreach ($e in $errors) {
        Write-Verbose ("Offset 0x{0:X4}: expected {1:X2}, read {2:X2}" -f $e.Offset, $e.Expected, $e.Read)
    }
}
