# PowerShell script authored by Sean Metcalf (@PyroTek3)
# 2025-09-12
# Script provided as-is

Param
 (
    $Domain = $env:userdnsdomain
 )

$DomainDC = (Get-ADDomainController -Discover -DomainName $Domain).Name
$DomainInfo = Get-ADDomain -Server $DomainDC


$DomainDC = Get-ADDomainController -Discover -DomainName $Domain

$TrustArray = Get-ADTrust -filter * -Server $DomainDC

$TrustArray | Where {$_.IntraForest -eq $False} | Select Direction,Source,Target,UsesAESKeys,SIDFilteringForestAware,SIDFilteringQuarantined,TGTDelegation | Format-Table -AutoSize

