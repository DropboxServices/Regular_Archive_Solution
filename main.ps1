# Uses Dropbox .NET SDK
# jackb@dropbox.com - 12/7/2016

using namespace Dropbox.Api

####################
#Variables to update
####################
$ScriptLocation = “C:\sample\"
$logfile = $ScriptLocation + "log.txt"
$exclusionFile = $ScriptLocation + "exclusions.csv"
$daysToArchive = 100
$token = "INSERT TOKEN HERE"
$archiveAccountEmail = "INSERT ARCHIVE EMAIL ADDRESS HERE"

########################
#Variables to NOT change
########################
$scriptName = "Archive Data Script"

[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dropbox.Api.dll”)
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Newtonsoft.Json.dll”)

##################
#Misc Functions
##################
function GetLogger($log, [bool]$output)
{
    $timestamp = Get-Date -format G
    $logString = "[$timestamp] $log"
    $logString | Out-File -FilePath $logfile -Append
    if ($output -eq $true)
    {
        Write-Output $logstring
    }
}

##################
#Dropbox Functions
##################

function ArchiveFilesProcess()
{
    try
    {
        #get teamclient for rest of script to use
        $client = New-Object DropboxTeamClient($token)

        GetMemberId

        GetLogger "Getting member list..." $true

        $members = $client.Team.MembersListAsync().Result
        $memberinfo = $members.Members
        $hasMore = $members.HasMore
        $cursor = $members.Cursor
        $exclusions = Import-Csv $exclusionFile
    
        foreach ($member in $memberinfo)
        {
            $count = 0   
            $memberId = $member.Profile.TeamMemberId
            $email = $member.Profile.Email

            #check exclusion list, if on it skip the move archive file process
            $exclude = $exclusions | Where-Object {$_.email -eq $email}

            #not excluded
            if ($exclude -eq $null)
            {
                ArchiveFiles $memberId $email
            }
            #excluded
            if ($exclude -ne $null)
            {
                GetLogger "[$email] User excluded from archive process." $true
            }
        }

        #code for continuation
        while ($hasMore)
        {
           $count++
           GetLogger "Getting member list (next continuation group[$count])..." $true

           $membersCont = $client.Team.MembersListContinueAsync($cursor).Result
           $memberinfo = $membersCont.Members
           $cursor = $membersCont.Cursor
           $hasMore = $membersCont.HasMore

           foreach ($member in $memberinfo)
           {   
               $memberId = $member.Profile.TeamMemberId
               $email = $member.Profile.Email
 
               #check exclusion list, if on it skip the move archive file process
               $exclude = $exclusions | Where-Object {$_.email -eq $email}

               #not excluded
               if ($exclude -eq $null)
               {
                   GetLogger "[$email] Moving files to archive account..." $false
                   ArchiveFiles $memberId $email
               }
               #excluded
               if ($exclude -ne $null)
               {
                   GetLogger "[$email] User excluded from archive process." $false 
               }  
           }
        }
  }
  catch
  {
    $errorMessage = $_.Exception.Message
    GetLogger "***Error during arhival process,  Exception: [$errorMessage]***" $true
  }
}

#######################################################################################
function GetMemberId()
{
    try
    {
        #get the memberId for the archiveEMail account we have
        GetLogger "Getting memberId for the archive account [$archiveAccountEmail]..." $true

        $userSelectorArg = [Dropbox.Api.Team.UserSelectorArg+Email]
        $userList = New-Object System.Collections.Generic.List[$userSelectorArg]
        $userList.Add($archiveAccountEmail)
        $memberGetItem = [Dropbox.Api.Team.MembersGetInfoItem+MemberInfo]
        $memberInfo = $client.Team.MembersGetInfoAsync($userList).Result

        foreach($memberGetItem in $memberInfo)
        {
            $archiveMemberId = $memberGetItem.AsMemberInfo.Value.Profile.TeamMemberId
        }
    }
    catch
    {
        $errorMessage = $_.Exception.Message
        GetLogger "***Error getting archive account MemberId!  Exception: [$errorMessage]***" $true
    }
}

