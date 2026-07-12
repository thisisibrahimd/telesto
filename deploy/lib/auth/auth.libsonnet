local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local identitySchema = importstr '../../../identity.schema.json';
local k = import 'ksonnet-util/kausal.libsonnet';

local helmutil = import '../../lib/helmutil.libsonnet';

{
  new(): {
    // kratos
    auth_db_cluster: helm.template('auth-db', '../../charts/cluster', {
      namespace: 'default',
      values: {
        cluster: {
          instances: 1,
          storage: {
            size: '1Gi',
          },
          roles: [
            {
              name: 'kratos',
              ensure: 'present',
              comment: 'Ory Kratos',
              login: true,
              superuser: false,
              createdb: false,
              connectionLimit: 8,
              passwordSecret: {
                name: 'pg-cluster-kratos-password',
              },
            },
            {
              name: 'hydra',
              ensure: 'present',
              comment: 'Ory Hydra',
              login: true,
              superuser: false,
              createdb: false,
              connectionLimit: 8,
              passwordSecret: {
                name: 'pg-cluster-hydra-password',
              },
            },
          ],
        },
      },
    }),
    ory_kratos_pg_user_password: k.core.v1.secret.new('pg-cluster-kratos-password', {
      username: std.base64('kratos'),
      password: std.base64('password'),
    }, 'kubernetes.io/basic-auth'),
    kratos_db: {
      apiVersion: 'postgresql.cnpg.io/v1',
      kind: 'Database',
      metadata: {
        name: 'kratos',
        namespace: 'default',
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
    kratos: helmutil.stripHelmHooks(helm.template('auth', '../../charts/kratos', {
      namespace: 'default',
      values: {
        deployment: {
          extraEnv: [
            {
              name: 'LOG_LEAK_SENSITIVE_VALUES',
              value: 'false',
            },
          ],
        },
        kratos: {
          oauth2_provider: {
            url: 'http://auth-hydra-admin:4445',
          },
          automigration: {
            enabled: true,
            type: 'job',
          },
          config: {
            dsn: 'postgres://kratos:password@auth-db-cluster-rw:5432/kratos?sslmode=disable&max_conns=4&max_idle_conns=2',
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
    gateway_kratos_public: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'Gateway',
      metadata: {
        name: 'gateway-kratos-public',
        namespace: 'default',
        annotations: {
          'cert-manager.io/cluster-issuer': 'local-cluster-issuer',
        },
      },
      spec: {
        gatewayClassName: 'nginx',
        listeners: [
          {
            name: 'http',
            port: 80,
            protocol: 'HTTP',
            hostname: 'auth.telesto.test',
          },
          {
            name: 'https',
            port: 443,
            protocol: 'HTTPS',
            hostname: 'auth.telesto.test',
            allowedRoutes: {
              namespaces: {
                from: 'All',
              },
            },
            tls: {
              mode: 'Terminate',
              certificateRefs: [
                {
                  group: '',
                  kind: 'Secret',
                  name: 'test-telesto-auth-tls',
                  namespace: 'default',
                },
              ],
            },
          },
        ],
      },
    },
    httproute_kratos_public_http_to_https_redirect: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'http-route-kratos-public-http-to-https-redirect',
        namespace: 'default',
      },
      spec: {
        parentRefs: [
          {
            name: 'gateway-kratos-public',
            sectionName: 'http',
          },
        ],
        hostnames: [
          'auth.telesto.test',
        ],
        rules: [
          {
            filters: [
              {
                type: 'RequestRedirect',
                requestRedirect: {
                  scheme: 'https',
                  statusCode: 301,
                  port: 443,
                },
              },
            ],
          },
        ],
      },
    },
    httproute_kratos_public: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'http-route-kratos-public',
        namespace: 'default',
      },
      spec: {
        parentRefs: [
          {
            name: 'gateway-kratos-public',
          },
        ],
        hostnames: [
          'auth.telesto.test',
        ],
        rules: [
          {
            matches: [
              {
                path: {
                  type: 'PathPrefix',
                  value: '/',
                },
              },
            ],
            backendRefs: [
              {
                name: 'auth-kratos-public',
                port: 80,
              },
            ],
          },
        ],
      },
    },
    gateway_kratos_admin: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'Gateway',
      metadata: {
        name: 'gateway-kratos-admin',
        namespace: 'default',
        annotations: {
          'cert-manager.io/cluster-issuer': 'local-cluster-issuer',
        },
      },
      spec: {
        gatewayClassName: 'nginx',
        listeners: [
          {
            name: 'http',
            port: 80,
            protocol: 'HTTP',
            hostname: 'admin.auth.telesto.test',
          },
          {
            name: 'https',
            port: 443,
            protocol: 'HTTPS',
            hostname: 'admin.auth.telesto.test',
            allowedRoutes: {
              namespaces: {
                from: 'All',
              },
            },
            tls: {
              mode: 'Terminate',
              certificateRefs: [
                {
                  group: '',
                  kind: 'Secret',
                  name: 'test-telesto-auth-admin-tls',
                  namespace: 'default',
                },
              ],
            },
          },
        ],
      },
    },
    httproute_kratos_admin_http_to_https_redirect: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'http-route-kratos-admin-http-to-https-redirect',
        namespace: 'default',
      },
      spec: {
        parentRefs: [
          {
            name: 'gateway-kratos-admin',
            sectionName: 'http',
          },
        ],
        hostnames: [
          'admin.auth.telesto.test',
        ],
        rules: [
          {
            filters: [
              {
                type: 'RequestRedirect',
                requestRedirect: {
                  scheme: 'https',
                  statusCode: 301,
                  port: 443,
                },
              },
            ],
          },
        ],
      },
    },
    httproute_kratos_admin: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'http-route-kratos-admin',
        namespace: 'default',
      },
      spec: {
        parentRefs: [
          {
            name: 'gateway-kratos-admin',
          },
        ],
        hostnames: [
          'admin.auth.telesto.test',
        ],
        rules: [
          {
            matches: [
              {
                path: {
                  type: 'PathPrefix',
                  value: '/',
                },
              },
            ],
            backendRefs: [
              {
                name: 'auth-kratos-admin',
                port: 80,
              },
            ],
          },
        ],
      },
    },
    // hydra
    ory_hydra_pg_user_password: k.core.v1.secret.new('pg-cluster-hydra-password', {
      username: std.base64('hydra'),
      password: std.base64('password'),
    }, 'kubernetes.io/basic-auth'),
    hydra_db: {
      apiVersion: 'postgresql.cnpg.io/v1',
      kind: 'Database',
      metadata: {
        name: 'hydra',
        namespace: 'default',
      },
      spec: {
        databaseReclaimPolicy: 'delete',
        cluster: {
          name: 'auth-db-cluster',
        },
        name: 'hydra',
        owner: 'hydra',
      },
    },
    ory_hydra_secret: k.core.v1.secret.new('hydra-secrets', {
      dsn: std.base64('postgres://hydra:password@auth-db-cluster-rw:5432/hydra?sslmode=disable&max_conns=4&max_idle_conns=2'),
      secretsCookie: std.base64('aaaabbbbccccdddd'),
      secretsSystem: std.base64('aaaabbbbccccdddd'),
    }, 'Opaque'),
    hydra: helmutil.stripHelmHooks(helm.template('auth', '../../charts/hydra', {
      namespace: 'default',
      values: {
        secret: {
          enabled: true,
        },
        hydra: {
          automigration: {
            enabled: true,
            type: 'job',
            customArgs: ['migrate', 'sql', 'up', '-e', '--yes', '--config', '/etc/config/hydra.yaml'],
          },
          secrets: {
            system: 'aaaabbbbccccdddd',
            cookie: 'aaaabbbbccccdddd'
            
          },
          config: {
            ttl: {
              access_token: '1h',
            },
            dsn: 'postgres://hydra:password@auth-db-cluster-rw:5432/hydra?sslmode=disable&max_conns=4&max_idle_conns=2',
            urls: {
              'self': {
                issuer: 'https://hydra.telesto.test',
              },
              login: 'https://auth.telesto.test/self-service/login/browser',
              consent: 'https://app.telesto.test/consent',
            },
          },
        },
      },
    })),
    gateway_hydra_public: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'Gateway',
      metadata: {
        name: 'gateway-hydra-public',
        namespace: 'default',
        annotations: {
          'cert-manager.io/cluster-issuer': 'local-cluster-issuer',
        },
      },
      spec: {
        gatewayClassName: 'nginx',
        listeners: [
          {
            name: 'http',
            port: 80,
            protocol: 'HTTP',
            hostname: 'hydra.telesto.test',
          },
          {
            name: 'https',
            port: 443,
            protocol: 'HTTPS',
            hostname: 'hydra.telesto.test',
            allowedRoutes: {
              namespaces: {
                from: 'All',
              },
            },
            tls: {
              mode: 'Terminate',
              certificateRefs: [
                {
                  group: '',
                  kind: 'Secret',
                  name: 'test-telesto-hydra-tls',
                  namespace: 'default',
                },
              ],
            },
          },
        ],
      },
    },
    httproute_hydra_public_http_to_https_redirect: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'http-route-hydra-public-http-to-https-redirect',
        namespace: 'default',
      },
      spec: {
        parentRefs: [
          {
            name: 'gateway-hydra-public',
            sectionName: 'http',
          },
        ],
        hostnames: [
          'hydra.telesto.test',
        ],
        rules: [
          {
            filters: [
              {
                type: 'RequestRedirect',
                requestRedirect: {
                  scheme: 'https',
                  statusCode: 301,
                  port: 443,
                },
              },
            ],
          },
        ],
      },
    },
    httproute_hydra_public: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'http-route-hydra-public',
        namespace: 'default',
      },
      spec: {
        parentRefs: [
          {
            name: 'gateway-hydra-public',
          },
        ],
        hostnames: [
          'hydra.telesto.test',
        ],
        rules: [
          {
            matches: [
              {
                path: {
                  type: 'PathPrefix',
                  value: '/',
                },
              },
            ],
            backendRefs: [
              {
                name: 'auth-hydra-public',
                port: 4444,
              },
            ],
          },
        ],
      },
    },
    gateway_hydra_admin: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'Gateway',
      metadata: {
        name: 'gateway-hydra-admin',
        namespace: 'default',
        annotations: {
          'cert-manager.io/cluster-issuer': 'local-cluster-issuer',
        },
      },
      spec: {
        gatewayClassName: 'nginx',
        listeners: [
          {
            name: 'http',
            port: 80,
            protocol: 'HTTP',
            hostname: 'admin.hydra.telesto.test',
          },
          {
            name: 'https',
            port: 443,
            protocol: 'HTTPS',
            hostname: 'admin.hydra.telesto.test',
            allowedRoutes: {
              namespaces: {
                from: 'All',
              },
            },
            tls: {
              mode: 'Terminate',
              certificateRefs: [
                {
                  group: '',
                  kind: 'Secret',
                  name: 'test-telesto-hydra-admin-tls',
                  namespace: 'default',
                },
              ],
            },
          },
        ],
      },
    },
    httproute_hydra_admin_http_to_https_redirect: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'http-route-hydra-admin-http-to-https-redirect',
        namespace: 'default',
      },
      spec: {
        parentRefs: [
          {
            name: 'gateway-hydra-admin',
            sectionName: 'http',
          },
        ],
        hostnames: [
          'admin.hydra.telesto.test',
        ],
        rules: [
          {
            filters: [
              {
                type: 'RequestRedirect',
                requestRedirect: {
                  scheme: 'https',
                  statusCode: 301,
                  port: 443,
                },
              },
            ],
          },
        ],
      },
    },
    httproute_hydra_admin: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'http-route-hydra-admin',
        namespace: 'default',
      },
      spec: {
        parentRefs: [
          {
            name: 'gateway-hydra-admin',
          },
        ],
        hostnames: [
          'admin.hydra.telesto.test',
        ],
        rules: [
          {
            matches: [
              {
                path: {
                  type: 'PathPrefix',
                  value: '/',
                },
              },
            ],
            backendRefs: [
              {
                name: 'auth-hydra-admin',
                port: 4445,
              },
            ],
          },
        ],
      },
    },
  },
}
