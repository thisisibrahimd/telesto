local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local identitySchema = importstr './identity.schema.json';

local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local deployment = k.apps.v1.deployment;

local helmutil = import '../../lib/util/helm.libsonnet';

local cnpgutil = import '../util/cnpg.libsonnet';

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
local issuers = import '../util/issuers.libsonnet';

{
  _config:: {
    _global: {
      namespace: 'auth',
    },
    issuerRefName: '',
    issuerRefKind: 'ClusterIssuer',
    kratos: {
      domain: 'auth.telesto.test',
    },
    dex: {
      enabled: false,
      domain: 'dex.telesto.test',
      argocdClientSecret: '',
      githubClientID: '',
      githubClientSecret: '',
    },


  },

  // database for auth components
  dbAuthPKI: cnpgutil.pki.new(
    name='db-auth',
    namespace=$._config._global.namespace,
    clusterName='auth-db-cluster',
    issuerRefName=$._config.issuerRefName,
    issuerRefKind=$._config.issuerRefKind
  ),

  // TODO: libsonnetify helm values
  clusterDBAuth: helm.template('auth-db', '../../charts/cluster', {
    skipTests: true,
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


  certDBAuthClientKratos: certs.db.client.new(
    name='db-auth-client-kratos',
    namespace=$._config._global.namespace,
    commonName='kratos',
    issuerRefName=$._config.issuerRefName,
    issuerRefKind=$._config.issuerRefKind
  ),

  dbRoleKratos: cnpg.postgresql.v1.databaseRole.new('role-kratos')
                + cnpg.postgresql.v1.databaseRole.metadata.withNamespace($._config._global.namespace)
                + cnpg.postgresql.v1.databaseRole.spec.cluster.withName('auth-db-cluster')
                + cnpg.postgresql.v1.databaseRole.spec.withName('kratos')
                + cnpg.postgresql.v1.databaseRole.spec.withComment('ORY Kratos')
                + cnpg.postgresql.v1.databaseRole.spec.withLogin(true)
                + cnpg.postgresql.v1.databaseRole.spec.withSuperuser(false)
                + cnpg.postgresql.v1.databaseRole.spec.withCreatedb(false)
                + cnpg.postgresql.v1.databaseRole.spec.withDatabaseRoleReclaimPolicy('delete'),
  dbKratos: cnpg.postgresql.v1.database.new('kratos')
            + cnpg.postgresql.v1.database.metadata.withNamespace($._config._global.namespace)
            + cnpg.postgresql.v1.database.spec.cluster.withName('auth-db-cluster')
            + cnpg.postgresql.v1.database.spec.withName('kratos')
            + cnpg.postgresql.v1.database.spec.withOwner('kratos')
            + cnpg.postgresql.v1.database.spec.withDatabaseReclaimPolicy('delete'),


  // kratos svc
  certKratosPublic: certs.server.new(
    name='kratos-public',
    namespace=$._config._global.namespace,
    commonName=$._config.kratos.domain,
    issuerRefName=$._config.issuerRefName
  ),
  certKratosAdmin: certs.server.new(
    name='kratos-admin',
    namespace=$._config._global.namespace,
    commonName='auth-kratos-admin.auth',
    issuerRefName=$._config.issuerRefName
  ),
  kratos: helmutil.stripHelmHooks(helm.template('auth', '../../charts/kratos', {
    skipTests: true,
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
              secretName: 'cert-db-auth-client-kratos',
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
    hostname=$._config.kratos.domain,
    gatewayClassName='nginx',
    issuerRefName=$._config.issuerRefName,
    serviceName='auth-kratos-public',
    servicePort=443,
    caCertConfigMapName='bundle-telesto'
  ),

  // dex db
  dex: if $._config.dex.enabled then {
    certDBAuthClientDex: certs.db.client.new(
      name='db-auth-client-dex',
      namespace=$._config._global.namespace,
      commonName='dex',
      issuerRefName=$._config.issuerRefName,
      issuerRefKind=$._config.issuerRefKind
    ),
    dbRoleDex: cnpg.postgresql.v1.databaseRole.new('role-dex')
               + cnpg.postgresql.v1.databaseRole.metadata.withNamespace($._config._global.namespace)
               + cnpg.postgresql.v1.databaseRole.spec.cluster.withName('auth-db-cluster')
               + cnpg.postgresql.v1.databaseRole.spec.withName('dex')
               + cnpg.postgresql.v1.databaseRole.spec.withComment('Dex IDP')
               + cnpg.postgresql.v1.databaseRole.spec.withLogin(true)
               + cnpg.postgresql.v1.databaseRole.spec.withSuperuser(false)
               + cnpg.postgresql.v1.databaseRole.spec.withCreatedb(false)
               + cnpg.postgresql.v1.databaseRole.spec.withDatabaseRoleReclaimPolicy('delete'),
    dbDex: cnpg.postgresql.v1.database.new('dex')
           + cnpg.postgresql.v1.database.metadata.withNamespace($._config._global.namespace)
           + cnpg.postgresql.v1.database.spec.cluster.withName('auth-db-cluster')
           + cnpg.postgresql.v1.database.spec.withName('dex')
           + cnpg.postgresql.v1.database.spec.withOwner('dex')
           + cnpg.postgresql.v1.database.spec.withDatabaseReclaimPolicy('delete'),
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
          staticClients: [],
          connectors: [],
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
  },
}
