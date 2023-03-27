# PC Control
SmartThings Edge driver to control and monitor a Windows PC with a SmartThings device.

This driver uses Wake-on-LAN to wake up a PC, and sends HTTP requests to a third-party opensource PC Windows package to control the PC's shutdown operation.

## Requirements
* SmartThings Hub
* Windows PC
* [Remote Shutdown Manager](https://github.com/karpach/remote-shutdown-pc)
* This driver installed on your SmartThings Hub


## Functionality

The SmartThings device created by this driver will have a simple switch with which you can wake up and 'shut down' a Windows PC.  There are multiple options for what kind of 'shut down' command to send the PC:
* hibernate
* suspend
* shutdown
* turn screen off
* lock
* restart
* force shutdown

The type of shutdown command sent when the switch is turned off is configured on the device Controls screen.

The **Remote Shutdown manager** application runs in the background of the PC and is accessible through the system tray.  It responds to HTTP requests to execute the desired shutdown command, and can also be configured to require a secret key be included with all requests.  For more information, see the Github page link provided above.

The driver can also monitor the on/off state of the PC by enabling this option in device Settings.  The driver will send a periodic 'ping' message to the PC to determine its state.  If no answer, the switch is turned off, if answered, the switch is turned on.  This ensures the switch state stays synched with the actual PC state.

## Installation
### Remote Shutdown Manager
* Go to the [Releases page](https://github.com/karpach/remote-shutdown-pc/releases) for the Github repository and download the latest version of the [remote-shutdown-pc.zip](https://github.com/karpach/remote-shutdown-pc/releases/download/v1.1.9/remote-shutdown-pc.zip) file.
* Unzip the package from your Downloads folder to a new folder on your PC
* Run the application file: Karpach.RemoteShutdown.Controller.exe
* Find the new icon in your system tray and right click on it to open the Settings window
* Configure:
  * System tray command (not relevant to the SmartThings device)
  * Secret code (optional)
  * Port (ensure whatever is configured is unused)
### Edge Driver
* Proceed to this driver's [channel invite page](https://bestow-regional.api.smartthings.com/invite/Q1jP7BqnNNlL).  Enroll your hub and select the **PC Control V1** driver to install to your hub.
* Once the driver is available on your hub (could take up to 12 hours), the next time you use the SmartThings mobile app to do an *Add device / Scan for nearby devices*, a new device will be created and found in the SmartThings room where your hub device is located.
#### Device Configuration
* Open the device to its Controls screen and then select the 3-vertical-dot menu in the upper right corner then select **Settings**.  
* Configure the following items:
  * **WOL MAC Address** - this is the mac address of your PC in the form xx:xx:xx:xx:xx:xx
  * **WOL Broadcast Address** - this should normally not be changed unless WOL commands don't seem to be working; you can try port 9 instead of 7
  * **RSM IP Address:Port** - this is the IP address of your PC and the port number you configured in the Remote Shutdown Manager settings window
  * **RSM Secre**t - this is the secret code you optionally configured in the Remote Shutdown Manager settings window
  * **Monitor Enable** - Turn this on to enable ongoing monitoring of your PC to keep the switch state synched
  * **Monitor Frequency** - Choose the frequency of 'pings' that will be sent to your PC to keep the switch state synched

## Usage
### Device Controls screen
Elements:
* Switch - turning on and off will execute a WOL command or shutdown command respectively.  If monitoring of the PC is not enabled, and the switch is out of synch with the PC, then when the switch is turned on and the PC is already on or when the switch is turned off and the PC is already off, then the switch will revert to the current state of the PC.  
* Configure switch 'off' action button - this defines the command that will be sent when the switch (above) is turned off.  Note that selecting the action with this button will not immediately execute the action; it is only for configuring the command sent to the PC when the switch (above) is turned off.
* Create New Device button - use this to create additional PC Control devices if you have other PCs you want to control
