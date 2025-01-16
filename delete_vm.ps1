$vcenter="vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
$wscred = Import-Clixml -Path "C:\Users\admin\Documents\ws_credentials.xml"
$wscred | Format-List

Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Warn
$datastore="NIM01-1"
$passdc = $dccred.Password

$eersteGebruiker = Invoke-Command -ComputerName 10.3.0.2 -Credential $dccred -ScriptBlock {
    $pad = "C:\Users\Administrator\Documents\users.csv"
    $users = Import-Csv -Path $pad
    
    # Geef de eerste gebruiker terug
    $users | Select-Object -First 1
}

# Nu kun je de $eersteGebruiker variabele gebruiken op je lokale machine
if ($eersteGebruiker) {
    $voornaam = $eersteGebruiker.Voornaam
    $achternaam = $eersteGebruiker.Achternaam

    
    Write-Host "Eerste gebruiker: Voornaam: $voornaam, Achternaam: $achternaam"
} else {
    Write-Host "Geen gebruikers gevonden in het CSV-bestand."
}

Connect-VIServer $vcenter -Credential $vcentercred
Start-Sleep -Seconds 60

$vmnaam= "ws-$voornaam$achternaam"
$hostname="ws-$voornaam$achternaam"
$password = "Mike123"
$serverNameOrIp = "test"
$userdc = $dccred.UserName
$domein = "mijden.lan"
$ip= "10.2.0.32"
$credential = New-Object System.Management.Automation.PSCredential ("admin", $wscred.Password)

Write-host $credential.Password

# Zoek de VM op die we willen uitschakelen en verwijderen
$vm = Get-VM -Name $vmnaam

# Zorg ervoor dat de VM eerst wordt uitgeschakeld
if ($vm.PowerState -eq "PoweredOn") {
    Write-Host "VM $vmnaam wordt uitgeschakeld..."
    Stop-VM -VM $vm -Force -Confirm:$false
    Start-Sleep -Seconds 60
} else {
    Write-Host "VM $vmnaam is al uitgeschakeld."
}

# Verwijder de VM
Write-Host "Verwijderen van VM $vmnaam..."
Remove-VM -VM $vm -DeletePermanently -Confirm:$false

# Verbreek de verbinding met de vCenter-server
Disconnect-VIServer -Server $vcenter -Confirm:$false
Write-Host "Script voltooid."
