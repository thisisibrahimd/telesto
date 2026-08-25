local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local identitySchema = importstr './identity.schema.json';
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local helmutil = import '../../lib/util/helm.libsonnet';

local dnsutil = import '../../lib/util/dns.libsonnet';

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local certificate = cm.nogroup.v1.certificate
local cnpg = import '../cloudnative-pg-crds/1.30.0/main.libsonnet';

local sgw = import '../util/simple_gateway.libsonnet';
local secureGateway = import '../util/secure_gateway.libsonnet';

local certs = import '../util/certs.libsonnet';

{
  _config:: {
    _global: {
      namespace: 'auth',
    },
    domain: 'auth.telesto.test',
    clusterIssuerRefName: 'cluster-issuer-central',

    argocdClientSecret: '',

    githubClientID: '',
    githubClientSecret: '',
  },

  // database for auth components
  certDBCluster: certs.server.new(
    name='kratos-public',
    namespace=$._config._global.namespace,
    commonName='auth.telesto.test',
    issuerName=$._config.clusterIssuerRefName
  ),
  certDBClient: certs.server.new(
    name='kratos-public',
    namespace=$._config._global.namespace,
    commonName='auth.telesto.test',
    issuerName=$._config.clusterIssuerRefName
  ),
  certDBAuthServer: cm.nogroup.v1.certificate.new('db-auth-server')
                    + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                    + cm.nogroup.v1.certificate.spec.withIsCA(true)
                    + cm.nogroup.v1.certificate.spec.withCommonName('db-auth-server')
                    + cm.nogroup.v1.certificate.spec.withSecretName('cert-db-auth-server')
                    + cm.nogroup.v1.certificate.spec.secretTemplate.withLabels({ 'cnpg.io/reload': '' })
                    + cm.nogroup.v1.certificate.spec.withUsages(['server auth'])
                    + cm.nogroup.v1.certificate.spec.withDnsNames(
                      dnsutil.dnsnames.cnpg.new('auth-db-cluster', 'auth')
                    )
                    + cm.nogroup.v1.certificate.spec.privateKey.withAlgorithm('ECDSA')
                    + cm.nogroup.v1.certificate.spec.privateKey.withSize(256)
                    + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                    + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                    + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  issuerDBAuthServer: cm.nogroup.v1.issuer.new('issuer-db-auth-server')
                      + cm.nogroup.v1.issuer.metadata.withNamespace($._config._global.namespace)
                      + cm.nogroup.v1.issuer.spec.ca.withSecretName('cert-db-auth-server'),
  certDBAuthClient: cm.nogroup.v1.certificate.new('db-auth-client')
                    + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                    + cm.nogroup.v1.certificate.spec.withIsCA(true)
                    + cm.nogroup.v1.certificate.spec.withCommonName('streaming-replica')
                    + cm.nogroup.v1.certificate.spec.withSecretName('cert-db-auth-client')
                    + cm.nogroup.v1.certificate.spec.secretTemplate.withLabels({ 'cnpg.io/reload': '' })
                    + cm.nogroup.v1.certificate.spec.withUsages(['client auth'])
                    + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                    + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                    + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  issuerDBAuthClient: cm.nogroup.v1.issuer.new('issuer-db-auth-client')
                      + cm.nogroup.v1.issuer.metadata.withNamespace($._config._global.namespace)
                      + cm.nogroup.v1.issuer.spec.ca.withSecretName('cert-db-auth-client'),
  // TODO: libsonnetify helm values
  auth_db_cluster: helm.template('auth-db', '../../charts/cluster', {
    namespace: $._config._global.namespace,
    values: {
      cluster: {
        enabledSuperuserAccess: false,
        instances: 1,
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
        storage: {
          size: '1Gi',
        },
        certificates: {
          serverTLSSecret: 'cert-db-auth-server',
          serverCASecret: 'cert-db-auth-server',
          clientCASecret: 'cert-db-auth-client',
          replicationTLSSecret: 'cert-db-auth-client',
        },
      },
    },
  }),
  certDBAuthKratosClient: cm.nogroup.v1.certificate.new('db-auth-kratos-client')
                          + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                          + cm.nogroup.v1.certificate.spec.withCommonName('kratos')
                          + cm.nogroup.v1.certificate.spec.withSecretName('cert-db-auth-kratos-client')
                          + cm.nogroup.v1.certificate.spec.withUsages([
                            'client auth',
                          ])
                          + cm.nogroup.v1.certificate.spec.privateKey.withAlgorithm('ECDSA')
                          + cm.nogroup.v1.certificate.spec.privateKey.withSize(256)
                          + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                          + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                          + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),

  kratosDBRole: cnpg.postgresql.v1.databaseRole.new('role-kratos')
                + cnpg.postgresql.v1.databaseRole.metadata.withNamespace($._config._global.namespace)
                + cnpg.postgresql.v1.databaseRole.spec.cluster.withName('auth-db-cluster')
                + cnpg.postgresql.v1.databaseRole.spec.withName('kratos')
                + cnpg.postgresql.v1.databaseRole.spec.withComment('ORY Kratos')
                + cnpg.postgresql.v1.databaseRole.spec.withLogin(true)
                + cnpg.postgresql.v1.databaseRole.spec.withSuperuser(false)
                + cnpg.postgresql.v1.databaseRole.spec.withCreatedb(false)
                + cnpg.postgresql.v1.databaseRole.spec.withDatabaseRoleReclaimPolicy('delete'),
  kratosDB: cnpg.postgresql.v1.database.new('kratos')
            + cnpg.postgresql.v1.database.metadata.withNamespace($._config._global.namespace)
            + cnpg.postgresql.v1.database.spec.cluster.withName('auth-db-cluster')
            + cnpg.postgresql.v1.database.spec.withName('kratos')
            + cnpg.postgresql.v1.database.spec.withOwner('kratos')
            + cnpg.postgresql.v1.database.spec.withDatabaseReclaimPolicy('delete'),
  // kratos svc
  certKratosPublic: certs.server.new(
    name='kratos-public',
    namespace=$._config._global.namespace,
    commonName=$._config.domain,
    issuerName=$._config.clusterIssuerRefName
  ),
  certKratosAdmin: certs.server.new(
    name='kratos-admin',
    namespace=$._config._global.namespace,
    commonName='auth-kratos-admin.auth',
    issuerName=$._config.clusterIssuerRefName
  ),
  kratos: helmutil.stripHelmHooks(helm.template('auth', '../../charts/kratos', {
    namespace: $._config._global.namespace,
    values: {
      deployment: {
        customStartupProbe: {
          failureThreshold: 5,
          initialDelaySeconds: 1,
          periodSeconds: 1,
          successThreshold: 1,
          timeoutSeconds: 2,
          httpGet:
            {
              httpHeaders:
                [
                  {
                    name: 'Host',
                    value: '127.0.0.1',
                  },
                ],
              path: '/admin/health/ready',
              port: 4434,
              scheme: 'HTTPS',
            },
        },
        customReadinessProbe: {
          failureThreshold: 5,
          periodSeconds: 10,
          initialDelaySeconds: 5,
          httpGet:
            {
              httpHeaders:
                [
                  {
                    name: 'Host',
                    value: '127.0.0.1',
                  },
                ],
              path: '/admin/health/alive',
              port: 4434,
              scheme: 'HTTPS',
            },
        },
        extraVolumes: [
          {
            name: 'db-client-cert',
            secret: {
              secretName: 'cert-db-auth-kratos-client',
            },
          },
          {
            name: 'kratos-public-cert',
            secret: {
              secretName: 'cert-kratos-public',
            },
          },
          {
            name: 'kratos-admin-cert',
            secret: {
              secretName: 'cert-kratos-admin',
            },
          },
        ],
        extraVolumeMounts: [
          {
            name: 'db-client-cert',
            mountPath: '/etc/secrets/db',
            readOnly: true,
          },
          {
            name: 'kratos-public-cert',
            mountPath: '/etc/certs/public',
            readOnly: true,
          },
          {
            name: 'kratos-admin-cert',
            mountPath: '/etc/certs/admin',
            readOnly: true,
          },
        ],
      },
      service: {
        admin: {
          name: 'https',
          port: 443,
        },
        public: {
          name: 'https',
          port: 443,
        },
      },
      kratos: {
        automigration: {
          enabled: true,
          type: 'job',
        },
        config: {
          log: {
            leak_sensitive_values: true,
          },
          dsn: 'postgres://kratos@auth-db-cluster-rw.auth:5432/kratos?sslmode=verify-full&sslrootcert=/etc/secrets/db/ca.crt&sslcert=/etc/secrets/db/tls.crt&sslkey=/etc/secrets/db/tls.key&max_conns=4&max_idle_conns=2',
          cookies: {
            domain: 'telesto.test',
            path: '/',
            // same_site: 'Lax',
          },
          session: {
            cookie: {
              domain: 'telesto.test',
              path: '/',
              // same_site: 'Lax',
            },
          },
          serve: {
            admin: {
              base_url: 'https://auth-kratos-admin.auth',
              tls: {
                key: {
                  path: '/etc/certs/admin/tls.key',
                },
                cert: {
                  path: '/etc/certs/admin/tls.crt',
                },
              },
            },
            public: {
              base_url: 'https://auth.telesto.test',
              cors: {
                debug: true,
                enabled: true,
                allowed_origins: [
                  'https://app.telesto.test',
                  'https://telesto-private.app',
                ],
                allowed_methods: [
                  'POST',
                  'GET',
                  'PUT',
                  'PATCH',
                  'DELETE',
                ],
                allowed_headers: [
                  'Authorization',
                  'Content-Type',
                  'Cookie',
                ],
                exposed_headers: [
                  'Content-Type',
                  'Set-Cookie',
                ],
                allow_credentials: true,
              },
              tls: {
                key: {
                  path: '/etc/certs/public/tls.key',
                },
                cert: {
                  path: '/etc/certs/public/tls.crt',
                },
              },
            },
          },
          secrets: {
            default: [
              ' dolore occaecat nostrud Ut',
              'sit et commodoaute ut voluptate consectetur Duis',
            ],
          },
          identity: {
            default_schema_id: 'default',
            schemas: [
              {
                id: 'default',
                url: 'file:///etc/config/identity.default.schema.json',
              },
            ],
          },
          courier: {
            smtp: {
              connection_uri: 'smtps://test:test@mailslurper:1025/?skip_ssl_verify=true',
            },
          },
          selfservice: {
            default_browser_return_url: 'https://app.telesto.test/',
            allowed_return_urls: [
              'https://app.telesto.test',
            ],
            methods: {
              passkey: {
                enabled: true,
                config: {
                  rp: {
                    display_name: 'Telesto',
                    id: 'telesto.test',
                    origins: [
                      'https://app.telesto.test',
                    ],
                  },
                },
              },
            },
            flows: {
              login: {
                ui_url: 'https://app.telesto.test/login',
              },
              registration: {
                enabled: true,
                ui_url: 'https://app.telesto.test/register',
              },
            },
          },
        },
        identitySchemas: {
          'identity.default.schema.json': std.toString(std.parseYaml(identitySchema)),
        },
      },
    },
  }), 120),
  gatewayKratosPublic: secureGateway.new(
    name='kratos-public',
    namespace=$._config._global.namespace,
    hostname='auth.telesto.test',
    gatewayClassName='nginx',
    issuerName='cluster-issuer-central',
    issuerKind='ClusterIssuer',
    serviceName='auth-kratos-public',
    servicePort=443,
    caCertConfigMapName='bundle-telesto'
  ),

  // dex db
  cert_db_auth_dex_client: cm.nogroup.v1.certificate.new('db-auth-dex-client')
                           + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                           + cm.nogroup.v1.certificate.spec.withCommonName('dex')
                           + cm.nogroup.v1.certificate.spec.withSecretName('cert-db-auth-dex-client')
                           + cm.nogroup.v1.certificate.spec.withUsages([
                             'client auth',
                           ])
                           + cm.nogroup.v1.certificate.spec.privateKey.withAlgorithm('ECDSA')
                           + cm.nogroup.v1.certificate.spec.privateKey.withSize(256)
                           + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                           + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                           + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  dex_db_role: {
    apiVersion: 'postgresql.cnpg.io/v1',
    kind: 'DatabaseRole',
    metadata: {
      name: 'role-dex',
      namespace: 'auth',
    },
    spec: {
      cluster: {
        name: 'auth-db-cluster',
      },
      name: 'dex',
      comment: 'dex',
      login: true,
      superuser: false,
      createdb: false,
      databaseRoleReclaimPolicy: 'delete',
    },
  },
  dex_db: {
    apiVersion: 'postgresql.cnpg.io/v1',
    kind: 'Database',
    metadata: {
      name: 'dex',
      namespace: 'auth',
    },
    spec: {
      databaseReclaimPolicy: 'delete',
      cluster: {
        name: 'auth-db-cluster',
      },
      name: 'dex',
      owner: 'dex',
    },
  },
  // dex
  dex: helm.template('dex', '../../charts/dex', {
    namespace: 'auth',
    values: {
      volumes: [{
        name: 'db-client-cert',
        secret: {
          secretName: 'cert-db-auth-dex-client',
          defaultMode: std.parseOctal('640'),
        },
      }],
      volumeMounts: [{
        name: 'db-client-cert',
        mountPath: '/etc/secrets/db',
        readOnly: true,
      }],
      config: {
        issuer: 'https://dex.telesto.test',
        enablePasswordDB: true,
        staticClients: [
          {
            id: 'argocd',
            redirectURIs: [
              'https://argocd.telesto.test/auth/callback',
            ],
            name: 'ArgoCD',
            secret: $._config.argocdClientSecret,
          },
        ],
        connectors: [
          {
            type: 'github',
            id: 'argocd-telesto-test',
            name: 'ArgoCD (test)',
            config: {
              clientID: $._config.githubClientID,
              clientSecret: $._config.githubClientSecret,
              redirectURI: 'https://dex.telesto.test/callback',
              orgs: [
                {
                  name: 'telestoai',
                  teams: [
                    'engineers',
                  ],
                },
              ],
              teamNameField: 'slug',
            },
          },
        ],
        storage: {
          type: 'postgres',
          config: {
            host: 'auth-db-cluster-rw.auth',
            port: 5432,
            database: 'dex',
            user: 'dex',
            ssl: {
              mode: 'verify-full',
              caFile: '/etc/secrets/db/ca.crt',
              keyFile: '/etc/secrets/db/tls.key',
              certFile: '/etc/secrets/db/tls.crt',
            },
          },
        },
      },
      https: {
        enabled: false,
      },
    },
  }),
  gatewayDex: sgw.new(
    name='dex',
    namespace=$._config._global.namespace,
    hostname='dex.telesto.test',
    gatewayClassName='nginx',
    issuerName='cluster-issuer-central',
    serviceName='dex',
    servicePort=5556
  ),
}
