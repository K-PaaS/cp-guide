### [Index](https://github.com/K-PAAS/Guide/blob/master/README.md) > [CP Install](/install-guide/Readme.md) > Istio 멀티 클러스터 설치 가이드
<br>

## Table of Contents
1. [문서 개요](#1)    
    1.1. [목적](#1.1)  
    1.2. [범위](#1.2)  
    1.3. [시스템 구성도](#1.3)  
    1.4. [참고 자료](#1.4)  

2. [Prerequisite](#2)  
    2.1. [설치 목록](#2.1)  
    2.2. [방화벽 정보](#2.2)     

3. [Istio 멀티 클러스터 설치](#3)  
    3.1. [Deployment 파일 다운로드](#3.1)   
    3.2. [도구 설치](#3.2)  
    3.3. [멀티 클러스터 접근 구성](#3.3)       
    3.4. [Istio 멀티 클러스터 설치 변수 정의](#3.4)   
    3.5. [Istio 멀티 클러스터 설치 스크립트 실행](#3.5)  
    3.6. [(참조) Istio 멀티 클러스터 삭제](#3.6)   
       
4. [샘플 어플리케이션 배포](#4)  
    4.1. [클러스터 Cluster1 애플리케이션 배포](#4.1)     
    4.2. [클러스터 Cluster2 애플리케이션 배포](#4.2)    
    4.3. [Istio Gateway 배포](#4.3)    
    4.4. [애플리케이션 접속](#4.4)     
   
<br>

## <span id='1'> 1. 문서 개요  
### <span id='1.1'> 1.1. 목적
본 문서(Istio 멀티 클러스터 설치 가이드)는 서로 다른 네트워크에 있는 두 Kubernetes 클러스터의 서비스 간 통신이 가능하도록 Istio 멀티 클러스터를 설치하는 방법을 기술한다.<br>
<br>

### <span id='1.2'>1.2. 범위
설치 범위는 Istio 멀티 클러스터 설치 기준으로 작성하였다.

<br>

### <span id='1.3'>1.3. 시스템 구성도

<br>    

### <span id='1.4'>1.4. 참고 자료
> [[Istio] Install Multicluster](https://istio.io/latest/docs/setup/install/multicluster)

<br>

## <span id='2'> 2. Prerequisite
- 작업 인스턴스는 **Ubuntu 22.04** 또는 **Ubuntu 20.04** 환경에서 설치하는 것을 기준으로 한다.
- **두 개의 클러스터**를 대상으로 Istio 멀티 클러스터를 구성한다.
- 각 클러스터는 **로드 밸런서(LoadBalancer)** 유형의 서비스 지원이 필요하다.

<br>

### <span id='2.1'>2.1. 설치 목록
설치되는 도구 목록은 아래와 같다.
| 도구 | 버전 |
| :---: | :---: |  
| kubectl | 1.27.5 |
| Helm | 3.12.3 |
| step | 0.24.4 |
| Podman | - |
| ca-certificates | - |
| Istio | 1.19.1 |

| Istio 버전 | Kubernetes 지원 버전|  
| :---: | :---: |  
| 1.19.1 |1.25, 1.26, 1.27, 1.28|  

<br>

### <span id='2.2'>2.2. 방화벽 정보
IaaS Security Group의 열어줘야할 Port를 설정한다.

- Master Node

| <center>프로토콜</center> | <center>포트</center> | <center>비고</center> |  
| :---: | :---: | :--- |  
| TCP | 111 | NFS PortMapper |  
| TCP | 2049 | NFS |  
| TCP | 2379-2380 | etcd server client API |  
| TCP | 6443 | Kubernetes API Server |  
| TCP | 10250 | Kubelet API |  
| TCP | 10251 | kube-scheduler |  
| TCP | 10252 | kube-controller-manager |  
| TCP | 10255 | Read-Only Kubelet API |  
| UDP | 4789 | Calico networking VXLAN |  

- Worker Node

| <center>프로토콜</center> | <center>포트</center> | <center>비고</center> |  
| :---: | :---: | :--- |  
| TCP | 111 | NFS PortMapper |  
| TCP | 2049 | NFS |  
| TCP | 10250 | Kubelet API |  
| TCP | 10255 | Read-Only Kubelet API |  
| TCP | 30000-32767 | NodePort Services |  
| UDP | 4789 | Calico networking VXLAN |  


<br>

## <span id='3'>3. NFS설치

### <span id='3.1'>3.1. 설치 링크
NHN의 경우 default로 제공되는 StorageClass가 없고, Cinder는 쿠버네티스에서 더이상 지원하는 Storage가 아니기 때문에 제외한다. 
컨테이너플랫폼에서 제공하는 NFS를 설치한다. <br>
[NFS서버 설치](https://github.com/K-PaaS/container-platform/blob/master/install-guide/nfs-server-install-guide.md)

### <span id='3.1'>3.2. NFS provisoner 배포

<details>
  <summary><h4> :lock: NFS Provisoner YAML</h4></summary>
  <h1></h1>

  vi nfs.yaml

```sh

---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: nfs-pod-provisioner
spec:
  selector:
    matchLabels:
      app: nfs-pod-provisioner
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: nfs-pod-provisioner
    spec:
      serviceAccountName: nfs-pod-provisioner-sa # name of service account
      containers:
        - name: nfs-pod-provisioner
          image: gcr.io/k8s-staging-sig-storage/nfs-subdir-external-provisioner:v4.0.0
          volumeMounts:
            - name: nfs-provisioner
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME # do not change
              value: cp-nfs-provisioner # SAME AS PROVISIONER NAME VALUE IN STORAGECLASS
            - name: NFS_SERVER # do not change
              value: {NFS_SERVER_PRIVATE_IP} # Ip of the NFS SERVER
            - name: NFS_PATH # do not change
              value: /home/share/nfs  # path to nfs directory setup
      volumes:
       - name: nfs-provisioner # same as volumemouts name
         nfs:
           server: {NFS_SERVER_PRIVATE_IP}
           path: /home/share/nfs
---

kind: ServiceAccount
apiVersion: v1
metadata:
  name: nfs-pod-provisioner-sa
---
kind: ClusterRole # Role of kubernetes
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-provisioner-clusterRole
rules:
  - apiGroups: [""] # rules on persistentvolumes
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-provisioner-rolebinding
subjects:
  - kind: ServiceAccount
    name: nfs-pod-provisioner-sa
    namespace: default
roleRef: # binding cluster role to service account
  kind: ClusterRole
  name: nfs-provisioner-clusterRole # name defined in clusterRole
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-pod-provisioner-otherRoles
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-pod-provisioner-otherRoles
subjects:
  - kind: ServiceAccount
    name: nfs-pod-provisioner-sa # same as top of the file
roleRef:
  kind: Role
  name: nfs-pod-provisioner-otherRoles
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cp-storageclass
provisioner: cp-nfs-provisioner
parameters:
  archiveOnDelete: "false"
```

```sh
kubectl apply -f nfs.yaml
```
  <h1></h1>
  <br>
  </details>


<br>

## <span id='4'>4. Istio 멀티 클러스터 설치

### <span id='4.1'>4.1. Deployment 파일 다운로드
Istio 멀티 클러스터 설치를 위해 컨테이너 플랫폼 포털 Deployment 파일을 다운로드 받아 아래 경로로 위치시킨다.<br>

+ 컨테이너 플랫폼 포털 Deployment 파일 다운로드 :
   [cp-portal-deployment-v1.5.0.tar.gz](https://nextcloud.k-paas.org/index.php/s/SSo9H3qjLsFn3ob/download)

```bash
# Deployment 파일 다운로드 경로 생성
$ mkdir -p ~/workspace/container-platform
$ cd ~/workspace/container-platform

# Deployment 파일 다운로드 및 파일 경로 확인
$ wget --content-disposition https://nextcloud.k-paas.org/index.php/s/SSo9H3qjLsFn3ob/download

$ ls ~/workspace/container-platform
  cp-portal-deployment-v1.5.0.tar.gz

# Deployment 파일 압축 해제
$ tar -xvf cp-portal-deployment-v1.5.0.tar.gz
```

<br>

### <span id='4.2'>4.2. 도구 설치
Istio 멀티 클러스터 설치에 필요한 커맨드 라인 등 도구 설치 스크립트를 실행한다.
```bash
$ cd ~/workspace/container-platform/cp-portal-deployment/istio_mc
$ chmod +x install_tools.sh
$ ./install_tools.sh
```

<br>

### <span id='4.3'>4.3. 멀티 클러스터 접근 구성
Istio 멀티 클러스터를 설치할 클러스터 Cluster1, Cluster2에 접근할 수 있도록 컨텍스트 구성이 필요하다. <br>
:loudspeaker: Cluster1, Cluster2 두 kubeconfig 파일 내 cluster, context, user 명이 중복되지 않는지 확인한다.
```bash
# .kube 디렉터리 생성
$ mkdir -p ${HOME}/.kube

# Cluster1, Cluster2 kubeconfig 파일 위치
$ ls ${HOME}/.kube
cluster1-config  cluster2-config

# kubeconfig 파일 경로 설정
$ export KUBECONFIG="${HOME}/.kube/cluster1-config:${HOME}/.kube/cluster2-config"
```
- 컨텍스트 목록 조회 정상 확인
```bash
$ kubectl config get-contexts
CURRENT   NAME    CLUSTER    AUTHINFO         NAMESPACE
*         ctx-1   cluster1   cluster1-admin
          ctx-2   cluster2   cluster2-admin
```
- 클러스터 접근 정상 확인
```bash
# Cluster1 노드 조회 
$ kubectl get nodes --context=ctx-1
NAME                                  STATUS   ROLES    AGE     VERSION
k8s-cluster-1-default-worker-node-0   Ready    <none>   5h44m   v1.27.3

# Cluster2 노드 조회 
$ kubectl get nodes --context=ctx-2
NAME                                  STATUS   ROLES    AGE     VERSION
k8s-cluster-2-default-worker-node-0   Ready    <none>   5h43m   v1.27.3
```

<br>

### <span id='4.4'>4.4. Istio 멀티 클러스터 설치 변수 정의
Istio 멀티 클러스터를 설치하기 전 변수 값 정의가 필요하다. 설정에 필요한 정보를 확인하여 변수를 설정한다. 

```bash
$ cd ~/workspace/container-platform/cp-portal-deployment/istio_mc
$ vi istio-vars-mc.sh
```
```bash                                                     
# COMMON VARIABLE (Please change the value of the variables below.)
CLUSTER1_CONFIG[CTX]="{cluster1 context name}"    # Cluster1 Context Name
CLUSTER2_CONFIG[CTX]="{cluster2 context name}"    # Cluster2 Context Name
```

<b>CLUSTER1_CONFIG[CTX]</b><br>
클러스터 Cluster1의 컨텍스트 명 입력

<b>CLUSTER2_CONFIG[CTX]</b><br>
클러스터 Cluster2의 컨텍스트 명 입력

<br>

- 예시
```bash
# 컨텍스트 목록 조회
$ kubectl config get-contexts
CURRENT   NAME          CLUSTER    AUTHINFO         NAMESPACE
*         ctx-1 (입력)  cluster1   cluster1-admin
          ctx-2 (입력)  cluster2   cluster2-admin

# 컨텍스트 명 입력
CLUSTER1_CONFIG[CTX]="ctx-1"
CLUSTER2_CONFIG[CTX]="ctx-2"
```

<br>

### <span id='4.5'>4.5. Istio 멀티 클러스터 설치 스크립트 실행
Istio 멀티 클러스터를 설치를 위한 스크립트를 실행한다.
```bash
$ chmod +x deploy-istio-mc.sh
$ ./deploy-istio-mc.sh
```
```bash
Istio 1.19.1 Download Complete!
...
Your certificate has been saved in certs/root-cert.pem.
Your private key has been saved in certs/root-ca.key.
[Install Istio in cluster1]...
Your certificate has been saved in certs/cluster1/ca-cert.pem.
Your private key has been saved in certs/cluster1/ca-key.pem.
namespace/istio-system created
secret/cacerts created
✔ Istio core installed
✔ Istiod installed
✔ Installation complete
Made this installation the default for injection and validation.
✔ Ingress gateways installed
✔ Installation complete
gateway.networking.istio.io/cross-network-gateway created
customresourcedefinition.apiextensions.k8s.io/gatewayclasses.gateway.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/gateways.gateway.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/httproutes.gateway.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/referencegrants.gateway.networking.k8s.io created
[Install Istio in cluster2]...
Your certificate has been saved in certs/cluster2/ca-cert.pem.
Your private key has been saved in certs/cluster2/ca-key.pem.
namespace/istio-system created
secret/cacerts created
✔ Istio core installed
✔ Istiod installed
✔ Installation complete
Made this installation the default for injection and validation.
✔ Ingress gateways installed
✔ Installation complete
gateway.networking.istio.io/cross-network-gateway created
customresourcedefinition.apiextensions.k8s.io/gatewayclasses.gateway.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/gateways.gateway.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/httproutes.gateway.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/referencegrants.gateway.networking.k8s.io created
secret/istio-remote-secret-cluster1 created
secret/istio-remote-secret-cluster2 created

--------------------------------------------------------------
[cluster1 (ctx-1)] $ istioctl remote-clusters
--------------------------------------------------------------
NAME         SECRET                                        STATUS      ISTIOD
cluster2     istio-system/istio-remote-secret-cluster2     syncing     istiod-7f5d46f778-77m8s

--------------------------------------------------------------
[cluster2 (ctx-2)] $ istioctl remote-clusters
--------------------------------------------------------------
NAME         SECRET                                        STATUS     ISTIOD
cluster1     istio-system/istio-remote-secret-cluster1     synced     istiod-5fc66dc77-k24sk
```
<br>

## <span id='5'>5. 컨테이너 플랫폼 포털 배포
### <span id='5.1'>5.1. StorageClass 설정
각 CSP 쿠버네티스 서비스에서 기본 StorageClass를 제공하는지 확인
+ StorageClass를 제공하지 않는다면 별도 설치 필요 
```bash
# 클러스터 Cluster1의 StorageClass 조회 (별도 설치)
$ kubectl get storageclass --context=${CLUSTER1_CONFIG[CTX]}
NAME              PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
cp-storageclass   cp-nfs-provisioner   Delete          Immediate           false                  2m46s

# 클러스터 Cluster2의 StorageClass 조회
$ kubectl get storageclass --context=${CLUSTER2_CONFIG[CTX]}
NAME                          PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
nks-block-storage (default)   blk.csi.ncloud.com   Delete          WaitForFirstConsumer   true                   5h14m
```
<br>

### <span id='5.2'>5.2. Ingress NGINX Controller 배포
컨테이너 플랫폼 포털은 Kubernetes 리소스 Ingress를 통해 각 서비스를 라우팅하며 Ingress NGINX Controller를 기본 IngressClass로 사용한다.

> 클러스터 Cluster1, Cluster2에 Ingress NGINX Controller 배포
```bash
# Helm으로 Cluster1에 Ingress NGINX Controller 배포 
$ helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --kube-context=${CLUSTER1_CONFIG[CTX]}

# Helm으로 Cluster2에 Ingress NGINX Controller 배포 
$ helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --kube-context=${CLUSTER2_CONFIG[CTX]}
```

<br>

### <span id='5.3'>5.3. 컨테이너 플랫폼 포털 설정

#### <div id='5.3.1'>5.3.1. 컨테이너 플랫폼 포털 변수 정의
컨테이너 플랫폼 포털을 배포하기 전 변수 값 정의가 필요하다. 배포에 필요한 정보를 확인하여 변수를 설정한다. 

:bulb: Keycloak 기본 배포 방식은 **HTTP**이며 인증서를 통한 **HTTPS**를 설정하고자 하는 경우 아래 내용을 참조하여 선처리한다. 
  <details>
  <summary><h4> :lock: Keycloak Ingress TLS 설정 방법</h4></summary>
  
  <h1></h1>
  
  ```bash
  $ cd ~/workspace/container-platform/cp-portal-deployment/script_mc
  $ vi cp-portal-vars-mc.sh
  ```
  ```bash
  # KEYCLOAK (해당 주석 위치로 이동)
  KEYCLOAK_URL="https://keycloak.${HOST_DOMAIN}"                 # keycloak url (if apply TLS, https:// )
  ...
  KEYCLOAK_INGRESS_TLS_ENABLED="true"　                          # keycloak ingress tls enabled (if apply TLS, true)
  KEYCLOAK_TLS_CERT_PATH="/home/ubuntu/tls/tls.crt" (예시)       # keycloak tls cert file path (if apply TLS, cert file path)
  KEYCLOAK_TLS_KEY_PATH="/home/ubuntu/tls/tls.key"  (예시)       # keycloak tls key file path (if apply TLS, key file path)
  ```
  #### Keycloak 변수 값 변경
  +  **KEYCLOAK_URL** <br> http -> `https` 로 변경 <br><br>
  +  **KEYCLOAK_INGRESS_TLS_ENABLED** <br> `true`로 변경<br><br>
  +  **KEYCLOAK_TLS_CERT_PATH** <br> TLS cert 파일 경로 추가<br><br>
  +  **KEYCLOAK_TLS_KEY_PATH** <br> TLS key 파일 경로 추가
  <h1></h1>
  <br>
  </details>

```bash
$ cd ~/workspace/container-platform/cp-portal-deployment/script_mc
$ vi cp-portal-vars-mc.sh
```

```bash                                                    
# COMMON VARIABLE (Please change the value of the variables below.)
CLUSTER1_CONFIG[CTX]="{cluster1 context name}"                                  # Cluster1 Context Name
CLUSTER1_CONFIG[MASTER_NODE_IP]="{cluster1 master node public ip}"              # Cluster1 Master Node Public IP
CLUSTER1_CONFIG[API_SERVER]="https://${CLUSTER1_CONFIG[MASTER_NODE_IP]}:6443"   # Cluster1 API Server
CLUSTER1_CONFIG[STORAGECLASS]="cp-storageclass"                                 # Cluster1 StorageClass Name
CLUSTER1_CONFIG[IAAS_TYPE]="1"                                                  # Cluster1 Cluster IaaS Type ([1] AWS, [2] OPENSTACK, [3] NAVER, [4] NHN, [5] KT)

CLUSTER2_CONFIG[CTX]="{cluster2 context name}"                                  # Cluster2 Context Name
CLUSTER2_CONFIG[MASTER_NODE_IP]="{cluster2 master node public ip}"              # Cluster2 Master Node Public IP
CLUSTER2_CONFIG[API_SERVER]="https://${CLUSTER2_CONFIG[MASTER_NODE_IP]}:6443"   # Cluster2 API Server
CLUSTER2_CONFIG[STORAGECLASS]="cp-storageclass"                                 # Cluster2 StorageClass Name
CLUSTER2_CONFIG[IAAS_TYPE]="1"                                                  # Cluster2 Cluster IaaS Type ([1] AWS, [2] OPENSTACK, [3] NAVER, [4] NHN, [5] KT)

HOST_DOMAIN="{host domain}"                                                     # Host Domain (e.g. xx.xxx.xxx.xx.nip.io)
PROVIDER_TYPE="{container platform portal provider type}"                       # Container Platform Portal Provider Type (Please enter 'standalone' or 'service')
```

```bash    
# Example
CLUSTER1_CONFIG[CTX]="ctx-1"
CLUSTER1_CONFIG[MASTER_NODE_IP]="xxx.xxx.xxx.xxx"
CLUSTER1_CONFIG[API_SERVER]="https://xxx.xxx.xxx.xxx:6443"
CLUSTER1_CONFIG[STORAGECLASS]="cp-storageclass"
CLUSTER1_CONFIG[IAAS_TYPE]="1"

CLUSTER2_CONFIG[CTX]="ctx-2"
CLUSTER2_CONFIG[MASTER_NODE_IP]="xxx.xxx.xxx.xxx"
CLUSTER2_CONFIG[API_SERVER]="https://xxx.xxx.xxx.xxx:6443"
CLUSTER2_CONFIG[STORAGECLASS]="cp-storageclass"
CLUSTER2_CONFIG[IAAS_TYPE]="2"

HOST_DOMAIN="xx.xxx.xxx.xx.nip.io"
PROVIDER_TYPE="standalone"
```

- **CLUSTER_CONFIG**
  + **[CTX]** <br>해당 클러스터 컨텍스트 명 입력
  + **[MASTER_NODE_IP]** <br>해당 클러스터 Master Node Public IP 입력<br>
    - Master Node에 접근하기 어려운 경우, Worker Node Public IP 입력 
  + **[API_SERVER]** <br>해당 클러스터 API Server URL 입력
  + **[STORAGECLASS]** <br>해당 클러스터 StorageClass 명 입력
  + **[IAAS_TYPE]** <br>해당 클러스터 IaaS 환경 입력
    - [1] AWS, [2] OPENSTACK, [3] NAVER, [4] NHN, [5] KT


- **PROVIDER_TYPE** <br>컨테이너 플랫폼 포털 제공 타입 입력 <br>
   + 본 가이드는 포털 단독 배포 형 설치 가이드로 **'standalone'** 값 입력 필요 <br><br>
   
- **HOST_DOMAIN** <br>클러스터 **Cluster1**의 `{ingress-nginx-controller service EXTERNAL-IP}.nip.io` 입력<br>
   + 컨테이너 플랫폼 포털은 Kubernetes 리소스 Ingress를 통해 각 서비스를 라우팅하며, 클러스터 설치 시 Ingress NGINX Controller 배포를 포함한다.
     호스트 도메인은 Ingress NGINX Controller Service의 <b>EXTERNAL-IP</b> 와 무료 wildcard DNS 서비스 <b>nip.io</b>를 사용한다.
  <br>


```bash
# 클러스터 Cluster1의 컨텍스트(ctx-1)로 이동
$ kubectl config use-context ctx-1
Switched to context "ctx-1".

# 클러스터 컨텍스트 명 조회
  $ kubectl config get-contexts
    CURRENT   NAME           CLUSTER    AUTHINFO         NAMESPACE
    *         ctx-1 (입력)   cluster1   cluster1-admin
              ctx-2 (입력)   cluster2   cluster2-admin

  # 클러스터 API Server URL 조회
  $ kubectl config view
   apiVersion: v1
   clusters:
     - cluster:
         certificate-authority-data: DATA+OMITTED
         server: https://xxx.xxx.xxx.xxx:6443 (입력)
       name: cluster1

  # 클러스터 StorageClass 조회
  $ kubectl get sc
  NAME                        PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
  cp-storageclass (default)   cp-nfs-provisioner   Delete          Immediate           false                  82d


  # 클러스터 Cluster1의 'ingress-nginx-controller' 서비스 EXTERNAL-IP 조회 (LoadBalancer 타입)
  $ kubectl get svc -n ingress-nginx --context=ctx-1
  NAME                       TYPE           CLUSTER-IP      EXTERNAL-IP            PORT(S)                      AGE
  ingress-nginx-controller   LoadBalancer   xx.xxx.xxx.xx   xx.xxx.xxx.xx (조회)   80:30820/TCP,443:32268/TCP   10d
  ```   
  
<br>

#### <div id='5.3.2'>5.3.2. 컨테이너 플랫폼 포털 배포 스크립트 실행
컨테이너 플랫폼 포털 배포를 위한 배포 스크립트를 실행한다.

```bash
$ chmod +x deploy-cp-portal-mc.sh
$ ./deploy-cp-portal-mc.sh
```
<br>

컨테이너 플랫폼 포털 관련 리소스가 정상적으로 배포되었는지 확인한다.<br>
리소스 Pod의 경우 Node에 바인딩 및 컨테이너 생성 후 Running 상태로 전환되기까지 몇 초가 소요된다.

- **Vault Pod 조회**
>`$ kubectl get pods -n vault`
```sh
NAME                                       READY   STATUS    RESTARTS   AGE
cp-vault-0                                 2/2     Running   0          6m
cp-vault-agent-injector-86c8f48987-7b9vk   2/2     Running   0          6m
```

- **Harbor Pod 조회**
>`$ kubectl get pods -n harbor`      
```sh
NAME                                       READY   STATUS    RESTARTS        AGE
cp-harbor-chartmuseum-7d6df785b6-tqrfg     2/2     Running   0               6m10s
cp-harbor-core-84d98bcc86-wk6l9            2/2     Running   1 (5m34s ago)   6m10s
cp-harbor-database-0                       2/2     Running   1 (4m59s ago)   6m10s
cp-harbor-jobservice-58d86dd55-4n6nr       2/2     Running   2 (5m23s ago)   6m10s
cp-harbor-notary-server-5c444769f6-rlj89   1/2     Running   1 (19s ago)     6m10s
cp-harbor-notary-signer-64d874bbf6-z4xxc   2/2     Running   0               6m10s
cp-harbor-portal-7d88cc5d89-fbwwn          2/2     Running   0               6m10s
cp-harbor-redis-0                          2/2     Running   0               6m10s
cp-harbor-registry-6f6445db78-m72rz        3/3     Running   0               6m10s
cp-harbor-trivy-0                          2/2     Running   0               6m10s
```  

- **MariaDB Pod 조회**
>`$ kubectl get pods -n mariadb --context=ctx-2`
```sh
NAME           READY   STATUS    RESTARTS   AGE
cp-mariadb-0   2/2     Running   0          2m44s
```    

- **Keycloak Pod 조회**
>`$ kubectl get pods -n keycloak`     
```sh
NAME                          READY   STATUS    RESTARTS   AGE
cp-keycloak-8c8584f58-d7lzj   2/2     Running   0          3m5s
cp-keycloak-8c8584f58-dck4d   2/2     Running   0          3m5s
```

- **컨테이너 플랫폼 포털 Pod 조회**
>`$ kubectl get pods -n cp-portal --context=ctx-1`        
```sh
NAME                                             READY   STATUS    RESTARTS   AGE
cp-portal-api-deployment-58fd89c958-s7psz        2/2     Running   0          3m23s
cp-portal-terraman-deployment-577ffb557c-ttkqj   2/2     Running   0          3m21s
cp-portal-ui-deployment-659fb4c85f-fp7br         2/2     Running   0          3m25s
```  

>`$ kubectl get pods -n cp-portal --context=ctx-2`        
```sh
NAME                                               READY   STATUS    RESTARTS        AGE
cp-portal-common-api-deployment-64bcb8df7c-b5jc4   2/2     Running   0               3m57s
cp-portal-metric-api-deployment-7f9cf64544-4sb4t   2/2     Running   2 (3m27s ago)   3m56s
```  

<br>


<br>    

## <div id='6'>6. 컨테이너 플랫폼 포털 접속
컨테이너 플랫폼 포털에 접속한다.<br><br>
**컨테이너 플랫폼 포털 URL** : `http://portal.${HOST_DOMAIN}` 
  + [[3.1.2. 컨테이너 플랫폼 포털 변수 정의]](#3.1.2) 에서 정의한 `HOST_DOMAIN` 값 입력

<br>

### <div id='6.1'/>6.1. 컨테이너 플랫폼 포털 관리자 계정 로그인
관리자 계정은 패스워드 초기화 설정이 필요하므로 아래 내용을 참조하여 선처리한다.
<details>
<summary><h4> :key: 컨테이너 플랫폼 포털 관리자 계정 패스워드 설정 </h4></summary>
  
<h1></h1>  

### 1. Keycloak Admin 계정 정보 조회 
Keycloak Admin 계정 정보는 아래 명령어를 통해 확인한다.
```bash
# Keycloak Admin 계정 조회
$ kubectl get cm cp-portal-configmap -n cp-portal -o yaml | grep KEYCLOAK_ADMIN
KEYCLOAK_ADMIN_USERNAME: ********* (Username)
KEYCLOAK_ADMIN_PASSWORD: ********* (Password)
```

<br>

### 2. Keycloak Admin Console 접속 및 로그인
Keycloak Admin Console에 접속 후 조회한 Keycloak Admin 계정으로 로그인한다.<br><br>

**Keycloak Admin Console URL** : `http://keycloak.${HOST_DOMAIN}/auth/admin`
  + Keycloak TLS 적용 시 `https` 로 접속
  + [[3.1.2. 컨테이너 플랫폼 포털 변수 정의]](#3.1.2) 에서 정의한 `HOST_DOMAIN` 값 입력

![image 011]

<br>

### 3. 컨테이너 플랫폼 관리자 계정 패스워드 초기화 
- 왼쪽 상단의 Realm 정보를 `Cp-realm` 으로 변경한다.

![image 012]

- 메뉴 [Users] 선택 후 Username 이 `admin`인 계정을 클릭한다.

![image 013]  
  
- 메뉴 [Credentials] 선택 후 버튼 [Reset password]을 클릭하여 패스워드 초기화를 진행한다.
  + **Password** : `초기화할 패스워드 값 입력`
  + **Temporary** : `Off` 선택
     - 'On' 으로 선택할 경우 사용자는 다음 로그인 시 비밀번호 재변경 필요

![image 014]
![image 015]

<h1></h1>

</details>

- 관리자 계정으로 컨테이너 플랫폼 포털에 로그인한다.
  + **Username** : `admin`
  + **Password** : `초기화한 패스워드 값`
  
![image 002]

<br>

### <div id='6.2'/>6.2. 컨테이너 플랫폼 포털 사용자 계정 로그인
#### 사용자 회원가입    
- 하단의 'Register' 버튼을 클릭한다.
  
![image 003]

- 등록할 사용자 계정정보를 입력 후 'Register' 버튼을 클릭하여 컨테이너 플랫폼 포털에 회원가입한다.
  
![image 004]  

- 회원가입 후 바로 포털 접속이 불가하며 관리자로부터 해당 사용자가 이용할 Namespace와 Role을 할당 받은 후 포털 이용이 가능하다.
Namespace와 Role 할당은 [[4.3. 컨테이너 플랫폼 사용자/운영자 포털 사용 가이드]](#4.3) 를 참고한다.

![image 005]    

#### 사용자 로그인   
- 회원가입을 통해 등록된 계정으로 컨테이너 플랫폼 포털에 로그인한다.
  
![image 006]

<br>    

### <div id='6.3'/>6.3. 컨테이너 플랫폼 포털 사용 가이드
- 컨테이너 플랫폼 포털 사용방법은 아래 사용가이드를 참고한다.  
  + [컨테이너 플랫폼 포털 사용 가이드](../../use-guide/portal/container-platform-portal-guide.md)    

<br>

## <span id='7'>7. 샘플 애플리케이션 배포 
### [Bookinfo Application](https://istio.io/latest/docs/examples/bookinfo/)
<figure>
    <img src="https://istio.io/latest/docs/examples/bookinfo/withistio.svg" title="Bookinfo Application">
</figure>

#### 애플리케이션 배포 위치 
| 애플리케이션| Cluster1 | Cluster2 |
| :---: |:---: | :---: |  
| productpage | :heavy_check_mark: | :heavy_check_mark: |
| details |  | :heavy_check_mark: |
| ratings |  :heavy_check_mark: |  |
| reviews-v1 | :heavy_check_mark: |  |
| reviews-v2 |  | :heavy_check_mark: |
| reviews-v3| :heavy_check_mark: |  |

<br>

### <span id='7.1'>7.1. 클러스터 Cluster1 애플리케이션 배포 
```bash
$ cd ~/workspace/container-platform/cp-portal-deployment/istio_mc
$ source istio-vars-mc.sh 
$ kubectl create namespace sample --context=${CLUSTER1_CONFIG[CTX]}
$ kubectl label namespace sample istio-injection=enabled --context=${CLUSTER1_CONFIG[CTX]}
$ kubectl create -f bookinfo-cluster1.yaml -n sample --context=${CLUSTER1_CONFIG[CTX]}
```
#### 배포 리소스 목록
```bash
service/details created
service/ratings created
deployment.apps/ratings-v1 created
service/reviews created
deployment.apps/reviews-v1 created
deployment.apps/reviews-v3 created
service/productpage created
deployment.apps/productpage-v1 created
```

<br>

### <span id='7.2'>7.2. 클러스터 Cluster2 애플리케이션 배포 
```bash
$ kubectl create namespace sample --context=${CLUSTER2_CONFIG[CTX]}
$ kubectl label namespace sample istio-injection=enabled --context=${CLUSTER2_CONFIG[CTX]}
$ kubectl create -f bookinfo-cluster2.yaml -n sample --context=${CLUSTER2_CONFIG[CTX]}
```
#### 배포 리소스 목록
```bash
service/details created
deployment.apps/details-v1 created
service/ratings created
service/reviews created
deployment.apps/reviews-v2 created
service/productpage created
deployment.apps/productpage-v1 created
```
<br>

### <span id='7.3'>7.3. Istio Gateway 배포
```bash
$ kubectl create -f bookinfo-gateway.yaml -n sample --context=${CLUSTER1_CONFIG[CTX]}
$ kubectl create -f bookinfo-gateway.yaml -n sample --context=${CLUSTER2_CONFIG[CTX]}
```
```
gateway.networking.istio.io/bookinfo-gateway created
virtualservice.networking.istio.io/bookinfo created
```

<br>

### <span id='7.4'>7.4. 애플리케이션 접속 
```bash 
$ export INGRESS_NAME=istio-ingressgateway
$ export INGRESS_NS=istio-system

# 클러스터 Cluster1 Gateway로 접속할 경우
$ export GATEWAY_URL=$(kubectl -n "$INGRESS_NS" --context=${CLUSTER1_CONFIG[CTX]} get service \
"$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# 클러스터 Cluster2 Gateway로 접속할 경우
$ export GATEWAY_URL=$(kubectl -n "$INGRESS_NS" --context=${CLUSTER2_CONFIG[CTX]} get service \
"$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# BookInfo 애플리케이션 접속 URL 확인
$ echo "http://${GATEWAY_URL}/productpage"
http://xxx.xxx.xxx.xxx/productpage
```
<br>


## <span id='8'>8. 리소스 삭제

#### <div id='8.1'>8.1. (참조) 컨테이너 플랫폼 포털 리소스 삭제
배포된 컨테이너 플랫폼 포털 리소스의 삭제를 원하는 경우 아래 스크립트를 실행한다.<br>
:loudspeaker: (주의) 컨테이너 플랫폼 포털이 운영되는 상태에서 해당 스크립트 실행 시, **운영에 필요한 리소스가 모두 삭제**되므로 주의가 필요하다.<br>

```bash
$ cd ~/workspace/container-platform/cp-portal-deployment/script_mc
$ chmod +x uninstall-cp-portal-mc.sh
$ ./uninstall-cp-portal-mc.sh
```

<br>

### <span id='8.2'>8.2. (참조) Istio 멀티 클러스터 삭제
설치된 Istio 멀티 클러스터 구성의 삭제를 원하는 경우 아래 스크립트를 실행한다.<br>
:loudspeaker: (주의) 해당 스크립트 실행 시, **Istio 멀티클러스터 구성이 모두 제거**되므로 주의가 필요하다.<br>

```bash
$ cd ~/workspace/container-platform/cp-portal-deployment/istio_mc
$ chmod +x uninstall-istio-mc.sh
$ ./uninstall-istio-mc.sh
```