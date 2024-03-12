Thank you for downloading SE WatchDog.

**************************************************************************
If you are updating WatchDog DO NOT copy over the config.json file
**************************************************************************


To Use this script there is some setup that you need to do.

Place the file where you want.

send a shortcut of the .bat to your desktop or where ever you want.

open up the config.json file
	
	-the '\\' in the path's is required.
	
	-If you are using The Nexus Controller Leave the it as true.
	
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
