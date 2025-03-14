# Define the two AE servers you host (replace with your actual server hostnames/FQDNs)
$aeServer1 = "aeserver1.example.com"
$aeServer2 = "aeserver2.example.com"

# Define the local machine name (member server) for reporting
$localMachine = $env:COMPUTERNAME

# Define OCSP/CRL targets from documentation (for domain members)
$ocspCrlUrls = @(
    "http://ocsp.one.digicert.com",
    "http://crl.one.digicert.com",
    "http://cacerts.one.digicert.com"
)

$ocspCrlIP = "216.168.244.38"

# Define ports required for AE servers (from domain members)
$aeServerPorts = @{
    "RPC_Endpoint" = 135    # RPC Endpoint Mapper for DCOM/RPC
    # Note: Dynamic range 49152-65535 is implied but not fully tested due to impracticality
}

# Function to test TCP port connectivity
function Test-Port {
    param (
        [string]$ComputerName,
        [int]$Port,
        [string]$Protocol
    )
    
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect($ComputerName, $Port)
        $tcp.Close()
        return [PSCustomObject]@{
            Source = $localMachine
            Target = $ComputerName
            Port = $Port
            Protocol = $Protocol
            Status = "Success"
            Error = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            Source = $localMachine
            Target = $ComputerName
            Port = $Port
            Protocol = $Protocol
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
}

# Initialize results array
$results = @()

Write-Host "Testing connectivity from member server $localMachine to OCSP/CRL and AE servers..." -ForegroundColor Green

# Test OCSP/CRL URLs
foreach ($url in $ocspCrlUrls) {
    $uri = [System.Uri]$url
    $port = 80  # All OCSP/CRL URLs use HTTP/80
    $hostName = $uri.Host
    
    $results += Test-Port -ComputerName $hostName -Port $port -Protocol "HTTP"
}

# Test OCSP/CRL IP
$results += Test-Port -ComputerName $ocspCrlIP -Port 80 -Protocol "HTTP"

# Test connectivity to hosted AE servers
foreach ($aeServer in @($aeServer1, $aeServer2)) {
    foreach ($port in $aeServerPorts.GetEnumerator()) {
        $results += Test-Port -ComputerName $aeServer -Port $port.Value -Protocol $port.Key
    }
    # Optional: Test AE server responsiveness with a ping
    $pingResult = Test-Connection -ComputerName $aeServer -Count 2 -Quiet
    $results += [PSCustomObject]@{
        Source = $localMachine
        Target = $aeServer
        Port = "N/A"
        Protocol = "ICMP"
        Status = if ($pingResult) { "Success" } else { "Failed" }
        Error = if ($pingResult) { $null } else { "Ping failed" }
    }
}

# Display results
$results | Format-Table -AutoSize -Property Source, Target, Port, Protocol, Status, Error

# Save results to CSV
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$results | Export-Csv -Path "MemberServer_Connectivity_Test_$localMachine_$timestamp.csv" -NoTypeInformation

Write-Host "Test completed. Results saved to MemberServer_Connectivity_Test_$localMachine_$timestamp.csv" -ForegroundColor Green

# Check for failures
$failures = $results | Where-Object { $_.Status -eq "Failed" }
if ($failures) {
    Write-Host "WARNING: The following connectivity tests failed:" -ForegroundColor Yellow
    $failures | Format-Table -AutoSize
} else {
    Write-Host "All connectivity tests passed successfully!" -ForegroundColor Green
}