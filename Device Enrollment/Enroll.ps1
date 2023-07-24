$devicename = Read-Host -Prompt 'What is your device name'
$devicegroup = Read-Host -Prompt 'What is your AAD Device Group eg AAD-Melbourne-Devices-001'

Install-script Get-WindowsAutoPilotInfo -Force -Confirm:$False

Set-executionpolicy remotesigned

Set-Clipboard -Value "USERNAME for cutting and pasting"

Get-WindowsAutoPilotInfo.ps1 -GroupTag Autopilot-AAD-SelfDeploying-Student -Online -AddtoGroup $devicegroup -AssignedComputerName $devicename