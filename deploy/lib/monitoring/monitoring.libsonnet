local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local k = import 'ksonnet-util/kausal.libsonnet';

local certs = import '../util/certs.libsonnet';

local grafanacrds = import '../grafana-crds/5.25.0/main.libsonnet';
local grafana = grafanacrds.grafana.v1beta1.grafana;
local datasource = grafanacrds.grafana.v1beta1.grafanaDatasource;

local secureGateway = import '../util/secure_gateway.libsonnet';

{
  _config:: {
    _global: {
      namespace: 'monitoring',
    },


    issuerRefName: '',
    issuerRefKind: 'ClusterIssuer',

  },
  grafana_operator: {
    grafana_operator_helm: helm.template('goperator', '../../charts/grafana-operator', {
      skipTests: true,
      namespace: $._config._global.namespace,
      values: {},
    }),
  },
  grafana: {
    grafana_internal_cert: certs.server.new(
      name='grafana-internal',
      namespace=$._config._global.namespace,
      commonName='grafana-internal.' + $._config._global.namespace,
      issuerRefName=$._config.issuerRefName,
      issuerRefKind=$._config.issuerRefKind,
    ),
    grafana_grafana: grafana.new('grafana-internal')
                     + grafana.metadata.withNamespace($._config._global.namespace)
                     + grafana.metadata.withLabelsMixin({
                       instance: 'internal',
                     })
                     + grafana.spec.withConfigMixin({
                       log: {
                         mode: 'console',
                       },
                       server: {
                         protocol: 'https',
                         cert_file: '/etc/certs/grafana/tls.crt',
                         cert_key: '/etc/certs/grafana/tls.key',
                       },
                     })
                     + grafana.spec.client.tls.withInsecureSkipVerify(true)
                     + grafana.spec.deployment.spec.template.spec.withVolumes({
                       name: 'cert-grafana',
                       secret: {
                         secretName: 'cert-grafana-internal',
                       },
                     })
                     + grafana.spec.deployment.spec.template.spec.withContainers(
                       grafana.spec.deployment.spec.template.spec.containers.withName('grafana')
                       + grafana.spec.deployment.spec.template.spec.containers.readinessProbe.httpGet.withScheme('HTTPS')
                       + grafana.spec.deployment.spec.template.spec.containers.readinessProbe.httpGet.withPort(3000)
                       + grafana.spec.deployment.spec.template.spec.containers.readinessProbe.httpGet.withPath('/api/health')
                       + grafana.spec.deployment.spec.template.spec.containers.withVolumeMountsMixin({
                         name: 'cert-grafana',
                         mountPath: '/etc/certs/grafana',
                         readOnly: true,
                       }),
                     ),
    grafana_gateway: secureGateway.new(
      name='grafana',
      namespace=$._config._global.namespace,
      hostname='grafana.telesto.test',
      gatewayClassName='nginx',
      issuerRefName=$._config.issuerRefName,
      issuerRefKind=$._config.issuerRefKind,
      serviceName='grafana-internal-service',
      servicePort=3000,
      caCertConfigMapName='bundle-telesto'
    ),
  },
  loki: {
    loki_internal_cert: certs.server.new(
      name='loki-internal',
      namespace=$._config._global.namespace,
      commonName='loki-internal.' + $._config._global.namespace,
      issuerRefName=$._config.issuerRefName,
      issuerRefKind=$._config.issuerRefKind,
    ),
    loki_helm: helm.template(
      'loki-internal', '../../charts/loki', {
        skipTests: true,
        namespace: $._config._global.namespace,
        values: {
          loki: {
            commonConfig: {
              replication_factor: 1,
            },
            server: {
              http_tls_config: {
                cert_file: '/etc/certs/loki/tls.crt',
                key_file: '/etc/certs/loki/tls.key',
              },
            },
            storage: {
              type: 'filesystem',
              filesystem: {
                chunks_directory: '/var/loki/chunks',
                rules_directory: '/var/loki/rules',
              },
            },
            schemaConfig: {
              configs: [{
                from: '2024-04-01',
                store: 'tsdb',
                object_store: 'filesystem',
                schema: 'v13',
                index: {
                  prefix: 'loki_index_',
                  period: '24h',
                },
              }],
            },
            ingester: {
              chunk_encoding: 'snappy',
            },
            tracing: {
              enabled: false,
            },
            querier: {
              // Default is 4, if you have enough memory and CPU you can increase, reduce if OOMing
              max_concurrent: 2,
            },
          },

          test: {
            enabled: false,
          },
          lokiCanary: {
            enabled: false,
          },

          deploymentMode: 'Monolithic',
          singleBinary: {
            replicas: 1,
            resources: {
              limits: {
                cpu: 3,
                memory: '4Gi',
              },
              requests: {
                cpu: 2,
                memory: '2Gi',
              },
            },
            readinessProbe: {
              httpGet: {
                path: '/ready',
                port: 3100,
                scheme: 'HTTPS',
              },
            },
            extraEnv: [{
              name: 'GOMEMLIMIT',
              value: '3740MiB',
            }],
            extraVolumes: [{
              name: 'cert-loki-internal',
              secret: {
                secretName: 'cert-loki-internal',
              },
            }],
            extraVolumeMounts: [{
              name: 'cert-loki-internal',
              mountPath: '/etc/certs/loki',
              readOnly: true,
            }],
          },

          minio: {
            enabled: false,
          },

          gateway: {
            enabled: false,
          },
          backend: {
            replicas: 0,
          },
          read: {
            replicas: 0,
          },
          write: {
            replicas: 0,
          },
          ingester: {
            replicas: 0,
          },
          querier: {
            replicas: 0,
          },
          queryFrontend: {
            replicas: 0,
          },
          queryScheduler: {
            replicas: 0,
          },
          distributor: {
            replicas: 0,
          },
          compactor: {
            replicas: 0,
          },
          indexGateway: {
            replicas: 0,
          },
          bloomCompactor: {
            replicas: 0,
          },
          bloomGateway: {
            replicas: 0,
          },
        },
      }
    ),
    loki_datasource: datasource.new('gd-loki-internal')
                     + datasource.metadata.withNamespace($._config._global.namespace)
                     + datasource.spec.instanceSelector.withMatchLabelsMixin({
                       instance: 'internal',
                     })
                     + datasource.spec.datasource.withName('loki-internal')
                     + datasource.spec.datasource.withType('loki')
                     + datasource.spec.datasource.withAccess('proxy')
                     + datasource.spec.datasource.withUrl('https://loki-internal.monitoring:3100')
                     + datasource.spec.datasource.withJsonDataMixin({
                       tlsSkipVerify: true,
                       httpHeaderName1: 'X-Scope-OrgID',
                       manageAlerts: false,
                     })
                     + datasource.spec.datasource.withSecureJsonDataMixin({
                       httpHeaderValue1: '1',
                     }),
  },
  mimir: {},
  tempo: {},
}
