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

headermsg
LOCATION='westeurope'
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
RESOURCENAME=$(jq -r .parameters.resourceName.value ${PARAMETERS_FILE})
if [ "${CREATE_AAD_SP}" == 'yes' ]; then
    echo "Creating Service Principal..."
    SP=$(az ad sp create-for-rbac --name ${RESOURCENAME}-${DATE} --output json)
    echo ${SP} | jq . > aks_sp_cred.json
    SP_NAME=$(echo ${SP} | jq -r .name)
    SP_APPID=$(echo ${SP} | jq -r .appId)
    SP_PWD=$(echo ${SP} | jq -r .password)
    SP_OBJECTID=$(az ad sp show --id ${SP_NAME} --query objectId -o tsv)
    cp -f ${PARAMETERS_FILE} ${PARAMETERS_FILE}.bak 
    jq '.parameters.existingServicePrincipalClientId.value = $sp_appid' --arg sp_appid "${SP_APPID}" ${PARAMETERS_FILE} \
    	> ${PARAMETERS_FILE}.tmp \
    	&& mv -f ${PARAMETERS_FILE}.tmp ${PARAMETERS_FILE}
    jq '.parameters.existingServicePrincipalClientSecret.value = $sp_pwd' --arg sp_pwd "${SP_PWD}" ${PARAMETERS_FILE} \
    	> ${PARAMETERS_FILE}.tmp \
    	&& mv -f ${PARAMETERS_FILE}.tmp ${PARAMETERS_FILE}
    jq '.parameters.existingServicePrincipalObjectId.value = $sp_objectid' --arg sp_objectid "${SP_OBJECTID}" ${PARAMETERS_FILE} \
    	> ${PARAMETERS_FILE}.tmp \
    	&& mv -f ${PARAMETERS_FILE}.tmp ${PARAMETERS_FILE}
    jq '.parameters.existingVirtualNetworkResourceGroup.value = $resource_group_name' --arg resource_group_name "${RESOURCE_GROUP_NAME}" ${PARAMETERS_FILE} \
    	> ${PARAMETERS_FILE}.tmp \
    	&& mv -f ${PARAMETERS_FILE}.tmp ${PARAMETERS_FILE}
fi

echo "Generating GNU/Linux root SSH key pair..."
ssh-keygen -b 2048 -t rsa -f linuxAdminSshKey -q -N ""
jq '.parameters.linuxAdminSshPublicKey.value = $public_key' --arg public_key "$(cat linuxAdminSshKey.pub)" ${PARAMETERS_FILE} \
    > ${PARAMETERS_FILE}.tmp \
    && mv -f ${PARAMETERS_FILE}.tmp ${PARAMETERS_FILE}
sed -i '/^$/d' ${PARAMETERS_FILE}

jq '.parameters.linuxAdminSshPublicKey.value = $public_key' --arg public_key "$(cat linuxAdminSshKey.pub)" ${PARAMETERS_FILE} \
    > ${PARAMETERS_FILE}.tmp \
    && mv -f ${PARAMETERS_FILE}.tmp ${PARAMETERS_FILE}
sed -i '/^$/d' ${PARAMETERS_FILE}

if [ "$(jq .parameters.createVnet.value arm/deploy-gpu-aks.parameters.json)" = 'true' ]
then
	jq '.parameters.existingVirtualNetworkResourceGroup.value = $vnetrg' --arg vnetrg "${RESOURCE_GROUP_NAME}" ${PARAMETERS_FILE} \
    	> ${PARAMETERS_FILE}.tmp \
    	&& mv -f ${PARAMETERS_FILE}.tmp ${PARAMETERS_FILE}
	sed -i '/^$/d' ${PARAMETERS_FILE}
fi

echo "Deploying managed Kubernetes cluster..."
if [ $(az group exists -g ${RESOURCE_GROUP_NAME}) = 'false' ]; then
	az group create -n ${RESOURCE_GROUP_NAME} -l ${LOCATION}
fi
az deployment group create \
	-g ${RESOURCE_GROUP_NAME} \
	-n ${RESOURCENAME}-deployment \
	--template-file ${TEMPLATE_FILE} \
	--parameters @${PARAMETERS_FILE} \
    --subscription ${SUBSCRIPTION} \
	--verbose