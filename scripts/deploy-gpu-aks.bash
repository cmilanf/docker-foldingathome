#!/bin/bash
VERSION='1.0'
headermsg () {
	echo "Folding@home Azure Kubernetes Service deployment script v${VERSION}"
	echo "...with GPU support via CUDA!"
	echo "Copyright (c) 2020 Carlos Milán Figueredo - MIT License"
	echo ""
}

usagemsg () {
	echo "$0 -g <resource group name> --template-file <template file> --parameters-file <parameters file>"
	echo "		--subscription <Azure subscription name or id> [--create-aad-sp] [--location <Azure region>]"
	echo ""
}

chkbin () {
    if ! [ -x "$(command -v $1)" ]; then
	    echo "ERROR: This script requires $1 program to continue. Please install it."
	    exit 1
    fi
}

# Function to change values in JSON parameters file
# $1 -> Parameter name
# $2 -> Variable with the parameter value
# $3 -> Parameter file name
jqsubs () {
	jq ".parameters.$1.value = \$argument" --arg argument "$2" $3 \
    	> $3.tmp && mv -f $3.tmp $3
}

headermsg
LOCATION='westeurope'
AKS_CLUSTER_NAME=''
DNS_PREFIX=''
while [ $# -gt 0 ]
do
	case "$1" in
		-g)
			RESOURCE_GROUP_NAME="$2"
			shift 2
			;;
		--template-file)
			TEMPLATE_FILE="$2"
			shift 2
			;;
		--parameters-file)
			PARAMETERS_FILE="$2"
			shift 2
			;;
        --subscription)
            SUBSCRIPTION="$2"
            shift 2
            ;;
        --create-aad-sp)
            CREATE_AAD_SP='yes'
            shift 1
            ;;
		--location)
			LOCATION="$2"
			shift 2
			;;
		--aks-cluster-name)
			AKS_CLUSTER_NAME="$2"
			shift 2
			;;
		--dns-prefix)
			DNS_PREFIX="$2"
			shift 2
			;;
		*)
			echo "ERROR: Incorrect arguments or syntax fail: $1"; echo ''
			usagemsg
			exit 1
			;;
	esac
done

if [ -z "${RESOURCE_GROUP_NAME}" ] || [ -z "${TEMPLATE_FILE}" ] || [ -z "${PARAMETERS_FILE}" ] \
	|| [ -z "${SUBSCRIPTION}" ]; then
	echo "ERROR: required parameter is missing."
	exit 2
fi

chkbin jq
chkbin ssh-keygen
chkbin az
chkbin sed

DATE=$(date '+%Y%m%d%H%M%S')
if ! [ -z ${AKS_CLUSTER_NAME} ]; then
	jqsubs 'resourceName' ${AKS_CLUSTER_NAME} ${PARAMETERS_FILE}
else
	AKS_CLUSTER_NAME=$(jq -r .parameters.resourceName.value ${PARAMETERS_FILE})
fi
if [ "${CREATE_AAD_SP}" == 'yes' ]; then
    echo "Creating Service Principal..."
    SP=$(az ad sp create-for-rbac --name ${AKS_CLUSTER_NAME}-${DATE} --output json)
    echo ${SP} | jq . > aks_sp_cred.json
    SP_NAME=$(echo ${SP} | jq -r .name)
    SP_APPID=$(echo ${SP} | jq -r .appId)
    SP_PWD=$(echo ${SP} | jq -r .password)
    SP_OBJECTID=$(az ad sp show --id ${SP_NAME} --query objectId -o tsv)
    cp -f ${PARAMETERS_FILE} ${PARAMETERS_FILE}.bak
	jqsubs 'existingServicePrincipalClientId' "${SP_APPID}" ${PARAMETERS_FILE}
	jqsubs 'existingServicePrincipalClientSecret' "${SP_PWD}" ${PARAMETERS_FILE}
	jqsubs 'existingServicePrincipalObjectId' "${SP_OBJECTID}" ${PARAMETERS_FILE}
	jqsubs 'existingVirtualNetworkResourceGroup' "${RESOURCE_GROUP_NAME}" ${PARAMETERS_FILE}
fi

echo "Generating GNU/Linux root SSH key pair..."
ssh-keygen -b 2048 -t rsa -f linuxAdminSshKey -q -N ""
jqsubs 'linuxAdminSshPublicKey' "$(cat linuxAdminSshKey.pub)" ${PARAMETERS_FILE}

if [ "$(jq .parameters.createVnet.value arm/deploy-gpu-aks.parameters.json)" = 'true' ]
then
	jqsubs 'existingVirtualNetworkResourceGroup' "${RESOURCE_GROUP_NAME}" ${PARAMETERS_FILE}
	jqsubs 'newOrExistingVirtualNetworkName' "${AKS_CLUSTER_NAME}" ${PARAMETERS_FILE}
fi
if ! [ -z ${DNS_PREFIX} ]; then
	jqsubs 'dnsPrefix' "${DNS_PREFIX}" ${PARAMETERS_FILE}
fi
sed -i '/^$/d' ${PARAMETERS_FILE}

echo "Deploying managed Kubernetes cluster..."
if [ $(az group exists -g ${RESOURCE_GROUP_NAME} --subscription ${SUBSCRIPTION}) = 'false' ]; then
	az group create -n ${RESOURCE_GROUP_NAME} -l ${LOCATION} --subscription ${SUBSCRIPTION}
fi
az deployment group create \
	-g ${RESOURCE_GROUP_NAME} \
	-n ${AKS_CLUSTER_NAME}-deployment \
	--template-file ${TEMPLATE_FILE} \
	--parameters @${PARAMETERS_FILE} \
    --subscription ${SUBSCRIPTION} \
	--verbose