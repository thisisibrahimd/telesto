local pb = import '../../lib/pocketbase/pocketbase.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  // _config+:: {
  //   telesto: {
  //     argo_plugin_token_name: 'telesto.telesto_plugin.token',
  //     argo_plugin_token: 'aGVsbG8=',
  //   },
  //   pocketbase: {
  //     pocketbase: {
  //       ingress: {
  //         enabled: true,
  //         host: 'telesto.dev',
  //       },
  //     },
  //   },
  // },
  ingress_nginx: helm.template('ingress-nginx', '../../charts/ingress-nginx', {
    namespace: 'default',
    values: {
      controller: {
        extraArgs: {
          'enable-ssl-passthrough': '',
        },
        hostPort: { enabled: true },
      },
    },
  }),
  cert_manager: helm.template('cert-manager', '../../charts/cert-manager', {
    namespace: 'default',
    values: {
      crds: {
        enabled: true,
      },
    },
  }),
  argocd: helm.template('argo-cd', '../../charts/argo-cd', {
    namespace: 'default',
    values: {
      configs: {
        secret: {
          extra: {
            'telesto.telesto_plugin.token': 'aGVsbG8=',
          },
        },
      },
      server: {
        ingress: {
          enabled: true,
          hostname: 'argo.telesto.dev',
          path: '/',
          ingressClassName: 'nginx',
          tls: true,
          annotations: {
            'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
            'nginx.ingress.kubernetes.io/ssl-passthrough': 'true',
          },
        },
      },
    },
  }),
  pocketbase: pb,
  app: {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'ApplicationSet',
    metadata: {
      name: 'otelcols',
      namespace: 'default',
    },
    spec: {
      goTemplate: true,
      goTemplateOptions: ['missingkey=error'],
      generators: [
        {
          plugin: {
            configMapRef: {
              name: 'tel-argo-plugin',
            },
            requeueAfterSeconds: 10,
          },
        },
      ],
      template: {
        metadata: {
          name: '{{.otelcol}}',
        },
        spec: {
          project: 'default',
          syncPolicy: {
            automated: {
              enabled: true,
              prune: true,
              selfHeal: true,
              allowEmpty: true,
            },
          },
          source: {
            repoURL: 'https://open-telemetry.github.io/opentelemetry-helm-charts',
            targetRevision: '0.138.1',
            chart: 'opentelemetry-collector',
            helm: {
              releaseName: '{{.otelcol}}',
              valuesObject: {
                mode: 'deployment',
                image: {
                  repository: 'otel/opentelemetry-collector',
                },
                command: {
                  name: 'otelcol',
                },
                ports: {
                  'jaeger-compact': {
                    enabled: false,
                  },
                  'jaeger-thrift': {
                    enabled: false,
                  },
                  'jaeger-grpc': {
                    enabled: false,
                  },
                  zipkin: {
                    enabled: false,
                  },

                },
                alternateConfig: {
                  exporters: {
                    debug: {},
                  },
                  extensions: {
                    health_check: {
                      endpoint: '${env:MY_POD_IP}:13133',
                    },
                  },
                  processors: {
                    batch: {},
                    memory_limiter: {
                      check_interval: '5s',
                      limit_percentage: 80,
                      spike_limit_percentage: 25,
                    },
                  },
                  receivers: {
                    otlp: {
                      protocols: {
                        grpc: {
                          endpoint: '${env:MY_POD_IP}:4317',
                        },
                        http: {
                          endpoint: '${env:MY_POD_IP}:4318',
                        },
                      },
                    },
                    zipkin: {
                      endpoint: '${env:MY_POD_IP}:9411',
                    },
                  },
                  service: {
                    extensions: [
                      'health_check',
                    ],
                    pipelines: {
                      logs: {
                        exporters: [
                          'debug',
                        ],
                        processors: [
                          'memory_limiter',
                          'batch',
                        ],
                        receivers: [
                          'otlp',
                        ],
                      },
                      metrics: {
                        exporters: [
                          'debug',
                        ],
                        processors: [
                          'memory_limiter',
                          'batch',
                        ],
                        receivers: [
                          'otlp',
                        ],
                      },
                      traces: {
                        exporters: [
                          'debug',
                        ],
                        processors: [
                          'memory_limiter',
                          'batch',
                        ],
                        receivers: [
                          'otlp',
                        ],
                      },
                    },
                  },
                },
              },
            },
          },
          destination: {
            server: 'https://kubernetes.default.svc',
            namespace: 'default',
          },

        },
      },
    },
  },
}
