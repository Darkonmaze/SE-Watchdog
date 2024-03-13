#-------------Config Retrival--------------------------------------------------

# Read configuration from JSON file
$configFile = "config.json"
$global:config = Get-Content -Path $configFile -Raw | ConvertFrom-Json

#------------------------------------------------------------------------------

#Display startup message
$StartupMessage = @"
==================================================
|  SE-WatchDog                                   |
|                                                |
|  Developed By: Darkon                          |
|  Developed to be used with: Nexus/Torch        |
|                                                |
|  This Program will watch for the               |
|  Nexus Controller to be up... If not           |
|  It will wait for it to be up. After which     |
|  the servers will start.                       |
|                                                |
|  If the Nexus Controller for some reason       |
|  shuts down this program will shut down        |
|  all the servers.                              |
|                                                |
|  All logs generated from this script           | 
|  will be posted in:                            |
|  "...\WatchDog\Logs"                           |
|                                                |
==================================================
"@ 

#-------------Torch log directory----------------------------------------------

# Extract TorchLogs from configuration
$torchLogs = $config.TorchLogs

#-------------Window Size Function---------------------------------------------

function Resize-ConsoleWindow {
	$console = $host.UI.RawUI
	$newBufferSize = $console.BufferSize
	$newBufferSize.Width = 200  # Adjust the width as needed
	$newWindowSize = $console.WindowSize
	$newWindowSize.Width = 100  # Adjust the width as needed
	$console.BufferSize = $newBufferSize
	$console.WindowSize = $newWindowSize
}	

# Resize console window
Resize-ConsoleWindow

#-------------Count down Function-----------------------------------------------

# Function to perform countdown
function Start-Countdown {
    param (
        [int]$Duration
    )

    while ($Duration -gt 0) {
        # Display the countdown
        Write-Host "Countdown: $Duration seconds remaining..."

        # Decrement the countdown
        $Duration--

        # Wait for 1 second before next countdown iteration
        Start-Sleep -Seconds 1
    }
}


#-------------Startup Message--------------------------------------------------

Write-Host $StartupMessage

#-------------Name of Window---------------------------------------------------

# Set custom window title
$WindowTitle = "SE-WatchDog"
[Console]::Title = $WindowTitle

#-------------Timestamp Function-----------------------------------------------

# Function to get timestamp
function Get-Timestamp {
    return "[{0:HH:mm:ss}]" -f (Get-Date)
}

#-------------WatchDog Log Directories-----------------------------------------


#Get the directory of WatchDog
$scriptDir = $PSScriptRoot

# Define the name of the Log File
$newDirectoryName = "Logs"

# Construct the Full path to the Logs
$logDirectory = Join-Path -Path $PSScriptRoot -childPath $newDirectoryName

# Check if the directory already exists
if (-not (test-Path -Path $logDirectory -type container)) {
	# Create the directory if it does not exist
	New-Item -Path $logDirectory -ItemType Directory -Force
	} else {
		#Directory already exists.
	}
$global:logFile = Join-Path -Path $logDirectory -ChildPath "WatchDogLog_$(Get-Date -Format 'yyyy-MM-dd').log"

# Function to write log messages
function Write-Log {
    param(
        [string]$Messages,
        [bool]$WriteToConsole = $true
    )

    foreach ($Message in $Messages) {
        $logMessage = "$(Get-Timestamp) $Message"
        Add-Content -Path $global:logFile -Value $logMessage
        if ($WriteToConsole) {
            Write-Host $logMessage
        }
    }
}

#-------------FATAL Error Function---------------------------------------------

# Read configuration from JSON file
$configFile = "config.json"
$config = Get-Content -Path $configFile -Raw | ConvertFrom-Json

# Get the list of log directories from the configuration
$logDirectories = $config.TorchDirectories.LogDirectory

# Function to search for fatal errors in log directories
function Search-FatalErrors {
    param (
        [string[]]$torchLogs
    )

    # Initialize a list to store server directories with fatal errors
    $serversWithErrors = @()

    # Define the regular expression pattern to search for
    $pattern = '^\[\d{2}:\d{2}:\d{2}\.\d{4}\] \[INFO\] Initializer:.*\.dmp$'

    # Get the current date and time minus 30 seconds
    $startDate = (Get-Date).AddSeconds(-30)

    # Loop through each log directory
    foreach ($logDir in $torchLogs) {
        # Get a list of log files in the log directory
        $logFiles = Get-ChildItem -Path $logDir -Filter "Torch-*.log" | Sort-Object LastWriteTime -Descending

        # Select the first log, if available
        $selectedLog = $logFiles | Select-Object -First 1

        # Check if the log file is not null
        if ($selectedLog -ne $null) {
            # Read the content of the selected log file
            $logContent = Get-Content $selectedLog.FullName -ErrorAction SilentlyContinue

            # Get the last write time of the log file
            $lastWriteTime = $selectedLog.LastWriteTime

            # Check Time Window: Compare the last write time with the start time
            if ($lastWriteTime -gt $startDate) {
                # Initialize a flag to indicate if fatal error is found in the time window
                $fatalErrorFound = $false

                # Loop through each line in the log content within the time window
                foreach ($line in $logContent) {
                    # Check if the line contains the fatal error pattern
                    if ($line -match $pattern) {
                        # Set the flag and exit the loop if a fatal error is found
                        $fatalErrorFound = $true
                        break
                    }
                }

                # If a fatal error is found within the time window, add the server directory to the list
                if ($fatalErrorFound) {
                    $serversWithErrors += $logDir
                }
            }
        }
    }

    # Output the list of server directories with fatal errors
    return $serversWithErrors
}


