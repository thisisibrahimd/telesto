local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local ocdeployer = import '../../lib/otelcoldeployer/otelcoldeployer.libsonnet';
local t = import '../../lib/telesto/main.libsonnet';
local identitySchema = importstr '../../../identity.schema.json';
local k = import 'k.libsonnet';

local ca = import '../../lib/networking/ca.jsonnet';
local gateway = import '../../lib/networking/gateway.jsonnet';
{
  // telesto certificate management infra
  // install ca cert from local machine into cluster and create cluster issuer
  telesto_ca_infra: ca.new(),


  // gateway networking
  gateway: gateway.new(),


  // telesto db infra
  telesto_db_operator: helm.template('telesto-db-operator', '../../charts/cloudnative-pg', {
    namespace: 'default',
    values: {},
  }),
  telesto_db_cluster: helm.template('telesto-db', '../../charts/cluster', {
    namespace: 'default',
    values: {
      cluster: {
        instances: 1,
        storage: {
          size: '5Gi',
        },
        roles: [
        ],
      },
    },
  }),


  // argocd installation
  argocd: helm.template('customer-captian', '../../charts/argo-cd', {
    namespace: 'default',
    values: {
      global: {
        domain: 'argocd.telesto.test',
      },
      configs: {
        params: {
          'server.insecure': true,
        },
        secret: {
          extra: {
            'otelcoldeployer.otelcoldeployer_plugin.token': 'GVsbG8=',
          },
        },
      },
      server: {
        httproute: {
          enabled: true,
          hostnames: [
            'argocd.telesto.test',
          ],
          rules: [
            {
              match: [
                {
                  path: {
                    type: 'PathPrefix',
                    value: '/',
                  },
                },
              ],
              filter: [
                {
                  type: 'RequestRedirect',
                  requestRedirect: {
                    scheme: 'https',
                    port: 443,
                  },
                },
              ],
            },
          ],
          parentRefs: [
            {
              name: 'gateway-argocd',
              namespace: 'default',
            },
          ],
        },
      },
    },
  }),
  gateway_argo: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'Gateway',
    metadata: {
      name: 'gateway-argocd',
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
          hostname: 'argocd.telesto.test',
        },
        {
          name: 'https',
          port: 443,
          protocol: 'HTTPS',
          hostname: 'argocd.telesto.test',
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
                name: 'test-telesto-argocd-tls',
                namespace: 'default',
              },
            ],
          },
        },
      ],
    },
  },


  // AUTH SOLUTION
  kratos_db_cluster: helm.template('kratos-db', '../../charts/cluster', {
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
            createdb: true,
            connectionLimit: 4,
            passwordSecret: {
              name: 'pg-cluster-kratos-password',
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
    },
    spec: {
      cluster: {
        name: 'kratos-db-cluster',
      },
      name: 'kratos',
      owner: 'kratos',
    },
  },
  kratos: helm.template('auth', '../../charts/kratos', {
    namespace: 'default',
    values: {
      ingress: {
        public: {
          enabled: false,
          className: 'nginx',
          annotations: {
            'cert-manager.io/cluster-issuer': 'local-cluster-issuer',
          },
          tls: [
            {
              secretName: 'kratos-server-tls',
              hosts: [
                'auth.telesto.test',
              ],
            },
          ],
          hosts: [
            {
              host: 'auth.telesto.test',
              paths: [
                {
                  path: '/',
                  pathType: 'ImplementationSpecific',
                },
              ],
            },
          ],
        },
      },
      deployment: {
        extraEnv: [
          {
            name: 'LOG_LEAK_SENSITIVE_VALUES',
            value: 'false',
          },
        ],
      },
      kratos: {
        config: {
          dsn: 'postgres://kratos:password@kratos-db-cluster-rw:5432/kratos?sslmode=disable&max_conns=20&max_idle_conns=4',
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
        automigration: {
          enabled: true,
        },
        identitySchemas: {
          'identity.default.schema.json': std.toString(std.parseYaml(identitySchema)),
        },
      },
    },
  }),
  gateway_kratos_public: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'Gateway',
    metadata: {
      name: 'gateway-kratos-public',
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
  httproute_kratos_public: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    metadata: {
      name: 'http-route-kratos',
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
  kratos_initial_user_jobs: {

  },


  // TELESTO APP
  t: t.new('telesto-app')
     + t.withImage('quay.io/telesto/telesto:0.0.5-alpha-amd64'),
  rqlite: helm.template('db', '../../charts/rqlite', {
    namespace: 'default',
    values: {},
  }),


  otelcoldeployer: ocdeployer.otelcoldeployer.new(),

  // monitoring
  // object storage
  ob_storage: helm.template('ob-storage', '../../charts/rustfs', {
    namespace: 'default',
    values: {
      mode: {
        distributed: {
          enabled: false,
        },
        standalone: {
          enabled: true,
        },
      },
      secret: {
        rustfs: {
          access_key: 'rustfsadmin',
          secret_key: 'rustfsadmin',
        },
      },
      storageclass: {
        name: 'standard',
      },
      ingress: {
        enabled: false,
      },
      gatewayApi: {
        enabled: false,
        gatewayClass: 'nginx',
        hostname: 'rustfs.telesto.test',
      },
    },
  }),
  gateway_rustfs_console: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'Gateway',
    metadata: {
      name: 'gateway-rustfs-console',
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
          hostname: 'console.rustfs.telesto.test',
        },
        {
          name: 'https',
          port: 443,
          protocol: 'HTTPS',
          hostname: 'console.rustfs.telesto.test',
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
                name: 'test-telesto-rustfs-console-tls',
                namespace: 'default',
              },
            ],
          },
        },
      ],
    },
  },
  httproute_rustfs: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    metadata: {
      name: 'http-route-rustfs-console',
    },
    spec: {
      parentRefs: [
        {
          name: 'gateway-rustfs-console',
        },
      ],
      hostnames: [
        'console.rustfs.telesto.test',
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
              name: 'ob-storage-rustfs-svc',
              port: 9001,
            },
          ],
        },
      ],
    },
  },

  // openobserve
  openobserve: helm.template('telesto-openobserve', '../../charts/openobserve-standalone', {
    namespace: 'default',
    values: {
      auth: {
        // OpenObserve root user email
        ZO_ROOT_USER_EMAIL: 'admin@telesto.test',
        // OpenObserve root user password
        ZO_ROOT_USER_PASSWORD: 'Password1!',

        ZO_S3_ACCESS_KEY: '2FfVfGTRffdhGOUm4hDb',
        ZO_S3_SECRET_KEY: 'svUvwpRgMr8LmWxELQgho36ym8I0IKD2hymU7O8p',
      },
      config: {},
      persistence: {
        storageClass: 'standard',
      },
    },
  }),
  gateway_openobserve: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'Gateway',
    metadata: {
      name: 'gateway-openobserve-console',
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
          hostname: 'console.openobserve.telesto.test',
        },
        {
          name: 'https',
          port: 443,
          protocol: 'HTTPS',
          hostname: 'console.openobserve.telesto.test',
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
                name: 'test-telesto-openobserve-console-tls',
                namespace: 'default',
              },
            ],
          },
        },
      ],
    },
  },
  httproute_openobserve: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    metadata: {
      name: 'http-route-openobserve-console',
    },
    spec: {
      parentRefs: [
        {
          name: 'gateway-openobserve-console',
        },
      ],
      hostnames: [
        'console.openobserve.telesto.test',
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
              name: 'telesto-openobserve-openobserve-standalone',
              port: 5080,
            },
          ],
        },
      ],
    },
  },
}
