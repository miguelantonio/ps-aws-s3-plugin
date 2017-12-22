#Requires -Version 4

<#
.SYNOPSIS
  Remove objects
.DESCRIPTION
  Remove objects from an AWS Bucket
.PARAMETER accessKey
    AWS Access Key
.PARAMETER secretKey
    AWS Secret Key
.NOTES
  Version:        1.0.0
  Author:         Rundeck
  Creation Date:  12/20/2017
  
#>


Param (
    [string]$accessKey,
    [string]$secretKey
)

Begin {
	Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKey 
}

Process {

	Try{

        $S3Uri = $Env:RD_CONFIG_S3URI

		$Params = @{}

    	if($Env:RD_CONFIG_DEFAULT_REGION){
            $Params.add("Region", $Env:RD_CONFIG_DEFAULT_REGION) 
        }

        if($Env:RD_CONFIG_ENDPOINT_URL){
            $Params.add("EndpointUrl", $Env:RD_CONFIG_ENDPOINT_URL) 
        }

        $uri=[System.Uri]$S3Uri

        if($uri.LocalPath -ne "/"){
            $KeyPrefix = $uri.LocalPath

            if($KeyPrefix.StartsWith("/")){
              $KeyPrefix=$KeyPrefix.Remove(0, 1)  
            }

        }else{
            $KeyPrefix = $uri.LocalPath
        }

        $files = Get-S3Object -BucketName $uri.Authority -KeyPrefix $KeyPrefix @Params

        foreach($file in $files) { 

            write-host "Removing file :  $($file.key)"
            Remove-S3Object -BucketName $uri.Authority -Key $file.key -Force @Params

        }

        write-host "Done"

		
    }
    
    Catch{
    	Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
    	exit 1
    }



}

