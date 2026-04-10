local k = import '../k.libsonnet';

{
  local configmap = k.core.v1.configMap,

  otelcoldeployer: {
    new(name='otelcoldeployer-plugin'): {
      configmap: {
        argo_cm_plugin: configmap.new(
          name=name + '-config',
          data={
            token: '$otelcoldeployer.otelcoldeployer_plugin.token',
            baseUrl: 'http://telesto-api.default.svc.cluster.local:9000',
            requestTimeout: '60',
          }
        ),

      },
      applicationset: {
        apiVersion: 'argoproj.io/v1alpha1',
        kind: 'ApplicationSet',
        metadata: {
          name: name,
          namespace: 'default',
        },
        spec: {
          goTemplate: true,
          goTemplateOptions: ['missingkey=error'],
          generators: [
            {
              plugin: {
                configMapRef: {
                  name: name + '-config',
                },
                requeueAfterSeconds: 10,
              },
            },
          ],
          template: {
            metadata: {
              name: 'telesto-{{.otelcol.id}}',
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
                  releaseName: 'telesto-{{.otelcol.id}}',
                  valuesObject: {
                    mode: 'deployment',
                    image: {
                      repository: 'otel/opentelemetry-collector',
                    },
                    command: {
                      name: 'otelcol',
                    },
                    ingress: {
                      enabled: true,
                      ingressClassName: 'cloud-provider-kind',
                      hosts: [
                        {
                          host: '{{.otelcol.name}}.otelcol.telesto.localhost',
                          paths: [
                            {
                              path: '/',
                              pathType: 'Prefix',
                              port: 4318,
                            },
                          ],
                        },
                      ],

                    },
                    ports: {
                      otlp: {
                        enabled: false,
                      },
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
    },
  },

}
