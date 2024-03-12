#-------------Config Retrival--------------------------------------------------

# Read configuration from JSON file
$configFile = "config.json"
$global:config = Get-Content -Path $configFile -Raw | ConvertFrom-Json

#------------------------------------------------------------------------------

#Display startup message
$StartupMessage = @"
==================================================
|  Space Engineers WatchDog                      |
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
$WindowTitle = "Space Engineers WatchDog"
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

function Search-FatalErrors {
    param (
        [string[]]$torchLogs
    )

    # Initialize a hashtable to store logs per server
    $logsPerServer = @{}

    # Define the regular expression pattern to search for
    $pattern = '\[INFO\] *Initializer:.*\.dmp'

    # Get the current date and time minus 30 seconds
    $startDate = (Get-Date).AddSeconds(-30)

    # Loop through each log directory
    foreach ($logDir in $torchLogs) {
        # Get a list of log files in the log directory
        $logFiles = Get-ChildItem -Path $logDir -Filter "Torch-*.log" | Sort-Object LastWriteTime -Descending

        # Select the first log, if available
        $selectedLogs = $logFiles | Select-Object -First 1

        # Read the content of the selected log file
        $logContent = Get-Content $selectedLogs.FullName -ErrorAction SilentlyContinue

        # Check if the log content contains the error message within the last 30 seconds
        if ($logContent -match $pattern -and $selectedLogs.LastWriteTime -gt $startDate) {
            #$logsPerServer[$logDir] = "Fatal error found in $($selectedLogs.Name) within the last 30 seconds"
			return $true
        } else {           
			#$logsPerServer[$logDir] = "No fatal error found in $($selectedLogs.Name) within the last 30 seconds"
			return $false
        }
    }

    # Output the result
    return $logsPerServer
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

while ($true) {
$currentStatus = $serverStatus
#-------------Nexus Controller-------------------------------------------------
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

# Call the function and pass the array of log directories
$result = Search-FatalErrors -torchLogs $torchDirectories.LogDirectory


# Output the result
if ($result -eq $true) {
    foreach ($serverProcess in $config.TorchDirectories) {
            $serverName = $serverProcess.Name
            $executable = $serverProcess.Path
		    # Check if the server process is running before attempting to stop it
		    $processName = (Get-Process | Where-Object {$_.Path -like $executable}).Id
            if ($processName) {
                Write-Log -Message "The server has encountered a fatal error shutting down the $($serverName) server..."
                Stop-Process -ID $processName -Force
            } else {
                #Servers are offline
            }
        else {
		    Write-Log -message "No Fatal errors found in the logs"
	    }
    }
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

# check if there is a change in serverStatus. IF so do this
	if ($currentStatus -ne $previousStatus) {
		if ($currentStatus)
		{
		Write-Log -message "All servers are running Nominally"
	} else {
		Write-Log -message "One more servers has encoutered an"
		Write-Log -message "error or was shutdown. No action needed."
    }
	# update previous status
	$previousStatus = $currentStatus
	}
Start-Sleep -Seconds 10
}
# Additional logic can be added as needed