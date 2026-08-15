local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local dnsutil = import '../../lib/util/dns.libsonnet';

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';


local cnpg = import '../cloudnative-pg-crds/1.30.0/main.libsonnet';
local databaseRole = cnpg.postgresql.v1.databaseRole;
local database = cnpg.postgresql.v1.database;
local cluster = cnpg.postgresql.v1.cluster;


local es = import '../external-secrets-crds/2.9.0/main.libsonnet';
local externalSecret = es.nogroup.v1.externalSecret;
local clusterSecretStore = es.nogroup.v1.clusterSecretStore;
local secretStore = es.nogroup.v1.secretStore;

local deployment = k.apps.v1.deployment;
local container = k.core.v1.container;
local cPort = k.core.v1.containerPort;
local service = k.core.v1.service;

{
  _config:: {
    _global: {
      namespace: 'app',
    },
    clusterIssuerRefName: '',
    telesto: {
      telesto: {
        port: 443,
        name: 'telesto',
      },
    },
    externalSecretsToken: '',
    telestoDeployerToken: '',
  },

  _images:: {
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
                    mountPath: '/etc/certs/db',
                    readOnly: true,
                  })
                  + container.withVolumeMountsMixin({
                    name: 'server-cert',
                    mountPath: '/etc/certs/server',
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
              + deployment.metadata.withAnnotations({
                'reloader.stakater.com/auto': 'true',
              })
              + deployment.spec.template.spec.withVolumesMixin({
                name: 'db-client-cert',
                secret: {
                  secretName: 'cert-db-telesto-app-client',
                },
              })
              + deployment.spec.template.spec.withVolumesMixin({
                name: 'server-cert',
                secret: {
                  secretName: 'cert-telesto-server',
                },
              })
              + deployment.spec.template.spec.withVolumesMixin({
                name: 'config',
                secret: {
                  secretName: 'config-telesto',
                },
              }),
  service: k.util.serviceFor(self.deployment)
           + service.metadata.withNamespace($._config._global.namespace),
  secret: k.core.v1.secret.new('config-telesto', {
            'telesto.json': std.base64(std.toString({
              auth: {
                kratos: {
                  internalEndpoint: 'http://auth-kratos-public.auth',
                  publicEndpoint: 'https://auth.telesto.test',
                },
              },
              storage: {
                migrate: true,
                dsn: 'postgres://telesto-app@telesto-db-cluster-rw.app:5432/telesto?sslmode=verify-full&sslrootcert=/etc/certs/db/ca.crt&sslcert=/etc/certs/db/tls.crt&sslkey=/etc/certs/db/tls.key',
              },
              server: {
                address: ':' + $._config.telesto.telesto.port,
                port: $._config.telesto.telesto.port,
                // cert: "/etc/certs/server/tls.crt",
                // key: "/etc/certs/server/tls.key"
                telestoDeployer: {
                  token: $._config.telestoDeployerToken,
                },
                externalSecrets: {
                  token: $._config.externalSecretsToken,
                },
              },
            })),
          }, 'Opaque')
          + k.core.v1.secret.metadata.withNamespace($._config._global.namespace),
  certServer: cm.nogroup.v1.certificate.new('telesto-server')
              + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
              + cm.nogroup.v1.certificate.spec.withCommonName('app.telesto.net')
              + cm.nogroup.v1.certificate.spec.withSecretName('cert-telesto-server')
              + cm.nogroup.v1.certificate.spec.withUsages([
                'server auth',
              ])
              + cm.nogroup.v1.certificate.spec.privateKey.withAlgorithm('RSA')
              + cm.nogroup.v1.certificate.spec.privateKey.withSize(4096)
              + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
              + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
              + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
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
        port: 443,
      },
    },
  },

  // secrets
  telestoClusterSecretStoreCredentials: k.core.v1.secret.new('telesto-cluster-secret-store-creds', {
                                          token: std.base64($._config.externalSecretsToken),
                                        }, 'Opaque')
                                        + k.core.v1.secret.metadata.withNamespace($._config._global.namespace)
                                        + k.core.v1.secret.metadata.withLabels({
                                          'external-secrets.io/type': 'webhook',
                                        }),
  telestoClusterSecretStore: clusterSecretStore.new('telesto-cluster-secret-store')
                             + clusterSecretStore.metadata.withNamespace($._config._global.namespace)
                             + clusterSecretStore.spec.provider.webhook.withUrl('http://telesto.app:443/telestos/{{ .remoteRef.key }}/tokens')
                             + clusterSecretStore.spec.provider.webhook.result.withJsonPath('$.tokens')
                             + clusterSecretStore.spec.provider.webhook.withHeaders({
                               'Content-Type': 'application/json',
                               Authorization: 'Bearer {{ print .auth.token }}',
                             })
                             + clusterSecretStore.spec.withConditions(
                               clusterSecretStore.spec.conditions.withNamespaceRegexes('telesto-.*')
                             )
                             + clusterSecretStore.spec.provider.webhook.withSecrets(
                               clusterSecretStore.spec.provider.webhook.secrets.withName('auth')
                               + clusterSecretStore.spec.provider.webhook.secrets.secretRef.withName('telesto-cluster-secret-store-creds')
                               + clusterSecretStore.spec.provider.webhook.secrets.secretRef.withNamespace('app')
                             ),
  // database
  secretCertDBTelestoServer: k.core.v1.secret.new('cert-db-telesto-server', {}, 'kubernetes.io/tls')
                             + k.core.v1.secret.metadata.withNamespace($._config._global.namespace)
                             + k.core.v1.secret.metadata.withLabelsMixin({ 'cnpg.io/reload': '' }),
  certDBTelestoServer: cm.nogroup.v1.certificate.new('db-telesto-server')
                       + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                       + cm.nogroup.v1.certificate.spec.withIsCA(true)
                       + cm.nogroup.v1.certificate.spec.withCommonName('db-telesto-server')
                       + cm.nogroup.v1.certificate.spec.withSecretName('cert-db-telesto-server')
                       + cm.nogroup.v1.certificate.spec.withUsages(['server auth'])
                       + cm.nogroup.v1.certificate.spec.withDnsNames(
                         dnsutil.dnsnames.cnpg.new('telesto-db-cluster', $._config._global.namespace)
                       )
                       + cm.nogroup.v1.certificate.spec.privateKey.withAlgorithm('ECDSA')
                       + cm.nogroup.v1.certificate.spec.privateKey.withSize(256)
                       + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                       + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                       + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  issuerDBTeletsoServer: cm.nogroup.v1.issuer.new('issuer-db-telesto-server')
                         + cm.nogroup.v1.issuer.metadata.withNamespace($._config._global.namespace)
                         + cm.nogroup.v1.issuer.spec.ca.withSecretName('cert-db-telesto-server'),
  secretCertDBTelestoClient: k.core.v1.secret.new('cert-db-telesto-client', {}, 'kubernetes.io/tls')
                             + k.core.v1.secret.metadata.withNamespace($._config._global.namespace)
                             + k.core.v1.secret.metadata.withLabelsMixin({ 'cnpg.io/reload': '' }),
  certDBTelestoClient: cm.nogroup.v1.certificate.new('db-telesto-client')
                       + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                       + cm.nogroup.v1.certificate.spec.withIsCA(true)
                       + cm.nogroup.v1.certificate.spec.withCommonName('streaming-replica')
                       + cm.nogroup.v1.certificate.spec.withSecretName('cert-db-telesto-client')
                       + cm.nogroup.v1.certificate.spec.withUsages(['client auth'])
                       + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                       + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                       + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  issuerDBTelestoClient: cm.nogroup.v1.issuer.new('issuer-db-telesto-client')
                         + cm.nogroup.v1.issuer.metadata.withNamespace($._config._global.namespace)
                         + cm.nogroup.v1.issuer.spec.ca.withSecretName('cert-db-telesto-client'),
  telestoDBCluster: helm.template('telesto-db', '../../charts/cluster', {
    namespace: $._config._global.namespace,
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
  telestoDBRole: cnpg.postgresql.v1.databaseRole.new('role-telesto')
                 + cnpg.postgresql.v1.databaseRole.metadata.withNamespace($._config._global.namespace)
                 + cnpg.postgresql.v1.databaseRole.spec.cluster.withName('telesto-db-cluster')
                 + cnpg.postgresql.v1.databaseRole.spec.withName('telesto-app')
                 + cnpg.postgresql.v1.databaseRole.spec.withComment('Telesto App')
                 + cnpg.postgresql.v1.databaseRole.spec.withLogin(true)
                 + cnpg.postgresql.v1.databaseRole.spec.withSuperuser(false)
                 + cnpg.postgresql.v1.databaseRole.spec.withCreatedb(false)
                 + cnpg.postgresql.v1.databaseRole.spec.withDatabaseRoleReclaimPolicy('delete'),
  telestoDB: cnpg.postgresql.v1.database.new('telesto')
             + cnpg.postgresql.v1.database.metadata.withNamespace($._config._global.namespace)
             + cnpg.postgresql.v1.database.spec.cluster.withName('telesto-db-cluster')
             + cnpg.postgresql.v1.database.spec.withName('telesto')
             + cnpg.postgresql.v1.database.spec.withOwner('telesto-app')
             + cnpg.postgresql.v1.database.spec.withDatabaseReclaimPolicy('delete'),
}
