# PowerShell script authored by Sean Metcalf (@PyroTek3)
# 2026-02-26
# Last Updated: 2026-02-27
# Script provided as-is

Param
 (
    $Domain = $env:userdnsdomain,
    [switch]$CheckADAdmins,
    [switch]$AllUsers
 )

IF ( ($CheckADAdmins -eq $False) -AND ($AllUsers -eq $False) )
 { $CheckADAdmins = $True }

$DomainDC = (Get-ADDomainController -Discover -DomainName $Domain).Name
$DomainInfo = Get-ADDomain -Server $DomainDC

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
    $ADAccountMetaDataVauleArray = Get-ADReplicationAttributeMetadata -Server $DomainDC -Object $ADAccountArrayItem.DistinguishedName -prop unicodepwd,pwdlastset
    $ADAccountMetaDataVauleArrayPwdLastSet = $ADAccountMetaDataVauleArray | Where {$_.AttributeName -eq 'pwdLastSet'}
    $ADAccountMetaDataVauleArrayunicodePwd = $ADAccountMetaDataVauleArray | Where {$_.AttributeName -eq 'unicodePwd'}

    $ADAccountMetaDataVauleArrayPwdLastSetDate = ($ADAccountMetaDataVauleArrayPwdLastSet.LastOriginatingChangeTime).ToString('yyyy-MM-dd')
    $ADAccountMetaDataVauleArrayunicodePwdPwdDate = ($ADAccountMetaDataVauleArrayunicodePwd.LastOriginatingChangeTime).ToString('yyyy-MM-dd')


    IF ($ADAccountMetaDataVauleArrayPwdLastSetDate -eq $ADAccountMetaDataVauleArrayunicodePwdPwdDate)
     { $DidPasswordChangeValue = $True }
    ELSE
     { $DidPasswordChangeValue = $False }

    $ADAccountMetaDataRecord = [PSCustomObject]@{
        AccountID           = $ADAccountArrayItem.SAMAccountName
        AccountDN             = $ADAccountArrayItem.DistinguishedName
        PasswordLastSet        = $ADAccountMetaDataVauleArrayPwdLastSet.LastOriginatingChangeTime
        PasswordLastChanged     = $ADAccountMetaDataVauleArrayunicodePwd.LastOriginatingChangeTime
        PasswordChanged   = $DidPasswordChangeValue
      }
    $ADAccountMetaDataArray += $ADAccountMetaDataRecord
 }

IF ($CheckADAdmins -eq $True)
 { 
    Write-Host "$Domain AD Admin Account Password Changes:" -ForegroundColor Cyan
    $ADAccountMetaDataArray | Sort AccountID | Format-Table -AutoSize
 }

IF ($AllUsers -eq $True)
 { 
    Write-Host "$Domain Domain Accounts with Fake Password Changes:" -ForegroundColor Cyan
    $ADAccountMetaDataArray | Where {$_.PasswordChanged -eq $False} | Sort AccountID | Format-Table -AutoSize
 }