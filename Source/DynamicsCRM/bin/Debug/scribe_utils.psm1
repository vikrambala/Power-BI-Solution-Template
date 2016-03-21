﻿function SUGet-AuthHeader
{
    param([Parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $userName,
          [Parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()][string] $password)

    $auth = $userName + ":" + $password
    $auth_payload = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($auth))
    $headers = @{}
    $headers.Add("Authorization", $auth_payload)

    # Generate authentication payload

    return $headers
}

function SUGet-SolutionID
{
    param([Parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()] [string]$solutionName,
          [Parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()] [string]$organizationID,
          [Parameter(Mandatory=$true, Position=2)][ValidateNotNull()] $authenticationHeader)

    $uri_solutions = "https://api.scribesoft.com/v1/orgs/{0}/solutions"
    
    $uri = [string]::Format($uri_solutions, $organizationID)
    
    $response = Invoke-RestMethod -Method Get -Headers $authenticationHeader -Uri $uri
    $id = $response.Where({$_.name -eq $solutionName}).id
    
    return $id
}

function SUGet-SolutionStatus
{
    param([Parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $solutionID,
          [Parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()][string] $organizationID,
          [Parameter(Mandatory=$true, Position=2)][ValidateNotNull()] $authenticationHeader)

    $uri_solution_status = "https://api.scribesoft.com/v1/orgs/{0}/solutions/{1}"
    $uri = [string]::Format($uri_solution_status, $organizationID, $solutionID)
    
    $response = Invoke-RestMethod -Method Get -Headers $authenticationHeader -Uri $uri
    $status = $response.status

    return $status
}


function SUGet-AgentID
{
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$agentName,
          [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$organizationID,
          [Parameter(Mandatory=$true)][ValidateNotNull()] $authenticationHeader)

    $uri_agents = "https://api.scribesoft.com/v1/orgs/{0}/agents"
    
    $uri = [string]::Format($uri_agents, $organizationID)
    
    $response = Invoke-RestMethod -Method Get -Headers $authenticationHeader -Uri $uri
    [string]$id = $response.Where({$_.name -eq $agentName}).id

    return $id
}

function SUNew-ReplicationSolution
{
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$solutionName,
          [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$organizationID,
          [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$agentID,
          [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$connectionIDForSource,
          [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$connectionIDForTarget,
          [Parameter(Mandatory=$true)][ValidateNotNull()] $authenticationHeader)

    $uri_solution = "https://api.scribesoft.com/v1/orgs/{0}/solutions"
    $template = @"
                    {
                        "Name": "",
                        "AgentId": "",
                        "Description": "",
                        "ConnectionIdForSource": "",
                        "ConnectionIdForTarget": "",
                        "SolutionType": ""
                    }
"@

    $uri = [string]::Format($uri_solution, $organizationID)
    $obj = $template | ConvertFrom-Json
    $obj.Name = $solutionName
    $obj.AgentId = $agentID
    $obj.ConnectionIdForSource = $connectionIDForSource
    $obj.ConnectionIdForTarget = $connectionIDForTarget
    $obj.SolutionType = "Replication"
    
    $body = $obj | ConvertTo-Json
    $response = Invoke-RestMethod -Method Post -Headers $authenticationHeader -Uri $uri -ContentType "application/json" -Body $body
    $id = $response.id

    return $id
}

# Internal function
function SUGet-ConnectorID()
{
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$ConnectionType,
          [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$OrganizationID,
          [Parameter(Mandatory=$true)][ValidateNotNull()] $AuthenticationHeader)

    $uri_connectors = "https://api.scribesoft.com/v1/orgs/{0}/connectors"
    $uri = [string]::Format($uri_connectors, $OrganizationID)
    
    $response = Invoke-RestMethod -Method Get -Headers $AuthenticationHeader -Uri $uri
    
    $id = $null
    
    switch ($ConnectionType)
    {
        "CRM"
        {
            $id = $response.Where({$_.name -eq "Microsoft Dynamics CRM"}).id
        }
        "MSSQL"
        {
            $id = $response.Where({$_.name -eq "Microsoft SQL Server"}).id
        }
        "Salesforce"
        {
            $id = $response.Where({$_.name -eq "Salesforce"}).id
        }
    }

    return $id
}


function SUNew-Connection
{
    param([Parameter(Mandatory=$true)][ValidateSet("CRM", "MSSQL", "Salesforce")][ValidateNotNullOrEmpty()] [string]$ConnectionType,
          [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$ConnectionName,
          [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$OrganizationID,
          [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [string]$AgentID,
          [Parameter(Mandatory=$true)][ValidateNotNull()] $AuthenticationHeader,
          [Parameter(Mandatory=$false)] $Properties)

    $uri_connections = "https://api.scribesoft.com/v1/orgs/{0}/connections"
    $uri_connection  = "https://api.scribesoft.com/v1/orgs/{0}/connections/{1}"
    $template = @"
                {
                    "Id": "",
                    "Alias": "",
                    "Color": "",
                    "ConnectorId": "",
                    "Name": "",
                    "Properties": [
                                    {
                                        "Key": "",
                                        "Value": ""
                                    }
                                  ]
                }
"@

    #  Check if connection exists and drop it
    $uri = [string]::Format($uri_connections, $OrganizationID)
    $response = Invoke-RestMethod -Method Get -Headers $AuthenticationHeader -Uri $uri
    $found_connection = $response.Where({$_.name -eq $ConnectionName})
    if ($found_connection -ne $null)
    {
        $id = $found_connection.id
        $uri = [string]::Format($uri_connection, $OrganizationID, $id)
        $response = Invoke-RestMethod -Method Delete -Headers $AuthenticationHeader -Uri $uri
    }

    #  Obtain ID of the connector
    $connector_id = SUGet-ConnectorID -ConnectionType $ConnectionType -OrganizationID $OrganizationID -AuthenticationHeader $AuthenticationHeader

    #  Fill in required information for the connection
    $obj = $template | ConvertFrom-Json
    $obj.Name = $ConnectionName
    $obj.ConnectorId = $connector_id
    $obj.Color = "#FFEA69A6"
    #  Set properties if any were passed
    if ($Properties -ne $null)
    {
        $obj.Properties = $Properties
    }

    $uri = [string]::Format($uri_connections, $OrganizationID)
    $body = $obj | ConvertTo-Json
    $response = Invoke-RestMethod -Method Post -Headers $authenticationHeader -Uri $uri -ContentType "application/json" -Body $body
    $id = $response.id

    return $id
}




Export-ModuleMember -Function SUGet-AuthHeader
Export-ModuleMember -Function SUGet-SolutionID
Export-ModuleMember -Function SUGet-AgentID
Export-ModuleMember -Function SUGet-SolutionStatus
Export-ModuleMember -Function SUNew-ReplicationSolution
Export-ModuleMember -Function SUNew-Connection
# Internal function
Export-ModuleMember -Function SUGet-ConnectorID


