$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
$dccred = New-Object System.Management.Automation.PSCredential ($dccred.UserName, $dccred.Password)
Invoke-Command -ComputerName 10.3.0.2 -Credential $dccred -ScriptBlock {
    $bestaandeGebruikers = @()
    while ($true) {
        $Response = Invoke-RestMethod http://10.3.0.40:8085/Staff
        Write-Host $Response 
        
        foreach ($user in $response.data) {
            $voornaam = $user.Voornaam
            $achternaam = $user.Achternaam
            $personeelsnummer = $user.Personeelsnummer
            $afdeling = $user.Afdeling
            $email = $user.Email
            

            $samAccountName = "$voornaam $achternaam"
            $wachtwoord = [System.Web.Security.Membership]::GeneratePassword(8,2)
            $controlegebruiker = Get-ADUser -Filter {SamAccountName -eq $samAccountName}
            if ($controlegebruiker -eq $null) {
                New-ADUser -Name $voornaam -GivenName $voornaam -Surname $achternaam -SamAccountName $samAccountName -Department $afdeling -UserPrincipalName "$samAccountName@mijden.lan" -Path "OU=$afdeling,DC=mijden,DC=lan" -AccountPassword (ConvertTo-SecureString $wachtwoord -AsPlainText -Force) -Enabled $true -ChangePasswordAtLogon $true
                $object = [PSCustomObject]@{
                Voornaam = $voornaam
                Achternaam = $achternaam
                Afdeling = $afdeling
                }
                $emailontvanger = $email
                $emailafzender = "mike.fhict@gmail.com"
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
                $port= 587
                $userName = 'mike.fhict@gmail.com'
                $password = "lyzd gjuh otjy szdg"
                [SecureString]$securepassword = $password | ConvertTo-SecureString -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securepassword

                Send-MailMessage -To $emailontvanger -From $emailafzender -Subject $onderwerp -Body $body -SmtpServer $smtpServer -Port $port -UseSsl -Credential $credential
                Write-Host "Gebruiker $samAccountName aangemaakt met wachtwoord: $wachtwoord er is een email verstuurd naar het opgegeven mail adress"

                $vmnaam = "ws-$voornaam$achternaam"
                $hostname = "ws-$voornaam$achternaam"
                $serverNaamOfIp = "test"
                $gebruikerdc = $dccred.UserName
                $domein = "mijden.lan"
                $ip = "10.2.0.32"
                $credential = New-Object System.Management.Automation.PSCredential ("admin", $dccred.Password)

                Write-host $credential.Password
                $vm = New-VM -name $vmnaam -Template ws-user-temp -ResourcePool I540703 -Datastore NIM01-1 -Location I540703  

                Write-Host "VM $vmnaam aangemaakt"

                Start-Sleep -Seconds 60 

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
                        start-sleep -seconds 30
                        Rename-Computer -NewName $using:hostname -Force -Restart
                    } else {
                        winget search Discord
                        winget install Discord -s msstore --accept-package-agreements --accept-source-agreements --silent
                        start-sleep -seconds 30
                        Rename-Computer -NewName $using:hostname -Force -Restart
                    }
                }
            } else {
                
                
                if (-not $bestaandeGebruikers.Contains($samAccountName)) {
                    Write-Host "Gebruiker $samAccountName bestaat al."
                    $bestaandeGebruikers += $samAccountName  
                }
                

            }
        }
        Start-Sleep -Seconds 30

    }
    
}