#-------------Main Loop--------------------------------------------------------
# Pull NexusControllerEnabled from the Config.json file
$global:nexusEnabled = $config.NexusControllerEnabled
# Initialize a boolean for $serverStatus
$previousStatus = $null

if (-not $nexusEnabled) {
		Write-Log -Message "The Nexus Controller is disabled. If this is intended Disregard. If not enable it through the config file"
	}

# Initialize a hashtable to store the start counts of each server
$serverStartCounts = @{}
try {
while ($true) {
$currentStatus = $serverStatus
#-------------Nexus Controller-------------------------------------------------
# check if there is a change in serverStatus. IF so do this
	if ($currentStatus -ne $previousStatus) {
		if ($currentStatus)
		{
		Write-Log -message "All servers are running Nominally"
	} else {
		Write-Log -message "One ore more servers has encoutered an"
		Write-Log -message "error or was shutdown. No action needed."
    }
	# update previous status
	$previousStatus = $currentStatus
	}
	
#If the Controller is enabled through the config file
	if ($nexusEnabled) {
		# Check if Nexus Controller is running
		$nexusControllerProcess = Get-Process -Name "NexusControllerV2" -ErrorAction SilentlyContinue

		# Usage
		# Checks to see if the Nexus Controller is running. If not shuts the servers down.
			if (-not $nexusControllerProcess) {
			Write-Log "Nexus Controller is not running. Shutting down all servers..."
			foreach ($serverProcess in $config.TorchDirectories) {
				$serverName = $serverProcess.Name
				$executable = $serverProcess.Path
				# Check if the server process is running before attempting to stop it
				$processName = (Get-Process | Where-Object {$_.Path -like $executable}).Id
				if ($processName) {
					Write-Log -message "Shutting down $($serverName) server..."
					Stop-Process -ID $processName -Force
				} else {
					#Servers are offline
				}
			}
			Write-Log -Message "Waiting for the Nexus Controller..."
			Start-Sleep -Seconds 10
			continue  # Skip checking server status until Nexus Controller is restarted
			}
	}
#-------------Fatal Error Crash Check------------------------------------------
# Call the function to search for fatal errors
$serversWithErrors = Search-FatalErrors -torchLogs $logDirectories

# Output the list of servers with fatal errors
#Write-Host "Servers with fatal errors:"
foreach ($server in $serversWithErrors) {
    Write-Log -message "$($server) has encountered a fatal error"
	$serverStatus = $false
}

#-------------Find Server Processes not running and start them------------------


$currentTime = Get-Date
# Usage
# Watches the server processes. IF not precent > Starts the server 
   foreach ($serverProcess in $config.TorchDirectories) {
        $serverName = $serverProcess.Name
        $executable = $serverProcess.Path
        $arguments = "-autostart"
        $processRunning = Get-Process | Where-Object {$_.Path -like $executable}
		
        # Check if the server has been started 3 times within the last 30 minutes
        if ($serverStartCounts.ContainsKey($serverName) -and $serverStartCounts[$serverName]["Count"] -ge 4) {
            Write-Log -Message "Skipping $($serverProcess.Name) server start. It has been started 3 times within the last 30 minutes."
            continue
        }
		
        # Check if the server was started within the last 30 minutes and update the start count
        if ($serverStartCounts.ContainsKey($serverName) -and ($currentTime - $serverStartCounts[$serverName]["LastStart"]).TotalMinutes -lt 30) {
            
        }
        else {
            $serverStartCounts[$serverName] = @{ "Count" = 1; "LastStart" = $currentTime }
        }

        if (-not $processRunning) {
            if ($serverStartCounts[$serverName]["Count"] -lt 4) {
                Write-Log -message "We detected that $($serverName) is down. Waiting 15 seconds to see if it starts back up"
				Start-Countdown -Duration 15 #counting down 10 seconds before it checks again
				if (-not $processRunning) {
					Write-Log -Message "$($serverProcess.Name) is infact down. Restart it..."
					Start-Process -FilePath $executable -ArgumentList $arguments
					$serverStartCounts[$serverName]["Count"]++
					$serverStatus = $false
					} else {
						Write-Log -message "We caught $($serverName) with its pants down everything is fine now."
					}
			}
        
			else {
            # Skip prompting if the server is already running
			}
		} else {
			$serverStatus = $true
		}
	}


Start-Sleep -Seconds 10
} 

} catch {
	
	Write-log -message "An error occurred: $_"
    Write-log -message "Error message: $($Error[0].Exception.Message)"
    Write-log -message "Error category: $($Error[0].CategoryInfo.Category)"
    Write-log -message "Script line: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Read-Host "Press any key to continue..."
}
# Additional logic can be added as needed
