admin:
  address:
    socket_address:
      # Localhost-only: kubelet probes use the main listener /ready route.
      # Prometheus scraping is done by the OTel sidecar over the loopback interface.
      address: 127.0.0.1
      port_value: 9901

static_resources:
  listeners:
    - name: ingress
      address:
        socket_address:
          address: 0.0.0.0
          port_value: 8080
      filter_chains:
        - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                stat_prefix: ingress_http
                codec_type: AUTO
                generate_request_id: true
                tracing:
                  provider:
                    name: envoy.tracers.opentelemetry
                    typed_config:
                      "@type": type.googleapis.com/envoy.config.trace.v3.OpenTelemetryConfig
                      grpc_service:
                        envoy_grpc:
                          cluster_name: opentelemetry_collector
                        timeout: 0.250s
                      service_name: ${service_name}-gateway
                http_filters:
                  - name: envoy.filters.http.router
                    typed_config:
                      "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
                route_config:
                  name: local_route
                  virtual_hosts:
                    - name: backend
                      domains: ["*"]
                      routes:
                        - match:
                            path: "/ready"
                          direct_response:
                            status: 200
                            body:
                              inline_string: "OK"
%{ for route in routes ~}
                        - match:
                            prefix: "${route.prefix}"
                          route:
                            cluster: "${route.cluster}"
                            timeout: "${route.timeout_s}s"
                            retry_policy:
                              retry_on: "5xx,reset,connect-failure,refused-stream"
                              num_retries: ${route.retries}
                              per_try_timeout: "${route.timeout_s}s"
%{ endfor ~}

  clusters:
%{ for route in routes ~}
    - name: ${route.cluster}
      type: STRICT_DNS
      lb_policy: ROUND_ROBIN
      connect_timeout: 5s
      dns_lookup_family: V4_ONLY
      load_assignment:
        cluster_name: ${route.cluster}
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: ${route.cluster_host}
                      port_value: ${route.port}
%{ endfor ~}
    - name: opentelemetry_collector
      type: STATIC
      lb_policy: ROUND_ROBIN
      connect_timeout: 1s
      typed_extension_protocol_options:
        envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
          "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
          explicit_http_config:
            http2_protocol_options: {}
      load_assignment:
        cluster_name: opentelemetry_collector
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: 127.0.0.1
                      port_value: 4317
