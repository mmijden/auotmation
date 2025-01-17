# Import benodigde inloggegevens
$vcenter = "vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"

# Configure PowerCLI
Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Warn

# Oneindige loop om te blijven checken voor offboarding verzoeken
while ($true) {
    try {
        # Ophalen offboarding verzoeken van API
        $Response = Invoke-RestMethod http://10.3.0.40:8085/offboard
        
        # Voor elke gebruiker die offboard moet worden
        foreach ($user in $response.data) {
            $voornaam = $user.Voornaam
            $achternaam = $user.Achternaam
            $samAccountName = "$voornaam $achternaam"
            
            # Controleer of gebruiker bestaat
            $gebruiker = Get-ADUser -Filter {SamAccountName -eq $samAccountName}
            
            if ($gebruiker) {
                Write-Host "Start offboarding voor $samAccountName..."

                # 1. VM uitzetten en verwijderen
    Connect-VIServer $vcenter -Credential $vcentercred
                $vmnaam = "ws-$voornaam-$achternaam"

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
        }
}
catch {
        Write-Host "Fout opgetreden: $_"
    }
    
    Write-Host "Wacht op nieuwe offboarding verzoeken..."
    Start-Sleep -Seconds 30
}
