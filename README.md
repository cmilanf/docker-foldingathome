# Docker Folding@home at Microsoft AKS and ACI with GPU support
[Folding@home](https://foldingathome.org/) is a biomedical research project that use the distributed computing power of volunteers arround the world. It consist on a client program that retrieves a computing workload from a server processes it and return the results back. There are client versions for Windows, macOS or GNU/Linux.

The biomedical research is focused in the complex calculations of proteins folding that would allow scientist to develop a drug or antibody targeting. This would have impact in the treatment of a wide range of diseases.

With quickly evolving pandemia of the [COVID-19](https://en.wikipedia.org/wiki/Coronavirus_disease_2019), it came to my attention that computer scientist should provide any help we would be able to: whatever it would be providing remote collaboration tools during quarentine periods, predicting future situation through data analysis or helping scientist in the development of tratments or vaccines.

Then I saw the following tweet from the Folding@home official account:
![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/tweet-fah.png)

So I took no time into setting up the client on my workstation and start recieving data for processing that would contribute with the COVID-19 research! Though there are exceptions, most of the COVID-19 related research require GPU computing power rather than CPU.
![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/FAHControl_desktop0.png)

I spreaded the word over social networks and many people added to the initiative:
[Twitter thread link](https://twitter.com/cmilanf/status/1238960691865944067)

But I thought I could do something more using container and cloud technologies and this is what this repository is about.

## Packaged solution for deploying Folding@home in AKS with GPU support and ACI
Many organizations and individuals use public cloud for taking advantages of his features, such as hyper-scale, pay as you go model, instant provisioning of compute resources... With this packaged solution you are on the fasttrack for donating a bit or a lot of your compute spending on Azure and helping the with the research.

This repository includes:
  * A **Dockerfile** that builds a Docker image with the Folding@home (FAH from now) client ready to run as a container. It is based on the [official NVIDIA CUDA docker image](https://hub.docker.com/r/nvidia/cuda/), Ubuntu 18.04 flavour.
  * Several **Azure Resource Manager templates** that are able to deploy a GPU-enabled (NC6 Azure VM by default) **Azure Kubernetes Service** (AKS) cluster and/or **Azure Container Instances** (ACI). While AKS is able to leverage GPU computing power, it is still on preview stage for ACI, so for the time being, ACI deployments will be CPU-only.
  * Two **Kubernetes manifests**, one for installing [NVIDIA device plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin), that will made our GPU visible to our pods and manageable by Kubernetes; the second one for actually deploying the FAH client.
  * Two **low level bash scripts** that creates de Azure AD Service Principal required for AKS and the AKS itself; while the second script clean the created resources.
  * One **setup script** in case you what to start fast and easy through a text user interface.

The package of this repository is inteded to be run from GNU/Linux compatible system, WSL included.

## Quickstart - Prerequisites and Launching the setup utility
Follow these steps to have your FAH client running on AKS or ACI:

  1. Install git and clone this repository `git clone https://github.com/cmilanf/docker-foldingathome.git`.
  2. Install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) on your GNU/Linux distribution.
  3. Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
  4. Install script dependencies: `dialog`, `sed`, `jq`, `ssh-keygen`. They should be available on the package management tool of your GNU  Linux distribution. As I will be providing a ready-made Docker image of the FAH client, you don't need Docker or building the image.
  5. Login into Azure by typing `az login`.
  6. List available subscriptions with `az account list -o table` and select one with `az account set -s <subscription id>`. Keep the id  number at hand.
  7. Launch setup utility with `./setup.bash -g <Azure resource group name to create or use> -s <subscription name or id> -l <location>`.  For example: `./setup.bash -g fah -s MSDN -l westeurope

After following the steps you will be able to see the following screen:
![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-mainmenu.png)

ARM templates at `arm/`` folder are already prepared to use my FAH Docker image, so Docker related operations are optional.

## Quickstart - Deploying Azure Kubernetes Service

  1. Select **AKS** and you should see all the data preloaded. Push `Deploy` button and the Azure AD and AKS cluster will be deployed. Please, note that GPU resources on Azure are not cheap, I take no responsability for your consumption! Please use the [Azure Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) to estimate your costs!

![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-aks0.png)

![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-aks1.png)

We will be able to see Azure resources provisined.

![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-aks2.png)

Time to configure Kubernetes!

  2. Select **AKS_CRED** and enter the AKS cluster name. It will automatically set kubectl context.

  ![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-akscred.png)

  3. Select **K8S_NVIDIA** to install the device pluging.

  ![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-k8s-nvidia0.png)

  If setup went well, running `kubectl describe node | grep nvidia` should show something like the following:

  ![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-k8s-nvidia1.png)

  4. Select **K8S_FAH** to deploy the FAH client to Kubernetes. You can setup your user name and team number.

  ![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-k8s-fah0.png)

  If everything went well you can see the FAH client pod with `kubectl get pods` and show the log with `kubectl logs fahclient-675cbf5b99-tt7hk` (in my case, characters afer the name are generated dynamically).

  ![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-k8s-fah1.png)

You can see the NVIDIA CUDA detected the Tesla K80 that the Standard_NC6 Azure Virtual Machine has. The environment is ready and the pod will automatically pickup workloads for both: CPU and GPU (CUDA library only, no OpenCL).

## Azure Container Instances
Instead of going the AKS way, we can go to ACI that is a single step: select **ACI** from the menu:

![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-aci0.png)

You can change the parameters and the number of ACI instances to deploy. After a few minutes we have our Container Instances running and picking up CPU based workloads:

![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-aci1.png)

![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-aci2.png)

## Cleaning up - BE CAREFUL
You can use **AKS_CLEAN** for cleaning up the resources you created and stop any Azure consumtion related to these steps. This operation will DELETE the created Azure AD Service Principal and **the complete resource group, whatever you have deployed into**. Be careful using this.

![](https://github.com/cmilanf/docker-foldingathome/raw/master/images/setup-clean0.png)

In order to confirm you agree with the operation, you will have to write "iknowwhatiamdoing".

## Thanks to
Beatriz Sebastián Peña for her caring and support.
Everyone who are doing their best for fighting the COVID-19 pandemia.
