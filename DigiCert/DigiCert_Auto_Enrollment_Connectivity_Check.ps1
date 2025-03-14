# Define the two AE servers you host (replace with your actual server hostnames/FQDNs)
$aeServer1 = "ae1.contoso.com"
$aeServer2 = "ae2.contoso.com"

# Define the local machine name for reporting
$localMachine = $env:COMPUTERNAME

# Define DigiCert service targets from documentation
$digicertUrls = @(
    "https://one.digicert.com",              # AE Server to DC1 Web Services (HTTPS/443)
    "https://clientauth.one.digicert.com",   # AE Server to DC1 Web Services (HTTPS/443)
    "http://ocsp.one.digicert.com",          # OCSP/CRL (HTTP/80)
    "http://crl.one.digicert.com",           # OCSP/CRL (HTTP/80)
    "http://cacerts.one.digicert.com"        # OCSP/CRL (HTTP/80)
)

$digicertIPs = @(
    "45.60.44.211",    # DigiCert CA IPs (HTTPS/443)
    "45.60.46.211",
    "45.60.48.211",
    "45.60.50.211",
    "45.60.52.211",
    "45.60.105.211",
    "216.168.244.38"   # OCSP/CRL IP (HTTP/80)
)

# Define ports required for AE servers (based on documentation for domain member communication)
$aeServerPorts = @{
    "RPC_Endpoint" = 135    # RPC Endpoint Mapper for DCOM/RPC from domain members to AE servers
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

Write-Host "Testing connectivity from $localMachine to DigiCert services and hosted AE servers..." -ForegroundColor Green

# Test DigiCert URLs
foreach ($url in $digicertUrls) {
    $uri = [System.Uri]$url
    $port = if ($uri.Scheme -eq "https") { 443 } else { 80 }
    $hostName = $uri.Host
    
    $results += Test-Port -ComputerName $hostName -Port $port -Protocol $uri.Scheme
}

# Test DigiCert IPs
foreach ($ip in $digicertIPs) {
    $results += Test-Port -ComputerName $ip -Port 80 -Protocol "HTTP"
    $results += Test-Port -ComputerName $ip -Port 443 -Protocol "HTTPS"
}

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
$results | Export-Csv -Path "AE_Connectivity_Test_$localMachine_$timestamp.csv" -NoTypeInformation

Write-Host "Test completed. Results saved to AE_Connectivity_Test_$localMachine_$timestamp.csv" -ForegroundColor Green

# Check for failures
$failures = $results | Where-Object { $_.Status -eq "Failed" }
if ($failures) {
    Write-Host "WARNING: The following connectivity tests failed:" -ForegroundColor Yellow
    $failures | Format-Table -AutoSize
} else {
    Write-Host "All connectivity tests passed successfully!" -ForegroundColor Green
}