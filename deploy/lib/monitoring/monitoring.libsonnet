local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local k = import 'k.libsonnet';

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
            auth_enabled: false,
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
          chunksCache: {
            enabled: false,
          },
          resultsCache: {
            enabled: false,
          },
          indexCache: {
            enabled: false,
          },
          metadataCache: {
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
                       manageAlerts: false,
                     }),
  },
  mimir: {
    mimir_internal_cert: certs.server.new(
      name='mimir-internal',
      namespace=$._config._global.namespace,
      commonName='mimir-internal.' + $._config._global.namespace,
      issuerRefName=$._config.issuerRefName,
      issuerRefKind=$._config.issuerRefKind,
    ),
    local statefulSet = k.apps.v1.statefulSet,
    local configMap = k.core.v1.configMap,
    local container = k.core.v1.container,
    local service = k.core.v1.service,
    local persistentVolumeClaimTemplate = k.core.v1.persistentVolumeClaimTemplate,
    mimir_config: configMap.new('mimir-internal-config', {
                    'mimir.yaml': std.manifestYamlDoc({
                      multitenancy_enabled: false,
                      blocks_storage: {
                        backend: 'filesystem',
                        bucket_store: {
                          sync_dir: '/var/mimir/tsdb-sync',
                        },
                        filesystem: {
                          dir: '/var/mimir/data/tsdb',
                        },
                        tsdb: {
                          dir: '/var/mimir/tsdb',
                        },
                      },
                      compactor: {
                        data_dir: '/var/mimir/compactor',
                        sharding_ring: {
                          kvstore: {
                            store: 'memberlist',
                          },
                        },
                      },
                      distributor: {
                        ring: {
                          instance_addr: '127.0.0.1',
                          kvstore: {
                            store: 'memberlist',
                          },
                        },
                      },
                      ingester: {
                        ring: {
                          instance_addr: '127.0.0.1',
                          kvstore: {
                            store: 'memberlist',
                          },
                          replication_factor: 1,
                        },
                      },
                      ruler_storage: {
                        backend: 'filesystem',
                        filesystem: {
                          dir: '/var/mimir/rules',
                        },
                      },
                      server: {
                        http_listen_port: 9009,
                        http_tls_config: {
                          cert_file: '/etc/certs/mimir/tls.crt',
                          key_file: '/etc/certs/mimir/tls.key',
                        },
                        log_level: 'info',
                      },
                      store_gateway: {
                        sharding_ring: {
                          replication_factor: 1,
                        },
                      },
                    }),
                  })
                  + configMap.metadata.withNamespace($._config._global.namespace),
    mimir_service: service.new(
                     'mimir-internal',
                     selector={
                       app: 'mimir-internal',
                     },
                     ports=[
                       {
                         name: 'http-metrics',
                         port: 9009,
                         protocol: 'TCP',
                         targetPort: 'http-metrics',
                       },
                       {
                         name: 'grpc',
                         port: 9095,
                         protocol: 'TCP',
                         targetPort: 'grpc',
                       },
                     ]
                   )
                   + service.metadata.withNamespace($._config._global.namespace),
    mimir_service_headless: service.new(
                              'mimir-internal-headless',
                              selector={
                                app: 'mimir-internal',
                              },
                              ports=[
                                {
                                  name: 'http-metrics',
                                  port: 9009,
                                  protocol: 'TCP',
                                  targetPort: 'http-metrics',
                                },
                                {
                                  name: 'grpc',
                                  port: 9095,
                                  protocol: 'TCP',
                                  targetPort: 'grpc',
                                },
                              ]
                            )
                            + service.metadata.withNamespace($._config._global.namespace)
                            + service.spec.withClusterIP('None'),
    mimir_container:: container.new('mimir-monolithic', 'docker.io/grafana/mimir:3.2.0')
                      + container.withArgs(['-target=all', '-config.file=/etc/mimir/mimir.yaml'])
                      + container.withPortsMixin({
                        containerPort: 9009,
                        name: 'http-metrics',
                        protocol: 'TCP',
                      })
                      + container.withPortsMixin({
                        containerPort: 9095,
                        name: 'grpc',
                        protocol: 'TCP',
                      })
                      + container.withVolumeMountsMixin({
                        name: 'cert-mimir-internal',
                        mountPath: '/etc/certs/mimir',
                        readOnly: true,
                      })
                      + container.withVolumeMountsMixin({
                        name: 'mimir-internal-config',
                        mountPath: '/etc/mimir',
                        readOnly: true,
                      })
                      + container.withVolumeMountsMixin({
                        name: 'storage',
                        mountPath: '/data',
                      })
                      + container.readinessProbe.withFailureThreshold(3)
                      + container.readinessProbe.withInitialDelaySeconds(60)
                      + container.readinessProbe.withInitialDelaySeconds(10)
                      + container.readinessProbe.withSuccessThreshold(1)
                      + container.readinessProbe.withTimeoutSeconds(1)
                      + container.readinessProbe.httpGet.withScheme('HTTPS')
                      + container.readinessProbe.httpGet.withPort('http-metrics')
                      + container.readinessProbe.httpGet.withPath('/ready'),
    mimir_volume_claim:: persistentVolumeClaimTemplate.metadata.withName('storage')
                         + persistentVolumeClaimTemplate.spec.withAccessModesMixin('ReadWriteOnce')
                         + persistentVolumeClaimTemplate.spec.resources.withRequests({ storage: '2Gi' })
                         + persistentVolumeClaimTemplate.spec.withVolumeMode('Filesystem'),
    mimir_stateful_set: statefulSet.new(
                          name='mimir-internal',
                          replicas=1,
                          containers=$.mimir.mimir_container,
                          volumeClaims=$.mimir.mimir_volume_claim,
                          podLabels={ app: 'mimir-internal' }
                        )
                        + statefulSet.metadata.withNamespace($._config._global.namespace)
                        + statefulSet.spec.withServiceName('mimir-internal-headless')
                        // + statefulSet.spec.selector.withMatchLabelsMixin({
                        //   app: 'mimir-internal',
                        // })
                        // + statefulSet.spec.template.metadata.withLabelsMixin({
                        //   app: 'mimir-internal',
                        // })
                        + statefulSet.spec.template.spec.withVolumesMixin({
                          name: 'cert-mimir-internal',
                          secret: {
                            secretName: 'cert-mimir-internal',
                          },
                        })
                        + statefulSet.spec.template.spec.withVolumesMixin({
                          name: 'mimir-internal-config',
                          configMap: {
                            name: 'mimir-internal-config',
                            items: [{
                              key: 'mimir.yaml',
                              path: 'mimir.yaml',
                            }],
                          },
                        }),

    mimir_datasource: datasource.new('gd-mimir-internal')
                      + datasource.metadata.withNamespace($._config._global.namespace)
                      + datasource.spec.instanceSelector.withMatchLabelsMixin({
                        instance: 'internal',
                      })
                      + datasource.spec.datasource.withName('mimir-internal')
                      + datasource.spec.datasource.withType('prometheus')
                      + datasource.spec.datasource.withAccess('proxy')
                      + datasource.spec.datasource.withUrl('https://mimir-internal.monitoring:9009/prometheus')
                      + datasource.spec.datasource.withJsonDataMixin({
                        tlsSkipVerify: true,
                        manageAlerts: false,
                        httpMethod: 'POST',
                        prometheusType: 'Mimir',
                        prometheusVersion: '3.2.0',
                      }),
  },
  tempo: {
    tempo_internal_cert: certs.server.new(
      name='tempo-internal',
      namespace=$._config._global.namespace,
      commonName='tempo-internal.' + $._config._global.namespace,
      issuerRefName=$._config.issuerRefName,
      issuerRefKind=$._config.issuerRefKind,
    ),

  },
}
