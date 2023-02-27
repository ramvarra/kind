#!/bin/bash
# Kind Cluster setup

export POD_SUBNET="10.244.0.0/16"
export SERVICE_SUBNET="10.96.0.0/12"

err_exit() { echo "ERROR: $*" 1>&2; exit 1; }

check_cluster() {
    cl=${1:?cluster name required}
    kind get clusters | grep "^$cl$" &> /dev/null
}

create_kind() {
    [ -f kind-cluster.yaml.template ] || err_exit "Kind config kind-cluster.yaml.template not found"
    if check_cluster $CLUSTER_NAME
    then
        echo "Removing kind cluster: $CLUSTER_NAME"
        kind delete cluster --name $CLUSTER_NAME
    fi
    check_cluster $CLUSTER_NAME && err_exit "Failed to remove cluster $CLUSTER_NAME"

    CONFIG_FILE=/tmp/${USER}-${CLUSTER_NAME}-kind-cluster.yaml
    envsubst '$POD_SUBNET $SERVICE_SUBNET' < kind-cluster.yaml.template > $CONFIG_FILE
    [ -f $CONFIG_FILE ] || err_exit "Config file: $CONFIG_FILE not found"
    echo "Creating cluster $CLUSTER_NAME"
    kind create cluster --name $CLUSTER_NAME --config $CONFIG_FILE
    check_cluster rv || err_exit "cluster creation failed"

    [ "$(kubectl config current-context)" = "kind-${CLUSTER_NAME}" ] || err_exit "kubectl current context is not ${CLUSTER_NAME}-kind"
}

install_calico() {
    [ -f calico-custom-resources.yaml.template ] || err_exit "Calico config calico-custom-resources.yaml.template not found"
    [ "$(kubectl config current-context)" = "kind-${CLUSTER_NAME}" ] || err_exit "kubectl current context is not ${CLUSTER_NAME}-kind"
    CALICO_CONFIG=/tmp/${USER}-${CLUSTER_NAME}-calico-custom-resources.yaml
    envsubst '$POD_SUBNET' < calico-custom-resources.yaml.template > $CALICO_CONFIG
    [ -f $CALICO_CONFIG ] || err_exit "Calico config $CALICO_CONFIG not found"

    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
    sleep 2
    kubectl apply -f $CALICO_CONFIG
}


install_canal() {
  URL=https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/canal.yaml
  echo "Installing Canal/Flannel CNI: $URL"
  kubectl apply -f $URL || err_exit "Failed to install canal/flannel"
}

install_ingress_chart_v1() {
    # NOT WORKING in kind
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
       --version 4.2.5 \
       --namespace ingress-nginx \
       --create-namespace \
       --set controller.kind=DaemonSet \
       --set controller.hostPort.enabled=true \
       --set controller.hostPort.ports.http=80 \
       --set controller.hostPort.ports.https=443 \
       --set controller.service.enabled=false \
       --set controller.ingressClassResource.name=ingress-nginx
}       

install_ingress_chart() {
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.hostNetwork=true \
        --set controller.kind=DaemonSet \
        --set controller.service.enabled=false 
}

install_ingress() {
    helm repo list | grep '^ingress-nginx ' > /dev/null || {
       helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || err_exit "Failed to add repo ingress-nginx"
    }

    helm repo update || err_exit "help repo update failed"
    #install_ingress_chart_v1 || err_exit "Install install_ingress_chart_v1 failed"
    install_ingress_chart || err_exit "Install install_ingress_chart failed"

}

CLUSTER_NAME=${1:?Usage: $0 <cluster_name>}
create_kind || err_exit "kind failed"
#install_calico || err_exit "Failed to install calico"
install_canal || err_exit "Failed to install canal"
install_ingress || err_exit "Failed to install ingress chart"

watch kubectl get pods -A

