# [Windows Subsystem for Linux Version 2](https://docs.microsoft.com/en-us/windows/wsl/)

# Install-WSL

A Powershell script to automate the setup of WSL and allow to run ansible playbook on you favorite linux distro

## Features:

- Installs WSL required features
- Installs WSL
- Installs Ubuntu Distro
- Installs Ansible
- Runs ansible playbooks

## Installation

Fire up an elevated powershell and run this:

```
powershell -ExecutionPolicy ByPass -command "& { . .\install-wsl.ps1; Install-WSLInteractive }"
```
