# Define the list of Domain Controllers
$DomainControllers = @(
    "dc01.contoso.com",
    "dc02.contoso.com",
    "dc03.contoso.com",
    "dc04.contoso.com",
    "dc05.contoso.com",
    "dc06.contoso.com"
)

# Define the list of ports and their descriptions
$Ports = @{
    135   = "RPC Endpoint Mapper (TCP)"
    389   = "LDAP (TCP/UDP)"
    636   = "LDAP SSL (TCP)"
    3268  = "LDAP GC (TCP)"
    3269  = "LDAP GC SSL (TCP)"
    53    = "DNS (TCP/UDP)"
    88    = "Kerberos (TCP/UDP)"
    445   = "SMB (TCP)"
    464   = "Kerberos Password Change (TCP/UDP)"
    123   = "W32Time (UDP)"
}

# Function to test connectivity to a specific port
function Test-Port {
    param (
        [string]$ComputerName,
        [int]$Port,
        [string]$Protocol
    )
    try {
        if ($Protocol -eq "UDP") {
            $endpoint = New-Object System.Net.IPEndPoint ([System.Net.Dns]::GetHostAddresses($ComputerName)[0], $Port)
            $udpClient = New-Object System.Net.Sockets.UdpClient
            $udpClient.Connect($endpoint)
            $udpClient.Close()
        } else {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($ComputerName, $Port)
            $tcpClient.Close()
        }
        return $true
    } catch {
        return $false
    }
}

# Iterate over each Domain Controller and test each port
foreach ($dc in $DomainControllers) {
    Write-Host "Testing connectivity to $dc" -ForegroundColor Green
    foreach ($port in $Ports.Keys) {
        $service = $Ports[$port]
        $protocols = if ($service -match 'TCP/UDP') { @("TCP", "UDP") } else { @($service -split ' ')[-1] }
        foreach ($protocol in $protocols) {
            $result = Test-Port -ComputerName $dc -Port $port -Protocol $protocol
            if ($result) {
                $status = "Open"
                $color = "Cyan"
            } else {
                $status = "Closed or Unreachable"
                $color = "Red"
            }
            Write-Host "Port $port ($protocol) - ${service}: $status" -ForegroundColor $color
        }
    }
    Write-Host ""
}
