﻿$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
$dccred = New-Object System.Management.Automation.PSCredential ($dccred.UserName, $dccred.Password)
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$wscred = Import-CliXml -Path "C:\Users\admin\Documents\ws_credentials.xml"

Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Warn
$vcenter = "vcenter.netlab.fontysict.nl"
$datastore = "NIM01-1"
$passdc = $dccred.Password

$processedUsers = @()  # Array to track processed users

while ($true) {
    $response = Invoke-RestMethod -Uri 'http://10.3.0.40:8085/Staff' -Method Get
    Write-Host "API Response: $($response | ConvertTo-Json -Depth 10)"  

    if (-not $response) {
        Write-Host 'Geen gegevens ontvangen, wacht op gegevens'
        Start-Sleep -Seconds 60
    } else {
        foreach ($user in $response.data) {
            if ($user.voornaam -and $user.achternaam -and $user.email -and $user.afdeling) {
                $voornaam = $user.voornaam
                $achternaam = $user.achternaam
                $email = $user.email
                $afdeling = $user.afdeling

                $samAccountName = "$voornaam $achternaam"

                # Controleer of de gebruiker al verwerkt is
                if ($processedUsers -contains $samAccountName) {
                    Write-Host "Gebruiker $samAccountName is al verwerkt."
                    continue
                }

                $wachtwoord = [System.Web.Security.Membership]::GeneratePassword(8,2)

                # Controleer of de gebruiker al bestaat in AD
                $controlegebruiker = Get-ADUser -Filter {SamAccountName -eq $samAccountName}
                
                if ($controlegebruiker -eq $null) {
                    # Maak een nieuwe gebruiker aan als deze nog niet bestaat
                    New-ADUser -Name $voornaam -GivenName $voornaam -Surname $achternaam -SamAccountName $samAccountName -Department $afdeling -UserPrincipalName "$samAccountName@mijden.lan" -Path "OU=$afdeling,DC=mijden,DC=lan" -AccountPassword (ConvertTo-SecureString $wachtwoord -AsPlainText -Force) -Enabled $true -ChangePasswordAtLogon $true
                    Write-Host "Gebruiker $samAccountName aangemaakt met wachtwoord: $wachtwoord"
                    
                    # Stuur een e-mail naar de gebruiker
                    $emailontvanger = $email
                    $emailafzender = "fontysmike@gmail.com"
                    $onderwerp = "Uw nieuwe account"
                    $body = @"
Beste $voornaam,
Uw account is aangemaakt.
Uw gebruikersnaam is: $samAccountName 
Uw wachtwoord is: $wachtwoord
Met vriendelijke groet,
IT-afdeling vd M
"@
                    $smtpServer = "smtp.gmail.com"
                    $port = 587
                    $userName = 'fontysmike@gmail.com'
                    $password = "ON5S020lO7wyz7"
                    $securepassword = $password | ConvertTo-SecureString -AsPlainText -Force
                    Send-MailMessage -To $emailontvanger -From $emailafzender -Subject $onderwerp -Body $body -SmtpServer $smtpServer -Port $port  -Credential (New-Object System.Management.Automation.PSCredential($userName, $securepassword))   
                } else {
                    Write-Host "Gebruiker $samAccountName bestaat al."
                }

                # Voeg de gebruiker toe aan de lijst van verwerkte gebruikers
                $processedUsers += $samAccountName

                # Maak de VM aan voor deze gebruiker
                $vmnaam = "ws-$voornaam$achternaam"
                $existingVM = Get-VM -Name $vmnaam -ErrorAction SilentlyContinue

                if ($existingVM) {
                    Write-Host "VM $vmnaam bestaat al. Overslaan."
                    continue
                }

                Write-Host "VM voor $voornaam $achternaam wordt aangemaakt."
                Connect-VIServer $vcenter -Credential $vcentercred
                Start-Sleep -Seconds 60

                $hostname = "ws-$voornaam$achternaam"
                $ip = "10.2.0.32"
                $credential = New-Object System.Management.Automation.PSCredential ("admin", $wscred.Password)

                $vm = New-VM -name $vmnaam -Template ws-user-temp -ResourcePool I540703 -Datastore NIM01-1 -Location I540703
                Start-VM -VM $vmnaam
                Start-Sleep -Seconds 60

                $vmTeZoeken = "ws-$voornaam$achternaam"
                $vm = Get-VM -Name $vmTeZoeken
                $ipv4Adres = $vm.Guest.IPAddress | Select-Object -First 1
                Write-Output $ipv4Adres
                Start-Sleep -Seconds 90
                Disconnect-VIServer -Server "vcenter.netlab.fontysict.nl" -Confirm:$false

                Invoke-Command -ComputerName $ipv4Adres -Credential $credential -ScriptBlock {
                    if ($using:afdeling -eq "Hr") {
                        winget install Google.Chrome --accept-package-agreements --accept-source-agreements --silent
                        Start-Sleep -seconds 30
                        Rename-Computer -NewName $using:hostname -Force -Restart
                    } else {
                        winget search Discord
                        winget install Discord -s msstore --accept-package-agreements --accept-source-agreements --silent
                        Start-Sleep -seconds 30
                        Rename-Computer -NewName $using:hostname -Force -Restart
                    }
                }

                do {
                    Start-Sleep -Seconds 240
                    $pingResult = Test-Connection -ComputerName $ipv4Adres -Count 1 -Quiet
                } until ($pingResult)

                Start-Sleep -Seconds 120

                $domeinToevoegen = Invoke-Command -ComputerName $ipv4Adres -Credential $credential -ScriptBlock {
                    try {
                        Write-Host "Probeer de computer toe te voegen aan het domein..."
                        Add-Computer -DomainName $using:domein -Credential $using:dccred -Force -Restart -ErrorAction Stop
                        Write-Host "Computer succesvol toegevoegd aan het domein."
                        
                        Start-Sleep -Seconds 60
                        Write-Host "Herstarten van de computer..."
                    } catch {
                        Write-Host "Fout bij het toevoegen aan het domein: $_"
                        return $false
                    }
                }

                if (-not $domeinToevoegen) {
                    Write-Host "Domein join mislukt. Foutmelding: $($domeinToevoegen)"
                    Start-Sleep -Seconds 30
                }

                Write-Host "Eerste gebruiker succesvol verwerkt."
            }
        }
    }
}
