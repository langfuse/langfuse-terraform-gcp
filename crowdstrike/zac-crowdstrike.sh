#!/bin/bash

#curl -sSL -o falcon-container-sensor-pull.sh "https://raw.githubusercontent.com/CrowdStrike/falcon-scripts/main/bash/containers/falcon-container-sensor-pull/falcon-container-sensor-pull.sh"
#chmod +x falcon-container-sensor-pull.sh

export cluster=langfuse
export cluster_zones=us-east1
export project_id=zac-02-d
export BUILD_PROJECT=zac-01-pp-d

gcloud container clusters get-credentials $cluster --zone $cluster_zones --project $project_id;

#export FALCON_NAMESPACE=falcon-system
#kubectl create namespace $FALCON_NAMESPACE
#kubectl label ns --overwrite $FALCON_NAMESPACE pod-security.kubernetes.io/enforce=privileged
#
#export FALCON_CID=$(gcloud --project=${BUILD_PROJECT} secrets versions access latest --secret=falcon_cid)
#export FALCON_REGION=us-1
#
## based on this page https://falcon.crowdstrike.com/documentation/page/q444c05c/deploy-falcon-kubernetes-protection-agent-with-a-helm-chart
##KPA
#export FALCON_CLIENT_ID=$(gcloud --project=${BUILD_PROJECT} secrets versions access latest --secret=falcon_kpa_client_id)
#export FALCON_CLIENT_SECRET=$(gcloud --project=${BUILD_PROJECT} secrets versions access latest --secret=falcon_kpa_client_secret)
#
#export FALCON_IMAGE_PULL_TOKEN=$(./falcon-container-sensor-pull.sh \
#  -u $FALCON_CLIENT_ID \
#  -s $FALCON_CLIENT_SECRET \
#  -t kpagent \
#  --get-pull-token)
#
#export FALCON_IMAGE_REPO=$(./falcon-container-sensor-pull.sh \
#  -u $FALCON_CLIENT_ID \
#  -s $FALCON_CLIENT_SECRET \
#  -t kpagent \
#  --list-tags | jq -r '.repository')
#
#export FALCON_IMAGE_TAG=$(./falcon-container-sensor-pull.sh \
#  -u $FALCON_CLIENT_ID \
#  -s $FALCON_CLIENT_SECRET \
#  -t kpagent \
#  --list-tags | jq -r '.tags[-1]')
#
#helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
#helm repo update
#helm repo list
#
#export FALCON_KPA_REPO=crowdstrike/cs-k8s-protection-agent
#
#helm install kpagent $FALCON_KPA_REPO \
#  -n falcon-kubernetes-protection --create-namespace \
#  --set crowdstrikeConfig.cid=$FALCON_CID \
#  --set crowdstrikeConfig.clientID=$FALCON_CLIENT_ID \
#  --set crowdstrikeConfig.clientSecret=$FALCON_CLIENT_SECRET \
#  --set crowdstrikeConfig.clusterName=$cluster \
#  --set crowdstrikeConfig.env=us-1 \
#  --set image.repository=$FALCON_IMAGE_REPO \
#  --set image.tag=$FALCON_IMAGE_TAG \
#  --set image.registryConfigJSON=$FALCON_IMAGE_PULL_TOKEN
##end KPA
#
## based on this page https://falcon.crowdstrike.com/documentation/page/d0c66bb8/deploy-falcon-sensor-for-linux-with-a-helm-chart
##begin CS
#
#export FALCON_CLIENT_ID=$(gcloud --project=${BUILD_PROJECT} secrets versions access latest --secret=falcon_cs_client_id)
#export FALCON_CLIENT_SECRET=$(gcloud --project=${BUILD_PROJECT} secrets versions access latest --secret=falcon_cs_client_secret)
#
#export FALCON_IMAGE_PULL_TOKEN=$(./falcon-container-sensor-pull.sh \
#  -u $FALCON_CLIENT_ID \
#  -s $FALCON_CLIENT_SECRET \
#  -t falcon-sensor \
#  --get-pull-token)
#
#export FALCON_IMAGE_REPO=$(./falcon-container-sensor-pull.sh \
#  -u $FALCON_CLIENT_ID \
#  -s $FALCON_CLIENT_SECRET \
#  -t falcon-sensor \
#  --list-tags | jq -r '.repository')
#
#export FALCON_IMAGE_TAG=$(./falcon-container-sensor-pull.sh \
#  -u $FALCON_CLIENT_ID \
#  -s $FALCON_CLIENT_SECRET \
#  -t falcon-sensor \
#  --list-tags | jq -r '.tags[-1]')
#
#helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
#helm repo update
#helm repo list
#
#export FALCON_SENSOR_REPO=crowdstrike/falcon-sensor
#
#export FALCON_ART_USERNAME="fc-$(echo ${FALCON_CID} | awk '{ print tolower($0) }' | cut -d'-' -f1)"
#export FALCON_ART_PASSWORD=$(./falcon-container-sensor-pull.sh \
#-u $FALCON_CLIENT_ID \
#-s $FALCON_CLIENT_SECRET \
#--dump-credentials  | awk 'NR==6 {print $4}')
#
#export PARTIALPULLTOKEN=$(echo -n "$FALCON_ART_USERNAME:$FALCON_ART_PASSWORD" | base64)
#export FALCON_IMAGE_PULL_TOKEN=$(echo "{\"auths\":{\"registry.crowdstrike.com\":{\"auth\":\"$PARTIALPULLTOKEN\"}}}" | base64)
#
#helm install falcon-sensor $FALCON_SENSOR_REPO \
#  -n $FALCON_NAMESPACE \
#  --set falcon.cid=$FALCON_CID \
#  --set node.image.repository=$FALCON_IMAGE_REPO \
#  --set node.image.tag=$FALCON_IMAGE_TAG \
#  --set node.image.registryConfigJSON=$FALCON_IMAGE_PULL_TOKEN \
#  --set node.enabled=true --set node.backend=bpf
##end CS

#begin to uninstall KPA and CS
#helm uninstall kpagent -n falcon-kubernetes-protection
#kubectl get all -n falcon-kubernetes-protection
#kubectl delete ns falcon-kubernetes-protection
#
#helm uninstall falcon-sensor
#helm uninstall falcon-helm -n falcon-system
#kubectl get all -n falcon-system
#kubectl delete ns falcon-system
#rm ./falcon-container-sensor-pull.sh
##end uninstall

exit $?
