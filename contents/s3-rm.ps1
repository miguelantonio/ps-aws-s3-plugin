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
.PARAMETER S3Uri
    S3 URI
.NOTES
  Version:        1.0.0
  Author:         Miguel
  Creation Date:  12/20/2017
  
#>


Param (
    [string]$accessKey,
    [string]$secretKey,
    [string]$S3Uri
)

Begin {
	Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKey 
}

Process {

	Try{

		$Params = @{}

    	if($Env:RD_CONFIG_DEFAULT_REGION){
            $Params.add("Region", $Env:RD_CONFIG_DEFAULT_REGION) 
        }

        if($Env:RD_CONFIG_ENDPOINT_URL){
            $Params.add("EndpointUrl", $Env:RD_CONFIG_ENDPOINT_URL) 
        }

        $uri=[System.Uri]$S3Uri

        $files = Get-S3Object -BucketName $uri.Authority -KeyPrefix $uri.PathAndQuery @Params

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

