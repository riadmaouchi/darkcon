
<#
.SYNOPSIS
        Install WSL, Ansible and run playbooks
.DESCRIPTION
        This PowerShell script install WSL, Ansible and it run playbooks
.EXAMPLE
        PS> powershell -command "& { . .\install-wsl.ps1; Install-WSLInteractive }"

.LINK
        https://github.com/rmaouchi/d@rkcon-infra
.NOTES
        Author: RM
#>

function Enable-WSL {
    $features = ("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform");
    $rebootRequired = $false
    for ($i = 1; $i -le $features.Length; $i++ ) {
        $feature = $features[$i - 1]

        if ((Get-WindowsOptionalFeature -Online -FeatureName  $feature).State -ne 'Enabled') {
            $wslinst = Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName  $feature
            if ($wslinst.Restartneeded -eq $true) {
                $rebootRequired | = $true
            }
        }
    }
}

function Get-DistroList () {
    
    $distrolist = wsl --list --online | Where-Object -FilterScript { $_.Length -gt 1 } | Select-Object -Skip 3 | ForEach-Object { $_.Substring(0, $_.IndexOf(' ')) } 
    $installedList = wsl --list --verbose
  
    $result = @()
   
    For ($i = 0; $i -lt ($distrolist.Length); $i++) {
        $distro = [PSCustomObject]@{
            Name      = ($distrolist)[$i]
            Id        = $($i + 1)
            Installed = (($installedList) | Select-String -Pattern  ($distrolist)[$i] -Quiet)
        }
        $result += $distro
    }

    return $result
}

function Remove-Distribution() {
    param(
        [string]$LinuxDistribution
    )
    wsl --unregister "$LinuxDistribution" | Out-Null
    winget uninstall "$LinuxDistribution" | Out-Null
}


