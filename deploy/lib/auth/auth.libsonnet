local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local identitySchema = importstr './identity.schema.json';
local k = import 'ksonnet-util/kausal.libsonnet';

local helmutil = import '../../lib/util/helm.libsonnet';
local netutil = import '../../lib/util/net.libsonnet';
local dnsutil = import '../../lib/util/dns.libsonnet';

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local cmv1 = cm.nogroup.v1;

{
  _config:: {
    _global: {
      namespace: 'auth',
    },
    domain: 'auth.telesto.test',
    clusterIssuerRefName: 'cluster-issuer-central',
  },
  // database for auth components
  secret_cert_db_auth_server: k.core.v1.secret.new('cert-db-auth-server', {}, 'kubernetes.io/tls')
                              + k.core.v1.secret.metadata.withNamespace($._config._global.namespace)
                              + k.core.v1.secret.metadata.withLabelsMixin({
                                'cnpg.io/reload': '',
                              }),
  cert_db_auth_server: cm.nogroup.v1.certificate.new('db-auth-server')
                       + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                       + cm.nogroup.v1.certificate.spec.withIsCA(true)
                       + cm.nogroup.v1.certificate.spec.withCommonName('db-auth-server')
                       + cm.nogroup.v1.certificate.spec.withSecretName('cert-db-auth-server')
                       + cm.nogroup.v1.certificate.spec.withUsages([
                         'server auth',
                       ])
                       + cm.nogroup.v1.certificate.spec.withDnsNames(
                         dnsutil.dnsnames.cnpg.new('auth-db-cluster', 'auth')
                       )
                       + cm.nogroup.v1.certificate.spec.privateKey.withAlgorithm('ECDSA')
                       + cm.nogroup.v1.certificate.spec.privateKey.withSize(256)
                       + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                       + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                       + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  issuer_db_auth_server: cm.nogroup.v1.issuer.new('issuer-db-auth-server')
                         + cm.nogroup.v1.issuer.metadata.withNamespace($._config._global.namespace)
                         + cm.nogroup.v1.issuer.spec.ca.withSecretName('cert-db-auth-server'),
  secret_cert_db_auth_client: k.core.v1.secret.new('cert-db-auth-client', {}, 'kubernetes.io/tls')
                              + k.core.v1.secret.metadata.withNamespace($._config._global.namespace)
                              + k.core.v1.secret.metadata.withLabelsMixin({
                                'cnpg.io/reload': '',
                              }),
  cert_db_auth_client: cm.nogroup.v1.certificate.new('db-auth-client')
                       + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                       + cm.nogroup.v1.certificate.spec.withIsCA(true)
                       + cm.nogroup.v1.certificate.spec.withCommonName('streaming-replica')
                       + cm.nogroup.v1.certificate.spec.withSecretName('cert-db-auth-client')
                       + cm.nogroup.v1.certificate.spec.withUsages([
                         'client auth',
                       ])
                       + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                       + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                       + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  issuer_db_auth_client: cm.nogroup.v1.issuer.new('issuer-db-auth-client')
                         + cm.nogroup.v1.issuer.metadata.withNamespace($._config._global.namespace)
                         + cm.nogroup.v1.issuer.spec.ca.withSecretName('cert-db-auth-client'),
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


  cert_db_auth_kratos_client: cm.nogroup.v1.certificate.new('db-auth-kratos-client')
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
  kratos_db_role: {
    apiVersion: 'postgresql.cnpg.io/v1',
    kind: 'DatabaseRole',
    metadata: {
      name: 'role-kratos',
      namespace: $._config._global.namespace,
    },
    spec: {
      cluster: {
        name: 'auth-db-cluster',
      },
      name: 'kratos',
      comment: 'ORY Kratos',
      login: true,
      superuser: false,
      createdb: false,
      databaseRoleReclaimPolicy: 'delete',
    },
  },
  kratos_db: {
    apiVersion: 'postgresql.cnpg.io/v1',
    kind: 'Database',
    metadata: {
      name: 'kratos',
      namespace: $._config._global.namespace,
    },
    spec: {
      databaseReclaimPolicy: 'delete',
      cluster: {
        name: 'auth-db-cluster',
      },
      name: 'kratos',
      owner: 'kratos',
    },
  },
  // kratos svc
  kratos: helmutil.stripHelmHooks(helm.template('auth', '../../charts/kratos', {
    namespace: $._config._global.namespace,
    values: {
      deployment: {
        extraVolumes: [{
          name: 'db-client-cert',
          secret: {
            secretName: 'cert-db-auth-kratos-client',
          },
        }],
        extraVolumeMounts: [{
          name: 'db-client-cert',
          mountPath: '/etc/secrets/db',
          readOnly: true,
        }],
        extraEnv: [
          {
            name: 'LOG_LEAK_SENSITIVE_VALUES',
            value: 'false',
          },
        ],
      },
      kratos: {
        automigration: {
          enabled: true,
          type: 'job',
        },
        config: {
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
              base_url: 'https://admin.auth.telesto.test',
            },
            public: {
              base_url: 'https://auth.telesto.test',
              cors: {
                debug: true,
                enabled: true,
                allowed_origins: [
                  'https://app.telesto.test',
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
  gatewayKratosPublic: (import '../util/simple_gateway.libsonnet') + {
    _config+:: {
      _global: {
        namespace: $._config._global.namespace,
      },
      name: 'kratos-public',
      hostname: 'auth.telesto.test',
      gatewayClassName: 'nginx',
      issuerRef: {
        name: 'cluster-issuer-central',
        kind: 'ClusterIssuer',
      },
      svc: {
        name: 'auth-kratos-public',
        port: 80,
      },
    },
  },
  gatewayKratosAdmin: (import '../util/simple_gateway.libsonnet') + {
    _config+:: {
      _global: {
        namespace: $._config._global.namespace,
      },
      name: 'kratos-admin',
      hostname: 'admin.auth.telesto.test',
      gatewayClassName: 'nginx',
      issuerRef: {
        name: 'cluster-issuer-central',
        kind: 'ClusterIssuer',
      },
      svc: {
        name: 'auth-kratos-admin',
        port: 80,
      },
    },
  },


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
          defaultMode: std.parseOctal("640"),
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
            secret: 'my-secret-here',
          },
        ],
        connectors: [
          {
            type: 'github',
            id: 'argocd-telesto-test',
            name: 'ArgoCD (test)',
            config: {
              clientID: 'Ov23liRefkARpwR7s7qs',
              clientSecret: '22814fd9291d1f9a96dc46d8b5ecfbb128ed31a8',
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
  gatewayDex: (import '../util/simple_gateway.libsonnet') + {
    _config+:: {
      _global: {
        namespace: $._config._global.namespace,
      },
      name: 'dex',
      hostname: 'dex.telesto.test',
      gatewayClassName: 'nginx',
      issuerRef: {
        name: 'cluster-issuer-central',
        kind: 'ClusterIssuer',
      },
      svc: {
        name: 'dex',
        port: 5556,
      },
    },
  },
}
