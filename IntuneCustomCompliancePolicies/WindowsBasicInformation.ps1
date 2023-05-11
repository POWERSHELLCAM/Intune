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

$cs=Get-WMIObject -class Win32_ComputerSystem
$os=Get-WMIObject win32_operatingsystem
$bs=Get-WmiObject win32_bios
$bl=Get-BitLockerVolume -MountPoint c:
$lp=Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%'" | Where-Object { $_.PartialProductKey } | Select-Object Description, LicenseStatus
$updatecount=((New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search("IsHidden=0 and IsInstalled=0").Updates).count
$result=[PSCustomObject]@{
    Name=$env:COMPUTERNAME
    OS=$os.Caption
    'OS Version'=$os.Version
    'OS Install Date'=([WMI]'').ConvertToDateTime($os.InstallDate)
    Make=$cs.Manufacturer
    Model=$cs.model
    'Physical Memory(GB)'=[int](($cs.TotalPhysicalMemory)/1gb)
    Serial=$bs.serialnumber
    'BIOS Version'=$bs.Version
    'OS Uptime' = [int64](new-timespan -start $(Get-CIMInstance -Class CIM_OperatingSystem).LastBootUpTime -end $(get-date)).Days
    'OSDisk Free Space'=[math]::Round((Get-PSDrive -Name C).Free / 1Gb)
    'Antivirus Presence'=if(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct){"Yes"}else{"No"}
    'Pending Update'=if($updatecount -ne 0){"Yes"}else{"No"}
    'Encryption State'=[string]($bl.VolumeStatus)
    'License Type' = $lp.Description
    'License Status'=if($lp.LicenseStatus -eq 1){"Activated"}else{"Not-Activated"}
    'TPM Chip Present'=if((Get-Tpm).tpmpresent){"Present"}else{"Absent"}
    'Tanium'=if(Get-Package -Name "*tanium client*"){"Present"}else{"Absent"}
    'Zscaler'=if(Get-Package -Name "*Zscaler*"){"Present"}else{"Absent"}
    'Sentinel'=if(Get-Package -Name "*Sentinel agent*"){"Present"}else{"Absent"}
    'SecureBoot'=if(Confirm-SecureBootUEFI){"Enabled"}else {"Disabled"}
    'Firmware Type'=$env:firmware_type
    'Sync Service'= [string]$((get-service dmwappushservice).starttype)
    'MECM Agent'=memcclientState
}
return $result | ConvertTo-Json -Compress
