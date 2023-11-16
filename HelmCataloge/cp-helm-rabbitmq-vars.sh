# COMMON VARIABLE FOR CHART
CHART_NAME="Enter the name of the chart"                                            # 패키지된 .tgz의 이름 입력
NAMESPACE="Enter namespace name to be deployed"                                     # 배포하고자 하는 namespace 입력

# DEFAULT VARIABLE FOR HARBOR
HARBOR_REPOSITORY_URL="Enter the harbor repository url"                             # cp-portal-vars에 설정된 harbor repository url를 입력
HARBOR_REPOSITORY_USERNAME="Enter the harbor repository username"                   # cp-portal-vars에 설정된 harbor repository의 username을 입력
HARBOR_REPOSITORY_PASSWORD="Enter the harbor repository password"                   # cp-portal-vars에 설정된 harbor repository의 password를 입력

# DEFAULT VARIABLE FOR DEPLOYMENT
IMAGE_TAGS="latest"                                                                 # image tag
IMAGE_PULL_POLICY="Always"                                                          # image pull policy
IMAGE_PULL_SECRET="cp-secret"                                                       # image pull secret
SERVICE_TYPE="ClusterIP"                                                            # service type in kubernetes
SERVICE_PROTOCOL="TCP"                                                              # service protocol in kubernetes
