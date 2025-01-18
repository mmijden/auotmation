$vcenter = "vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"

function Remove-UserResources {
    $dccred = Import-Clixml -Path "C:\Users\admin\Documents\dccredentials.xml"
    
    $userData = Invoke-RestMethod -Uri "http://10.3.0.40:8085/Staff" -Method Get

    if ($userData -and $userData.voornaam -and $userData.achternaam) {
        $voornaam = $userData.voornaam
        $achternaam = $userData.achternaam
        $vmnaam = "ws-$voornaam$achternaam"
        $vm = Get-VM -Name $vmnaam -ErrorAction SilentlyContinue

        if ($vm) {
            Write-Host "Verwijderen van VM: $vmnaam"
            Remove-VM -VM $vm -Confirm:$false
        } else {
            Write-Host "Geen VM gevonden voor gebruiker: $voornaam $achternaam"
        }

        Invoke-Command -ComputerName 10.3.0.2 -Credential $dccred -ScriptBlock {
            
            Remove-ADUser -Identity "$($using:voornaam) $($using:achternaam)" -Confirm:$false
            $computerName = $vmnaam 
            Start-Sleep -Seconds 30
            Remove-ADComputer -Identity $using:computerName -Confirm:$false
        }
        }
    } else {
        Write-Host "Fout: Geen geldige voornaam of achternaam ontvangen van de API."
    }


Connect-VIServer -Server $vcenter -Credential $vcentercred

Remove-UserResources

Disconnect-VIServer -Server $vcenter -Confirm:$false