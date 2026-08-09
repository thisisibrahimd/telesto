local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local kustomize = tanka.kustomize.new(std.thisFile);
local k = import "github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet";

local netutil = import '../../lib/util/net.libsonnet';


{
  _config:: {
    _global: {
      namespace: 'argocd',
    },
    domain: 'argocd.telesto.test',
  },

  argocd: helm.template('customer-captian', '../../charts/argo-cd', {
    namespace: $._config._global.namespace,
    values: {
      global: {
        domain: $._config.domain,
      },
      configs: {
        cm: {
          url: 'https://' + $._config.domain,
          'admin.enabled': 'false',
          'oidc.tls.insecure.skip.verify': true,
          'oidc.config': std.manifestYamlDoc({
            name: 'GitHub',
            issuer: 'https://dex.telesto.test',
            clientID: 'argocd',
            clientSecret: 'my-secret-here',
            requestedScopes: [
              'openid',
              'profile',
              'email',
              'groups',
            ],
          }, indent_array_in_object=true, quote_keys=false),
        },
        params: {
          'server.insecure': true,
        },
        secret: {
          extra: {
            'otelcoldeployer.otelcoldeployer_plugin.token': 'GVsbG8=',
          },
        },
      },
      dex: {
        enabled: false,
      },
      server: {
        httproute: {
          enabled: false,
        },
      },
    },
  }),
  gateway: (import '../util/simple_gateway.libsonnet') + {
    _config+:: {
      _global: {
        namespace: $._config._global.namespace,
      },
      name: 'argocd',
      hostname: $._config.domain,
      gatewayClassName: 'nginx',
      issuerRef: {
        name: 'cluster-issuer-central',
        kind: 'ClusterIssuer',
      },
      svc: {
        name: 'customer-captian-argocd-server',
        port: 80,
      },
    },
  },
}
