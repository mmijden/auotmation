# Import required credentials
$vcenter = "vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
$wscred = Import-CliXml -Path "C:\Users\admin\Documents\ws_credentials.xml"

# Configure PowerCLI
Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Warn

# Initialize variables
$datastore = "NIM01-1"
$domein = "mijden.lan"
$bestaandeGebruikers = @()

while ($true) {
    try {
        # Get users from API
        $Response = Invoke-RestMethod http://10.3.0.40:8085/Staff
        
        foreach ($user in $response.data) {
            $voornaam = $user.Voornaam
            $achternaam = $user.Achternaam
            $afdeling = $user.Afdeling
            $email = $user.Email
            $samAccountName = "$voornaam $achternaam"
            
            # Check if user already exists in AD
            $controlegebruiker = Get-ADUser -Filter {SamAccountName -eq $samAccountName}
            
            if ($null -eq $controlegebruiker -and -not $bestaandeGebruikers.Contains($samAccountName)) {
                # Create AD User
                $wachtwoord = [System.Web.Security.Membership]::GeneratePassword(8,2)
                New-ADUser -Name $voornaam -GivenName $voornaam -Surname $achternaam `
                          -SamAccountName $samAccountName -Department $afdeling `
                          -UserPrincipalName "$samAccountName@mijden.lan" `
                          -Path "OU=$afdeling,DC=mijden,DC=lan" `
                          -AccountPassword (ConvertTo-SecureString $wachtwoord -AsPlainText -Force) `
                          -Enabled $true -ChangePasswordAtLogon $true

                # Create VM
                $vmnaam = "ws-$voornaam-$achternaam"
                $hostname = $vmnaam
                
                # Connect to vCenter
                Connect-VIServer $vcenter -Credential $vcentercred
                
                # Create and start VM
                $vm = New-VM -name $vmnaam -Template ws-user-temp -ResourcePool I540703 -Datastore NIM01-1 -Location I540703
                Start-VM -VM $vmnaam
                
                # Wait for VM to get IP
                Start-Sleep -Seconds 60
                $vm = Get-VM -Name $vmnaam
                $ipv4Adres = $vm.Guest.IPAddress | Select-Object -First 1
                
                Disconnect-VIServer -Server $vcenter -Confirm:$false
                
                # Wait for VM to be ready
                Start-Sleep -Seconds 90
                
                # Configure VM based on department
                $credential = New-Object System.Management.Automation.PSCredential ("admin", $wscred.Password)
                Invoke-Command -ComputerName $ipv4Adres -Credential $credential -ScriptBlock {
                    if ($using:afdeling -eq "Hr") {
                        winget install Google.Chrome --accept-package-agreements --accept-source-agreements --silent
                    } else {
                        winget install Discord -s msstore --accept-package-agreements --accept-source-agreements --silent
                    }
                    Start-Sleep -Seconds 30
                    Rename-Computer -NewName $using:hostname -Force -Restart
                }
                
                # Wait for restart and join domain
                do {
                    Start-Sleep -Seconds 240
                    $pingResult = Test-Connection -ComputerName $ipv4Adres -Count 1 -Quiet
                } until ($pingResult)
                
                Start-Sleep -Seconds 120
                
                Invoke-Command -ComputerName $ipv4Adres -Credential $credential -ScriptBlock {
                    Add-Computer -DomainName $using:domein -Credential $using:dccred -Force -Restart
                }
                
                # Send email to user
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
                $port = 587
                $userName = 'mike.fhict@gmail.com'
                $password = "lyzd gjuh otjy szdg"
                [SecureString]$securepassword = $password | ConvertTo-SecureString -AsPlainText -Force
                $emailcred = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securepassword
                
                Send-MailMessage -To $email -From $emailafzender -Subject $onderwerp -Body $body `
                               -SmtpServer $smtpServer -Port $port -UseSsl -Credential $emailcred
                
                Write-Host "User $samAccountName created with VM $vmnaam and joined to domain"
                $bestaandeGebruikers += $samAccountName
            }
            else {
                if (-not $bestaandeGebruikers.Contains($samAccountName)) {
                    Write-Host "User $samAccountName already exists."
                    $bestaandeGebruikers += $samAccountName
                }
            }
        }
    }
    catch {
        Write-Host "Error occurred: $_"
    }
    
    Start-Sleep -Seconds 30
}