#######################################################################################
function ArchiveFiles($memberId, $email)
{
    $listCount = 0
    $archiveCount = 0
    $teamclient = New-Object DropboxTeamClient($token)
    try
    {
        GetLogger "[$email] Grabbing file list[s]..." $true

        $meta = $teamclient.AsMember($memberId).Files.ListFolderAsync("", $true).Result
        $hasMore = $meta.HasMore
        $cursor = $meta.Cursor
        $entries = $meta.Entries
        $entriesCount = $entries.Count

        if ($entriesCount -gt 0)
        {
            GetLogger "[$email] Checking files..." $true
        }
        else
        {
            GetLogger "[$email] User has no files or folders in Dropbox." $true
        }

        foreach ($entry in $entries)
        {
            $filePath = $entry.PathLower

            #compare client_modified and server_modified and get the newer date to use
            $modifiedDate = $entry.ServerModified

            if ($entry.ClientModified -igt $modifiedDate)
            {
                $modifiedDate = $entry.ClientModified
            }

            if ($entry.IsFile -and $modifiedDate -ilt $archiveDate)
            {
                $archiveCount++
                #get a copy reference
                GetLogger "[$email] Getting copy reference for [$filePath]..." $false
                $metaGet = $teamclient.AsMember($memberId).Files.CopyReferenceGetAsync($filePath).Result
                $copyRef = $metaGet.CopyReference

                #create archive folderpath and copy to archive account
                GetLogger "[$email] Saving copy reference for [$filePath] to archive account's Dropbox..." $false
                $todayDate = Get-Date -format yyyy-M-d
                $destPath = "/" + $email + "/" + $todayDate + $filePath
                $metaSet = $teamclient.AsMember($archiveMemberId).Files.CopyReferenceSaveAsync($copyRef, $destPath).Result

                #delete original file from source user's Dropbox
                GetLogger "[$email] Deleting original copy [$filePath]..." $false
                $metaDelete = $teamclient.AsMember($memberId).Files.DeleteAsync($filePath).Result

                if ($meta.Name -ne $null)
                {
                    $name = "/" + $meta.Name
                    GetLogger "[$email] File [$name] archived to [$destPath] successfully." $false
                }
            }
        }
        
        #code for continuation
        while ($hasMore)
        {
            $listCount++
            GetLogger "[$email] Grabbing file list (next continuation list[$listCount])..." $false

            $metaCont = $teamclient.AsMember($memberId).Files.ListFolderContinueAsync($cursor).Result
            $hasMore = $metaCont.HasMore
            $cursor = $metaCont.Cursor
            $entries = $metaCont.Entries

            foreach ($entry in $entries)
            {
                $filePath = $entry.PathLower

                #compare client_modified and server_modified and get the newer date to use
                $modifiedDate = $entry.ServerModified

                if ($entry.ClientModified -igt $modifiedDate)
                {
                    $modifiedDate = $entry.ClientModified
                }

                if ($entry.IsFile -and $modifiedDate -ilt $archiveDate)
                {
                    $archiveCount++
                    #get a copy reference
                    GetLogger "[$email] Getting copy reference for [$filePath]..." $false
                    $metaGet = $teamclient.AsMember($memberId).Files.CopyReferenceGetAsync($filePath).Result
                    $copyRef = $metaGet.CopyReference

                    #create archive folderpath and copy to archive account
                    GetLogger "[$email] Saving copy reference for [$filePath] to archive account's Dropbox..." $false
                    $todayDate = Get-Date -format yyyy-M-d
                    $destPath = "/" + $email + "/" + $todayDate + $filePath
                    $metaSet = $teamclient.AsMember($archiveMemberId).Files.CopyReferenceSaveAsync($copyRef, $destPath).Result

                    #delete original file from source user's Dropbox
                    GetLogger "[$email] Deleting original copy [$filePath]..." $false
                    $metaDelete = $teamclient.AsMember($memberId).Files.DeleteAsync($filePath).Result

                    if ($meta.Name -ne $null)
                    {
                        $name = "/" + $meta.Name
                        GetLogger "[$email] File [$name] archived to [$destPath] successfully." $false 
                    }
                }
            }
        }
        if ($archiveCount -eq 0)
        {
            GetLogger "[$email] No archive files to move for this account." $true
        }
        else
        {
            GetLogger "[$email] Total files archived for this account: [$archiveCount]" $true
        }  
    }
    catch
    {
       $errorMessage = $_.Exception.Message
       GetLogger "[$email] Error moving file [$filePath]  Exception: [$errorMessage] " $false
    }
}

#######################################################################################

####################
#SCRIPT ENTRY POINT
#Here we go...
###################
GetLogger "-----Beginning script: [$scriptName]-----" $true
GetLogger "-----Parameters: [LogFile]: $logfile [Script Location]: $ScriptLocation [Days To Archive]: $daysToArchive-----" $true

#calculate date to move files by
$archiveDate = (Get-Date).AddDays(-$daysToArchive).Date 

ArchiveFilesProcess

GetLogger "-----Completed script: [$scriptName]-----" $true