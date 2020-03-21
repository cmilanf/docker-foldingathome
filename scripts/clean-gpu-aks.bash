#!/bin/bash
VERSION='1.0'
headermsg () {
    echo "Folding@home Azure Kubernetes Service DELETE script v${VERSION}"
    echo "Copyright (c) 2020 Carlos Milán Figueredo - MIT License"
    echo ""
}

usagemsg () {
    echo "$0 -g <resource group name> --parameters-file <parameters file> --subscription <Azure subscription name or id>"
    echo "   --iknowwhatiamdoing"
    echo ""
}
while [ $# -gt 0 ]
do
    case "$1" in
        -g)
            RESOURCE_GROUP_NAME="$2"
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
        --iknowwhatiamdoing)
            IKNOW=true
            shift 1
            ;;
        *)
            echo "Incorrect arguments or syntax fail: $1"; echo ''
            exit 1
            ;;
    esac
done
if [ "$IKNOW" = true ]; then
    AAD_SP_CLIENTID=$(jq -r .parameters.existingServicePrincipalClientId.value ${PARAMETERS_FILE})
    echo "Azure AD SP to DELETE is: $AAD_SP_CLIENTID"
    echo "I will delete it in 5 seconds!"
    sleep 5
    az ad sp delete --id $AAD_SP_CLIENTID
    echo "I am going to delete resource group $RESOURCE_GROUP_NAME in 5 seconds!"
    sleep 5
    az group delete -y -g $RESOURCE_GROUP_NAME --subscription $SUBSCRIPTION
else
    echo "You don't know what you are doing. Please use --iknowwhatiamdoing."
fi