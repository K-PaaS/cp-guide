# helm chart 활용 가이드  

### 목적

이 가이드는 K-PaaS Container Platform에서 제공하는 Harbor를 활용하여 이미지와 Helm Chart를 관리하고 특정 인스턴스에 맞는 클러스터 리소스를 손쉽게 구성하는 방법을 안내한다.

### Prerequisite

본 가이드는 Container Platform Portal이 배포된 환경을 기준으로 작성되었다.

### `cp-helm` 디렉토리 구성  
```console
$cd $HOME/cp-helm ls -l
├── charts                                                                               # Helm Charts 파일 위치 / *.tgz 파일로 압축된 형태
└── cp-rabbitmq.tgz  
├── script                                                                               # 배포 관련 변수 및 스크립트 파일 위치
│   ├── cp-helm-rabbitmq-vars.sh
│   └── deploy-cp-helm.sh
└── values_orig
    └── cp-rabbitmq.yaml                                                                 # Helm Charts values.yaml 파일 위치
```

## Chart 활용 1. Packaging
- Chart 디렉토리로 이동한다.
    ```console
    $cd $HOME/charts/{CHART_NAME}
    ```
- 패키징전 Helm Chart 파일 구성 요소를 확인한다. </br>
_ex) cp-rabbitmq_
    ```console
    $cd $HOME/charts/cp-rabbitmq$ ls -l
    ├──Chart.lock
    ├──charts/
    ├──Chart.yaml
    ├──.helmignore
    ├──README.md
    ├──templates/
    ├──values.schema.json
    └──values.yaml
    ```
-  Helm Chart를 패키징한다.
    ```console
    $helm package ${CHART_NAME}
    ```
    _ex) cp-rabbitmq Helm Chart 패키징_
    ```console
    $helm package cp-rabbitmq
    $ls -l
    cp-rabbitmq/  cp-rabbitmq.tgz
    ```

## Chart 활용 2. values.yaml 수정하기
- Helm Chart의 values.yaml 파일을 수정한다.
    - Chart의 values.yaml을 values_orig 디렉토리로 복사한다.
        ```console
        $cp $HOME/cp-helm/charts/cp-rabbitmq/values.yaml $HOME/cp-helm/values_origin
        ```
    - 복사된 파일을 확인한다.
        ```console
        $cd $HOME/cp-helm/values_orig ls -l
        values.yaml
        ```
    - values.yaml 파일을 {CHART_NAME}.yaml로 이름을 변경한다.
        ```console
        $mv values.yaml cp-rabbitmq.yaml
        ```
    - 수정된 cp-rabbitmq.yaml 파일을 열어 수정한다. 
        - 이 파일을 통해 Helm Chart의 환경변수를 사용자 지정 값으로 대체할 수 있다.</br>
        _ex) RabbitMQ(cp-rabbitmq.yaml): 사용자의 username과 password, ingress의 사용 여부를 설정하고 있다._
        ```console
        $vi cp-rabbitmq.yaml
        ```
        ```yaml
        auth:
        ## @param auth.username RabbitMQ application username
        ## ref: https://github.com/bitnami/containers/tree/main/bitnami/rabbitmq#environment-variables
        ##
        username: "admin"
        ## @param auth.password RabbitMQ application password
        ## ref: https://github.com/bitnami/containers/tree/main/bitnami/rabbitmq#environment-variables
        ##
        password: "admin"
        ...
        ingress:
        ## @param ingress.enabled Enable ingress resource for Management console
        ##
        enabled: "false"
        ...
        ```

## Chart 활용 3. 변수 설정
- 스크립트 디렉토리로 이동한다.
    ```console
    $cd $HOME/cp-helm/script/cp-helm-rabbitmq-vars.sh    
    ```
- 배포에 필요한 정보를 확인하고 변수를 설정한다.
    ```sh
    # COMMON VARIABLE
    CHART_NAME="Enter the name of the chart"                                         # 패키지된 .tgz의 이름 입력
    NAMESPACE="Enter namespace name to be deployed"                                  # 배포하고자 하는 namespace 입력

    ## ex)
    ## CHART_NAME="cp-rabbitmq"
    ## NAMESPACE="rabbitmq"

    # HARBOR INFO
    HARBOR_REPOSITORY_URL="Enter the harbor repository url"                          # cp-portal-vars에 설정된 harbor repository url를 입력한다
    HARBOR_REPOSITORY_USERNAME="Enter the harbor repository username"                # cp-portal-vars에 설정된 harbor repository의 username을 입력한다
    HARBOR_REPOSITORY_PASSWORD="Enter the harbor repository password"                # cp-portal-vars에 설정된 harbor repository의 password를 입력한다

    # DEFAULT VARIABLE FOR DEPLOYMENT
    IMAGE_TAGS="latest"                                                              # image tag
    IMAGE_PULL_POLICY="Always"                                                       # image pull policy
    IMAGE_PULL_SECRET="cp-secret"                                                    # image pull secret
    SERVICE_TYPE="ClusterIP"                                                         # service type in kubernetes
    SERVICE_PROTOCOL="TCP"                                                           # service protocol in kubernetes
    ```

## Chart 활용 4. 배포
```console
$cd $HOME/cp-helm/script/deploy-cp-helm.sh
$chmod +x deploy-cp-helm.sh
$./deploy-cp-helm.sh
```
</br>

### 마치며

본 가이드를 통해 Helm Chart를 구성하고 배포하는 방법을 학습하였다. `cp-helm-${CHART_NAME}-vars.sh` 스크립트를 사용하여 Harbor Repository를 통해 이미지를 저장하고 배포하는 것이 가능하다. 주의 사항은 파일 이름을 생성할 때`{CHART_NAME}`를 정확하게 지정해야 한다.


