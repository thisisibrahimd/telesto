local k = import "github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet";

local argo = import '../argocd/3.4.1/main.libsonnet';
local argov1alpha1 = argo.argoproj.v1alpha1;
local applicationset = argo.argoproj.v1alpha1.applicationSet;

{
  local configmap = k.core.v1.configMap,

  _config:: {
    _global: {
      namespace: 'telestos',
    },

    clusterIssuerRefName: '',

    helmChartRepo: 'https://open-telemetry.github.io/opentelemetry-helm-charts',
    chart: 'opentelemetry-collector',
    chartVersion: '0.138.1',
    tokenName: 'plugin.telestodeployer.token',
  },
  _images:: {
  },

  secret: k.core.v1.secret.new('telestodeployer-plugin', {
            [$._config.tokenName]: std.base64("asdfjkl;"),
          }, 'Opaque')
          + k.core.v1.secret.metadata.withNamespace($._config._global.namespace)
          + k.core.v1.secret.metadata.withLabelsMixin({
            'app.kubernetes.io/part-of': 'argocd',
          }),
  configmap: {
    argo_cm_plugin: configmap.new(
      name='telestodeployer-plugin-config',
      data={
        token: '$' + $._config.tokenName,
        baseUrl: 'http://telesto:9000',
        requestTimeout: '60',
      }
    ),
  },
  otelcolHelmChartValues:: {
    mode: 'deployment',
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
        extensions: ['health_check'],
        pipelines: {
          logs: {
            exporters: ['debug'],
            processors: ['memory_limiter', 'batch'],
            receivers: ['otlp'],
          },
          metrics: {
            exporters: ['debug'],
            processors: ['memory_limiter', 'batch'],
            receivers: ['otlp'],
          },
          traces: {
            exporters: ['debug'],
            processors: ['memory_limiter', 'batch'],
            receivers: ['otlp'],
          },
        },
      },
    },

    extraManifests: [
      {
        apiVersion: 'gateway.networking.k8s.io/v1',
        kind: 'Gateway',
        metadata: {
          name: 'gateway-telesto-{{.otelcol.id}}',
          namespace: $._config._global.namespace,
          annotations: {
            'cert-manager.io/cluster-issuer': $._config.clusterIssuerRefName,
          },
        },
        spec: {
          gatewayClassName: 'nginx',
          listeners: [{
            name: 'https',
            port: 4318,
            protocol: 'HTTPS',
            hostname: '{{.telesto.id}}.t.telesto.test',
            allowedRoutes: {
              namespaces: {
                from: 'All',
              },
            },
            tls: {
              mode: 'Terminate',
              certificateRefs: [{
                group: '',
                kind: 'Secret',
                name: 'tls-test-telesto-t-{{.telesto.id}}',
                namespace: 'default',
              }],
            },
          }],
        },
      },
      {
        apiVersion: 'gateway.networking.k8s.io/v1',
        kind: 'HTTPRoute',
        metadata: {
          name: 'http-route-telesto-{{.telesto.id}}',
        },
        spec: {
          parentRefs: [{
            name: 'gateway-telesto-otelcol-{{.telesto.id}}',
            sectionName: 'https',
          }],
          hostnames: ['{{.telesto.id}}.t.telesto.test'],
          rules: [{
            matches: [{
              path: {
                type: 'PathPrefix',
                value: '/',
              },
            }],
            backendRefs: [{
              name: 'telesto-{{.telesto.id}}-opentelemetry-collector',
              port: 4318,
            }],
          }],
        },
      },
    ],
  },
  applicationset: applicationset.new('telesto')
                  + applicationset.metadata.withNamespace($._config._global.namespace)
                  + applicationset.spec.withGoTemplate(true)
                  + applicationset.spec.withGoTemplateOptions('missingkey=error')
                  + applicationset.spec.withGenerators(
                    applicationset.spec.generators.plugin.configMapRef.withName('telestodeployer-plugin-config')
                    + applicationset.spec.generators.plugin.withRequeueAfterSeconds(10)
                  )
                  + applicationset.spec.template.metadata.withName('telesto-{{.telesto.id}}')
                  + applicationset.spec.template.metadata.withNamespace($._config._global.namespace)
                  + applicationset.spec.template.spec.withProject('telestos')
                  + applicationset.spec.template.spec.syncPolicy.automated.withEnabled(true)
                  + applicationset.spec.template.spec.syncPolicy.automated.withPrune(true)
                  + applicationset.spec.template.spec.syncPolicy.automated.withSelfHeal(true)
                  + applicationset.spec.template.spec.syncPolicy.automated.withAllowEmpty(true)
                  + applicationset.spec.template.spec.source.withRepoURL($._config.helmChartRepo)
                  + applicationset.spec.template.spec.source.withTargetRevision($._config.chartVersion)
                  + applicationset.spec.template.spec.source.withChart($._config.clusterIssuerRefName)
                  + applicationset.spec.template.spec.source.helm.withReleaseName('telesto-{{.telesto.id}}')
                  + applicationset.spec.template.spec.source.helm.withValuesObject(self.otelcolHelmChartValues)
                  + applicationset.spec.template.spec.destination.withServer('https://kubernetes.default.svc')
                  + applicationset.spec.template.spec.destination.withNamespace($._config._global.namespace),

}
