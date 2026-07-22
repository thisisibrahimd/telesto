local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local ocdeployer = import '../../lib/otelcoldeployer/otelcoldeployer.libsonnet';
local t = import '../../lib/telesto/main.libsonnet';
local k = import 'ksonnet-util/kausal.libsonnet';

local ca = import '../../lib/networking/ca.libsonnet';
// local openobserve = import '../../lib/openobserve/openobserve.libsonnet';
local auth = import '../../lib/auth/auth.libsonnet';
local gateway = import '../../lib/networking/gateway.libsonnet';
local secret_json = std.extVar('secret_json');
local secret = std.parseJson(secret_json);

local wrap(name) = { [name]+: name };
local ns(name) = k.core.v1.namespace.new(name);

local namespaces = {
  crossplane_system: 'crossplane-system',
  storage: 'storage',
};

{
  // telesto certificate management infra
  // install ca cert from local machine into cluster and create cluster issuer
  telesto_ca_infra: ca.new(secret.certs.crtB64, secret.certs.keyB64),

  // gateway networking
  gateway: gateway.new(),

  ns_crossplane_system: ns(namespaces.crossplane_system),
  crossplane: helm.template('crossplane', '../../charts/crossplane', {
    namespace: namespaces.crossplane_system,
    values: {},
  }),
  crossplane_provider_aws_s3: {
    apiVersion: 'pkg.crossplane.io/v1',
    kind: 'Provider',
    metadata: {
      name: 'crossplane-contrib-provider-aws-s3',
      namespace: namespaces.crossplane_system,
    },
    spec: {
      package: 'xpkg.crossplane.io/crossplane-contrib/provider-aws-s3:v2.0.0',
    },
  },
  crossplane_provider_http: {
    apiVersion: 'pkg.crossplane.io/v1',
    kind: 'Provider',
    metadata: {
      name: 'crossplane-contrib-provider-http',
      namespace: namespaces.crossplane_system,
    },
    spec: {
      package: 'xpkg.crossplane.io/crossplane-contrib/provider-http:v1.0.14',
    },
  },
  crossplane_provider_http_config: {
    apiVersion: 'http.m.crossplane.io/v1alpha2',
    kind: 'ClusterProviderConfig',
    metadata: {
      name: 'cluster-provider-http-insecure-config',
      namespace: namespaces.crossplane_system,
    },
    spec: {
      credentials: {
        source: 'None',
      },
      tls: {
        insecureSkipVerify: true,
      },
    },
  },
  crossplane_function_yaml: {
    apiVersion: 'pkg.crossplane.io/v1',
    kind: 'Function',
    metadata: {
      name: 'crossplane-contrib-function-patch-and-transform',
      namespace: namespaces.crossplane_system,
    },
    spec: {
      package: 'xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.8.2',
    },
  },
  crossplane_kratos_user_crd: {
    apiVersion: 'apiextensions.crossplane.io/v2',
    kind: 'CompositeResourceDefinition',
    metadata: {
      name: 'kratosusers.auth.telesto.crossplane.io',
      namespace: namespaces.crossplane_system,
    },
    spec: {
      scope: 'Namespaced',
      group: 'auth.telesto.crossplane.io',
      names: {
        kind: 'KratosUser',
        plural: 'kratosusers',
      },
      versions: [
        {
          name: 'v1',
          served: true,
          referenceable: true,
          schema: {
            openAPIV3Schema: {
              type: 'object',
              properties: {
                spec: {
                  type: 'object',
                  properties: {
                    username: {
                      description: 'Kratos Username',
                      type: 'string',
                    },
                    passwordSecretRef: {
                      description: 'Kratos Password Secret Reference',
                      type: 'string',
                    },
                    passwordSecretNamespace: {
                      description: 'Kratos Password Secret Namespace',
                      type: 'string',
                    },
                  },
                },
                status: {
                  type: 'object',
                  properties: {
                    created: {
                      type: 'boolean',
                      default: false,
                      description: 'the user has been created',
                    },
                  },
                },
              },
            },
          },
        },
      ],
    },
  },
  crossplane_kratos_user_composition: {
    apiVersion: 'apiextensions.crossplane.io/v1',
    kind: 'Composition',
    metadata: {
      name: 'kratos-user-yaml',
      namespace: namespaces.crossplane_system,
    },
    spec: {
      compositeTypeRef: {
        apiVersion: 'auth.telesto.crossplane.io/v1',
        kind: 'KratosUser',
      },
      mode: 'Pipeline',
      pipeline: [
        {
          step: 'create-deployment-and-service',
          functionRef: {
            name: 'crossplane-contrib-function-patch-and-transform',
          },
          input: {
            apiVersion: 'pt.fn.crossplane.io/v1beta1',
            kind: 'Resources',
            resources: [
              {
                name: 'request-kratos-user',
                base: {
                  apiVersion: 'http.m.crossplane.io/v1alpha2',
                  kind: 'Request',
                  metadata: {
                    name: 'kratos-user-',
                  },
                  spec: {
                    forProvider: {
                      expectedResponseCheck: {
                        logic: 'if .response.body.traits.username == .payload.body.username then true else false end',
                        type: 'CUSTOM',
                      },
                      headers: {
                        'Content-Type': [
                          'application/json',
                        ],
                      },
                      insecureSkipTLSVerify: true,
                      isRemovedCheck: {
                        logic: 'if .response.statusCode == 404 and .response.body.status == "Not Found" then true else false end',
                        type: 'CUSTOM',
                      },
                      mappings: [
                        {
                          action: 'CREATE',
                          body: '{"credentials": {"password": {"config": {"password": .payload.body.password }}}, "schema_id": "default", "traits": {"username":.payload.body.username}}',
                          headers: {
                            'Content-Type': [
                              'application/json',
                            ],
                          },
                          url: '.payload.baseUrl',
                        },
                        {
                          action: 'OBSERVE',
                          url: '.payload.baseUrl + "/" + (.response.body.id | tostring)',
                        },
                        {
                          body: '{password: .payload.body.password}',
                          method: 'PUT',
                          headers: {
                            'Content-Type': [
                              'application/json',
                            ],
                          },
                          url: '.payload.baseUrl + "/" + (.response.body.id | tostring)',
                        },
                        {
                          action: 'REMOVE',
                          url: '.payload.baseUrl + "/" + (.response.body.id | tostring)',
                        },
                      ],
                      payload: {
                        baseUrl: 'http://auth-kratos-admin.default.svc.cluster.local/admin/identities',
                        body: '{ username: "", password: "" }',
                      },
                      waitTimeout: '5m',
                    },
                    providerConfigRef: {
                      kind: 'ClusterProviderConfig',
                      name: 'cluster-provider-http-insecure-config',
                    },
                  },
                },
                patches: [
                  {
                    type: 'FromCompositeFieldPath',
                    fromFieldPath: 'metadata.name',
                    toFieldPath: 'metadata.name',
                    transforms: [
                      {
                        type: 'string',
                        string: {
                          type: 'Format',
                          fmt: 'request-kratos-user-%s',
                        },
                      },
                    ],
                  },
                  {
                    type: 'CombineFromComposite',
                    combine: {
                      variables: [
                        {
                          fromFieldPath: 'spec.username',
                        },
                        {
                          fromFieldPath: 'spec.passwordSecretRef',
                        },
                        {
                          fromFieldPath: 'spec.passwordSecretNamespace',
                        },
                      ],
                      strategy: 'string',
                      string: {
                        fmt: '{"username": "%s", "password": "{{ %s:%s:password }}"}',
                      },
                    },
                    toFieldPath: 'spec.forProvider.payload.body',
                  },
                ],
                readinessChecks: [
                  {
                    type: 'None',
                    fieldPath: 'status.error',
                  },
                ],
              },
            ],
          },
        },
      ],
    },
  },
  // kratos_hema_password: k.core.v1.secret.new(secret.kratos.initialUsers[0].username + '-password', {
  //   password: std.base64(secret.kratos.initialUsers[0].password),
  // }, 'Opaque'),
  // kratos_user_hema: {
  //   apiVersion: 'auth.telesto.crossplane.io/v1',
  //   kind: 'KratosUser',
  //   metadata: {
  //     name: secret.kratos.initialUsers[0].username,
  //     namespace: 'default',
  //   },
  //   spec: {
  //     username: secret.kratos.initialUsers[0].username,
  //     passwordSecretRef: secret.kratos.initialUsers[0].username + '-password',
  //     passwordSecretNamespace: 'default',
  //   },
  // },

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
          enabled: false,
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
            },
          ],
          parentRefs: [
            {
              name: 'gateway-argocd',
              namespace: 'default',
              sectionName: 'https',
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
  httproute_argocd_http_to_https_redirect: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    metadata: {
      name: 'http-route-argocd-http-to-https-redirect',
    },
    spec: {
      parentRefs: [
        {
          name: 'gateway-argocd',
          sectionName: 'http',
        },
      ],
      hostnames: [
        'argocd.telesto.test',
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
  httproute_argocd: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    metadata: {
      name: 'http-route-argocd',
    },
    spec: {
      parentRefs: [
        {
          name: 'gateway-argocd',
          sectionName: 'https',
        },
      ],
      hostnames: [
        'argocd.telesto.test',
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
              name: 'customer-captian-argocd-server',
              port: 80,
            },
          ],
        },
      ],
    },
  },

  // AUTH SOLUTION
  auth: auth.new(),

  // TELESTO APP
  t: t.new('telesto-app')
     + t.withImage('quay.io/telesto/telesto:0.0.5-alpha-amd64'),
  rqlite: helm.template('db', '../../charts/rqlite', {
    namespace: 'default',
    values: {},
  }),

  // OTELCOL DEPLOYER
  otelcoldeployer: ocdeployer.otelcoldeployer.new(),

  // MONITORING
  // object storage
  ns_storge: ns(namespaces.storage),
  ob_storage: helm.template('ob-storage', '../../charts/rustfs', {
    namespace: namespaces.storage,
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
      namespace: namespaces.storage,
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
  httproute_rustfs_http_to_https_redirect: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    metadata: {
      name: 'http-route-rustfs-console-http-to-https-redirect',
      namespace: namespaces.storage,
    },
    spec: {
      parentRefs: [
        {
          name: 'gateway-rustfs-console',
          sectionName: 'http',
        },
      ],
      hostnames: [
        'console.rustfs.telesto.test',
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
  httproute_rustfs: {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    metadata: {
      name: 'http-route-rustfs-console',
      namespace: namespaces.storage,
    },
    spec: {
      parentRefs: [
        {
          name: 'gateway-rustfs-console',
          sectionName: 'https',
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


  ns_monitoring: k.core.v1.namespace.new('monitoring'),
  // optelemetry_collector_operator: helm.template('ocop', '../../charts/opentelemetry-operator', {
  //   namespace: 'monitoring',
  //   values: {
  //     manager: {
  //       collectorImage: {
  //         repository: 'ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s',
  //         tag: '0.153.0'
  //       }
  //     }
  //   },
  // }),
  // openobserve
  // openobserve: openobserve.new(),
}
