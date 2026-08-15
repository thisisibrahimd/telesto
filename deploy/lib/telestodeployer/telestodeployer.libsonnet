local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local argo = import '../argocd-crds/3.4.1/main.libsonnet';
local project = argo.argoproj.v1alpha1.appProject;
local applicationset = argo.argoproj.v1alpha1.applicationSet;

local es = import '../external-secrets-crds/2.9.0/main.libsonnet';
local externalSecret = es.nogroup.v1.externalSecret;

{
  local configmap = k.core.v1.configMap,

  _config:: {
    _global: {
      namespace: 'telestos',
    },

    argocdNamespace: 'argocd',

    clusterIssuerRefName: '',

    helmChartRepo: 'https://open-telemetry.github.io/opentelemetry-helm-charts',
    chart: 'opentelemetry-collector',
    chartVersion: '0.158.0',

    telestoDeployerToken: '',
  },
  _images:: {
  },

  secret: k.core.v1.secret.new('telestodeployer-plugin', {
            'plugin.telestodeployer-plugin.token': std.base64($._config.telestoDeployerToken),
          }, 'Opaque')
          + k.core.v1.secret.metadata.withNamespace('argocd')
          + k.core.v1.secret.metadata.withLabelsMixin({
            'app.kubernetes.io/part-of': 'argocd',
          }),
  configmap: configmap.new(
               name='telestodeployer-plugin-config',
               data={
                 token: '$telestodeployer-plugin:plugin.telestodeployer-plugin.token',
                 baseUrl: 'http://telesto.app:443',
                 requestTimeout: '60',
               }
             )
             // currently in argocd namespace due to limits. waiting for this pr: https://github.com/argoproj/argo-cd/pull/21044
             // + configmap.metadata.withNamespace($._config._global.namespace),
             + configmap.metadata.withNamespace('argocd'),
  otelcolHelmChartValues:: {
    mode: 'deployment',
    image: {
      repository: 'otel/opentelemetry-collector-contrib',
    },
    command: {
      name: 'otelcol-contrib',
    },
    annotations: {
      'reloader.stakater.com/auto': 'true',
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

    extraVolumes: [
      {
        name: 'telesto-tokens',
        secret: {
          secretName: 'telesto-tokens',
          optional: true,
        },
      },
    ],

    extraVolumeMounts: [
      {
        name: 'telesto-tokens',
        mountPath: '/etc/secrets/auth',
        readonly: true,
      },
    ],


    alternateConfig: {
      exporters: {
        debug: {},
      },
      extensions: {
        'bearertokenauth/telestotokenauth': {
          filename: '/etc/secrets/auth/telesto.tokens',
        },
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
        'otlp/auth': {
          protocols: {
            http: {
              endpoint: '${env:MY_POD_IP}:4318',
              auth: {
                authenticator: 'bearertokenauth/telestotokenauth',
              },
            },
          },
        },
        'nop/blocked': {
        },
      },
      service: {
        extensions: ['health_check', '{{ if .telesto.tokensAvailable }}bearertokenauth/telestotokenauth{{ end }}'],
        pipelines: {
          logs: {
            exporters: ['debug'],
            processors: ['memory_limiter', 'batch'],
            receivers: ['{{ if .telesto.tokensAvailable }}otlp/auth{{else}}nop/blocked{{ end }}'],
          },
          metrics: {
            exporters: ['debug'],
            processors: ['memory_limiter', 'batch'],
            receivers: ['{{ if .telesto.tokensAvailable }}otlp/auth{{else}}nop/blocked{{ end }}'],
          },
          traces: {
            exporters: ['debug'],
            processors: ['memory_limiter', 'batch'],
            receivers: ['{{ if .telesto.tokensAvailable }}otlp/auth{{else}}nop/blocked{{ end }}'],
          },
        },
      },
    },

    extraManifests: [
      externalSecret.new('telesto-tokens')
      + externalSecret.metadata.withNamespace('telesto-{{.telesto.id}}')
      + externalSecret.spec.secretStoreRef.withName('telesto-cluster-secret-store')
      + externalSecret.spec.secretStoreRef.withKind('ClusterSecretStore')
      + externalSecret.spec.withRefreshInterval('3s')
      + externalSecret.spec.target.withName('telesto-tokens')
      + externalSecret.spec.target.withDeletionPolicy('Delete')
      + externalSecret.spec.withData(
        externalSecret.spec.data.withSecretKey('telesto.tokens')
        + externalSecret.spec.data.remoteRef.withKey('{{.telesto.id}}')
      ),
      {
        apiVersion: 'gateway.networking.k8s.io/v1',
        kind: 'Gateway',
        metadata: {
          name: 'gateway-telesto-{{.telesto.id}}',
          namespace: 'telesto-{{.telesto.id}}',
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
          namespace: 'telesto-{{.telesto.id}}',
        },
        spec: {
          parentRefs: [{
            name: 'gateway-telesto-{{.telesto.id}}',
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
  telestosProject: project.new('telestos')
                   + project.metadata.withNamespace($._config.argocdNamespace)
                   + project.spec.withSourceRepos('*')
                   + project.spec.withSourceNamespaces($._config._global.namespace)
                   + project.spec.withDestinations(
                     project.spec.destinations.withNamespace('*')
                     + project.spec.destinations.withServer('*')
                   )
                   + project.spec.withClusterResourceWhitelist(
                     project.spec.clusterResourceWhitelist.withKind('*')
                     + project.spec.clusterResourceWhitelist.withGroup('*')
                   ),
  applicationset: applicationset.new('telesto')
                  + applicationset.metadata.withNamespace($._config._global.namespace)
                  + applicationset.spec.withGoTemplate(true)
                  + applicationset.spec.withGoTemplateOptions('missingkey=error')
                  + applicationset.spec.withGenerators(
                    applicationset.spec.generators.plugin.configMapRef.withName('telestodeployer-plugin-config')
                    + applicationset.spec.generators.plugin.withRequeueAfterSeconds(10)
                  )
                  + applicationset.spec.template.metadata.withName('telesto-{{.telesto.id}}')
                  + applicationset.spec.template.metadata.withNamespace('telesto-{{.telesto.id}}')
                  + applicationset.spec.template.spec.withProject('telestos')
                  + applicationset.spec.template.spec.syncPolicy.automated.withEnabled(true)
                  + applicationset.spec.template.spec.syncPolicy.withSyncOptionsMixin('CreateNamespace=true')
                  + applicationset.spec.template.spec.syncPolicy.managedNamespaceMetadata.withLabelsMixin({
                    'telesto-deployed': 'true',
                  })
                  + applicationset.spec.template.spec.syncPolicy.automated.withPrune(true)
                  + applicationset.spec.template.spec.syncPolicy.automated.withSelfHeal(true)
                  + applicationset.spec.template.spec.syncPolicy.automated.withAllowEmpty(true)
                  + applicationset.spec.template.spec.source.withRepoURL($._config.helmChartRepo)
                  + applicationset.spec.template.spec.source.withTargetRevision($._config.chartVersion)
                  + applicationset.spec.template.spec.source.withChart($._config.chart)
                  + applicationset.spec.template.spec.source.helm.withReleaseName('telesto-{{.telesto.id}}')
                  + applicationset.spec.template.spec.source.helm.withValuesObject(self.otelcolHelmChartValues)
                  + applicationset.spec.template.spec.destination.withServer('https://kubernetes.default.svc')
                  + applicationset.spec.template.spec.destination.withNamespace('telesto-{{.telesto.id}}'),
}
