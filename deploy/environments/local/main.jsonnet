// local ocdeployer = import '../../lib/otelcoldeployer/otelcoldeployer.libsonnet';
local t = import '../../lib/telesto/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local identitySchema = importstr '../../../identity.schema.json';

{
  t: t.new('telesto-app')
     + t.withImage('quay.io/telesto/telesto:0.0.4-alpha'),
  rqlite: helm.template('db', '../../charts/rqlite', {
    namespace: 'default',
    values: {
      ingress: {
        enabled: true,
        hosts: [
          'db.telesto.test',
        ],
      },
    },
  }),
  kratos: helm.template('auth', '../../charts/kratos', {
    namespace: 'default',
    values: {
      ingress: {
        public: {
          enabled: true,
          hosts: [
            {

              host: 'auth.telesto.test',
              paths: [
                {
                  path: "/",
                  pathType: "ImplementationSpecific"
                }
              ]
            },
          ],
        },
      },
      kratos: {
        config: {
          dsn: 'memory',
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
            default_browser_return_url: 'http://app.telesto.test/',
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
  // pg_op: helm.template('pg-operator', '../../charts/cloudnative-pg', {
  //   namespace: 'default',
  //   values: {

  //   },
  // }),
  // pg_db: helm.template('pg-db', '../../charts/cluster', {
  //   namespace: 'default',
  //   values: {
  //     cluster: {
  //       instances: 1,
  //       storage: {
  //         size: '1Gi',
  //       },
  //       roles: [
  //         {
  //           name: 'kratos',
  //           ensure: 'present',
  //           comment: 'Ory Kratos',
  //           login: true,
  //           superuser: false,
  //           createdb: true,
  //           connectionLimit: 4,
  //           passwordSecret: {
  //             name: 'pg-cluster-kratos-password',
  //           },
  //         },
  //       ],
  //     },
  //   },
  // }),
  // ory_kratos_pg_user_password: k.core.v1.secret.new('pg-cluster-kratos-password', {
  //   username: std.base64('kratos'),
  //   password: std.base64('password'),
  // }, 'kubernetes.io/basic-auth'),
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
        insecure: true,
        ingress: {
          enabled: true,
          hostname: 'argocd.telesto.test',
          path: '/',
          ingressClassName: 'cloud-provider-kind',
          tls: false,
        },
      },
    },
  }),
  // otelcoldeployer: ocdeployer.otelcoldeployer.new(),
}
