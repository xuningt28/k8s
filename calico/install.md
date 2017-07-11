# 1 download  calicoctl   master-node
wget https://github.com/projectcalico/calicoctl/releases/download/v1.3.0/calicoctl
chmod +x calicoctl
mv ./calicoctl /usr/bin
ETCD_ENDPOINTS=http://192.168.240.100:2379  ./calicoctl node run --node-image=quay.io/calico/node:v1.3.0 

# 2 system unit file (all node )
vi /usr/lib/systemd/system/calico-node.service
#[Unit]
#Description=calico-node
#After=docker.service
#Requires=docker.service
#[Service]
#EnvironmentFile=/etc/calico/calico.env
#ExecStartPre=-/usr/bin/docker rm -f calico-node
#ExecStart=/usr/bin/docker run --net=host --privileged \
# --name=calico-node \
# -e NODENAME=${CALICO_NODENAME} \
# -e IP=${CALICO_IP} \
# -e IP6=${CALICO_IP6} \
# -e CALICO_NETWORKING_BACKEND=${CALICO_NETWORKING_BACKEND} \
# -e AS=${CALICO_AS} \
# -e NO_DEFAULT_POOLS=${CALICO_NO_DEFAULT_POOLS} \
# -e CALICO_LIBNETWORK_ENABLED=${CALICO_LIBNETWORK_ENABLED} \
# -e ETCD_ENDPOINTS=${ETCD_ENDPOINTS} \
# -e ETCD_CA_CERT_FILE=${ETCD_CA_CERT_FILE} \
# -e ETCD_CERT_FILE=${ETCD_CERT_FILE} \
# -e ETCD_KEY_FILE=${ETCD_KEY_FILE} \
# -v /var/log/calico:/var/log/calico \
# -v /run/docker/plugins:/run/docker/plugins \
# -v /lib/modules:/lib/modules \
# -v /var/run/calico:/var/run/calico \
# quay.io/calico/node:v1.1.0
#ExecStop=-/usr/bin/docker stop calico-node
#
#[Install]
#WantedBy=multi-user.target

# 3 install the calico plugins
mkdir -p /opt/cni/bin
wget -N -P /opt/cni/bin https://github.com/projectcalico/cni-plugin/releases/download/v1.9.1/calico
wget -N -P /opt/cni/bin https://github.com/projectcalico/cni-plugin/releases/download/v1.9.1/calico-ipam
chmod +x /opt/cni/bin/calico /opt/cni/bin/calico-ipam
mkdir -p /etc/cni/net.d
cat >/etc/cni/net.d/10-calico.conf <<EOF
{
    "name": "calico-k8s-network",
    "cniVersion": "0.1.0",
    "type": "calico",
    "etcd_endpoints": "http://<ETCD_IP>:<ETCD_PORT>",
    "log_level": "info",
    "ipam": {
        "type": "calico-ipam"
    },
    "policy": {
        "type": "k8s"
    },
    "kubernetes": {
        "kubeconfig": "</PATH/TO/KUBECONFIG>"
    }
}
EOF

# 4 install standard CNI lo plugin
wget https://github.com/containernetworking/cni/releases/download/v0.3.0/cni-v0.3.0.tgz
tar -zxvf cni-v0.3.0.tgz
cp loopback /opt/cni/bin/


# 5 installing the calico network policy controller
# policy-controller.yaml
# Calico Version v2.3.0
# http://docs.projectcalico.org/v2.3/releases#v2.3.0
# This manifest includes the following component versions:
#   calico/kube-policy-controller:v0.6.0

# Create this manifest using kubectl to deploy
# the Calico policy controller on Kubernetes.
# It deploys a single instance of the policy controller.
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: calico-policy-controller
  namespace: kube-system
  labels:
    k8s-app: calico-policy
spec:
  # Only a single instance of the policy controller should be
  # active at a time.  Since this pod is run as a Deployment,
  # Kubernetes will ensure the pod is recreated in case of failure,
  # removing the need for passive backups.
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      name: calico-policy-controller
      namespace: kube-system
      labels:
        k8s-app: calico-policy
    spec:
      hostNetwork: true
      containers:
        - name: calico-policy-controller
          # Make sure to pin this to your desired version.
          image: quay.io/calico/kube-policy-controller:v0.6.0
          env:
            # Configure the policy controller with the location of
            # your etcd cluster.
            - name: ETCD_ENDPOINTS
              value: "http://127.0.0.1:2379"
            # Location of the Kubernetes API - this shouldn't need to be
            # changed so long as it is used in conjunction with
            # CONFIGURE_ETC_HOSTS="true".
            - name: K8S_API
              value: "https://kubernetes.default:443"
            # Configure /etc/hosts within the container to resolve
            # the kubernetes.default Service to the correct clusterIP
            # using the environment provided by the kubelet.
            # This removes the need for KubeDNS to resolve the Service.
            - name: CONFIGURE_ETC_HOSTS
              value: "true"

kubectl create -f policy-controller.yaml
kubectl get pods --namespace=kube-system
#NAME                             READY     STATUS    RESTARTS   AGE
#calico-policy-controller-2dhwv   1/1       Running   0          50m

# 6 config the kubelet
--network-plugin=cni
--cni-conf-dir=/etc/cni/net.d
--cin-bin-dir=/opt/cni/bin
# for Kubernetes versions prior to v1.4.0, the cni-conf-dir and cni-bin-dir options are not supported. Use --network-plugin-dir=/etc/cni/net.d instead.

# 7 config the kube-proxy
1: Start the kube-proxy with the --proxy-mode=iptables option.
2: Annotate the Kubernetes Node API object with net.experimental.kubernetes.io/proxy-mode set to iptables.

# 参考
http://www.jianshu.com/p/bafcb7e8f795
http://docs.projectcalico.org/v2.1/introduction/
http://www.tuicool.com/articles/RVba2yr
http://blog.dataman-inc.com/shurenyun-docker-133/

