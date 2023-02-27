kind delete cluster --name rv

# Create cluster wihout CNI
kind create cluster --name rv --config rv-kind-cluster.yaml

## Make sure coredns is in pending
```
$ k get pods -n kube-system
NAMESPACE            NAME                                       READY   STATUS    RESTARTS   AGE
kube-system          coredns-565d847f94-8nxvg                   0/1     Pending   0          118s
kube-system          coredns-565d847f94-chdgf                   0/1     Pending   0          118s
```

## Find the POD CIDR
```
$ k cluster-info dump | grep CIDR
"podCIDR": "10.244.0.0/24",

```
This shoud match calico-custom-resource.yaml ipPools[0].['cidr']


## Instal Tigera Calico Operator
```
$kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
```
## Create Calico CNI

```
$ kubectl apply -f calico-custom-resources.yaml
$ watch kubectl get pods -n calico-system
$ watch kubectl get pods -n kube-system
```


## Install ingress-nginx controller
```

$ kubectl label nodes rv-worker ingress-ready=true

$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

```

## pywebapp

```
$ kubectl apply -f pywebapp-pod.yaml
$ kubectl apply -f pywebapp-service.yaml
```

## Nettrouble shooting
```
    $ kubectl run -it netshoot --image=nicolaka/netshoot -- bash
      curl http://pywebapp-service:8080
```



## Contour setup

git clone https://github.com/projectcontour/contour.git

kubectl apply -f contour/examples/contour

## Install helm ingress-nginx
```
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

$ helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.hostNetwork=true \
    --set controller.kind=DaemonSet

$ kubectl get pods --namespace=ingress-nginx

```
