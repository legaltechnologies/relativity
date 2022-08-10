function Get-RelativityAPIToken ($relativityInstance, $clientId, $clientSecret)
{
    $headers = @{}
    $headers.Add('Content-Type','application/x-www-form-urlencoded')
    $headers.Add('X-CSRF-Header','-')

    $postdata = "client_id=$clientId&client_secret=$clientSecret&scope=SystemUserInfo&grant_type=client_credentials"

    try
    {
        $token = Invoke-RestMethod -Method Post -Headers $headers -UseBasicParsing -Uri "https://$relativityInstance/Relativity/Identity/connect/token" -Body $postdata
    }
    catch
    {
        Write-Error -Exception 'Bad ID or Secret' -Category AuthenticationError -RecommendedAction 'Check ID and Secret'
    }
    $token.access_token
}

# If I return the object, when serializing back to JSON, search criteria are gone. 
# If I send it to a -OutFile, I have a JSON which I can work with (e.g. replace conditions if I have a template search)
function Get-RelativitySearch ($relativityInstance, $accessToken, $workspaceArtifactID, $searchArtifactID)
{
    $headers = @{}
    #$headers.Add('Content-Type','application/x-www-form-urlencoded')
    $headers.Add('X-CSRF-Header','-')
    $headers.Add('Authorization',"Bearer $accessToken")

    $contentType = "application/json"

    $conditions = @{"workspaceArtifactID"=$workspaceArtifactID;"searchArtifactID"=$searchArtifactID}
    $jsonBody = ConvertTo-Json -InputObject $conditions

    $url = "https://$relativityInstance/Relativity.REST/api/Relativity.Services.Search.ISearchModule/Keyword%20Search%20Manager/ReadSingleAsync"
    Invoke-RestMethod -Method Post -UseBasicParsing -Uri $url -Headers $headers -ContentType $contentType -Body $jsonBody
}

function Copy-RelativitySearch ($relativityInstance, $accessToken, $workspaceArtifactID, $searchArtifactID)
{
    $headers = @{}
    #$headers.Add('Content-Type','application/x-www-form-urlencoded')
    $headers.Add('X-CSRF-Header','-')
    $headers.Add('Authorization',"Bearer $accessToken")

    $contentType = "application/json"

    $conditions = @{"workspaceArtifactID"=$workspaceArtifactID;"searchArtifactID"=$searchArtifactID}
    $jsonBody = ConvertTo-Json -InputObject $conditions

    $url = "https://$relativityInstance/Relativity.REST/api/Relativity.Services.Search.ISearchModule/Keyword%20Search%20Manager/CopySingleAsync"
    Invoke-RestMethod -Method Post -UseBasicParsing -Uri $url -Headers $headers -ContentType $contentType -Body $jsonBody
}

function Set-RelativitySearch ($relativityInstance, $accessToken, $workspaceArtifactID, $conditions)
{
    $headers = @{}
    #$headers.Add('Content-Type','application/x-www-form-urlencoded')
    $headers.Add('X-CSRF-Header','-')
    $headers.Add('Authorization',"Bearer $accessToken")

    $contentType = "application/json"

    $jsonBody = '{"workspaceArtifactID": ' + $workspaceArtifactID + ', "searchDTO": '+ $conditions + ' }'

    $url = "https://$relativityInstance/Relativity.REST/api/Relativity.Services.Search.ISearchModule/Keyword%20Search%20Manager/UpdateSingleAsync"
    Invoke-RestMethod -Method Post -UseBasicParsing -Uri $url -Headers $headers -ContentType $contentType -Body $jsonBody
}

# Not done yet
<#
function New-RelativitySearch ($relativityInstance, $accessToken, $conditions)
{
    $headers = @{}
    #$headers.Add('Content-Type','application/x-www-form-urlencoded')
    $headers.Add('X-CSRF-Header','-')
    $headers.Add('Authorization',"Basic $accessToken")

    $url = "https://$relativityInstance/Relativity.REST/api/Relativity.Services.Search.ISearchModule/Keyword%20Search%20Manager/CreateSingleAsync"
}
#>

<# Helper functions
GetEmailToLinkUrlAsync
GetFieldsForCriteriaConditionAsync
GetFieldsForObjectCriteriaCollectionAsync
GetFieldsForSearchResultViewAsync
GetSearchIncludesAsync
GetSearchOwnersAsync
GetAccessStatusAsync
#>
