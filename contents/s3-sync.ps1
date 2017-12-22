#Requires -Version 4

<#
.SYNOPSIS
  List AWS bucket objects
.DESCRIPTION
  List AWS bucket objects
.PARAMETER accessKey
    AWS Access Key
.PARAMETER secretKey
    AWS Secret Key
.NOTES
  Version:        1.0.0
  Author:         Rundeck
  Creation Date:  12/12/2017
  
#>


Param (
    [string]$accessKey,
    [string]$secretKey
)

Begin {
	Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKey 

    Function checkType($path){
        if( (Get-Item $path) -is [System.IO.DirectoryInfo] ) {
            return "directory"
        }else{
            return "file"
        }
    }

    Function s3Files($uri){

        $Params = @{}

        if($Env:RD_CONFIG_DEFAULT_REGION){
            $Params.add("Region", $Env:RD_CONFIG_DEFAULT_REGION) 
        }

        if($Env:RD_CONFIG_ENDPOINT_URL){
            $Params.add("EndpointUrl", $Env:RD_CONFIG_ENDPOINT_URL) 
        }

        $fileList = @{}

        if($uri.LocalPath -ne "/"){
            $LocalPath = $uri.LocalPath +"/"

            if($LocalPath.StartsWith("/")){
              $LocalPath=$LocalPath.Remove(0, 1)  
            }

            $KeyPrefix =  $uri.LocalPath +"/"
        }else{
            $KeyPrefix = $uri.LocalPath
        }

        
        Get-S3Object -BucketName $uri.Authority -KeyPrefix $KeyPrefix  @Params| % {

            #filtering 
            if($_.key  -ne $LocalPath  ){

                if($uri.LocalPath -ne "/"){
                    $s3FileKey = $_.key  -ireplace [regex]::Escape($LocalPath), ""                    
                }else{
                    $s3FileKey=$_.key
                }

                if($s3FileKey.StartsWith("/")){
                    $s3FileKey=$s3FileKey.Remove(0, 1)  
                }

                $hash = $_.ETag.Replace('"','')
                $fileList.Add($s3FileKey,$hash)
            }
            
        }

        return $fileList

    }

    Function localFiles($uri){
        $localFileList = @{}

        echo $uri.LocalPath

        Get-ChildItem $uri.LocalPath -Recurse  | % {

            $filePath = $_.FullName

            $type=checkType($filePath)

            if($type -eq "file"){
                $fileHash = Get-FileHash $filePath  -Algorithm MD5 

                $fileRelativePath =  $filePath -ireplace [regex]::Escape($uri.LocalPath), ""

                if($fileRelativePath.StartsWith("\")){
                  $fileRelativePath=$fileRelativePath.Remove(0, 1)  
                }

                $fileRelativePath = $fileRelativePath.Replace("\","/")

                $localFileList.Add($fileRelativePath, $fileHash.Hash.ToLower())
            }
        }

        return $localFileList
    }
    
}

Process {


    try{

        $source=$Env:RD_CONFIG_SOURCE
        $destination=$Env:RD_CONFIG_DESTINATION

        $Params = @{}

        $remove=$False
        if($Env:RD_CONFIG_REMOVE -eq "true"){
            $remove=$True
        }

        if($Env:RD_CONFIG_DEFAULT_REGION){
            $Params.add("Region", $Env:RD_CONFIG_DEFAULT_REGION) 
        }

        if($Env:RD_CONFIG_ENDPOINT_URL){
            $Params.add("EndpointUrl", $Env:RD_CONFIG_ENDPOINT_URL) 
        }

        write-host "Source: $($source)"
        write-host "Destination: $($destination)"
        write-host ""

        $uriSource=[System.Uri]$source
        $uriDestination=[System.Uri]$destination

        $sourceFileList = @{}
        $destinationFileList = @{}

        if($uriSource.Scheme -eq "s3" -and $uriDestination.Scheme -ne "s3"){ 
            $sourceFileList = s3Files($uriSource)
            $destinationFileList = localFiles($uriDestination) 
        }

        if($uriSource.Scheme -ne "s3" -and $uriDestination.Scheme -eq "s3"){ 
            $sourceFileList = localFiles($uriSource) 
            $destinationFileList = s3Files($uriDestination)
        }

        if($uriSource.Scheme -eq "s3" -and $uriDestination.Scheme -eq "s3"){ 
            $sourceFileList = s3Files($uriSource)
            $destinationFileList = s3Files($uriDestination)
        } 

        if($remove -eq $True){
            write-host "------ remove from destination ------"
            $need_remove = $destinationFileList.Keys | Where-Object { 
                ($_ -notin $sourceFileList.Keys) -or ($destinationFileList.$_ -ne $sourceFileList.$_) 
            }

            if($uriDestination.Scheme -ne "s3"){
                foreach($local_file in $need_remove) { 
                    $full_path=$uriDestination.LocalPath +"\"+ $local_file
                    echo "Removing local file: $($full_path)"
                    Remove-Item $full_path
                }
            }else{
                foreach($s3_file in $need_remove) { 
                    $key = $uriSource.LocalPath +"/" + $s3_file
                    echo "Removing s3 file: $($key)"
                    Remove-S3Object -BucketName $uriDestination.Authority -Key $key -Force
                }
            }
        }
        

        write-host ""
        write-host "------ need to add to destination  ------"
        $need_add = $sourceFileList.Keys | Where-Object { 
            ($_ -notin $destinationFileList.Keys) -or ($sourceFileList.$_ -ne $destinationFileList.$_) 
        }

        if($uriSource.Scheme -eq "s3" -and $uriDestination.Scheme -ne "s3" ){
            #Download it from S3
            foreach($s3_file in $need_add) {

                $localFile=$uriDestination.AbsolutePath +"/" + $s3_file
                
                if($uriSource.LocalPath -ne "/"){
                    $key = $uriSource.LocalPath +"/" + $s3_file

                    if($key.StartsWith("/")){
                      $key=$key.Remove(0, 1)  
                    }
                }else{
                    $key = $s3_file
                }

                echo "Downloading S3 file: $($key) from bucket $($uriSource.Authority) to $($localFile)"
                echo ""

                Copy-S3Object  -BucketName $uriSource.Authority -Key $key -LocalFile $localFile @Params
            }
        }

        if($uriSource.Scheme -ne "s3" -and $uriDestination.Scheme -eq "s3" ){
            #Uploading it from S3
            foreach($local_file in $need_add) {
                $full_path=$uriSource.LocalPath +"\"+ $local_file

                if($uriDestination.LocalPath -ne "\"){
                    $key = $uriDestination.LocalPath +"\"+ $local_file
                }else{
                    $key = $local_file
                }

                echo "Uploading file: $($full_path) to $($key)"
                

                Write-S3Object -BucketName $uriDestination.Authority -Key $key -File $full_path -Force  @Params
            }
        }

        if($uriSource.Scheme -eq "s3" -and $uriDestination.Scheme -eq "s3" ){
            #Download it from S3
            foreach($s3_file in $need_add) {
                echo "Coping S3 file: $($s3_file) to $($uriDestination.AbsolutePath)"
                Copy-S3Object  -BucketName $uriSource.Authority -Key $s3_file -DestinationKey $s3_file -DestinationBucket $uriDestination.Authority @Params
            }
        }
        

    }Catch{
        Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
        exit 1
    }

}

