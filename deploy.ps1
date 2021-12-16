function Get-ArchiveName {
    $LOG_FILE = "Build.log"
    if(Test-Path -PathType Leaf -Path $LOG_FILE) {
        $sln = Get-Content $LOG_FILE
        "$sln" -match '(?<=ProjectTitle:\s)(.*?)(?=\s|$)'
        $project_title = $Matches[0]
        "$project_title"
        "$sln" -match '(?<=ProjectPartNumber:\s)(.*?)(?=\s|$)'
        $project_part_number = $Matches[0]
        "$project_part_number"
        "$sln" -match '(?<=ProjectRevision:\s)(.*?)(?=\s|$)'
        $project_revision = $Matches[0]
        "$project_revision"
        $ARCHIVE_NAME = $project_part_number + '-' + $project_revision + ".zip"
        echo "ARCHIVE_NAME=$ARCHIVE_NAME" >> variables.env
        echo "PROJECT_TITLE=$project_title" >> variables.env
    }
    else {
        "File not found"
        exit 30
    }
}

function Manufacturing {
    "Start manufacturing process"
    Get-ChildItem -Filter "*Manufacturing" -Recurse | % {
        $Target = $_.fullname
        Compress-Archive $Target -DestinationPath "$Target.zip" -Force
        Get-FileHash "$Target.zip" -Algorithm MD5 >> "$Target.MD5"
        Remove-Item -Path $Target -Recurse -Force
    }    
}