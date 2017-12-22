#Requires -Version 4

<#
.SYNOPSIS
  Create an AWS bucket
.DESCRIPTION
  Create a bucket
.PARAMETER accessKey
    AWS Access Key
.PARAMETER secretKey
    AWS Secret Key
.PARAMETER S3Uri
    S3 URI
.NOTES
  Version:        1.0.0
  Author:         Rundeck
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

		New-S3Bucket -BucketName $uri.Authority @Params
		
    }
    
    Catch{
    	Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
    	exit 1
    }



}

