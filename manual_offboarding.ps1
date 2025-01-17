# Import benodigde inloggegevens
$vcenter = "vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"

# Configure PowerCLI
Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Warn

param(
    [Parameter(Mandatory=$true)]
    [string]$Voornaam,
    
    [Parameter(Mandatory=$true)]
    [string]$Achternaam
)

Write-Host "Start offboarding voor $Voornaam $Achternaam..."

# Controleer of gebruiker bestaat
$samAccountName = "$Voornaam $Achternaam"
$gebruiker = Get-ADUser -Filter {SamAccountName -eq $samAccountName}

if ($gebruiker) {
    # 1. VM uitzetten en verwijderen
    Connect-VIServer $vcenter -Credential $vcentercred
    $vmnaam = "ws-$Voornaam-$Achternaam"
    
    $vm = Get-VM -Name $vmnaam -ErrorAction SilentlyContinue
    if ($vm) {
        Stop-VM -VM $vm -Confirm:$false
        Remove-VM -VM $vm -DeletePermanently -Confirm:$false
        Write-Host "VM $vmnaam is verwijderd"
    }
    
    Disconnect-VIServer -Server $vcenter -Confirm:$false

    # 2. AD account uitschakelen en verplaatsen
    Disable-ADAccount -Identity $gebruiker
    Move-ADObject -Identity $gebruiker.DistinguishedName -TargetPath "OU=Disabled Users,DC=mijden,DC=lan"
    Write-Host "AD account $samAccountName is uitgeschakeld en verplaatst"

    Write-Host "Offboarding voltooid voor $samAccountName"
}
else {
    Write-Host "Gebruiker $samAccountName niet gevonden"
}
