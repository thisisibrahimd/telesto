local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local argo = import '../argocd-crds/3.4.1/main.libsonnet';
local project = argo.argoproj.v1alpha1.appProject;

local sgw = import '../util/simple_gateway.libsonnet';

local certs = import '../util/certs.libsonnet';
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

  cert: certs.server.new(
    name='argocd',
    namespace=$._config._global.namespace,
    commonName=$._config.domain,
    issuerName=$._config.clusterIssuerRefName
  ),
  // TODO: libsonnetify helm values
  argocd: helm.template('customer-captain', '../../charts/argo-cd', {
    namespace: $._config._global.namespace,
    values: {
      global: {
        networkPolicy: {
          create: false,
        },
        domain: $._config.domain,
      },
      applicationSet: {
        allowAnyNamespace: true,
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
  gateway: sgw.new(
    name="argocd",
    namespace=$._config._global.namespace,
    hostname=$._config.domain,
    gatewayClassName='nginx',
    issuerName='cluster-issuer-central',
    serviceName='customer-captain-argocd-server',
    servicePort=443
  ),
}
