local pb = import '../../lib/pocketbase/pocketbase.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local mainconfig = {
  telesto: {
    argo_plugin_token_name: 'telesto.telesto_plugin.token',
    argo_plugin_token: 'aGVsbG8=',
  },
};

{
  // etcd_operator: helm.template('etcd-operator', '../../charts/external-dns', {
  //   namespace: 'default',
  //   values: {
  //   },
  // }),
  // coredns: helm.template('coredns', '../../charts/external-dns', {
  //   namespace: 'default',
  //   values: {
  //   },
  // }),
  // external_dns: helm.template('external-dns', '../../charts/external-dns', {
  //   namespace: 'default',
  //   values: {
  //   },
  // }),
  // ingress_nginx: helm.template('ingress-nginx', '../../charts/ingress-nginx', {
  //   namespace: 'default',
  //   values: {
  //     controller: {
  //       extraArgs: {
  //         'enable-ssl-passthrough': '',
  //       },
  //       hostPort: { enabled: false },
  //     },
  //   },
  // }),
  cert_manager: helm.template('cert-manager', '../../charts/cert-manager', {
    namespace: 'default',
    values: {
      crds: {
        enabled: true,
      },
      extraObjects: [
        std.toString({
          apiVersion: 'cert-manager.io/v1',
          kind: 'Issuer',
          metadata: {
            name: 'selfsigned-issuer',
          },
          spec: {
            selfSigned: {},
          },
        }),
        //   {
        //     apiVersion: 'cert-manager.io/v1',
        //     kind: 'ClusterIssuer',
        //     metadata:
        //       {
        //         name: 'selfsigned-cluster-issuer',
        //       },
        //     spec: {
        //       selfSigned: {},
        //     },
        //   },
      ],
    },
  }),
  argocd: helm.template('argo-cd', '../../charts/argo-cd', {
    namespace: 'default',
    values: {
      global: {
        domain: 'argocd.telesto.localhost',
      },
      configs: {
        params: {
          'server.insecure': true,
        },
        secret: {
          extra: {
            'telesto.telesto_plugin.token': mainconfig.telesto.argo_plugin_token,
          },
        },
      },
      server: {
        certificate: {
          enabled: true,
          issuer: {
            name: 'selfsigned-issuer',
            kind: 'Issuer',
          },
        },
        insecure: true,
        ingress: {
          enabled: true,
          hostname: 'argocd.telesto.localhost',
          path: '/',
          ingressClassName: 'cloud-provider-kind',
          tls: true,
        },
      },
    },
  }),
  pocketbase: pb {
    _config+:: {
      pocketbase+: {
        pocketbase+: {
          ingress+: {
            enabled: true,
            host: 'telesto.localhost',
            className: 'cloud-provider-kind',
          },
          argo_cm_plugin+: {
            create: true,
          },
        },
      },
    },
    _images+:: {
      pocketbase: {
        pocketbase: 'quay.io/telesto/telesto-pb:v0.0.9-beta.1',
      },
    },
  },
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
              name: 'pocketbase-argo-cm-plugin-config',
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
                ingress: {
                  enabled: true,
                  ingressClassName: 'cloud-provider-kind',
                  hosts: [
                    {
                      host: '{{.otelcol}}.otelcol.telesto.net',
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
}
