# Disable Bluetooth Telephony (HFP)

Disables the Hands-Free Profile (HFP) on a Bluetooth audio device so Windows stops routing microphone/call audio through it. Stereo audio (A2DP) is unaffected.

Useful if you use a dedicated microphone and want to prevent Windows from switching your headphones to the lower-quality headset mode when an app (game, Discord, etc.) requests a microphone.

## Common Symptoms

This script fixes issues such as:

- Bluetooth headphones sound muffled or low quality when a game or app starts
- Audio cuts out or drops when joining voice chat (Discord, Steam, Xbox app, etc.)
- Headphones switch to "Headset" mode and microphone stops working correctly
- Marathon/Valorant game audio stops working when enabling in-game chat
- "Headset (AirPods Pro Hands-Free)" appears as the default audio device instead of "Headphones (AirPods Pro)"
- Windows automatically switches audio devices when an app requests a microphone

## Warning

- **Modifies the Windows registry.** Changes are made to `HKLM\SYSTEM\CurrentControlSet\Services\BTHPORT` which is part of the Bluetooth stack. Incorrect edits to this area can affect all Bluetooth devices. This script only changes the `Enabled` flag for the HFP service on the targeted device.
- **Requires Administrator.** The script will refuse to run without elevated privileges.
- **Registers a startup task.** A scheduled task is created in Task Scheduler that runs at every logon. See the Notes section for how to remove it.
- **Only affects the targeted device.** Other Bluetooth devices and profiles are not touched.

## Requirements

- Windows 10/11
- PowerShell (Run as Administrator)

## Usage

Run once as Administrator. The script disables telephony immediately and registers itself as a logon startup task so it applies automatically on every boot.

```powershell
.\disable_telephony.ps1
```

By default it targets any device matching `"AirPods"`. Use `-DeviceName` to target a different device:

```powershell
.\disable_telephony.ps1 -DeviceName "AirPods Pro"
.\disable_telephony.ps1 -DeviceName "Steelseries Arctis 7"
.\disable_telephony.ps1 -DeviceName "HyperX Cloud III"
.\disable_telephony.ps1 -DeviceName "Astro A50"
```

## How it works

When Windows connects a Bluetooth audio device that supports HFP, it creates a Hands-Free device node and enables the service in the Bluetooth stack registry. This script:

1. Finds the device's MAC address by name from the paired device list
2. Sets `Enabled = 0` for the HFP service UUID (`0000111e`) in `HKLM\SYSTEM\CurrentControlSet\Services\BTHPORT`
3. Removes the active HFP device node via `pnputil` so the change takes effect immediately without a reconnect
4. Registers a scheduled task to re-run at logon (since Windows recreates the HFP node on each connection)

## Notes

- The "Handsfree Telephony" checkbox in Devices and Printers may still appear checked — this is cosmetic. The HFP device node is not created on reconnect.
- The startup task is registered under the name `Disable <Device> Telephony` in Task Scheduler.
- To remove the startup task: open Task Scheduler and delete `Disable AirPods Telephony` (or whatever your device name is).
