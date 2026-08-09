local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local kustomize = tanka.kustomize.new(std.thisFile);
local k = import "github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet";

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local cmv1 = cm.nogroup.v1;
{
  _config:: {
    _global: {
      namespace: 'nginx-gateway',
    },

    certManagerNamespace: 'cert-manager',

    issuerName: 'issuer-nginx-gateway',

    caCertificateName: 'cert-nginx-gateway',
    serverCertificateName: 'nginx-gateway',
    agentCertificateName: 'nginx',

    clusterIssuerRefName: '',

  },
  // crds for gateway k8s api
  k8s_gateway_api_crds: kustomize.build('gatewaycrds/localized-gatewaycrds'),
  // ca cert for nginx gateway
  ca_cert_nginx_gateway: cm.nogroup.v1.certificate.new('nginx-gateway-ca')
                         + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                         + cm.nogroup.v1.certificate.spec.withIsCA(true)
                         + cm.nogroup.v1.certificate.spec.withCommonName('nginx-gateway')
                         + cm.nogroup.v1.certificate.spec.withSecretName('nginx-gateway-ca')
                         + cm.nogroup.v1.certificate.spec.privateKey.withAlgorithm('RSA')
                         + cm.nogroup.v1.certificate.spec.privateKey.withSize(2048)
                         + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                         + cm.nogroup.v1.certificate.spec.issuerRef.withKind('ClusterIssuer')
                         + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  // certmanager cert issuer for nginx gateway
  issuer_nginx_gateway: cm.nogroup.v1.issuer.new($._config.issuerName)
                        + cm.nogroup.v1.issuer.metadata.withNamespace($._config._global.namespace)
                        + cm.nogroup.v1.issuer.spec.ca.withSecretName('nginx-gateway-ca'),
  // server and client certifcates for nginx gateway
  cert_nginx_server: cm.nogroup.v1.certificate.new($._config.serverCertificateName)
                     + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                     + cm.nogroup.v1.certificate.spec.withSecretName('tls-server')
                     + cm.nogroup.v1.certificate.spec.withUsages([
                       'digital signature',
                       'key encipherment',
                     ])
                     + cm.nogroup.v1.certificate.spec.withDnsNames('ngf-nginx-gateway-fabric.nginx-gateway.svc')
                     + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.issuerName)
                     + cm.nogroup.v1.certificate.spec.issuerRef.withKind('Issuer')
                     + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  cert_nginx_agent: cm.nogroup.v1.certificate.new($._config.agentCertificateName)
                    + cm.nogroup.v1.certificate.metadata.withNamespace($._config._global.namespace)
                    + cm.nogroup.v1.certificate.spec.withSecretName('tls-agent')
                    + cm.nogroup.v1.certificate.spec.withUsages([
                      'digital signature',
                      'key encipherment',
                    ])
                    + cm.nogroup.v1.certificate.spec.withDnsNames('*.cluster.local')
                    + cm.nogroup.v1.certificate.spec.issuerRef.withName($._config.issuerName)
                    + cm.nogroup.v1.certificate.spec.issuerRef.withKind('Issuer')
                    + cm.nogroup.v1.certificate.spec.issuerRef.withGroup('cert-manager.io'),
  helm_ngf: helm.template('ngf', '../../charts/nginx-gateway-fabric', {
    namespace: $._config._global.namespace,
    values: {
      nginx: {
        service: {
          type: 'LoadBalancer',
        },
      },
    },
  }),
}
