export ETCD_NAME=sz-pg-oam-docker-test-001.tendcloud.com
export INTERNAL_IP=192.168.240.100
cat     >       etcd.service    <<EOF
[Unit]
Description=Etcd        Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos
[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
EnvironmentFile=-/etc/etcd/etcd.conf
ExecStart=/root/local/bin/etcd  \\
        --name  ${ETCD_NAME}    \\
        --cert-file=/etc/kubernetes/ssl/kubernetes.pem  \\
        --key-file=/etc/kubernetes/ssl/kubernetes-key.pem       \\
        --peer-cert-file=/etc/kubernetes/ssl/kubernetes.pem     \\
        --peer-key-file=/etc/kubernetes/ssl/kubernetes-key.pem  \\
        --trusted-ca-file=/etc/kubernetes/ssl/ca.pem    \\
        --peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem       \\
        --initial-advertise-peer-urls   https://${INTERNAL_IP}:2380     \\
        --listen-peer-urls      https://${INTERNAL_IP}:2380     \\
        --listen-client-urls    https://${INTERNAL_IP}:2379,https://127.0.0.1:2379      \\
        --advertise-client-urls https://${INTERNAL_IP}:2379     \\
        --initial-cluster-token etcd-cluster-0  \\
        --initial-cluster       sz-pg-oam-docker-test001.tendcloud.com=https://192.168.240.100:2380,sz-pg-oam-docker-test002.tendcloud.com=https://192.168.240.101:2380,sz-pg-oam-docker-test003.tendcloud.com=https://192.168.240.102:2380  \\
--initial-cluster-state new     \\
--data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF
