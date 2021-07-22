#!/bin/bash

CLIENT_ID="${client_id}"
CLIENT_SECRET="${client_secret}"
TENANT_ID="${tenant_id}"
MSI_PRINCIPAL_ID="${msi_principal_id}"
ROLE_DEFINITION_ID="${role_definition_id}"

ACCESS_TOKEN=$(curl -X POST -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&resource=https%3A%2F%2Fgraph.microsoft.com%2F" "https://login.microsoftonline.com/$TENANT_ID/oauth2/token" | jq -r '.access_token')

curl -X POST -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" -d "{ \"principalId\":\"$MSI_PRINCIPAL_ID\", \"roleDefinitionId\":\"$ROLE_DEFINITION_ID\", \"directoryScopeId\":\"/\" }"  https://graph.microsoft.com/beta/roleManagement/directory/roleAssignments