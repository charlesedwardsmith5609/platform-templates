receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  prometheus:
    config:
      scrape_configs:
        - job_name: envoy
          scrape_interval: 15s
          metrics_path: /stats/prometheus
          static_configs:
            - targets: ["127.0.0.1:9901"]

processors:
  batch:
    timeout: 5s
  resource:
    attributes:
      - action: upsert
        key: service.name
        value: ${service_name}-gateway
      - action: upsert
        key: service.namespace
        value: ${namespace}
      - action: upsert
        key: deployment.environment
        value: ${environment}

exporters:
  otlp:
    endpoint: ${otel_exporter_endpoint}
%{ if otel_exporter_insecure ~}
    tls:
      insecure: true
%{ endif ~}

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [resource, batch]
      exporters: [otlp]
    metrics:
      receivers: [otlp, prometheus]
      processors: [resource, batch]
      exporters: [otlp]
