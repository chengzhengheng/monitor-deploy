# Prometheus 监控

标签（空格分隔）： 自动化运维

---

#一、Prometheus架构
##1.1Prometheus 是什么

> Prometheus（普罗米修斯）是一个最初在SoundCloud上构建的监控系统。自2012年成为社区开源项目，拥有非常活跃的开发人员和用户社区。为强调开源及独立维护，Prometheus于2016年加入云原生云计算基金会（CNCF），成为继Kubernetes之后的第二个托管项目。
官网地址:
https://prometheus.io
https://github.com/prometheus

##1.2Prometheus 组成及架构


- Prometheus Server：收集指标和存储时间序列数据，并提供查询接口
- ClientLibrary：客户端库
- Push Gateway：短期存储指标数据。主要用于临时性的任务
- Exporters：采集已有的第三方服务监控指标并暴露metrics
- Alertmanager：告警
- Web UI：简单的Web控制

##1.3数据模型

> Prometheus将所有数据存储为时间序列；具有相同度量名称以及标签属于同一个指标。
每个时间序列都由度量标准名称和一组键值对（也成为标签）唯一标识。
时间序列格式：
{=, …}
示例：api_http_requests_total{method=”POST”, handler=”/messages”}

##1.4作业和实例

实例：可以抓取的目标称为实例（Instances）
作业：具有相同目标的实例集合称为作业
```
（Job）
scrape_configs:
-job_name: ‘prometheus’
static_configs:
-targets: [‘localhost:9090’]
-job_name: ‘node’
static_configs:
-targets: [‘192.168.1.10:9090’]
```

#二、K8S监控指标及实现思路
##2.1k8S监控指标

> Kubernetes本身监控

- Node资源利用率
- Node数量
- Pods数量（Node）
- 资源对象状态
- Pod监控

> Pod数量（项目）

- 容器资源利用率
- 应用程序

##2.2Prometheus监控K8S实现的架构

在这里插入图片描述

|监控指标|具体实现|举例
|----|---:|:----:|
|Pod性能|cAdvisor|容器CPU
|Node性能|node-exporter节点CPU|内存利用率
|K8S资源对象|kube-state-metrics|Pod/Deployment/Service

> 服务发现：
https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config

#三、在K8S平台部署Prometheus
##3.1集群环境
|IP地址|角色|备注
|----|---:|:----:|
|192.168.1.8|Kube-master|
|192.168.1.10|Kube-node01|


##3.2 项目地址

##3.3 使用RBAC进行授权

> RBAC（Role-Based Access Control，基于角色的访问控制）：负责完成授权（Authorization）工作。

```
编写授权yaml
[root@Kube-master k8s-prometheus]# cat prometheus-rbac.yaml 
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: prometheus
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile 
rules:
  - apiGroups:
      - ""
    resources:
      - nodes
      - nodes/metrics
      - services
      - endpoints
      - pods
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - configmaps
    verbs:
      - get
  - nonResourceURLs:
      - "/metrics"
    verbs:
      - get
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: prometheus
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: kube-system

#创建
[root@k8s-master prometheus-k8s]# kubectl apply -f prometheus-rbac.yaml

```
##3.4 配置管理

> 使用Configmap保存不需要加密配置信息
其中需要把nodes中ip地址根据自己的地址进行修改，其他不需要改动

