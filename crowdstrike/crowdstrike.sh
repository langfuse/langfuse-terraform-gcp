#!/bin/bash
set -x

# Sensor versions
FALCON_SENSOR_VERSION="7.24.0-17706-1.falcon-linux.Release.US-1"
KAC_VERSION="7.23.0-2103.container.x86_64.Release.US-1"
#BUILD_PROJECT="zac-01-pp-d"
#
#cluster="zac-dev"
#project_id="zac-01-pp-d"
#cluster_zones="us-east1"
#region="us-east1"



#BUILD_PROJECT=ss-pp-control-d
#export dockerAPIToken=$(gcloud --project=${BUILD_PROJECT} secrets versions access latest --secret=dockerAPIToken)
export FALCON_CID=$(gcloud --project=${BUILD_PROJECT} secrets versions access latest --secret=falcon_cid)
export FALCON_CLIENT_ID=$(gcloud --project=${BUILD_PROJECT} secrets versions access latest --secret=falcon_cs_client_id)
export FALCON_CLIENT_SECRET=$(gcloud --project=${BUILD_PROJECT} secrets versions access latest --secret=falcon_cs_client_secret)
export FALCON_CLOUD_API=api.crowdstrike.com
export FALCON_REGION=us-1
export FALCON_CONTAINER_REGISTRY=registry.crowdstrike.com
#export BinaryAuth_Project=ss-pp-build-d


# Fetch the sensor image tag from the CrowdStrike registry for the provided sensor type and version
fetch_sensor_image_tag() {
  local SENSOR_TYPE=$1
  local SENSOR_VERSION=$2

  # Obtain a token to interact with the CrowdStrike private registry:
  REGISTRY_BEARER=$(curl -X GET -s -u "${FALCON_ART_USERNAME}:${FALCON_ART_PASSWORD}" "https://${FALCON_CONTAINER_REGISTRY}/v2/token?=fc-${FALCON_CID}&scope=repository:$SENSOR_TYPE/${FALCON_REGION}/release/f$SENSOR_TYPE:pull&service=${FALCON_CONTAINER_REGISTRY}" | jq -r '.token')

  SOURCE_IMAGE_TAG=$(curl -s -X GET -s -H "authorization: Bearer ${REGISTRY_BEARER}" "https://${FALCON_CONTAINER_REGISTRY}/v2/${SENSOR_TYPE}/${FALCON_REGION}/release/$SENSOR_TYPE/tags/list" | jq -rM '.tags' | grep $SENSOR_VERSION | tail -1 | cut -d\" -f2)

  echo $SOURCE_IMAGE_TAG
}

# Copy image from CrowdStrike registry to ACR
copy_image_to_acr() {
  local SENSOR_TYPE=$1
  local SENSOR_VERSION=$2
  local MY_INTERNAL_IMAGE_REPO=$3
  local MY_INTERNAL_IMAGE_TAG=$4

  # Set the CrowdStrike sensor image repo, fetch the tag information
  SOURCE_IMAGE_REPO="${FALCON_CONTAINER_REGISTRY}/${SENSOR_TYPE}/${FALCON_REGION}/release/${SENSOR_TYPE}"
  SOURCE_IMAGE_TAG=$(fetch_sensor_image_tag $SENSOR_TYPE $SENSOR_VERSION)

  # Pull latest image
  docker pull $SOURCE_IMAGE_REPO:$SOURCE_IMAGE_TAG
  # Tag the images to point to your registry
  docker tag $SOURCE_IMAGE_REPO:$SOURCE_IMAGE_TAG $MY_INTERNAL_IMAGE_REPO:$MY_INTERNAL_IMAGE_TAG
  # push the images to your registry
  docker push $MY_INTERNAL_IMAGE_REPO:$MY_INTERNAL_IMAGE_TAG

  # Perform BinaryAuth for the image
  #binaryAuth $MY_INTERNAL_IMAGE_REPO $MY_INTERNAL_IMAGE_TAG
}

# BinaryAuth function
#binaryAuth() {
#  local IMAGE_REPO=$1
#  local IMAGE_TAG=$2
#  # BinaryAuth
#  DIGEST=$(gcloud container images describe ${IMAGE_REPO}:${IMAGE_TAG} --format='get(image_summary.digest)')
#  if [[ -z $(
#  gcloud container binauthz attestations list \
#    --project=${BinaryAuth_Project} \
#    --artifact-url=${IMAGE_REPO}@${DIGEST} \
#    --attestor=build-attestor \
#    --attestor-project=${BinaryAuth_Project} | grep ${IMAGE_REPO}@${DIGEST}) ]]; then
#    gcloud beta container binauthz attestations sign-and-create \
#      --project=${BinaryAuth_Project} \
#      --artifact-url=${IMAGE_REPO}@${DIGEST} \
#      --attestor=build-attestor \
#      --attestor-project=${BinaryAuth_Project} \
#      --keyversion-project=${BinaryAuth_Project} \
#      --keyversion-location=global \
#      --keyversion-keyring=build-attestor-key-ring \
#      --keyversion-key=build-attestor-key \
#      --keyversion=1
#  else
#    echo the image ${IMAGE_REPO}@${DIGEST} is SIGNED
#  fi
#}

# install helm
#apt install sudo curl -y
#curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
#chmod 700 get_helm.sh
#./get_helm.sh

# install docker
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
#add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
#apt update
#apt-cache policy docker-ce
#apt install docker-ce -y

# Authenticate to Gcloud using the SA Credentials
#if command -v sudo; then
#  docker() { sudo docker "${@}"; }
#  declare -f docker
#  sudo gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS} --project=${project_id}
#fi

# Get the GKE Cluster credentials for sensor deployment
gcloud container clusters get-credentials ${cluster} --zone ${cluster_zones} --project ${project_id};
gcloud container clusters get-credentials ${cluster} --region ${region} --project ${project_id};

# Authenticate to the ACR registry
#gcloud auth configure-docker ${ar_region}-docker.pkg.dev --quiet
#if command -v sudo; then
#  sudo gcloud auth configure-docker ${ar_region}-docker.pkg.dev --quiet
#fi

# Get OAuth2 token to interact with the CrowdStrike API:
export FALCON_CS_API_TOKEN=$(curl --data "client_id=${FALCON_CLIENT_ID}&client_secret=${FALCON_CLIENT_SECRET}" --request POST --silent https://${FALCON_CLOUD_API}/oauth2/token | jq -cr '.access_token | values')

# Get CrowdStrike registry username and password:
export FALCON_ART_USERNAME="fc-$(echo ${FALCON_CID} | awk '{ print tolower($0) }' | cut -d'-' -f1)"
export FALCON_ART_PASSWORD=$(curl -s -X GET -H "authorization: Bearer ${FALCON_CS_API_TOKEN}" https://${FALCON_CLOUD_API}/container-security/entities/image-registry-credentials/v1 | jq -cr '.resources[].token | values')

# Docker login to the ACR registry
echo $FALCON_ART_PASSWORD | docker login -u $FALCON_ART_USERNAME --password-stdin ${FALCON_CONTAINER_REGISTRY}

# CrowdStrike Helm repo add and update
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
helm repo update

#################################### Falcon sensor deployment steps ########################################
############################################################################################################

# Set the ACR repo, image tag information
#FALCON_SENSOR_INTERNAL_IMAGE_REPO=${ar_region}-docker.pkg.dev/${BUILD_PROJECT}/oci/crowdstrike/falcon-sensor
FALCON_SENSOR_INTERNAL_IMAGE_REPO=us-central1-docker.pkg.dev/zac-01-pp-d/oci/crowdstrike/falcon-sensor
FALCON_SENSOR_INTERNAL_IMAGE_TAG=$(fetch_sensor_image_tag falcon-sensor $FALCON_SENSOR_VERSION | cut -d'.' -f-3)

# Copy the image from CrowdStrike registry to ACR
#copy_image_to_acr falcon-sensor $FALCON_SENSOR_VERSION $FALCON_SENSOR_INTERNAL_IMAGE_REPO $FALCON_SENSOR_INTERNAL_IMAGE_TAG

DIGEST=$(gcloud container images describe ${FALCON_SENSOR_INTERNAL_IMAGE_REPO}:${FALCON_SENSOR_INTERNAL_IMAGE_TAG} --format='get(image_summary.digest)')

echo "Falcon-Sensor HELM Install"
helm upgrade --install --create-namespace -n falcon-system \
  crowdstrike crowdstrike/falcon-sensor \
  --set falcon.cid=${FALCON_CID} \
  --set node.image.repository=${FALCON_SENSOR_INTERNAL_IMAGE_REPO} \
  --set node.image.digest=${DIGEST} \
  --set node.backend=bpf

echo "KP Agent HELM Uninstall"
helm uninstall kpagent -n falcon-kubernetes-protection || echo kpagent is not installed

sleep 30

kubectl delete namespace falcon-kubernetes-protection --ignore-not-found=true

##################################### Falcon KAC deployment steps ##########################################
############################################################################################################

# Set the ACR repo, image tag information
#FALCON_KAC_INTERNAL_IMAGE_REPO=${ar_region}-docker.pkg.dev/${BUILD_PROJECT}/oci/crowdstrike/falcon-kac
FALCON_KAC_INTERNAL_IMAGE_REPO=us-central1-docker.pkg.dev/zac-01-pp-d/oci/crowdstrike/falcon-kac
FALCON_KAC_INTERNAL_IMAGE_TAG=$(fetch_sensor_image_tag falcon-kac $KAC_VERSION | cut -d'.' -f-3)

# Copy the image from CrowdStrike registry to ACR
#copy_image_to_acr falcon-kac $KAC_VERSION $FALCON_KAC_INTERNAL_IMAGE_REPO $FALCON_KAC_INTERNAL_IMAGE_TAG

DIGEST_KAC=$(gcloud container images describe ${FALCON_KAC_INTERNAL_IMAGE_REPO}:${FALCON_KAC_INTERNAL_IMAGE_TAG} --format='get(image_summary.digest)')

echo "Falcon-KAC HELM Install"
helm upgrade --install --create-namespace -n falcon-system \
  falcon-kac crowdstrike/falcon-kac \
  -f ../../crowdstrike/falcon-kac/kac-values.yaml \
  --set falcon.cid=${FALCON_CID} \
  --set image.repository=${FALCON_KAC_INTERNAL_IMAGE_REPO} \
  --set image.digest=${DIGEST_KAC} \
  --set falcon.trace=info \
  --set clusterName=ZC-${cluster}-${project_id}-${tier} \
  --set falcon.tags=ZC-${cluster}-${project_id}-${tier}

sleep 30

## Register Cluster
## CRD -> curl -sL https://github.com/crowdstrike/falcon-operator/releases/latest/download/falcon-operator.yaml
kubectl apply --validate=false -f ../../crowdstrike/falcon-node-sensor/crds/falcon-crds.yaml
echo "HELM Install"
helm upgrade --install --create-namespace -n falcon-system \
  falcon-node-sensor crowdstrike/falcon-node-sensor \
  --set crowdstrikeConfig.clientID=${FALCON_CLIENT_ID} \
  --set crowdstrikeConfig.clientSecret=${FALCON_CLIENT_SECRET} \
  --set crowdstrikeConfig.clusterName=ZC-${cluster}-${project_id}-${tier}

exit $?
