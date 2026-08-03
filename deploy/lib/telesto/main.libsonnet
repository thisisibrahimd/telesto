local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local k = import 'ksonnet-util/kausal.libsonnet';

local netutil = import '../util/net.libsonnet';
local dnsutil = import '../../lib/util/dns.libsonnet';

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local cmv1 = cm.nogroup.v1;

local deployment = k.apps.v1.deployment;
local container = k.core.v1.container;
local cPort = k.core.v1.containerPort;
local volume = k.core.v1.volume;
local service = k.core.v1.service;

{
  _config+:: {
    _global: {
      namespace: 'telesto',
    },
    clusterIssuerRefName: '',
    telesto: {
      telesto: {
        port: 9000,
        name: 'telesto',
      },
    },
  },

  _images+:: {
    telesto: 'ghcr.io/thisisibrahimd/telesto:0.0.3-next',
  },

  container::
    container.new('telesto', $._images.telesto),

  deployment: deployment.new(
                'telesto',
                1,
                containers=[
                  self.container
                  + container.withPorts(cPort.new('api', $._config.telesto.telesto.port))
                  + container.withCommand(['/usr/bin/telesto', 'serve', '--config', '/etc/telesto/telesto.json'])
                  + container.withVolumeMountsMixin({
                    name: 'db-client-cert',
                    mountPath: '/etc/secrets/db',
                    readOnly: true,
                  })
                  + container.withVolumeMountsMixin({
                    name: 'config',
                    mountPath: '/etc/telesto',
                    readOnly: true,
                  }),
                ],
              )
              + deployment.metadata.withNamespace($._config._global.namespace)
              + deployment.spec.template.spec.withVolumesMixin({
                name: 'db-client-cert',
                secret: {
                  secretName: 'cert-db-telesto-app-client',
                },
              })
              + deployment.spec.template.spec.withVolumesMixin({
                name: 'config',
                configMap: {
                  name: 'config-telesto',
                  items: [{
                    key: 'telesto.json',
                    path: 'telesto.json',
                  }],
                },
              }),
  service: k.util.serviceFor(self.deployment)
           + service.metadata.withNamespace($._config._global.namespace),
  config: k.core.v1.configMap.new('config-telesto', {
            'telesto.json': std.toString({
              server: {
                address: '0.0.0.0:9000',
                port: $._config.telesto.telesto.port,
              },
              auth: {
                kratos: {
                  internalEndpoint: 'http://auth-kratos-public.auth',
                  publicEndpoint: 'https://auth.telesto.test',
                },
              },
              storage: {
                migrate: true,
                dsn: 'postgres://telesto-app@telesto-db-cluster-rw.telesto:5432/telesto?sslmode=verify-full&sslrootcert=/etc/secrets/db/ca.crt&sslcert=/etc/secrets/db/tls.crt&sslkey=/etc/secrets/db/tls.key',
              },
            }),
          })
          + k.core.v1.configMap.metadata.withNamespace($._config._global.namespace),
  gatewayTelestoApp: (import '../util/simple_gateway.libsonnet') + {
    _config+:: {
      _global: {
        namespace: $._config._global.namespace,
      },
      name: 'telesto-app',
      hostname: 'app.telesto.test',
      gatewayClassName: 'nginx',
      issuerRef: {
        name: 'cluster-issuer-central',
        kind: 'ClusterIssuer',
      },
      svc: {
        name: 'telesto',
        port: 9000,
      },
    },
  },

  secret_cert_db_telesto_server: k.core.v1.secret.new('cert-db-telesto-server', {}, 'kubernetes.io/tls')
                                 + k.core.v1.secret.metadata.withNamespace($._config._global.namespace)
                                 + k.core.v1.secret.metadata.withLabelsMixin({
                                   'cnpg.io/reload': '',
                                 }),
  cert_db_telesto_server: cm.nogroup.v1.certificate.new('db-telesto-server')
                          + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                          + cm.nogroup.v1.certificate.spec.withIsCA(true)
                          + cm.nogroup.v1.certificate.spec.withCommonName('db-telesto-server')
                          + cm.nogroup.v1.certificate.spec.withSecretName('cert-db-telesto-server')
                          + cm.nogroup.v1.certificate.spec.withUsages([
                            'server auth',
                          ])
                          + cm.nogroup.v1.certificate.spec.withDnsNames(
                            dnsutil.dnsnames.cnpg.new('telesto-db-cluster', 'telesto')
                          )
                          + cm.nogroup.v1.certificate.spec.privateKey.withAlgorithm('ECDSA')
                          + cm.nogroup.v1.certificate.spec.privateKey.withSize(256)
                          + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                          + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                          + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  issuer_db_teletso_server: cm.nogroup.v1.issuer.new('issuer-db-telesto-server')
                            + cm.nogroup.v1.issuer.metadata.withNamespace($._config._global.namespace)
                            + cm.nogroup.v1.issuer.spec.ca.withSecretName('cert-db-telesto-server'),
  secret_cert_db_telesto_client: k.core.v1.secret.new('cert-db-telesto-client', {}, 'kubernetes.io/tls')
                                 + k.core.v1.secret.metadata.withNamespace($._config._global.namespace)
                                 + k.core.v1.secret.metadata.withLabelsMixin({
                                   'cnpg.io/reload': '',
                                 }),
  cert_db_telesto_client: cm.nogroup.v1.certificate.new('db-telesto-client')
                          + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                          + cm.nogroup.v1.certificate.spec.withIsCA(true)
                          + cm.nogroup.v1.certificate.spec.withCommonName('streaming-replica')
                          + cm.nogroup.v1.certificate.spec.withSecretName('cert-db-telesto-client')
                          + cm.nogroup.v1.certificate.spec.withUsages([
                            'client auth',
                          ])
                          + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                          + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                          + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  issuer_db_telesto_client: cm.nogroup.v1.issuer.new('issuer-db-telesto-client')
                            + cm.nogroup.v1.issuer.metadata.withNamespace($._config._global.namespace)
                            + cm.nogroup.v1.issuer.spec.ca.withSecretName('cert-db-telesto-client'),
  telesto_db_cluster: helm.template('telesto-db', '../../charts/cluster', {
    namespace: 'telesto',
    values: {
      cluster: {
        instances: 1,
        storage: {
          size: '5Gi',
        },
        postgresql: {
          parameters: {
            'pg_hba.conf': |||
              hostssl all all all cert
              hostnossl all all all reject
            |||,

          },
          pg_hba: [
            'hostssl all all all cert',
            'hostnossl all all all reject',
          ],
        },
        certificates: {
          serverTLSSecret: 'cert-db-telesto-server',
          serverCASecret: 'cert-db-telesto-server',
          clientCASecret: 'cert-db-telesto-client',
          replicationTLSSecret: 'cert-db-telesto-client',
        },
      },
    },
  }),

  cert_db_telesto_app_client: cm.nogroup.v1.certificate.new('db-telesto-app-client')
                              + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                              + cm.nogroup.v1.certificate.spec.withCommonName('telesto-app')
                              + cm.nogroup.v1.certificate.spec.withSecretName('cert-db-telesto-app-client')
                              + cm.nogroup.v1.certificate.spec.withUsages([
                                'client auth',
                              ])
                              + cm.nogroup.v1.certificate.spec.privateKey.withAlgorithm('ECDSA')
                              + cm.nogroup.v1.certificate.spec.privateKey.withSize(256)
                              + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                              + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                              + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  telesto_db_role: {
    apiVersion: 'postgresql.cnpg.io/v1',
    kind: 'DatabaseRole',
    metadata: {
      name: 'role-telesto',
      namespace: 'telesto',
    },
    spec: {
      cluster: {
        name: 'telesto-db-cluster',
      },
      name: 'telesto-app',
      comment: 'telesto app',
      login: true,
      superuser: false,
      createdb: false,
      databaseRoleReclaimPolicy: 'delete',
    },
  },
  telesto_db: {
    apiVersion: 'postgresql.cnpg.io/v1',
    kind: 'Database',
    metadata: {
      name: 'telesto',
      namespace: 'telesto',
    },
    spec: {
      databaseReclaimPolicy: 'delete',
      cluster: {
        name: 'telesto-db-cluster',
      },
      name: 'telesto',
      owner: 'telesto-app',
    },
  },
}
