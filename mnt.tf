resource helm_release "kubeprometheus" {
  name       = "kubeprometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "79.4.0"
  namespace  = "monitoring"
  create_namespace = true

  values = [yamlencode({

    nodeExporter = { enabled = false }

    kubeControllerManager = { enabled = false }
    kubeEtcd = { enabled = false }
    kubeScheduler = { enabled = false }

    grafana = {
      adminPassword = "admin"
      resources = {
        requests = { cpu = "50m",  memory = "120Mi" }
        limits   = { cpu = "200m", memory = "220Mi" }
      }
      service = { type = "ClusterIP" }
      defaultDashboardsEnabled = true
    }

    prometheus = {
      prometheusSpec = {
        nodeSelector = { role = "prometheus" }
        tolerations = [{
          key = "dedicated"
          operator = "Equal"
          value = "prometheus"
          effect   = "NoSchedule"
        }]
        resources = {
          requests = { cpu = "100m", memory = "300Mi" }
          limits   = { cpu = "400m", memory = "600Mi" }
        }
        scrapeInterval = "60s"
        retention      = "1d"

        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues = false
        ruleSelectorNilUsesHelmValues = false

      }
      service = { type = "ClusterIP" }
    }

    alertmanager = {
      alertmanagerSpec = {
        resources = {
          requests = { cpu = "20m", memory = "60Mi" }
          limits   = { cpu = "100m", memory = "120Mi" }
        }
      }
      service = { type = "ClusterIP" }
    }

    kube-state-metrics = {
      resources = {
        requests = { cpu = "70m", memory = "130Mi" }
        limits   = { cpu = "200m", memory = "220Mi" }
      }
    }

    prometheus-node-exporter = {
      resources = {
        requests = { cpu = "10m", memory = "25Mi" }
        limits   = { cpu = "100m", memory = "60Mi" }
      }
    }

  })]

}

resource kubernetes_config_map "ngxdashboard" {
  metadata {
    name = "nginxdashboard"
    namespace = "monitoring"
    labels = { grafana_dashboard = "1"}
  } 
  data = {
    "nginxdashboard.json" = file("${path.module}/dashboard.json")
  }
  depends_on = [ helm_release.kubeprometheus ]
}

resource helm_release "ngx" {
  name       = "nginx"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "nginx"
  version    = "22.2.3"
  namespace  = "nginx"
  create_namespace = true

  values = [yamlencode({
    service = {type = "ClusterIP"}
    metrics = {
      enabled = true
      serviceMonitor = {enabled = true, namespace = "nginx", interval = "60s"}
    }
    resources = {
      requests = { cpu = "10m", memory = "20Mi" }
      limits   = { cpu = "100m", memory = "60Mi" }
    }
   })
  ]

  depends_on = [ helm_release.kubeprometheus ]

}