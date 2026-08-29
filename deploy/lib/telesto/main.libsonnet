local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local dnsutil = import '../../lib/util/dns.libsonnet';

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';

local tc = import '../telesto-config/config.libsonnet';

local certs = import '../util/certs.libsonnet';

local sgw = import '../util/simple_gateway.libsonnet';

local secureGateway = import '../util/secure_gateway.libsonnet';

local cnpgutil = import '../util/cnpg.libsonnet';

local cnpg = import '../cloudnative-pg-crds/1.30.0/main.libsonnet';
local databaseRole = cnpg.postgresql.v1.databaseRole;
local database = cnpg.postgresql.v1.database;
local cluster = cnpg.postgresql.v1.cluster;

local es = import '../external-secrets-crds/2.9.0/main.libsonnet';
local externalSecret = es.nogroup.v1.externalSecret;
local clusterSecretStore = es.nogroup.v1.clusterSecretStore;
local secretStore = es.nogroup.v1.secretStore;

local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local deployment = k.apps.v1.deployment;
local container = k.core.v1.container;
local cPort = k.core.v1.containerPort;
local service = k.core.v1.service;

{
  _config:: {
    _global: {
      namespace: 'app',
    },
    issuerRefName: '',
    issuerRefKind: 'ClusterIssuer',
    domain: 'app.telesto.test',
    bundleName: 'bundle-telesto',
    telesto: {
      config: {
        server: {
          public: {
            address: ':443',
            cookies: {
              cookieEncKey: '',
              cookieStoreKey: '',
              sessionEncKey: '',
              sessionStoreKey: '',
            },
            csrf: {
              key: '',
            },

          },
          private: {
            address: ':8443',
            telestoDeployer: {
              token: '',
            },
            externalSecrets: {
              token: '',
            },
          },
        },
      },
    },
  },

  _images:: {
    telesto: 'ghcr.io/thisisibrahimd/telesto:0.0.3-next',
  },

  container::
    container.new('telesto', $._images.telesto),
  publicPort:: std.parseInt(std.splitLimit($._config.telesto.config.server.public.address, ':', 1)[1]),
  privatePort:: std.parseInt(std.splitLimit($._config.telesto.config.server.private.address, ':', 1)[1]),

  deployment: deployment.new(
                'telesto',
                1,
                containers=[
                  self.container
                  + container.withPortsMixin(cPort.new('public', $.publicPort))
                  + container.withPortsMixin(cPort.new('private', $.privatePort))
                  + container.withCommand(['/usr/bin/telesto', 'serve', '--config', '/etc/telesto/telesto.json'])
                  + container.readinessProbe.httpGet.withPort($.publicPort)
                  + container.readinessProbe.httpGet.withPath('/ping')
                  + container.readinessProbe.httpGet.withScheme('HTTPS')
                  + container.readinessProbe.withPeriodSeconds(1)
                  + container.readinessProbe.withInitialDelaySeconds(3)
                  + container.readinessProbe.withFailureThreshold(5)
                  + container.readinessProbe.withSuccessThreshold(3)
                  + container.withVolumeMountsMixin({
                    name: 'db-client-cert',
                    mountPath: '/etc/certs/db',
                    readOnly: true,
                  })
                  + container.withVolumeMountsMixin({
                    name: 'public-server-cert',
                    mountPath: '/etc/certs/server/public',
                    readOnly: true,
                  })
                  + container.withVolumeMountsMixin({
                    name: 'private-server-cert',
                    mountPath: '/etc/certs/server/private',
                    readOnly: true,
                  })
                  + container.withVolumeMountsMixin({
                    name: 'config',
                    mountPath: '/etc/telesto',
                    readOnly: true,
                  })
                  + container.withVolumeMountsMixin({
                    name: 'telesto-root-ca-cert',
                    mountPath: '/etc/certs/ca',
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
                name: 'public-server-cert',
                secret: {
                  secretName: 'cert-telesto-public-server',
                },
              })
              + deployment.spec.template.spec.withVolumesMixin({
                name: 'private-server-cert',
                secret: {
                  secretName: 'cert-telesto-private-server',
                },
              })
              + deployment.spec.template.spec.withVolumesMixin({
                name: 'config',
                secret: {
                  secretName: 'config-telesto',
                },
              })
              + deployment.spec.template.spec.withVolumesMixin({
                name: 'telesto-root-ca-cert',
                configMap: {
                  name: $._config.bundleName + '-root-ca',
                },
              }),
  publicService: service.new('telesto-public', { name: 'telesto' }, {
                   protocol: 'TCP',
                   port: $.publicPort,
                   targetPort: $.publicPort,
                 })
                 + service.metadata.withNamespace($._config._global.namespace),
  privateServer: service.new('telesto-private', { name: 'telesto' }, {
                   protocol: 'TCP',
                   port: $.privatePort,
                   targetPort: $.privatePort,
                 })
                 + service.metadata.withNamespace($._config._global.namespace),
  secret: k.core.v1.secret.new('config-telesto', {
            'telesto.json': std.base64(std.toString(
              tc.storage.withMigrate(true)
              + tc.storage.withDsn('postgres://telesto-app@telesto-db-cluster-rw.app:5432/telesto?sslmode=verify-full&sslrootcert=/etc/certs/db/ca.crt&sslcert=/etc/certs/db/tls.crt&sslkey=/etc/certs/db/tls.key')
              + tc.server.public.withAddress($._config.telesto.config.server.public.address)
              + tc.server.public.withBaseUrl('https://app.telesto.test')
              + tc.server.public.cookies.withCookieEncKey($._config.telesto.config.server.public.cookies.cookieEncKey)
              + tc.server.public.cookies.withCookieStoreKey($._config.telesto.config.server.public.cookies.cookieStoreKey)
              + tc.server.public.cookies.withSessionEncKey($._config.telesto.config.server.public.cookies.sessionEncKey)
              + tc.server.public.cookies.withSessionStoreKey($._config.telesto.config.server.public.cookies.sessionStoreKey)
              + tc.server.public.csrf.withKey($._config.telesto.config.server.public.csrf.key)
              + tc.server.public.tls.withCaCert('/etc/certs/ca/ca.crt')
              + tc.server.public.tls.withCert('/etc/certs/server/public/tls.crt')
              + tc.server.public.tls.withKey('/etc/certs/server/public/tls.key')
              + tc.server.public.auth.kratos.withInternalEndpoint('https://auth-kratos-public.auth')
              + tc.server.public.auth.kratos.withPublicEndpoint('https://auth.telesto.test')
              + tc.server.private.withAddress($._config.telesto.config.server.private.address)
              + tc.server.private.tls.withCert('/etc/certs/server/private/tls.crt')
              + tc.server.private.tls.withKey('/etc/certs/server/private/tls.key')
              + tc.server.private.telestoDeployer.withToken($._config.telesto.config.server.private.telestoDeployer.token)
              + tc.server.private.externalSecrets.withToken($._config.telesto.config.server.private.externalSecrets.token)
            )),
          })
          + k.core.v1.secret.metadata.withNamespace($._config._global.namespace),
  certPublicServer: certs.server.new(
    name='telesto-public-server',
    namespace=$._config._global.namespace,
    commonName=$._config.domain,
    issuerRefName=$._config.issuerRefName,
    issuerRefKind=$._config.issuerRefKind,
  ),
  certPrivateServer: certs.server.new(
    name='telesto-private-server',
    namespace=$._config._global.namespace,
    commonName='telesto-private.app',
    issuerRefName=$._config.issuerRefName,
    issuerRefKind=$._config.issuerRefKind,
  ),
  gateway: secureGateway.new(
    name='telesto-app',
    namespace=$._config._global.namespace,
    hostname=$._config.domain,
    gatewayClassName='nginx',
    issuerRefName=$._config.issuerRefName,
    issuerRefKind=$._config.issuerRefKind,
    serviceName='telesto-public',
    servicePort=$.publicPort,
    caCertConfigMapName=$._config.bundleName
  ),

  // secrets
  telestoClusterSecretStoreCredentials: k.core.v1.secret.new('telesto-cluster-secret-store-creds', {
                                          token: std.base64($._config.telesto.config.server.private.externalSecrets.token),
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
  dbTelestoPKI: cnpgutil.pki.new(
    name='db-telesto',
    namespace=$._config._global.namespace,
    clusterName='telesto-db-cluster',
    issuerRefName=$._config.issuerRefName,
    issuerRefKind=$._config.issuerRefKind
  ),
  telestoDBCluster: helm.template('telesto-db', '../../charts/cluster', {
    skipTest: true,
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
                              + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.issuerRefName)
                              + cm.nogroup.v1.certificate.spec.issuerRef.withKind($._config.issuerRefKind)
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
