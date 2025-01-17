# Import benodigde inloggegevens
$vcenter = "vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"

while ($true) {
    $Response = Invoke-RestMethod http://10.3.0.40:8085/offboard
    
    if ($Response.data.Voornaam) {
        $voornaam = $Response.data.Voornaam
        $achternaam = $Response.data.Achternaam
        
        Write-Host "Start offboarding voor $voornaam $achternaam"
        
        # VM uitzetten en verwijderen
        Connect-VIServer $vcenter -Credential $vcentercred
        $vm = Get-VM -Name "ws-$voornaam-$achternaam" -ErrorAction SilentlyContinue
        if ($vm) {
            Stop-VM -VM $vm -Confirm:$false
            Remove-VM -VM $vm -DeletePermanently -Confirm:$false
        }
        Disconnect-VIServer -Server $vcenter -Confirm:$false

        # AD account uitschakelen en verplaatsen
        $gebruiker = Get-ADUser -Filter {SamAccountName -eq "$voornaam $achternaam"}
        if ($gebruiker) {
            Disable-ADAccount -Identity $gebruiker
            Move-ADObject -Identity $gebruiker.DistinguishedName -TargetPath "OU=Disabled Users,DC=mijden,DC=lan"
        }
        
        Write-Host "Klaar met $voornaam $achternaam"
    }
    
    Start-Sleep -Seconds 30
}
