try{
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools 
    Write-Host "AD DS installed successfully"
} catch {
    Write-Host "AD DS installation failed"
    exit 0
}
$domainname = "corp.local"
Import-Module ADDSDeployment
Try{
    Install-ADDSForest -DomainName $domainname -InstallDNS
    Write-Host "AD DS Forest created successfully"
} Catch {
    Write-Host "AD DS Forest creation failed"
    exit 0
}