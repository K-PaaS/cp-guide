#!/bin/bash
source cp-helm-${CHART_NAME}-vars.sh

CMD_CREATE_REGISTRY_SECRET="kubectl create secret docker-registry $IMAGE_PULL_SECRET --docker-server=$HARBOR_REPOSITORY_URL --docker-username=$HARBOR_REPOSITORY_USERNAME --docker-password=$HARBOR_REPOSITORY_PASSWORD"

# push the chart in harbor

helm cm-push --username $HARBOR_REPOSITORY_USERNAME --password $HARBOR_REPOSITORY_PASSWORD ../charts/$CHART_NAME.tgz cp-portal-repository
helm repo update cp-portal-repository

# deploy rabbitmq
kubectl create namespace ${NAMESPACE}
$CMD_CREATE_REGISTRY_SECRET -n ${NAMESPACE}
helm install -f ../values/${CHART_NAME}.yaml ${CHART_NAME} cp-portal-repository/${CHART_NAME} -n ${NAMESPACE}