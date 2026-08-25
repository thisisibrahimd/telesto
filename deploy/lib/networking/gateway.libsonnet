local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local kustomize = tanka.kustomize.new(std.thisFile);

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local certificate = cm.nogroup.v1.certificate;
local issuer = cm.nogroup.v1.issuer;

local certs = import '../util/certs.libsonnet';

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

    issuerRefName: '',
    issuerRefKind: '',
    clusterIssuerRefName: 'cluster-issuer-central',
  },
  clusterIssuerRef:: certificate.spec.issuerRef.withName($._config.clusterIssuerRefName)
                     + certificate.spec.issuerRef.withKind('ClusterIssuer')
                     + certificate.spec.issuerRef.withGroup('cert-manager.io'),
  // crds for gateway k8s api
  k8sGatewayApiCRDS: kustomize.build('gatewaycrds/localized-gatewaycrds'),
  // ca cert for nginx gateway
  caCertNginxGateway: certificate.new('nginx-gateway-ca')
                      + certificate.metadata.withNamespace($._config._global.namespace)
                      + certificate.spec.withIsCA(true)
                      + certificate.spec.withCommonName('nginx-gateway')
                      + certificate.spec.withSecretName('nginx-gateway-ca')
                      + certificate.spec.privateKey.withAlgorithm('RSA')
                      + certificate.spec.privateKey.withSize(4096)
                      + self.clusterIssuerRef,
  // certmanager cert issuer for nginx gateway
  issuerNginxGateway: issuer.new($._config.issuerName)
                      + issuer.metadata.withNamespace($._config._global.namespace)
                      + issuer.spec.ca.withSecretName('nginx-gateway-ca'),
  issuerNginxGatewayRef:: certificate.spec.issuerRef.withName($._config.issuerName)
                          + certificate.spec.issuerRef.withKind('Issuer')
                          + certificate.spec.issuerRef.withGroup('cert-manager.io'),
  // server and client certifcates for nginx gateway
  certNginxServer: certificate.new($._config.serverCertificateName)
                   + certificate.metadata.withNamespace($._config._global.namespace)
                   + certificate.spec.withSecretName('tls-server')
                   + certificate.spec.withUsages([
                     'digital signature',
                     'key encipherment',
                   ])
                   + certificate.spec.withDnsNames('ngf-nginx-gateway-fabric.nginx-gateway.svc') # unique
                   + self.issuerNginxGatewayRef,
  certNginxAgent: certificate.new($._config.agentCertificateName)
                  + certificate.metadata.withNamespace($._config._global.namespace)
                  + certificate.spec.withSecretName('tls-agent')
                  + certificate.spec.withUsages([
                    'digital signature',
                    'key encipherment',
                  ])
                  + certificate.spec.withDnsNames('*.cluster.local') # unique
                  + self.issuerNginxGatewayRef,
  // TODO: libsonnetify helm values
  ngf: helm.template('ngf', '../../charts/nginx-gateway-fabric', {
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