```
[root@Kube-master k8s-prometheus]# cat prometheus-configmap.yaml 
# Prometheus configuration format https://prometheus.io/docs/prometheus/latest/configuration/configuration/
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: kube-system 
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: EnsureExists
data:
  prometheus.yml: |
    rule_files:
    - /etc/config/rules/*.rules

    scrape_configs:
    - job_name: prometheus
      static_configs:
      - targets:
        - localhost:9090

    - job_name: kubernetes-nodes
      scrape_interval: 30s
      static_configs:
      - targets:
        - 192.168.1.8:9100
        - 192.168.1.10:9100

    - job_name: kubernetes-apiservers
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - action: keep
        regex: default;kubernetes;https
        source_labels:
        - __meta_kubernetes_namespace
        - __meta_kubernetes_service_name
        - __meta_kubernetes_endpoint_port_name
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        insecure_skip_verify: true
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
 
    - job_name: kubernetes-nodes-kubelet
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        insecure_skip_verify: true
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

    - job_name: kubernetes-nodes-cadvisor
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - target_label: __metrics_path__
        replacement: /metrics/cadvisor
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        insecure_skip_verify: true
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

    - job_name: kubernetes-service-endpoints
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scrape
      - action: replace
        regex: (https?)
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scheme
        target_label: __scheme__
      - action: replace
        regex: (.+)
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_path
        target_label: __metrics_path__
      - action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        source_labels:
        - __address__
        - __meta_kubernetes_service_annotation_prometheus_io_port
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: kubernetes_namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_service_name
        target_label: kubernetes_name

    - job_name: kubernetes-services
      kubernetes_sd_configs:
      - role: service
      metrics_path: /probe
      params:
        module:
        - http_2xx
      relabel_configs:
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_probe
      - source_labels:
        - __address__
        target_label: __param_target
      - replacement: blackbox
        target_label: __address__
      - source_labels:
        - __param_target
        target_label: instance
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: kubernetes_namespace
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: kubernetes_name

    - job_name: kubernetes-pods
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scrape
      - action: replace
        regex: (.+)
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_path
        target_label: __metrics_path__
      - action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        source_labels:
        - __address__
        - __meta_kubernetes_pod_annotation_prometheus_io_port
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: kubernetes_namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: kubernetes_pod_name
    alerting:
      alertmanagers:
      - static_configs:
          - targets: ["alertmanager:80"]

[root@Kube-master k8s-prometheus]# cat prometheus-rules.yaml 
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules
  namespace: kube-system
data:
  general.rules: |
    groups:
    - name: general.rules
      rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: error 
        annotations:
          summary: "Instance {{ $labels.instance }} 停止工作"
          description: "{{ $labels.instance }} job {{ $labels.job }} 已经停止5分钟以上."
  node.rules: |
    groups:
    - name: node.rules
      rules:
      - alert: NodeFilesystemUsage
        expr: 100 - (node_filesystem_free_bytes{fstype=~"ext4|xfs"} / node_filesystem_size_bytes{fstype=~"ext4|xfs"} * 100) > 80 
        for: 1m
        labels:
          severity: warning 
        annotations:
          summary: "Instance {{ $labels.instance }} : {{ $labels.mountpoint }} 分区使用率过高"
          description: "{{ $labels.instance }}: {{ $labels.mountpoint }} 分区使用大于80% (当前值: {{ $value }})"

      - alert: NodeMemoryUsage
        expr: 100 - (node_memory_MemFree_bytes+node_memory_Cached_bytes+node_memory_Buffers_bytes) / node_memory_MemTotal_bytes * 100 > 80
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Instance {{ $labels.instance }} 内存使用率过高"
          description: "{{ $labels.instance }}内存使用大于80% (当前值: {{ $value }})"

      - alert: NodeCPUUsage    
        expr: 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance) * 100) > 60 
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Instance {{ $labels.instance }} CPU使用率过高"       
          description: "{{ $labels.instance }}CPU使用大于60% (当前值: {{ $value }})"
#创建

[root@Kube-master prometheus-k8s]# kubectl apply -f prometheus-configmap.yaml
[root@kube-master prometheus-k8s]# kubectl apply -f prometheus-rules.yaml

```
##3.5 有状态部署prometheus

> 使用静态供给的prometheus-statefulset-static-pv.yaml进行持久化

