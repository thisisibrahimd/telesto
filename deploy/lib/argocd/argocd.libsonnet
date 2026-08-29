local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local tm = import '../trust-manager-crds/0.24.0/main.libsonnet';
local bundle = tm.trust.v1alpha1.bundle;

local argo = import '../argocd-crds/3.4.1/main.libsonnet';
local project = argo.argoproj.v1alpha1.appProject;

local secureGateway = import '../util/secure_gateway.libsonnet';

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local certificate = cm.nogroup.v1.certificate;

local certs = import '../util/certs.libsonnet';

{
  _config:: {
    _global: {
      namespace: 'argocd',
    },
    domain: 'argocd.telesto.test',

    rootCASecretName: 'cert-root-ca-telesto',

    issuerRefName: '',
    issuerRefKind: 'ClusterIssuer',
    gatewayClassName: 'nginx',

    telestoNamespaces: ['telestos', 'telesto-*'],

    oidcIssuer: 'https://dex.telesto.test',
    oidcClientID: 'argocd',
    oidcClientSecret: '',
  },

  policy:: |||
    g, telestoai:engineers, role:admin
  |||,

  certArgoCDServer: certs.server.new(
                      name='argocd-server',
                      namespace=$._config._global.namespace,
                      commonName=$._config.domain,
                      issuerRefName=$._config.issuerRefName
                    )
                    + certificate.spec.withSecretName('argocd-server-tls'),
  certArgoCDRepoServer: certs.server.new(
                          name='argocd-repo-server',
                          namespace=$._config._global.namespace,
                          commonName=$._config.domain,
                          issuerRefName=$._config.issuerRefName
                        )
                        + certificate.spec.withSecretName('argocd-repo-server-tls'),

  // TODO: libsonnetify helm values
  argocd: helm.template('customer-captain', '../../charts/argo-cd', {
    namespace: $._config._global.namespace,
    values: {
      global: {
        networkPolicy: {
          create: false,
        },
        domain: $._config.domain,
        env: [
          {
            name: 'SSL_CERT_DIR',
            value: '/etc/ssl/certs',
          },
        ],
        extraVolumes: [
          {
            name: 'telesto-root-ca',
            configMap: {
              name: 'bundle-telesto',
            },
          },
        ],
        extraVolumeMounts: [
          {
            name: 'telesto-root-ca',
            mountPath: '/etc/ssl/certs',
            readOnly: true,
          },
        ],
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
          'application.namespaces': std.join(',', $._config.telestoNamespaces),
          'applicationsetcontroller.namespaces': std.join(',', $._config.telestoNamespaces),
          'applicationsetcontroller.enable.scm.providers': false,
        },
        rbac: {
          'policy.default': 'role:readonly',
          'policy.csv': $.policy,
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
  gatewayArgoCDServer: secureGateway.new(
    name='argocd-server',
    namespace=$._config._global.namespace,
    hostname=$._config.domain,
    gatewayClassName='nginx',
    issuerRefName=$._config.issuerRefName,
    serviceName='customer-captain-argocd-server',
    caCertConfigMapName='bundle-telesto'
  ),
}
