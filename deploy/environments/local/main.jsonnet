// util
local nsutil = import '../../lib/util/ns.libsonnet';

// namespace management
local _namespaces = [
  'argocd',
  'app',
  'storage',
  'monitoring',
  'auth',
  'nginx-gateway',
  'cert-manager',
  'trust-manager',
  'cnpg-system',
  'telestos',
  'external-secrets',
  'reloader',
];

// secrets
local secretsJson = std.extVar('secretsJson');
local secrets = std.parseJson(secretsJson);

{
  // create namespaces
  namespaces: { [std.format('ns_%s', n)]: nsutil.ns(n) for n in _namespaces },

  // components
  // cert management
  ca: (import '../../lib/networking/ca.libsonnet'),

  // trust-manager
  tm: (import '../../lib/networking/tm.libsonnet'),

  // gateway management
  gateway: (import '../../lib/networking/gateway.libsonnet'),

  // reloader
  reloader: (import '../../lib/reloader/reloader.libsonnet'),

  // database management
  cnpgSystem: (import '../../lib/storage/cnpg_system.libsonnet'),

  // external-secrets
  externalSecrets: (import '../../lib/external-secrets/externalsecrets.libsonnet'),

  // argocd installation
  argocd: (import '../../lib/argocd/argocd.libsonnet') + {
    _config+:: {
      oidcClientSecret: secrets.dex.clients.argocd.secret
      
    }
  },

  // auth solution
  auth: (import '../../lib/auth/auth.libsonnet') + {
    _config+:: {
      argocdClientSecret: secrets.dex.clients.argocd.secret,
      githubClientID: secrets.dex.connectors.github.clientID,
      githubClientSecret: secrets.dex.connectors.github.clientSecret,
    },
  },

  // telesto app
  telesto: (import '../../lib/telesto/main.libsonnet') + {
    _config+:: {
      _global: {
        namespace: 'app',
      },
      clusterIssuerRefName: $.ca._config.clusterIssuerName,
      telestoDeployerToken: secrets.server.telestoDeployerToken,
      externalSecretsToken: secrets.server.externalSecretsToken,
    },
    _images+:: {
      telesto: 'ghcr.io/thisisibrahimd/telesto:0.0.5-next-amd64',
    },
  },

  // telesto deployer
  telestodeployer: (import '../../lib/telestodeployer/telestodeployer.libsonnet') + {
    _config+:: {
      clusterIssuerRefName: $.ca._config.clusterIssuerName,

      telestoDeployerToken: secrets.server.telestoDeployerToken
    },
  },
}
