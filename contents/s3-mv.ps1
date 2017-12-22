#Requires -Version 4

<#
.SYNOPSIS
  Move AWS bucket objects
.DESCRIPTION
  Move AWS bucket objects
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

	Function checkLocalPath($path){
		$ValidPath = Test-Path $path -IsValid
		If ($ValidPath -eq $False) {
			write-error "local Path is not valid"
			return $false
		}

		return $True
	}


	Function checkType($path){
		if( (Get-Item $path) -is [System.IO.DirectoryInfo] ) {
			return "directory"
		}else{
			return "file"
		}
	}
}

Process {

	$source=$Env:RD_CONFIG_SOURCE
	$destination=$Env:RD_CONFIG_DESTINATION

	$uriSource=[System.Uri]$source
	$uriDestination=[System.Uri]$destination

	$Params = @{}

	if($Env:RD_CONFIG_DEFAULT_REGION){
        $Params.add("Region", $Env:RD_CONFIG_DEFAULT_REGION) 
    }

    if($Env:RD_CONFIG_ENDPOINT_URL){
        $Params.add("EndpointUrl", $Env:RD_CONFIG_ENDPOINT_URL) 
    }

    $WriteParams = @{}

	if($Env:RD_CONFIG_SEARCH_PATTERN){
        $WriteParams.add("SearchPattern", $Env:RD_CONFIG_SEARCH_PATTERN) 
    }

	
	if($uriSource.Scheme -eq "s3" -and $uriDestination.Scheme -eq "s3"){ 

		$files = Get-S3Object -BucketName $uriSource.Authority -KeyPrefix $uriSource.PathAndQuery @Params

		foreach($file in $files) { 
			Copy-S3Object	-BucketName $uriSource.Authority -Key $file.key -DestinationKey $file.key -DestinationBucket $uriDestination.Authority -Force @Params
	    } 
	}

	if($uriSource.Scheme -eq "s3" -and $uriDestination.Scheme -ne "s3"){ 
		$key =  $uriSource.LocalPath.Remove(0, 1)

		write-host "Downloading s3://$($uriSource.Authority)/$key  to $($uriDestination.AbsolutePath) "
		

		$type=checkType($uriDestination.AbsolutePath)

		$s3path = $uriSource.LocalPath

		if($s3path.StartsWith("/")){
          $s3path=$s3path.Remove(0, 1)  
        }

		$files = Get-S3Object -BucketName $uriSource.Authority -KeyPrefix $s3path @Params
		
		if($files -eq $null){
			write-error "The S3 path doesn't have files or the file doesn't exists"
			exit 1
		}	

		foreach($file in $files) { 
			#coping single file
	    	if($type -eq "file"){
				Copy-S3Object  -BucketName $uriSource.Authority -Key $file.key -LocalFile $uriDestination.AbsolutePath  @Params
			}else{
				Copy-S3Object  -BucketName $uriSource.Authority -Key $file.key -LocalFolder $uriDestination.AbsolutePath @Params
			}
		}	
						
	}	


	if($uriSource.Scheme -ne "s3" -and $uriDestination.Scheme -eq "s3"){ 
		$type=checkType($uriSource.LocalPath)

		if($uriDestination.LocalPath -ne "/"){
            $key =  $uriDestination.LocalPath.Remove(0, 1)
        }else{
            $key = [System.IO.Path]::GetFileName($uriSource.LocalPath)
        }

		if($type -eq "file"){
			write-host "Upload file from  $($uriSource.LocalPath) to s3://$($uriDestination.Authority)/$key "

			if ([string]::IsNullOrWhitespace($key)){
				$key =  $uriSource.LocalPath.Remove(0, 1)
			}

			Write-S3Object -BucketName $uriDestination.Authority -Key $key -File $uriSource.LocalPath  @Params @WriteParams 

			Get-S3Object -BucketName $uriDestination.Authority -Key $key  @Params

		}else{
			write-host "Upload folder from  $($uriSource.LocalPath) to $($uriDestination.LocalPath) "

			if ([string]::IsNullOrWhitespace($key)){
				$key =  $uriSource.AbsolutePath.Remove(0, 1)
			}
			
			if($Env:RD_CONFIG_RECURSIVE){
		        Write-S3Object -BucketName $uriDestination.Authority -KeyPrefix $key -Folder $uriSource.LocalPath -Recurse @Params @WriteParams 
		    }else{
		    	Write-S3Object -BucketName $uriDestination.Authority -KeyPrefix $key -Folder $uriSource.LocalPath @Params @WriteParams 
		    }

			Get-S3Object -BucketName $uriDestination.Authority -KeyPrefix $key @Params
		}
	}


	write-host ""
	write-host "Removing source"

	if($uriSource.Scheme -eq "s3"){ 
		$files = Get-S3Object -BucketName $uriSource.Authority -KeyPrefix $uriSource.LocalPath @Params

	    foreach($file in $files) { 
	        write-host "Removing S3 file :  $($file.key)"
	        Remove-S3Object -BucketName $uriSource.Authority -Key $file.key -Force @Params
	    }
    }else{

	    Get-ChildItem $uriSource.LocalPath -Recurse  | % {

            $filePath = $_.FullName

            $type=checkType($filePath)

            if($type -eq "file"){
                write-host "Removing local file :  $($filePath)"
                Remove-Item $filePath
            }
	    }
    }


}
