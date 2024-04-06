param location string
param environment string

var acrName = '${environment}-acr-${uniqueString(resourceGroup().id)}'
var vnetName = '${environment}-vnet-${uniqueString(resourceGroup().id)}'
var umiName = '${environment}-umi-${uniqueString(resourceGroup().id)}'
var acrPEName = '${environment}-acr-pe01'
var privateDnsZoneName = 'privatelink.azurecr.io'

module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'userAssignedIdentityDeployment'
  params: {
    name: umiName
    location: location
  }
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.5' = {
  name: 'virtualNetworkDeployment'
  params: {
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    name: vnetName
    location: location
    subnets: [
      {
        addressPrefix: '10.0.0.0/24'
        name: 'az-subnet-001'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        addressPrefix: '10.0.1.0/24'
        name: 'az-subnet-002'
      }
      {
        addressPrefix: '10.0.3.0/24'
        name: 'az-subnet-003'
      }
    ]
  }
}

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.2.4' = {
  name: 'privateDnsZoneDeployment'
  params: {
    name: privateDnsZoneName
    virtualNetworkLinks: [
      {
        registrationEnabled: true
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}

module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.4.1' = {
  name: 'privateEndpointDeployment'
  params: {
    name: acrPEName
    subnetResourceId: virtualNetwork.outputs.subnetNames[0]
    location: location
    privateDnsZoneGroupName: privateDnsZoneName
    privateDnsZoneResourceIds: [privateDnsZone.outputs.resourceId]
    privateLinkServiceConnections: [
      {
        name: acrPEName
        properties: {
          groupIds: [
            'registry'
          ]
          privateLinkServiceId: registry.outputs.resourceId
        }
      }
    ]
  }
}

module registry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'registryDeployment'
  params: {
    managedIdentities: {
      systemAssigned: false
      userAssignedResourceIds: [
        userAssignedIdentity.outputs.resourceId
      ]
    }
    name: acrName
    acrAdminUserEnabled: false
    acrSku: 'Premium'
    azureADAuthenticationAsArmPolicyStatus: 'enabled'
    exportPolicyStatus: 'enabled'
    location: location
    quarantinePolicyStatus: 'enabled'
    softDeletePolicyDays: 7
    softDeletePolicyStatus: 'disabled'
    tags: {
      Environment: environment
      'hidden-title': 'Container Registry'
      Role: 'DeploymentValidation'
    }
    trustPolicyStatus: 'enabled'
  }
}
