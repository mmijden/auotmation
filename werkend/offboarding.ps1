
$vcenter = "vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
$wscred = Import-Clixml -Path "C:\Users\admin\Documents\ws_credentials.xml"

Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Warn
$datastore = "NIM01-1"
$passdc = $dccred.Password


$gebruikers = Import-Csv -Path "C:\Users\admin\Documents\offboard.csv"

t
foreach ($gebruiker in $gebruikers) {
    $voornaam = $gebruiker.Voornaam
    $achternaam = $gebruiker.Achternaam

    Write-Host "Verwerk gebruiker: $voornaam $achternaam"

   
    $vmnaam = "ws-$voornaam$achternaam"
    $hostname = "ws-$voornaam$achternaam"
    $serverNameOrIp = "test"
    $domein = "mijden.lan"
    

    
    Connect-VIServer $vcenter -Credential $vcentercred
    Start-Sleep -Seconds 60

    
    $vm = Get-VM -Name $vmnaam

    
    if ($vm.PowerState -eq "PoweredOn") {
        Write-Host "VM $vmnaam wordt uitgeschakeld..."
        Stop-VM -VM $vm -Confirm:$false
        Write-Host "Wachten totdat de VM $vmnaam volledig is uitgeschakeld..."

        
        while ($vm.PowerState -eq "PoweredOn") {
            Start-Sleep -Seconds 10
            $vm = Get-VM -Name $vmnaam  
            Write-Host "De VM is nog steeds ingeschakeld, opnieuw controleren..."
        }

        Write-Host "VM $vmnaam is nu uitgeschakeld."
    } else {
        Write-Host "VM $vmnaam is al uitgeschakeld."
    }


    Write-Host "Verwijderen van VM $vmnaam..."
    Remove-VM -VM $vm -DeletePermanently -Confirm:$false

    
    Disconnect-VIServer -Server $vcenter -Confirm:$false

 
    $scriptblock = {
        param($voornaam, $achternaam, $hostname, $domein)

        Import-Module ActiveDirectory


        $samAccountName = "$voornaam $achternaam"

        $user = Get-ADUser -Filter {SamAccountName -eq $samAccountName} -ErrorAction SilentlyContinue
        if ($user) {
            Write-Host "Verwijderen van gebruiker uit AD: $samAccountName"
            Remove-ADUser -Identity $user -Confirm:$false
        } else {
            Write-Host "Gebruiker $samAccountName bestaat niet in AD."
        }

        $computer = Get-ADComputer -Filter {Name -eq "$hostname"} -ErrorAction SilentlyContinue
        if ($computer) {
            Write-Host "Verwijderen van computer uit AD: $hostname"
            Remove-ADComputer -Identity $computer -Confirm:$false
        } else {
            Write-Host "Computer $hostname bestaat niet in AD."
        }
    }

    Invoke-Command -ComputerName 10.3.0.2 -Credential $dccred -ScriptBlock $scriptblock -ArgumentList $voornaam, $achternaam, $hostname, $domein

    Write-Host "Offboarding voor $voornaam $achternaam voltooid."
}

Write-Host "Alle gebruikers zijn afgehandeld."
