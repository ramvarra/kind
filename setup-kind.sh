
err_exit() { echo "ERROR: $*" 1>&2; exit 1; }

check_cluster() {
    cl=${1:?cluster name required}
    kind get clusters | grep "^$cl$" &> /dev/null
}

create_kind() {
    if check_cluster $CLUSTER_NAME
    then
        echo "Removing kind cluster: $CLUSTER_NAME"
        kind delete cluster --name $CLUSTER_NAME
    fi
    check_cluster $CLUSTER_NAME && err_exit "Failed to remove cluster $CLUSTER_NAME"

    CONFIG_FILE=${CLUSTER_NAME}-kind-cluster.yaml
    [ -f $CONFIG_FILE ] || err_exit "Config file: $CONFIG_FILE not found"
    echo "Creating cluster $CLUSTER_NAME"
    kind create cluster --name $CLUSTER_NAME --config $CONFIG_FILE
    check_cluster rv || err_exit "cluster creation failed"

    [ "$(kubectl config current-context)" = "kind-${CLUSTER_NAME}" ] || err_exit "kubectl current context is not ${CLUSTER_NAME}-kind"
}
install_calico() {
    [ "$(kubectl config current-context)" = "kind-${CLUSTER_NAME}" ] || err_exit "kubectl current context is not ${CLUSTER_NAME}-kind"
    CALICO_CONFIG=${CLUSTER_NAME}-calico-custom-resources.yaml
    [ -f $CALICO_CONFIG ] || err_exit "Calico config $CALICO_CONFIG not found"

    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
    sleep 2
    kubectl apply -f $CALICO_CONFIG
}

install_ingress() {
    helm repo update
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.hostNetwork=true \
        --set controller.kind=DaemonSet


}
CLUSTER_NAME=${1:?Usage: $0 <cluster_name>}
#create_kind || err_exit "kind failed"
#install_calico || err_exit "Failed to install calico"
install_ingress || err_exit "Failed to install ingress"

watch kubectl get pods -A



