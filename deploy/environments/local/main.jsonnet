// util
local nsutil = import '../../lib/util/ns.libsonnet';

local tc = import '../../lib/telesto-config/config.libsonnet';

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
      issuerRefName: $.ca._config.clusterIssuerName,
      oidcClientSecret: secrets.dex.clients.argocd.secret,
    },
  },

  // auth solution
  auth: (import '../../lib/auth/auth.libsonnet') + {
    _config+:: {
      issuerRefName: $.ca._config.clusterIssuerName,
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
      issuerRefName: $.ca._config.clusterIssuerName,
      telesto+: {
        config+: tc.server.public.cookies.withCookieEncKey(secrets.server.public.cookies.cookieEncKey)
                + tc.server.public.cookies.withCookieStoreKey(secrets.server.public.cookies.cookieStoreKey)
                + tc.server.public.cookies.withSessionEncKey(secrets.server.public.cookies.sessionEncKey)
                + tc.server.public.cookies.withSessionStoreKey(secrets.server.public.cookies.sessionStoreKey)
                + tc.server.public.csrf.withKey(secrets.server.public.csrf.key)
                + tc.server.private.telestoDeployer.withToken(secrets.server.private.telestoDeployer.token)
                + tc.server.private.externalSecrets.withToken(secrets.server.private.externalSecrets.token),
      },
    },
    _images+:: {
      telesto: 'ghcr.io/thisisibrahimd/telesto:0.0.6-next-amd64',
    },
  },

  // telesto deployer
  telestodeployer: (import '../../lib/telestodeployer/telestodeployer.libsonnet') + {
    _config+:: {

      issuerRefName: $.ca._config.clusterIssuerName,
      telestoDeployerToken: secrets.server.private.telestoDeployer.token,
    },
  },
}
