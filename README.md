# Regular_Archive_Solution
A sample script to perform regular archive of Dropbox Business content to a central account. 

#Requires:
1. Microsoft PowerShell 5.0

#Installation:
1. Download and extract the sample (use download .zip)
2. Obtain an access token for the team
3. Configure the variables 
4. Run, or schedule the script

#Obtaining a Dropbox access token for your team:
1. Visit https://www.dropbox.com/developers/apps (you will need to be able to sign in as a team administrator). 
2. Click “Create App”
3. Select “Dropbox Business API” 
4. Select “Team Member File Access”
5. Give the app a unique name
6. Click “Create App”
7. Under “Generated Access Token”, click “Generate”. 
8. Copy the token. Store it somewhere safe. It should be protected like a password. 

#Script Variables:
1. PermanentlyDelete should be set to $false to not permanently delete files from Dropbox, or $true to permanently delete them.
2. Scriptlocation should be updated to the directory you wish to run the script from (this allows the script to find the Dropbox SDK .dll dependencies). 
3. Logfile is the name of the text file that should store information when the script runs. 
iii.	Exclusionfile contains the memebers that should not have archive operations run. The file is designed to be one email address per line. 
4. daysToArchive is the maximum age in days of content before it should be archived. 
5. Token is the security token you obtained in step 2. 
6. ArchiveaccountEmail is the email address for the archive account on your team. This tells the script where to send archive content. 

#Running the script:
1. To run the script from the command line, open PowerShell.exe and navigate to the script directory.  Run the script using “.\main.ps1”. 
2. Optionally, configure the script to run on a schedule using Microsoft Task Scheduler. The Microsoft Scripting center explains how to configure a scheduled task here: https://blogs.technet.microsoft.com/heyscriptingguy/2012/08/11/weekend-scripter-use-the-windows-task-scheduler-to-run-a-windows-powershell-script/ 




