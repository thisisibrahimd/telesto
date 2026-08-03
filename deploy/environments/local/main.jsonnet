// libraries
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local k = import 'ksonnet-util/kausal.libsonnet';

// util
local netutil = import '../../lib/util/net.libsonnet';
local nsutil = import '../../lib/util/ns.libsonnet';

// namespace management
local _namespaces = [
  'argocd',
  'telesto',
  'storage',
  'monitoring',
  'auth',
  'nginx-gateway',
  'cert-manager',
  'cnpg-system',
];
// local namespaces = { ['ns_' + std.strReplace(n, '-', '_')]: n for n in _namespaces };
local namespaces = { ['ns_' + std.strReplace(n, '-', '_')]: { name: n, namespace: nsutil.ns(n) } for n in _namespaces };

// secrets
local secret_json = std.extVar('secret_json');
local secret = std.parseJson(secret_json);

{
  // create namespaces
  namespaces: { [std.format('ns_%s', n)]: nsutil.ns(n) for n in _namespaces },


  // components

  // cert management
  ca: (import '../../lib/networking/ca.libsonnet') + {
    _config+:: {
      certificateBase64Encoded: secret.certs.crtB64,
      keyBase64Encoded: secret.certs.keyB64,
    },
  },

  // gateway management
  gateway: (import '../../lib/networking/gateway.libsonnet') + {
    _config+:: {
      clusterIssuerRefName: $.ca._config.clusterIssuerName,
    },
  },

  // database management
  cnpg_system: (import '../../lib/storage/cnpg_system.libsonnet') + {},

  // argocd installation
  argocd: (import '../../lib/argocd/argocd.libsonnet') + {},

  // auth solution
  auth: (import '../../lib/auth/auth.libsonnet') + {},

  // TELESTO APP
  telesto: (import '../../lib/telesto/main.libsonnet') + {
    _config+:: {
      clusterIssuerRefName: $.ca._config.clusterIssuerName,
    },
    _images+:: {
      telesto: 'ghcr.io/thisisibrahimd/telesto:0.0.3-next-amd64',
    },
  },

  // OTELCOL DEPLOYER
  // otelcoldeployer: ocdeployer.otelcoldeployer.new(),
}