function Install-WSLInteractive {
    
    $Menu = 'main'

    if ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -notcontains 'S-1-5-32-544') {
        $Menu = 'admin'
    }

    while ($Menu -ne 'exit') {
        Clear-Host
        Write-Host ' :: WSL INSTALL SCRIPTS FOR WINDOWS 11 v1.0.0'  -ForegroundColor Green
        Write-Host ''
        Write-Host '    This script will help you install ansible on WSL (Windows Subsystem for Linux)'
        Write-Host '    It is very nice to run your playbooks from your Windows System '
        Write-Host ''
        Write-Host ' :: NOTE: Tested on Windows 11 Version 22H2'

        switch ($menu) {
            'admin' {
                Write-Host ''
                Write-Host ' !! This script should be run as Administrator' -ForegroundColor Red
                Write-Host ' !! Please close this window and run the script as Administrator' -ForegroundColor Red
                Write-Host ''
                Write-Host '    Press enter to continue...' -NoNewLine
                $Host.UI.ReadLine()
                $Menu = 'exit'
            }
            'main' {
                Write-Host ''
                Write-Host ' :: Please enter a number from 1-3 to select an option from the list below'
                Write-Host ''
                Write-Host ' 1) Install a new WSL distro'
                Write-Host ' 2) Run Ansible playbook'
                Write-Host ' 3) Exit'
                Write-Host ''
                Write-Host ' >> ' -NoNewLine
            
                $Input = $Host.UI.ReadLine()

                switch ($Input) {
                    '1' {
                        $Menu = 'select-distro'
                    }
                    '2' {
                        $Menu = 'select-playbook'
                    }
                    '3' {
                        $Menu = 'exit'
                    }

                    default {
                        Write-Host ''
                        Write-Host ' !! Invalid option selected' -ForegroundColor red
                        Write-Host ''
                        Write-Host '    Press enter to continue...' -NoNewLine
                        $Host.UI.ReadLine()
                    }
                }
            }
            'select-distro' {
                Write-Host ''
                Write-Host ' :: Please enter a number from the list to select a distro to install'
                Write-Host ''

                $Distros = Get-DistroList
                $Distros | ForEach-Object {

                    if ($_.Installed) {
                        Write-Host " $($_.Id)) $($_.Name)" -NoNewline; Write-Host " (Installed)" -ForegroundColor Cyan
                    }
                    else {
                        Write-Host " $($_.Id)) $($_.Name)" 
                    }
                }

                $Max = $Distros.Count + 1
                Write-Host " $Max) Return to main menu"
                Write-Host ''
                Write-Host ' >> ' -NoNewLine
                $Input = $Host.UI.ReadLine()

                if ($Input -eq ([string]$Max)) {
                    $Menu = 'main'
                }
                else {
                    $Distro = $Distros | Where-Object -Property Id -eq -Value $Input
                    if ($null -eq $Distro ) {
                        Write-Host ''
                        Write-Host ' !! Invalid option selected' -ForegroundColor Red
                        Write-Host ''
                        Write-Host '    Press enter to continue...' -NoNewLine
                        $Host.UI.ReadLine()
                    }
                    else {
                        $Menu = 'install-distro-confirm'
                    }
                }
            }
            'install-distro-confirm' {
                Write-Host ''
                Write-Host " :: WARNING: Are you sure you want to install $($Distro.Name)? (y/n) " -ForegroundColor Yellow -NoNewLine
                $Input = $Host.UI.ReadLine()
				
                switch ($Input) {
                    'y' {
                        $Menu = 'install-distro'
                    }
                    'n' {
                        $Menu = 'select-distro'
                    }
                    default {
                        Write-Host ''
                        Write-Host ' !! Invalid input' -ForegroundColor Red
                        Write-Host ''
                        Write-Host '    Press enter to continue...' -NoNewLine
                        $Host.UI.ReadLine()
                        $Menu = 'select-distro'
                    }
                }
            }
            'install-distro' {
                Write-Host ''
                Write-Host "Installing $($Distro.Name)..."
				
                try {
                   
                    Enable-WSL
                    $wsl2 = wsl --set-default-version 2 | Out-Null 
                        
                  
                    $d = $Distro.Name -replace "`0", ""
                    if ($Distro.Installed) {
                        Remove-Distribution ($d)
                    }
                       
                    Copy-Item "./wsl/.wslconfig" -Destination "$env:USERPROFILE"
                        
                    wsl --install $d 
                    wsl --set-default $d | Out-Null
                    wsl --user root --shell-type standard --distribution $d -e sh -c "./wsl/setup-wsl.sh"
                    $Menu = 'install-ansible-confirm'
                }
                catch {
                    Write-Host ''
                    Write-Host ' !! An error occurred during the installation' -ForegroundColor Red
                    Write-Host " !! The error is: $PSItem" -ForegroundColor Red
                    Write-Host ''
                    Write-Host '    Your chosen distro could not be installed.'
                    Write-Host ''
                    Write-Host '    Press enter to continue...' -NoNewLine
                    $Host.UI.ReadLine()
                    $Menu = 'select-distro'
                }
            }
           
            'install-ansible-confirm' {
                Write-Host ''
                Write-Host " :: WARNING: Are you sure you want to install Ansible? (y/n) " -ForegroundColor Yellow -NoNewLine
                $Input = $Host.UI.ReadLine()
				
                switch ($Input) {
                    'y' {
                        $Menu = 'install-ansible'
                    }
                    'n' {
                        $Menu = 'main'
                    }
                    default {
                        Write-Host ''
                        Write-Host ' !! Invalid input' -ForegroundColor Red
                        Write-Host ''
                        Write-Host '    Press enter to continue...' -NoNewLine
                        $Host.UI.ReadLine()
                        $Menu = 'main'
                    }
                }
            }
            'install-ansible' {
                Write-Host ''
                Write-Host "Installing ansible"
                $d = $Distro.Name -replace "`0", ""
                wsl --user root --shell-type standard --distribution $d -e sh -c "./ansible/install_ansible.sh"
                $Menu = 'select-playbook'
            }
            'select-playbook' {
                Write-Host ''
                Write-Host ' :: Please enter a number from the list to select a playbook to install'
                Write-Host ''

                $EnvList = Get-ChildItem -Path "./ansible/inventories" -Filter "k8s_*" | ForEach-Object -Process { [System.IO.Path]::GetFileNameWithoutExtension($_) } { $_.BaseName.Split('_')[1] }

                $result = @()
   
                For ($i = 1; $i -lt ( $EnvList.Length ); $i++) {
                    $env = [PSCustomObject]@{
                        Name = ($EnvList)[$i]
                        Id   = $i
                    }
                    $result += $env
                }

                $TextInfo = (Get-Culture).TextInfo
                $result | ForEach-Object {
                    Write-Host " $($_.Id)) $($TextInfo.ToTitleCase($_.Name))" 
                }

                $Max = $result.Count + 1
                Write-Host " $Max) Return to main menu"
                Write-Host ''
                Write-Host ' >> ' -NoNewLine
                $Input = $Host.UI.ReadLine()

                if ($Input -eq ([string]$Max)) {
                    $Menu = 'main'
                }
                else {
                    $Env = $result  | Where-Object -Property Id -eq -Value $Input
                    if ($null -eq $Env  ) {
                        Write-Host ''
                        Write-Host ' !! Invalid option selected' -ForegroundColor Red
                        Write-Host ''
                        Write-Host '    Press enter to continue...' -NoNewLine
                        $Host.UI.ReadLine()
                    }
                    else {
                        $Menu = 'install-playbook-confirm'
                    }
                }
            }
            'install-playbook-confirm' {
                Write-Host ''
                Write-Host " :: WARNING: Are you sure you want to install playbook for environment : $($Env.Name) ? (y/n) " -ForegroundColor Yellow -NoNewLine
                $Input = $Host.UI.ReadLine()
				
                switch ($Input) {
                    'y' {
                        $Menu = 'install-playbook'
                    }
                    'n' {
                        $Menu = 'main'
                    }
                    default {
                        Write-Host ''
                        Write-Host ' !! Invalid input' -ForegroundColor Red
                        Write-Host ''
                        Write-Host '    Press enter to continue...' -NoNewLine
                        $Host.UI.ReadLine()
                        $Menu = 'main'
                    }
                }
            }
            'install-playbook' {
                Write-Host ''
                Write-Host "Installing playbook $($Env.Name)"
                $d = $Distro.Name -replace "`0", ""
                wsl --user root --shell-type standard --distribution $d -e sh -c "./ansible/configure_cluster.sh $($Env.Name)"
                $Menu = 'result-done'
            }
            'result-done' {
                Clear-Host
                Write-Host ' :: Installation done!'
                Write-Host ''
                Write-Host '    The WSL feature and Ansible are installed and enabled on your system'
                Write-Host ''
                Write-Host '    Enjoy!'
                Write-Host ''
                Write-Host '    Press enter to continue...' -NoNewLine
                $Host.UI.ReadLine()
                $Menu = 'exit'
            }
        }
    }
    
}