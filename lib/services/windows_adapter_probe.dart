/// Select a single present gadget using the live network stack, not WMI history.
const windowsGadgetAdapterQuery = r'''
$ErrorActionPreference = 'Stop'
$devices = @(Get-NetAdapter | Where-Object {
  $_.PnPDeviceID -like "*VID_0525&PID_A4A2*" -and $_.Status -ne 'Not Present'
})
if ($devices.Count -ne 1) { exit 0 }
$dev = $devices[0]
if ($dev.Name -and $dev.ifIndex -gt 0) {
  "$($dev.InterfaceDescription)`t$($dev.Name)`t$($dev.Status -eq 'Up')`t$($dev.ifIndex)`t$($dev.PnPDeviceID)"
}
''';
