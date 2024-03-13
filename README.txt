Thank you for downloading SE WatchDog.

**************************************************************************
If you are updating WatchDog DO NOT copy over the config.json file
**************************************************************************
This Script will watch for the Nexus controller process. If it does not see the process it will shut down all the server processes
and wait for the nexus controller to be back up.

It will watch the Server processes. If it detects that any of the server Processes are down
it will restart the server. It will also wait 10 seconds just incase the server is doing its scheduled restart.

It is supposed to watch the torch.log file for any fatal errors. Currently it will not shut down the server as
it needs to be tested more. It will just say that it detected a fatal error in the server logs

The Watchdog will post all output that has a timestamp into the logs in ...\watchdog\logs

If you have any questions or suggestions feel free to contact me on discord
I am on Nexus, Keen's, and Torch's Discord

You can also join our discord and get me there https://discord.gg/z5Jqtf94cP

Or just PM me.

To Use this script there is some setup that you need to do.

Place the file where you want.

send a shortcut of the .bat to your desktop or where ever you want.

open up the config.json file
	
	-the '\\' in the path's is required.
	
	-If you are using The Nexus Controller Leave the NexusControllerEnabled as true.
	
	-The "Torchlogs" Path you can find where you placed the torch files. If you have multiple servers add a ',' to each.
	-eg "C:\\Some\\Default\\Path",
		"C:\\Some\\Default\\Path"
	
	-For "TorchDirectories"
		-"Name" is the "instance" name By default it is just called "instance".
			-if you are running multiple instances of torch. You will need to change the instance name.
				-to do this go to your torch files and locate torch.cfg.
				-once there change <InstanceName>Instance</InstanceName> 
					to a unique name such as <InstanceName>Lobby</InstanceName>
		-Path is executable for torch.
		-"Arguments": ... DONT CHANGE THIS
		-"LogDirectory" Same as "TorchLogs"
		-if you have multiple servers copy from '{' to '}' and paste be low '{'
		
Use the .bat file to start the script.