```
[root@Kube-master k8s-prometheus]# cat prometheus-statefulset-static-pv.yaml 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-data
  namespace: kube-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  selector:
    matchLabels:
      pv: prometheus-data
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-data
  labels:
    pv: prometheus-data
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /data/nfs/prometheus_data
    server: 192.168.1.8
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: prometheus 
  namespace: kube-system
  labels:
    k8s-app: prometheus
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    version: v2.2.1
spec:
  serviceName: "prometheus"
  replicas: 1
  podManagementPolicy: "Parallel"
  updateStrategy:
   type: "RollingUpdate"
  selector:
    matchLabels:
      k8s-app: prometheus
  template:
    metadata:
      labels:
        k8s-app: prometheus
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      priorityClassName: system-cluster-critical
      serviceAccountName: prometheus
      initContainers:
      - name: "init-chown-data"
        image: "busybox:latest"
        imagePullPolicy: "IfNotPresent"
        command: ["chown", "-R", "65534:65534", "/data"]
        volumeMounts:
        - name: prometheus-data
          mountPath: /data
          subPath: ""
      containers:
        - name: prometheus-server-configmap-reload
          image: "jimmidyson/configmap-reload:v0.1"
          imagePullPolicy: "IfNotPresent"
          args:
            - --volume-dir=/etc/config
            - --webhook-url=http://localhost:9090/-/reload
          volumeMounts:
            - name: config-volume
              mountPath: /etc/config
              readOnly: true
          resources:
            limits:
              cpu: 10m
              memory: 10Mi
            requests:
              cpu: 10m
              memory: 10Mi

        - name: prometheus-server
          image: "prom/prometheus:v2.2.1"
          imagePullPolicy: "IfNotPresent"
          args:
            - --config.file=/etc/config/prometheus.yml
            - --storage.tsdb.path=/data
            - --web.console.libraries=/etc/prometheus/console_libraries
            - --web.console.templates=/etc/prometheus/consoles
            - --web.enable-lifecycle
          ports:
            - containerPort: 9090
          readinessProbe:
            httpGet:
              path: /-/ready
              port: 9090
            initialDelaySeconds: 30
            timeoutSeconds: 30
          livenessProbe:
            httpGet:
              path: /-/healthy
              port: 9090
            initialDelaySeconds: 30
            timeoutSeconds: 30
          # based on 10 running nodes with 30 pods each
          resources:
            limits:
              cpu: 200m
              memory: 1000Mi
            requests:
              cpu: 200m
              memory: 1000Mi
            
          volumeMounts:
            - name: config-volume
              mountPath: /etc/config
            - name: prometheus-data
              mountPath: /data
              subPath: ""
            - name: prometheus-rules
              mountPath: /etc/config/rules

      terminationGracePeriodSeconds: 300
      volumes:
        - name: config-volume
          configMap:
            name: prometheus-config
        - name: prometheus-rules
          configMap:
            name: prometheus-rules
        - name: prometheus-data
          persistentVolumeClaim:
            claimName: prometheus-data
            
#创建
[root@Kube-master prometheus-k8s]# kubectl apply -f prometheus-statefulset-static-pv.yaml

```
##3.6 创建service暴露访问端口

> 此处使用nodePort固定一个访问端口，不适用随机端口，便于访问

```
[root@Kube-master k8s-prometheus]# cat prometheus-service.yaml 
kind: Service
apiVersion: v1
metadata: 
  name: prometheus
  namespace: kube-system
  labels: 
    kubernetes.io/name: "Prometheus"
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec: 
  type: NodePort
  ports: 
    - name: http 
      port: 9090
      protocol: TCP
      targetPort: 9090
      nodePort: 30090
  selector: 
    k8s-app: prometheus
#创建
[root@k8s-master prometheus-k8s]# kubectl apply -f prometheus-service.yaml
#检查
[root@k8s-master prometheus-k8s]# kubectl get pod,svc -n kube-system
NAME                                        READY   STATUS    RESTARTS   AGE
pod/coredns-5bd5f9dbd9-wv45t                1/1     Running   1          8dpod/kubernetes-dashboard-7d77666777-d5ng4   1/1     Running   5          14dpod/prometheus-0                            2/2     Running   6          14dNAME                           TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)             AGE
service/kube-dns               ClusterIP   10.0.0.2     <none>        53/UDP,53/TCP       13dservice/kubernetes-dashboard   NodePort    10.0.0.127   <none>        443:30001/TCP       16dservice/prometheus             NodePort    10.0.0.33    <none>        9090:30090/TCP      13d

```

#四、在K8S平台部署Grafana

> 通过上面的web访问，可以看出prometheus自带的UI界面是没有多少功能的，可视化展示的功能不完善，不能满足日常的监控所需，因此常常我们需要再结合Prometheus+Grafana的方式来进行可视化的数据展示
官网地址：
https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/prometheus
https://grafana.com/grafana/download
刚才下载的项目中已经写好了Grafana的yaml，根据自己的环境进行修改

##4.1创建持久化grafana pv、pvc
```
[root@Kube-master k8s-prometheus]# cat grafana-pv.yaml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: "grafana-data-pv"
  labels:
    name: grafana-data-pv
    release: stable
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /data/nfs/grafana-data/
    server: 192.168.1.8
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-data-pvc
  namespace: kube-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  selector:
    matchLabels:
      name: grafana-data-pv
      release: stable
#创建
[root@Kube-master k8s-prometheus]# kubectl apply -f grafana-pv.yaml 
```

