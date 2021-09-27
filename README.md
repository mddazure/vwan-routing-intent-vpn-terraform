# VWAN with Terraform

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
  
  `git clone https://github.com/mddazure/vwan-vpn-terraform`
  
  - Change directory:
  
  `cd ./vwan-vpn-terraform`
  - Initialize terraform and download the azurerm resource provider:

  `terraform init`

- Now start the deployment (when prompted, confirm with **yes** to start the deployment):
 
  `terraform apply`

## Connect the branch 

To establish the VPN connection between the VWAN Hub and the "onprem" gateway, run this script:

`./connect-branch.sh`
