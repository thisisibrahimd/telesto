local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local argo = import '../argocd-crds/3.4.1/main.libsonnet';
local project = argo.argoproj.v1alpha1.appProject;
{
  _config:: {
    _global: {
      namespace: 'argocd',
    },
    domain: 'argocd.telesto.test',

    clusterIssuerRefName: 'cluster-issuer-central',
    gatewayClassName: 'nginx',

    oidcIssuer: 'https://dex.telesto.test',
    oidcClientID: 'argocd',
    oidcClientSecret: '',

  },

  // TODO: libsonnetify helm values
  argocd: helm.template('customer-captian', '../../charts/argo-cd', {
    namespace: $._config._global.namespace,
    values: {
      global: {
        domain: $._config.domain,
      },
      controller: {},
      applicationSet: {
        allowAnyNamespace: true,
      },
      rbac: {
        'policy.csv': |||
          p, role:org-admin, applications, *, */*, allow
          p, role:org-admin, clusters, get, *, allow
          p, role:org-admin, repositories, *, *, allow
          p, role:org-admin, logs, get, *, allow
          p, role:org-admin, exec, create, */*, allow
          g, telestoai:engineers, role:org-admin
        |||,
      },
      configs: {
        cm: {
          url: 'https://' + $._config.domain,
          // 'admin.enabled': 'false',
          'oidc.tls.insecure.skip.verify': true,
          'oidc.config': std.manifestYamlDoc({
            name: 'GitHub',
            issuer: $._config.oidcIssuer,
            clientID: $._config.oidcClientID,
            clientSecret: $._config.oidcClientSecret,
            requestedScopes: [
              'openid',
              'profile',
              'email',
              'groups',
            ],
          }, indent_array_in_object=true, quote_keys=false),
        },
        params: {
          'application.namespaces': 'telestos,telesto-*',
          'applicationsetcontroller.namespaces': 'telestos,telesto-*',
          'applicationsetcontroller.enable.scm.providers': false,
          'server.insecure': true,
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
  denyDefaultProject: project.new('default')
                      + project.metadata.withNamespace($._config._global.namespace)
                      + project.spec.withSourceRepos([])
                      + project.spec.withDestinations([])
                      + project.spec.withClusterResourceWhitelist([])
                      + project.spec.withNamespaceResourceBlacklist(
                        project.spec.namespaceResourceBlacklist.withKind('*')
                        + project.spec.namespaceResourceBlacklist.withGroup('*')
                      ),
  gateway: (import '../util/simple_gateway.libsonnet') + {
    _config+:: {
      _global: {
        namespace: $._config._global.namespace,
      },
      name: 'argocd',
      hostname: $._config.domain,
      gatewayClassName: $._config.gatewayClassName,
      issuerRef: {
        name: $._config.clusterIssuerRefName,
        kind: 'ClusterIssuer',
      },
      svc: {
        name: 'customer-captian-argocd-server',
        port: 443,
      },
    },
  },
}
