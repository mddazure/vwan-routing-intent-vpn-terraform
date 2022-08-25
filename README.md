# VWAN with Routing Intenet deployed through Terraform

Documentation: [How to configure Virtual WAN Hub routing intent and routing policies](https://docs.microsoft.com/en-us/azure/virtual-wan/how-to-routing-policies) 

Pre-GA:
- Both Hubs are deployed in West Europe. 
- Portal should be accessed at aka.ms/interhub to view Routing Intent settings in Firewall Manager

## Topology

![image](images/topology.png)

## Deployment

In Cloud Shell:

- Log in to Azure Cloud Shell at https://shell.azure.com/ and select Bash
- Ensure Azure CLI and extensions are up to date:
  
  `az upgrade --yes`
  
- If necessary select your target subscription:
  
  `az account set --subscription <Name or ID of subscription>`
  
- Clone the  GitHub repository:
  
  `git clone https://github.com/mddazure/vwan-routing-intent-vpn-terraform`
  
  - Change directory:
  
  `cd ./vwan-routing-intent-vpn-terraform`
  - Initialize terraform and download the azurerm resource provider:

  `terraform init`

- Now start the deployment (when prompted, confirm with **yes** to start the deployment):
 
  `terraform apply`

## Connect the branch 

To establish the VPN connection between the VWAN Hub and the "onprem" gateway, run this script:

`./connect-branch.sh`
