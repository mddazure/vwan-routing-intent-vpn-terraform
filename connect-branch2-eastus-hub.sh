az extension add --name virtual-wan

echo "# VNETGW: Get parameters from onprem vnet gateway"
vnetgwtunnelip1=$(az network vnet-gateway show -n qonprem2-gw -g vwan-ri-terraform-rg --query "bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]" --output tsv)
echo "VNET GW Tunnel address #1:" $vnetgwtunnelip1
vnetgwbgpip1=$(az network vnet-gateway show -n qonprem2-gw -g vwan-ri-terraform-rg --query "bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses"  --output tsv)
echo "VNET GW BGP address:" $vnetgwbgpip1
vnetgwasn=$(az network vnet-gateway show -n qonprem2-gw -g vwan-ri-terraform-rg --query "bgpSettings.asn" --output tsv)
echo "VNET GW BGP ASN:" $vnetgwasn
sharedkey="terraf0rm"

echo "# VWAN: Create remote site"
az network vpn-site create --ip-address $vnetgwtunnelip1 --name onprem2 -g vwan-ri-terraform-rg --asn $vnetgwasn --bgp-peering-address $vnetgwbgpip1 --virtual-wan demo-vwan --location westeurope --device-model VNETGW --device-vendor Azure --link-speed 100

echo "# VWAN: Create connection - remote site to hub gw"
az network vpn-gateway connection create --gateway-name demo-eastus-hub-vpngw --name onprem2-eastus --remote-vpn-site onprem2 -g vwan-ri-terraform-rg --shared-key $sharedkey --enable-bgp true --no-wait

echo "# VWAN: Get parameters from VWAN Hub GW"
hubgwtunneladdress=$(az network vpn-gateway show --name demo-eastus-hub-vpngw  -g vwan-ri-terraform-rg --query "bgpSettings.bgpPeeringAddresses[?ipconfigurationId == 'Instance0'].tunnelIpAddresses[0]" --output tsv)
echo "Hub GW Tunnel address:" $hubgwtunneladdress
hubgwbgpaddress=$(az network vpn-gateway show --name demo-eastus-hub-vpngw  -g vwan-ri-terraform-rg --query "bgpSettings.bgpPeeringAddresses[?ipconfigurationId == 'Instance0'].defaultBgpIpAddresses" --output tsv)
echo "Hub GW BGP address:" $hubgwbgpaddress
hubgwasn=$(az network vpn-gateway show --name demo-eastus-hub-vpngw  -g vwan-ri-terraform-rg --query "bgpSettings.asn" --output tsv)
echo "Hub GW BGP ASN:" $hubgwasn
hubgwkey=$(az network vpn-gateway connection show --gateway-name demo-eastus-hub-vpngw --name onprem2 -g vwan-ri-terraform-rg --query "sharedKey" --output tsv)

echo "# create local network gateway"
az network local-gateway create -g vwan-ri-terraform-rg -n lng2 --gateway-ip-address $hubgwtunneladdress --location eastus --asn $hubgwasn --bgp-peering-address $hubgwbgpaddress

echo "# VNET GW: connect from vnet gw to local network gateway"
az network vpn-connection create -n to-eastus-hub --vnet-gateway1 qonprem2-gw -g vwan-ri-terraform-rg --local-gateway2 lng2 -l westeurope --shared-key $sharedkey --enable-bgp
