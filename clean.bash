#!/bin/bash
PARAMETERS_FILE='arm/deploy-gpu-aks.parameters.json'
K8SDEPLOY_FILE='k8s/fah-deployment.yaml'
headermsg () {
	echo "Folding@home CLEAN script v${VERSION}"
	echo "Copyright (c) 2020 Carlos Milán Figueredo - MIT License"
	echo ""
}

usagemsg () {
	echo "This script removes deployment modifications from project folder. Be aware you may lose information by running it."
}

pause () {
    read -n 1 -s -r -p "Press any key to continue"
    echo ''
}

chkbin () {
    if ! [ -x "$(command -v $1)" ]; then
	    echo "ERROR: This script requires $1 program to continue. Please install it."
	    exit 1
    fi
}

headermsg
usagemsg
pause
chkbin sed
rm -vf aks_sp_cred.json
rm -vf linuxAdminSshKey*
jq '.parameters.linuxAdminSshPublicKey.value = $v' --arg v '' ${PARAMETERS_FILE} \
    > ${PARAMETERS_FILE}.tmp \
    && mv -f ${PARAMETERS_FILE}.tmp ${PARAMETERS_FILE}
jq '.parameters.existingServicePrincipalClientId.value = $v' --arg v '' ${PARAMETERS_FILE} \
    > ${PARAMETERS_FILE}.tmp \
    && mv -f ${PARAMETERS_FILE}.tmp ${PARAMETERS_FILE}
jq '.parameters.existingServicePrincipalClientSecret.value = $v' --arg v '' ${PARAMETERS_FILE} \
    > ${PARAMETERS_FILE}.tmp \
    && mv -f ${PARAMETERS_FILE}.tmp ${PARAMETERS_FILE}
jq '.parameters.existingServicePrincipalObjectId.value = $v' --arg v '' ${PARAMETERS_FILE} \
    > ${PARAMETERS_FILE}.tmp \
    && mv -f ${PARAMETERS_FILE}.tmp ${PARAMETERS_FILE}
rm -vf ${PARAMETERS_FILE}.bak
sed -i '/^$/d' ${PARAMETERS_FILE}
sed -i "25s|^.*$|          value: Anonymous|" ${K8SDEPLOY_FILE}
sed -i "27s|^.*$|          value: '0'|" ${K8SDEPLOY_FILE}
echo 'Done'
