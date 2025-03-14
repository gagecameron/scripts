################################################################################################################################################
# Active Directory Shadow Group Assignment - Microsoft Certificate Autoenrollment - version 1.0 [10-Apr-2024]
#
# USE AT YOUR OWN RISK. The use of this script is done at your own discretion and risk and with agreement that you will be
# solely responsible for any damage to your computer system or loss of data that results from such activities. You are
# solely responsible for adequate protection and backup of the data and equipment used in connection with any of the software,
# and we will not be liable for any damages that you may suffer in connection with using, modifying or distributing any of this software.
# No advice or information, whether oral or written, obtained by you from us or from this website shall create any warranty for the software.
#
################################################################################################################################################
##############################################################################################
#
# Dependencies: This script requires the Active Directory PowerShell module:
#               Install-Module -Name ActiveDirectory
#
##############################################################################################
##############################################################################################
# DO NOT UNCOMMENT THIS SECTION
# Create Scheduled Task - Run either of the below SCHTASKS commmand independently
# of this script, in either an Administrative cmd or PowerShell prompt.
##############################################################################################
<#

Run the below command to synch Shadow Groups every 10 Minutes

SCHTASKS /Create /TN "AD-ShadowGroups-Autoenroll" /SC MINUTE /mo 10 /TR 'powershell.exe -NoProfile -ExecutionPolicy bypass -File "C:\AD_Scripts\AD-ShadowGroups-Autoenroll.ps1"' /RU "NT AUTHORITY\SYSTEM" /RL HIGHEST

Run the below command to synch Shadow Groups every 5 Minutes

SCHTASKS /Create /TN "AD-ShadowGroups-Autoenroll" /SC MINUTE /mo 5 /TR 'powershell.exe -NoProfile -ExecutionPolicy bypass -File "C:\AD_Scripts\AD-ShadowGroups-Autoenroll.ps1"' /RU "NT AUTHORITY\SYSTEM" /RL HIGHEST

#>
######################################################################
# Specify the secondary group names
######################################################################

$serverGroupName = "Autoenroll-Servers"
$workstationGroupName = "Autoenroll-Computers"

######################################################################
# Retrieve Domain Computers group
######################################################################

$domainComputersGroup = Get-ADGroup -Filter {Name -eq "Domain Computers"}

######################################################################
# Check if the Domain Computers group exists
######################################################################

if ($domainComputersGroup -eq $null) {
    Write-Host "Domain Computers group not found. Please make sure it exists."
    exit
}

######################################################################
# Retrieve computers from Domain Computers group
######################################################################

$computers = Get-ADGroupMember -Identity $domainComputersGroup

######################################################################
# Loop through each computer and add to appropriate secondary group 
# based on OperatingSystem attribute
######################################################################

foreach ($computer in $computers) {
    $computerDetails = Get-ADComputer -Identity $computer.Name -Properties OperatingSystem

    if ($computerDetails.OperatingSystem -like "Windows Server*") {
        # Add the computer to the server group
        Add-ADGroupMember -Identity $serverGroupName -Members $computer
        # Write-Host "Added $($computer.Name) to group $serverGroupName."
    }
    elseif (($computerDetails.OperatingSystem -like "Windows 10*") –or ($computerDetails.OperatingSystem -like 'Windows 11*')) {
        # Add the computer to the workstation group
        Add-ADGroupMember -Identity $workstationGroupName -Members $computer
        # Write-Host "Added $($computer.Name) to group $workstationGroupName."
    }
}

exit