##4.2创建grafana
```
[root@Kube-master k8s-prometheus]# cat grafana.yaml 
apiVersion: apps/v1 
kind: StatefulSet 
metadata:
  name: grafana
  namespace: kube-system
spec:
  serviceName: "grafana"
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        imagePullPolicy: IfNotPresent
        ports:
          - containerPort: 3000
            protocol: TCP
        resources:
          limits:
            cpu: 100m            
            memory: 256Mi          
          requests:
            cpu: 100m            
            memory: 256Mi
        volumeMounts:
          - name: grafana-data-volume
            mountPath: /var/lib/grafana
      securityContext:
        fsGroup: 472
        runAsUser: 472
      volumes:
        - name: grafana-data-volume
          persistentVolumeClaim:
            claimName: grafana-data-pvc

---

apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: kube-system
spec:
  type: NodePort
  ports:
  - port : 80
    targetPort: 3000
    nodePort: 30091
  selector:
    app: grafana

#创建
[root@Kube-master k8s-prometheus]# kubectl apply -f grafana.yaml 
```

##4.3检查grafana启动状态

```
我们可以看到这里的状态是CrashLoopBackOff，并没有正常启动，我们查看下这个 Pod 的日志：
   [root@Kube-master k8s-prometheus]# kubectl logs -f -n kube-system grafana-0 
GF_PATHS_DATA='/var/lib/grafana' is not writable.
You may have issues with file permissions, more information here: http://docs.grafana.org/installation/docker/#migration-from-a-previous-version-of-the-docker-container-to-5-1-or-later
mkdir: can't create directory '/var/lib/grafana/plugins': Permission denied
```

> 上面的错误是在5.1版本之后才会出现的，当然你也可以使用之前的版本来规避这个问题。
可以看到是日志中错误很明显就是/var/lib/grafana目录的权限问题，这还是因为5.1版本后 groupid 更改了引起的问题，我们这里增加了securityContext，但是我们将目录/var/lib/grafana挂载到 pvc 这边后目录的拥有者并不是上面的 grafana(472)这个用户了，所以我们需要更改下这个目录的所属用户，这个时候我们可以利用一个 Job 任务去更改下该目录的所属用户：（grafana-chown-job.yaml）

```
    [root@Kube-master k8s-prometheus]# cat granfa-job.yaml 
apiVersion: batch/v1
kind: Job
metadata:
  name: grafana-chown
  namespace: kube-system
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: grafana-chown
        command: ["chown", "-R", "472:472", "/var/lib/grafana"]
        image: busybox
        imagePullPolicy: IfNotPresent
        volumeMounts:
        - name: grafana-data-volume
          mountPath: /var/lib/grafana
      volumes:
      - name: grafana-data-volume
        persistentVolumeClaim:
          claimName: grafana-data-pvc

#上面我们利用一个 busybox 镜像将/var/lib/grafana目录更改成了472这个 user 和 group，不过还需要注意的是下面的 volumeMounts 和 volumes 需要和上面的 Deployment 对应上。

#现在我们删除之前创建的grafana，重新创建：

[root@Kube-master k8s-prometheus]# kubectl delete -f grafana.yaml
[root@Kube-master k8s-prometheus]# kubectl apply -f grafana.yaml 
#重新执行完成后，可以查看下上面的创建的资源对象是否正确了：

[root@Kube-master k8s-prometheus]# kubectl get -n kube-system pod
NAME                          READY     STATUS      RESTARTS   AGE
grafana-79477fbb7c-2mb84      1/1       Running     0          2m
grafana-chown-k8zt7           0/1       Completed   0          2m

我们可以看到有一个状态为Completed的 Pod，这就是上面我们用来更改 grafana 目录权限的 Pod，是一个 Job 任务，所以执行成功后就退出了，状态变成了Completed，而上面的 grafana 的 Pod 也已经是Running状态了，可以查看下该 Pod 的日志确认下：
```
##4.4 Grafana的web访问

> 使用任意一个NodeIP加端口进行访问，访问地址：http://NodeIP:Port,此例就是：http://192.168.1.8:30091 成功访问界面如下，会需要进行账号密码登陆，默认账号密码都为admin，登陆之后会让修改密码 添加监控数据源http://prometheus.kube-system:9090

> 从上面的图中可以看出Prometheus的界面可视化展示的功能较单一，不能满足需求，因此我们需要结合Grafana来进行可视化展示Prometheus监控数据，在上一章节，已经成功部署了Granfana，因此需要在使用的时候添加dashboard和Panel来设计展示相关的监控项，但是实际上在Granfana社区里面有很多成熟的模板，我们可以直接使用，然后根据自己的环境修改Panel中的查询语句来获取数据
https://grafana.com/grafana/dashboards


