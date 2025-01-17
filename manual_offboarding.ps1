$vcenter = "vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"

while ($true) {
    $Response = Invoke-RestMethod http://10.3.0.40:8085/offboard
    
    if ($Response.data.Voornaam) {
        $voornaam = $Response.data.Voornaam
        $achternaam = $Response.data.Achternaam
        
        Write-Host "Start offboarding voor $voornaam $achternaam"
        
        Connect-VIServer $vcenter -Credential $vcentercred
        $vm = Get-VM -Name "ws-$voornaam-$achternaam" -ErrorAction SilentlyContinue
        if ($vm) {
            Stop-VM -VM $vm -Confirm:$false
            Remove-VM -VM $vm -DeletePermanently -Confirm:$false
        }
        Disconnect-VIServer -Server $vcenter -Confirm:$false


        Invoke-Command -ComputerName '10.3.0.2' -ScriptBlock { 
            $computerName = "ws-$using:voornaam-$using:achternaam"
            Remove-Computer -Name $computerName -Force -RemoveFromDomain
            Remove-ADUser -Identity "$using:voornaam $using:achternaam" -Confirm:$false
            Write-Host "Verwijdering van $using:voornaam $using:achternaam is gelukt."
        }

        Write-Host "Wacht op gegevens voor offboarding..."
    
    Start-Sleep -Seconds 30
}
}