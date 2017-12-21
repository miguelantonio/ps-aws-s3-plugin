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
.PARAMETER source
    Local path or S3 URI
 .PARAMETER destination
    Local path or S3 URI
.NOTES
  Version:        1.0.0
  Author:         Miguel
  Creation Date:  12/12/2017
  
#>


Param (
    [string]$accessKey,
    [string]$secretKey,
    [string]$source,
    [string]$destination
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

	
	#s3 to local file (download)
	if($uriSource.Scheme -eq "s3" -and $uriDestination.Scheme -eq "s3"){ 

		$key =  $uriSource.AbsolutePath.Remove(0, 1)
		$destinationKey =  $uriDestination.AbsolutePath.Remove(0, 1)


		Copy-S3Object	-BucketName $uriSource.Authority ` 
		                -Key $key `
		                -DestinationKey $destinationKey `
		                -DestinationBucket $uriDestination.Authority `
		                @Params
	}

	if($uriSource.Scheme -eq "s3" -and $uriDestination.Scheme -ne "s3"){ 
		write-host "Downloading $($uriSource.AbsoluteUri) to $($uriDestination.AbsoluteUri) "
		$key =  $uriSource.AbsolutePath.Remove(0, 1)

		$type=checkType($uriDestination.AbsolutePath)

		#check if the s3 path is not a file (a folder) then sue KeyPrefix instead
		$isS3File = $True

		try{
			$object = Get-S3Object -BucketName  $uriSource.Authority -Key $key @Params
			echo $object
		}Catch [Amazon.S3.AmazonS3Exception]{
			write-host "The s3 path is not a file, moving multiples files"
	    	$isS3File=$False
	    }

	    if($isS3File){
	    	#coping single file
	    	if($type -eq "file"){
				Copy-S3Object  -BucketName $uriSource.Authority `
							   -Key $key `
							   -LocalFile $uriDestination.AbsolutePath  `
							   @Params
			}else{
				Copy-S3Object  -BucketName $uriSource.Authority `
							   -Key $key `
							   -LocalFolder $uriDestination.AbsolutePath `
							   @Params
			}
	    }else{
			#coping multiples files
			Copy-S3Object  -BucketName $uriSource.Authority `
						   -KeyPrefix $key `
						   -LocalFolder $uriDestination.AbsolutePath `
						   @Params
	    
	    }
						
	}	


	if($uriSource.Scheme -ne "s3" -and $uriDestination.Scheme -eq "s3"){ 
		$type=checkType($uriSource.AbsolutePath)
		$key =  $uriDestination.AbsolutePath.Remove(0, 1)

		if($type -eq "file"){
			write-host "Upload file from  $($uriSource.AbsoluteUri) to $($uriDestination.AbsoluteUri) "

			if ([string]::IsNullOrWhitespace($key)){
				$key =  $uriSource.AbsolutePath.Remove(0, 1)
			}

			Write-S3Object -BucketName $uriDestination.Authority `
			               -Key $key `
			               -File $uriSource.AbsolutePath  `
			               @Params `
			               @WriteParams 

			Get-S3Object -BucketName $uriDestination.Authority -Key $key  @Params

		}else{
			write-host "Upload folder from  $($uriSource.AbsoluteUri) to $($uriDestination.AbsoluteUri) "

			if ([string]::IsNullOrWhitespace($key)){
				$key =  $uriSource.AbsolutePath.Remove(0, 1)
			}
			
			if($Env:RD_CONFIG_RECURSIVE){
		        Write-S3Object -BucketName $uriDestination.Authority -KeyPrefix '\' -Folder $uriSource.LocalPath -SearchPattern "*.*" -Recurse @Params @WriteParams 
		    }else{
		    	Write-S3Object -BucketName $uriDestination.Authority -KeyPrefix '\' -Folder $uriSource.LocalPath -SearchPattern "*.*" @Params @WriteParams 
		    }

			Get-S3Object -BucketName $uriDestination.Authority -KeyPrefix '\' @Params
		}
	}

}
