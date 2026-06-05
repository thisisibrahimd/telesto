local k = import '../k.libsonnet';

{
  local configmap = k.core.v1.configMap,

  otelcoldeployer: {
    withBaseUrl(url): {

    },
    new(name='otelcoldeployer-plugin'): {
      configmap: {
        argo_cm_plugin: configmap.new(
          name=name + '-config',
          data={
            token: '$otelcoldeployer.otelcoldeployer_plugin.token',
            baseUrl: 'http://telesto-app:9000',
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
                    extraManifests: [
                      {
                        apiVersion: 'gateway.networking.k8s.io/v1',
                        kind: 'Gateway',
                        metadata: {
                          name: 'gateway-telesto-otelcol-{{.otelcol.id}}',
                          annotations: {
                            'cert-manager.io/cluster-issuer': 'local-cluster-issuer',
                          },
                        },
                        spec: {
                          gatewayClassName: 'nginx',
                          listeners: [
                            {
                              name: 'https',
                              port: 4318,
                              protocol: 'HTTPS',
                              hostname: '{{.otelcol.id}}.o.telesto.test',
                              allowedRoutes: {
                                namespaces: {
                                  from: 'All',
                                },
                              },
                              tls: {
                                mode: 'Terminate',
                                certificateRefs: [
                                  {
                                    group: '',
                                    kind: 'Secret',
                                    name: 'test-telesto-otel-{{.otelcol.id}}-tls',
                                    namespace: 'default',
                                  },
                                ],
                              },
                            },
                          ],
                        },
                      },

                      {
                        apiVersion: 'gateway.networking.k8s.io/v1',
                        kind: 'HTTPRoute',
                        metadata: {
                          name: 'http-route-otelcol-{{.otelcol.id}}',
                        },
                        spec: {
                          parentRefs: [
                            {
                              name: 'gateway-telesto-otelcol-{{.otelcol.id}}',
                            },
                          ],
                          hostnames: [
                            '{{.otelcol.id}}.o.telesto.test',
                          ],
                          rules: [
                            {
                              matches: [
                                {
                                  path: {
                                    type: 'PathPrefix',
                                    value: '/',
                                  },
                                },
                              ],
                              backendRefs: [
                                {
                                  name: 'telesto-{{.otelcol.id}}-opentelemetry-collector',
                                  port: 4318,
                                },
                              ],
                            },
                          ],
                        },
                      },
                    ],
                    image: {
                      repository: 'otel/opentelemetry-collector',
                    },
                    command: {
                      name: 'otelcol',
                    },
                    ingress: {
                      enabled: false,
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
                        'otlphttp/openobserve': {
                          endpoint: 'http://telesto-openobserve-openobserve-standalone:5080/api/3EhiM7nyihexMgJiDV6bzPKGPQH',
                          headers: {
                            Authorization: 'Basic YWRtaW5AdGVsZXN0by50ZXN0OlBYSUhiR25aRW9jZkpoOUg=',
                            'stream-name': 't-{{.otelcol.id}}',
                          },
                        },
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
                              'otlphttp/openobserve'
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
