<#
.SYNOPSIS
    Create deployment record in .CSV file.
   
.DESCRIPTION
    This script will create the deployment or autopilot provisiong record. These records will be stored in .CSV file available on shared path. Additionally it will prepare the .HTML report.
.NOTES
    Version: 1.0
    Original Author: Shishir Kushawaha
    Modifiedby: Shishir Kushawaha
    Email: srktcet@gmail.com  
    Date Created: 29-05-2023
#> 

function memcclientState
{
    if(get-service ccmexec -ErrorAction SilentlyContinue)
    {
        if((get-service ccmexec).Status -eq 'Running')
        {
            if(($null -ne (New-Object -ComObject 'Microsoft.SMS.Client').GetAssignedSite()) -and ((New-Object -ComObject 'Microsoft.SMS.Client').GetCurrentManagementPoint()))
            {
                return "Healthy"
            }
            else 
            {
                return 'Unhealthy'
            }
        }
        else 
        {
            return 'Unhealthy'
        }
    }
    else 
    {
        return 'Unhealthy'
    }
}

#region variable declaration
$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$targetpath=""
$DomainUser=""
$domainPassword=""
$securePassword = ConvertTo-SecureString $domainPassword -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($DomainUser, $securePassword)
New-PSDrive -Name 'L' -PSProvider FileSystem -Root $targetpath  -Persist -Credential $Cred
$csvFile="L:\deploymentAndProvisioningRecords.csv"
$cs=Get-WMIObject -class Win32_ComputerSystem
$os=Get-WMIObject win32_operatingsystem
$bs=Get-WmiObject win32_bios
$bl=Get-BitLockerVolume -MountPoint c:
$lp=Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%'" | Where-Object { $_.PartialProductKey } | Select-Object Description, LicenseStatus
$updatecount=((New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search("IsHidden=0 and IsInstalled=0").Updates).count
#--CSS formatting
$test=@'
<style type="text/css">
 h1, h5,h2, th { text-align: left; font-family: Segoe UI;font-size: 13px;}
table { margin: left; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; }
th { background: #0046c3; color: #fff; max-width: 400px; padding: 5px 10px; font-size: 12px;}
td { font-size: 11px; padding: 5px 20px; color: #000; }
tr { background: #b8d1f3; }
tr:nth-child(even) { background: #dae5f4; }
tr:nth-child(odd) { background: #b8d1f3; }
</style>
'@
#endregion variable declaration

$systemDetails=[PSCustomObject]@{
    Name=$env:COMPUTERNAME
    OS=$os.Caption
    'OS Version'=$os.Version
    'OS Install Date'=([WMI]'').ConvertToDateTime($os.InstallDate)
    Make=$cs.Manufacturer
    Model=$cs.model
    'Physical Memory(GB)'=[int](($cs.TotalPhysicalMemory)/1gb)
    Serial=$bs.serialnumber
    'BIOS Version'=$bs.Version
    'Time Zone'=(get-timezone).id
    'Keyboard Layout'=(Get-Culture).displayname
    'System Locale'=(Get-WinSystemLocale).displayname
    'OSDisk Free Space'=[math]::Round((Get-PSDrive -Name C).Free / 1Gb)
    'Encryption State'=[string]($bl.VolumeStatus)
    'License Type' = $lp.Description
    'License Status'=if($lp.LicenseStatus -eq 1){"Activated"}else{"Not-Activated"}
    'TPM Chip Present'=if((Get-Tpm).tpmpresent){"Present"}else{"Absent"}
    'SecureBoot'=if(Confirm-SecureBootUEFI){"Enabled"}else {"Disabled"}
    'Firmware Type'=$env:firmware_type
    'IP Address' = (Get-WmiObject win32_Networkadapterconfiguration | Where-Object { $_.ipaddress -notlike $null }).IPaddress | Select-Object -First 1
    'MAC Address'=(Get-WmiObject win32_networkadapter | Where-Object {$_.physicaladapter -eq $true -and $_.netconnectionstatus -eq 2} ).macaddress
    'MECM Agent'=memcclientState
    'Antivirus Presence'=if(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct){"Yes"}else{"No"}
    'Pending Update'=if($updatecount -ne 0){"Yes"}else{"No"}
}

Export-Csv $csvfile -inputobject $systemDetails -append -Force
if(test-path "L:\deploymentAndProvisioningRecords.html")
{
    remove-item "L:\deploymentAndProvisioningRecords.html" -force
}

start-sleep 10

Import-Csv $csvfile | ConvertTo-html  -Head $test -Body "<h2>All Deployment</h2>" >> "L:\deploymentAndProvisioningRecords.html"

net use L: /delete

