local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local identitySchema = importstr './identity.schema.json';

local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local deployment = k.apps.v1.deployment;

local helmutil = import '../../lib/util/helm.libsonnet';

local dnsutil = import '../../lib/util/dns.libsonnet';

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local certificate = cm.nogroup.v1.certificate;
local issuer = cm.nogroup.v1.issuer;

local cnpg = import '../cloudnative-pg-crds/1.30.0/main.libsonnet';
local cluster = cnpg.postgresql.v1.cluster;
local database = cnpg.postgresql.v1.database;
local databaseRole = cnpg.postgresql.v1.databaseRole;

local secureGateway = import '../util/secure_gateway.libsonnet';

local certs = import '../util/certs.libsonnet';

{
  _config:: {
    _global: {
      namespace: 'auth',
    },
    domainKratos: 'auth.telesto.test',
    domainDex: 'dex.telesto.test',

    issuerRefName: '',
    issuerRefKind: 'ClusterIssuer',

    argocdClientSecret: '',
    githubClientID: '',
    githubClientSecret: '',
  },

  // database for auth components
  certDBCluster: certs.server.new(
    name='kratos-public',
    namespace=$._config._global.namespace,
    commonName=$._config.domainKratos,
    issuerRefName=$._config.issuerRefName
  ),
  certDBClient: certs.server.new(
    name='kratos-public',
    namespace=$._config._global.namespace,
    commonName=$._config.domainKratos,
    issuerRefName=$._config.issuerRefName
  ),
  certDBAuthServer: certificate.new('db-auth-server')
                    + certificate.metadata.withNamespace($._config._global.namespace)
                    + certificate.spec.withIsCA(true)
                    + certificate.spec.withCommonName('db-auth-server')
                    + certificate.spec.withSecretName('cert-db-auth-server')
                    + certificate.spec.secretTemplate.withLabels({ 'cnpg.io/reload': '' })
                    + certificate.spec.withUsages(['server auth'])
                    + certificate.spec.withDnsNames(
                      dnsutil.dnsnames.cnpg.new('auth-db-cluster', 'auth')
                    )
                    + certificate.spec.privateKey.withAlgorithm('ECDSA')
                    + certificate.spec.privateKey.withSize(256)
                    + certificate.spec.issuerRef.withName($._config.issuerRefName)
                    + certificate.spec.issuerRef.withKind('ClusterIssuer')
                    + certificate.spec.issuerRef.withGroup('cert-manager.io'),
  issuerDBAuthServer: issuer.new('issuer-db-auth-server')
                      + issuer.metadata.withNamespace($._config._global.namespace)
                      + issuer.spec.ca.withSecretName('cert-db-auth-server'),
  certDBAuthClient: certificate.new('db-auth-client')
                    + certificate.metadata.withNamespace($._config._global.namespace)
                    + certificate.spec.withIsCA(true)
                    + certificate.spec.withCommonName('streaming-replica')
                    + certificate.spec.withSecretName('cert-db-auth-client')
                    + certificate.spec.secretTemplate.withLabels({ 'cnpg.io/reload': '' })
                    + certificate.spec.withUsages(['client auth'])
                    + certificate.spec.issuerRef.withName($._config.issuerRefName)
                    + certificate.spec.issuerRef.withKind('ClusterIssuer')
                    + certificate.spec.issuerRef.withGroup('cert-manager.io'),
  issuerDBAuthClient: issuer.new('issuer-db-auth-client')
                      + issuer.metadata.withNamespace($._config._global.namespace)
                      + issuer.spec.ca.withSecretName('cert-db-auth-client'),
  // TODO: libsonnetify helm values
  clusterDBAuth: helm.template('auth-db', '../../charts/cluster', {
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
  certDBAuthKratosClient: certificate.new('db-auth-kratos-client')
                          + certificate.metadata.withNamespace($._config._global.namespace)
                          + certificate.spec.withCommonName('kratos')
                          + certificate.spec.withSecretName('cert-db-auth-kratos-client')
                          + certificate.spec.withUsages([
                            'client auth',
                          ])
                          + certificate.spec.privateKey.withAlgorithm('ECDSA')
                          + certificate.spec.privateKey.withSize(256)
                          + certificate.spec.issuerRef.withName($._config.issuerRefName)
                          + certificate.spec.issuerRef.withKind('ClusterIssuer')
                          + certificate.spec.issuerRef.withGroup('cert-manager.io'),

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
    commonName=$._config.domainKratos,
    issuerRefName=$._config.issuerRefName
  ),
  certKratosAdmin: certs.server.new(
    name='kratos-admin',
    namespace=$._config._global.namespace,
    commonName='auth-kratos-admin.auth',
    issuerRefName=$._config.issuerRefName
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
    issuerRefName=$._config.issuerRefName,
    serviceName='auth-kratos-public',
    servicePort=443,
    caCertConfigMapName='bundle-telesto'
  ),

  // dex db
  certAuthDBDexClient: certs.db.client.new(
    name='db-auth-client-dex',
    namespace=$._config._global.namespace,
    commonName='dex',
    issuerRefName=$._config.issuerRefName,
  ),
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
  certDex: certs.server.new(
    name='dex',
    namespace=$._config._global.namespace,
    commonName=$._config.domainDex,
    issuerRefName=$._config.issuerRefName
  ),
  dex: helm.template('dex', '../../charts/dex', {
    skipTests: true,
    namespace: 'auth',
    values: {
      volumes: [
        {
          name: 'db-client-cert',
          secret: {
            secretName: 'cert-db-auth-client-dex',
            defaultMode: std.parseOctal('640'),
          },
        },
        {
          name: 'server-cert',
          secret: {
            secretName: 'cert-dex',
            defaultMode: std.parseOctal('640'),
          },
        },
      ],
      volumeMounts: [
        {
          name: 'db-client-cert',
          mountPath: '/etc/certs/db',
          readOnly: true,
        },
        {
          name: 'server-cert',
          mountPath: '/etc/certs/server',
          readOnly: true,
        },
      ],
      config: {
        issuer: 'https://' + $._config.domainDex,
        enablePasswordDB: false,
        web: {
          http: '',
          tlsCert: '/etc/certs/server/tls.crt',
          tlsKey: '/etc/certs/server/tls.key',
        },
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
              caFile: '/etc/certs/db/ca.crt',
              keyFile: '/etc/certs/db/tls.key',
              certFile: '/etc/certs/db/tls.crt',
            },
          },
        },
      },
      https: {
        enabled: true,
      },
    },
  }),
  gatewayDex: secureGateway.new(
    name='dex',
    namespace=$._config._global.namespace,
    hostname=$._config.domainDex,
    gatewayClassName='nginx',
    issuerRefName=$._config.issuerRefName,
    serviceName='dex',
    servicePort=5554,
    caCertConfigMapName='bundle-telesto'
  ),
}
