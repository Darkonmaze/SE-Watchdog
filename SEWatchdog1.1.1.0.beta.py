import os
import json
import subprocess
import time
import re
import psutil
import sys
from datetime import datetime, timedelta

#-------------Config Retrival--------------------------------------------------
# Read configuration from JSON file
config_file = "config.json"
with open(config_file, "r") as f:
    config = json.load(f)

#------------------------------------------------------------------------------

# Display startup message
startup_message = """
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
"""

print(startup_message)

#-------------Window Size Function---------------------------------------------
def resize_console_window():
    os.system("mode con cols=200 lines=100")  # Adjust console window size

resize_console_window()

#-------------Count down Function-----------------------------------------------
def start_countdown(duration):
    while duration > 0:
        print(f"Countdown: {duration} seconds remaining...")
        duration -= 1
        time.sleep(1)

#-------------Startup Message--------------------------------------------------
print(startup_message)

#-------------Name of Window---------------------------------------------------
window_title = "SE-WatchDog"
os.system(f"title {window_title}")

#-------------Timestamp Function-----------------------------------------------
def get_timestamp():
    return datetime.now().strftime("[%H:%M:%S]")

#-------------WatchDog Log Directories-----------------------------------------
# Define the name of the Log File
new_directory_name = "Logs"

# Construct the Full path to the Logs
script_directory = os.path.dirname(os.path.realpath(__file__))
log_directory = os.path.join(script_directory, new_directory_name)

# Check if the directory already exists
if not os.path.exists(log_directory):
    os.makedirs(log_directory)

log_file = os.path.join(log_directory, f"WatchDogLog_{datetime.now().strftime('%Y-%m-%d')}.log")

# Function to write log messages
def write_log(messages, write_to_console=True):
    with open(log_file, "a") as f:
        for message in messages:
            log_message = f"{get_timestamp()} {message}"
            f.write(log_message + "\n")
            if write_to_console:
                print(log_message)

#-------------FATAL Error Function---------------------------------------------
# Function to search for fatal errors in log directories
def search_fatal_errors(torch_logs):
    servers_with_errors = []
    pattern = r"^\d{2}:\d{2}:\d{2}\.\d{4} \[FATAL\]  (\w+): (.*)$"
    start_date = datetime.now() - timedelta(seconds=30)

    for log_dir in torch_logs:
        log_files = sorted(os.listdir(log_dir), key=lambda x: os.path.getmtime(os.path.join(log_dir, x)), reverse=True)

        if log_files:
            selected_log = os.path.join(log_dir, log_files[0])
            last_write_time = datetime.fromtimestamp(os.path.getmtime(selected_log))

            if last_write_time > start_date:
                fatal_error_found = False

                with open(selected_log, "r") as f:
                    for line in f:
                        if re.match(pattern, line):
                            fatal_error_found = True
                            break

                if fatal_error_found:
                    servers_with_errors.append(log_dir)

    return servers_with_errors

#-------------Main Loop--------------------------------------------------------
nexus_enabled = config["NexusControllerEnabled"]
previous_status = None
server_start_counts = {}

if not nexus_enabled:
    write_log(["The Nexus Controller is disabled. If this is intended Disregard. If not enable it through the config file"])

try:
    while True:
        current_status = None
        #-------------Nexus Controller-------------------------------------------------
        # check if there is a change in serverStatus. IF so do this
        if current_status != previous_status:
            if current_status:
                write_log(["All servers are running Nominally"])
            else:
                write_log(["One ore more servers has encountered an", "error or was shutdown. No action needed."])
            
            previous_status = current_status

        # If the Controller is enabled through the config file
        if nexus_enabled:
            nexus_controller_process = subprocess.run(["tasklist", "/fi", "imagename eq NexusControllerV2"], capture_output=True, text=True)

            if "NexusControllerV2" not in nexus_controller_process.stdout:
                write_log(["Nexus Controller is not running. Shutting down all servers..."])
                
                for server in config["TorchDirectories"]:
                    server_name = server["Name"]
                    executable = server["Path"]
                    process_name = None

                    for proc in psutil.process_iter():
                        if proc.name() == executable:
                            process_name = proc.pid
                            break

                    if process_name:
                        write_log([f"Shutting down {server_name} server..."])
                        subprocess.run(["taskkill", "/f", "/pid", str(process_name)])
                    
                write_log(["Waiting for the Nexus Controller..."])
                time.sleep(10)
                continue

        #-------------Fatal Error Crash Check------------------------------------------
        # Call the function to search for fatal errors
        servers_with_errors = search_fatal_errors(config["TorchDirectories"])

        # Output the list of servers with fatal errors
        for server in servers_with_errors:
            write_log([f"{server} has encountered a fatal error"])

        #-------------Find Server Processes not running and start them------------------
        current_time = datetime.now()

        for server in config["TorchDirectories"]:
            server_name = server["Name"]
            executable = server["Path"]
            process_running = any(proc.name() == executable for proc in psutil.process_iter())

            if not process_running:
                if server_start_counts.get(server_name, {}).get("Count", 0) < 4:
                    write_log([f"We detected that {server_name} is down. Waiting 15 seconds to see if it starts back up"])
                    start_countdown(15)
                    if not any(proc.name() == executable for proc in psutil.process_iter()):
                        write_log([f"{server_name} is infact down. Restart it..."])
                        subprocess.Popen([executable, "-autostart"])
                        server_start_counts[server_name] = {"Count": server_start_counts.get(server_name, {}).get("Count", 0) + 1, "LastStart": current_time}
                        current_status = False
                    else:
                        write_log([f"We caught {server_name} with its pants down everything is fine now."])

        time.sleep(10)

except Exception as e:
    write_log([f"An error occurred: {e}"])
    write_log([f"Script line: {sys.exc_info()[-1].tb_lineno}"])
    input("Press Enter to continue...")  # Wait for user input to close window