- [x] 推荐模板：

- 集群资源监控的模板号：3119，如图所示进行添加
当模板添加之后如果某一个Panel不显示数据，可以点击Panel上的编辑，查询PromQL语句，然后去Prometheus自己的界面上进行调试PromQL语句是否可以获取到值，最后调整之后的监控界面如图所示
- 资源状态监控：6417
同理，添加资源状态的监控模板，然后经过调整之后的监控界面如图所示，可以获取到k8s中各种资源状态的监控展示

- Node监控：9276
同理，添加资源状态的监控模板，然后经过调整之后的监控界面如图所示，可以获取到各个node上的基本情况

- 一个Prometheus仪表板的节点导出器CN  8919


##4.3 监控K8S集群中Pod、Node、资源对象数据的方法

###1）Pod
> kubelet的节点使用cAdvisor提供的metrics接口获取该节点所有Pod和容器相关的性能指标数据，安装kubelet默认就开启了
暴露接口地址：
https://NodeIP:10255/metrics/cadvisor
https://NodeIP:10250/metrics/cadvisor

###2）Node
> 需要使用node_exporter收集器采集节点资源利用率。
https://github.com/prometheus/node_exporter
使用文档：https://prometheus.io/docs/guides/node-exporter/

```
使用node_exporter.sh脚本分别在所有服务器上部署node_exporter收集器，不需要修改可直接运行脚本
[root@Kube-master k8s-prometheus]# cat node_exporter.sh 
#!/bin/bash

#wget https://github.com/prometheus/node_exporter/releases/download/v0.17.0/node_exporter-0.17.0.linux-amd64.tar.gz

tar zxf node_exporter-0.17.0.linux-amd64.tar.gz
mv node_exporter-0.17.0.linux-amd64 /usr/local/node_exporter

cat <<EOF >/usr/lib/systemd/system/node_exporter.service
[Unit]
Description=https://prometheus.io

[Service]
Restart=on-failure
ExecStart=/usr/local/node_exporter/node_exporter --collector.systemd --collector.systemd.unit-whitelist=(docker|kubelet|kube-proxy|flanneld).service

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl restart node_exporter
#检测node_exporter的进程，是否生效
[root@Kube-master k8s-prometheus]# sh node_exporter.sh 
Created symlink from /etc/systemd/system/multi-user.target.wants/node_exporter.service to /usr/lib/systemd/system/node_exporter.service.
[root@Kube-master k8s-prometheus]# ps -ef|grep node_exporter
root     29962     1  1 15:25 ?        00:00:00 /usr/local/node_exporter/node_exporter --collector.systemd --collector.systemd.unit-whitelist=(docker|kubelet|kube-proxy|flanneld).service
root     30116 32352  0 15:26 pts/0    00:00:00 grep --color=auto node_exporter
[root@Kube-master k8s-prometheus]# ss -antup | grep 9100
tcp    LISTEN     0      128    [::]:9100               [::]:*                   users:(("node_exporter",pid=29962,fd=3))
tcp    ESTAB      0      0      [::ffff:192.168.1.8]:9100                  [::ffff:192.168.1.10]:61641               users:(("node_exporter",pid=29962,fd=5))

```
###3）资源对象
kube-state-metrics采集了k8s中各种资源对象的状态信息，只需要在master节点部署就行

https://github.com/kubernetes/kube-state-metrics
```
#克隆kube-state-metrics
[root@Kube-master ~]# git clone https://github.com/kubernetes/kube-state-metrics
正克隆到 'kube-state-metrics'...
remote: Enumerating objects: 32, done.
remote: Counting objects: 100% (32/32), done.
remote: Compressing objects: 100% (25/25), done.
remote: Total 18649 (delta 11), reused 16 (delta 6), pack-reused 18617
接收对象中: 100% (18649/18649), 15.96 MiB | 44.00 KiB/s, done.
处理 delta 中: 100% (11734/11734), done.
#修改对应版本信息
[root@Kube-master ~]# cd kube-state-metrics/examples/
[root@Kube-master examples]# kubectl apply -f standard/
clusterrolebinding.rbac.authorization.k8s.io/kube-state-metrics created
clusterrole.rbac.authorization.k8s.io/kube-state-metrics created
deployment.apps/kube-state-metrics created
serviceaccount/kube-state-metrics created
service/kube-state-metrics created
```
 
