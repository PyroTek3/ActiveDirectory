# PowerShell script authored by Sean Metcalf (@PyroTek3)
# 2026-02-26
# Last Updated: 2026-03-04
# Script provided as-is

Param
 (
    [atring]$Domain = $env:userdnsdomain,
    [switch]$CheckADAdmins,
    [switch]$AllUsers
 )

IF ( ($CheckADAdmins -eq $False) -AND ($AllUsers -eq $False) )
 { [switch]$CheckADAdmins = $True }

[string]$DomainDC = (Get-ADDomainController -Discover -DomainName $Domain).Name
[array]$DomainInfo = Get-ADDomain -Server $DomainDC

IF ($CheckADAdmins -eq $True)
 { 
    Write-Host "Discovering AD Admins..." -ForegroundColor Cyan
    [array]$ADAccountArray = Get-ADGroupMember -Identity 'Administrators' -Recursive -Server $DomainDC  
 }

IF ($AllUsers -eq $True)
 { 
    Write-Host "Discovering All User Accounts..." -ForegroundColor Cyan
    [array]$ADAccountArray = Get-ADUser -Filter * -Server $DomainDC  
 }

Write-Host "Identifying Fake Password Changes for Accounts..." -ForegroundColor Cyan
$ADAccountMetaDataArray = @()
ForEach ($ADAccountArrayItem in $ADAccountArray)
 {
    $ADAccountMetaDataValueArray = Get-ADReplicationAttributeMetadata -Server $DomainDC -Object $ADAccountArrayItem.DistinguishedName -prop unicodepwd,pwdlastset
    $ADAccountMetaDataValueArrayPwdLastSet = $ADAccountMetaDataValueArray | Where {$_.AttributeName -eq 'pwdLastSet'}
    $ADAccountMetaDataValueArrayunicodePwd = $ADAccountMetaDataValueArray | Where {$_.AttributeName -eq 'unicodePwd'}

    $ADAccountMetaDataValueArrayPwdLastSetDate = ($ADAccountMetaDataValueArrayPwdLastSet.LastOriginatingChangeTime).ToString('yyyy-MM-dd')
    $ADAccountMetaDataValueArrayunicodePwdPwdDate = ($ADAccountMetaDataValueArrayunicodePwd.LastOriginatingChangeTime).ToString('yyyy-MM-dd')


    IF ($ADAccountMetaDataValueArrayPwdLastSetDate -eq $ADAccountMetaDataValueArrayunicodePwdPwdDate)
     { $DidPasswordChangeValue = $True }
    ELSE
     { $DidPasswordChangeValue = $False }

    $ADAccountMetaDataRecord = [PSCustomObject]@{
        AccountID              = $ADAccountArrayItem.SAMAccountName
        AccountDN              = $ADAccountArrayItem.DistinguishedName
        PasswordLastSet        = $ADAccountMetaDataValueArrayPwdLastSet.LastOriginatingChangeTime
        PasswordLastChanged    = $ADAccountMetaDataValueArrayunicodePwd.LastOriginatingChangeTime
        PasswordChanged        = $DidPasswordChangeValue
      }
    [array]$ADAccountMetaDataArray += $ADAccountMetaDataRecord
 }

IF ($CheckADAdmins -eq $True)
 { 
    Write-Host "$Domain AD Admin Account Password Changes:" -ForegroundColor Cyan
    $ADAccountMetaDataArray | Sort AccountID | Format-Table -AutoSize
 }

IF ($AllUsers -eq $True)
 { 
    Write-Host "$Domain Domain Accounts with Fake Password Changes:" -ForegroundColor Cyan
    $ADAccountMetaDataArray | Where-Object {$_.PasswordChanged -eq $False} | Sort AccountID | Format-Table -AutoSize
 }