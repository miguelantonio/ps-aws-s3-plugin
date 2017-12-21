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
.PARAMETER S3Uri
    S3 URI
.NOTES
  Version:        1.0.0
  Author:         Miguel
  Creation Date:  12/12/2017
  
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

		$human_print=$False
		if($Env:RD_CONFIG_HUMAN_READABLE -eq "true"){
            $human_print=$True
        }

        $Params = @{}

    	if($Env:RD_CONFIG_DEFAULT_REGION){
            $Params.add("Region", $Env:RD_CONFIG_DEFAULT_REGION) 
        }

        if($Env:RD_CONFIG_ENDPOINT_URL){
            $Params.add("EndpointUrl", $Env:RD_CONFIG_ENDPOINT_URL) 
        }

        $uri=[System.Uri]$S3Uri

        $KeyPrefix =  $uri.PathAndQuery +"/"

		$files = Get-S3Object -BucketName $uri.Authority -KeyPrefix $KeyPrefix @Params

		if($human_print){
			#print human readable
			foreach($file in $files) { 
				write-host "key:  $($file.key)"
				write-host "LastModified: $($file.LastModified)"
				write-host "Owner: $($file.Owner)"
				write-host "Size: $([math]::Round($file.Size/1024/1024,2)) MB" 
				write-host "ETag: $($file.ETag)"
				write-host "StorageClass: $($file.StorageClass)"

				write-host "---------------------------------------------"

			}

		}else{

			#print JSON
			$json=$files | ConvertTo-Json
			echo $json
		}

		
    }
    
    Catch{
    	Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
    	exit 1
    }



}

