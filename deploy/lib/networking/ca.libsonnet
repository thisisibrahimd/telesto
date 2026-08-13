local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local certificate = cm.nogroup.v1.certificate;
local clusterIssuer = cm.nogroup.v1.clusterIssuer;

{
  _config:: {
    _global: {
      namespace: 'cert-manager',
    },
    secretRootCAName: 'cert-root-ca-telesto',
    clusterIssuerName: 'cluster-issuer-central',
  },
  clusterIssuerRootCA: clusterIssuer.new('cluster-issuer-self-signed-telesto-root-ca') + {
    spec+: {
      selfSigned+: {},
    },
  },
  telestoRootCa: certificate.new('telesto-root-ca')
                 + certificate.metadata.withNamespace($._config._global.namespace)
                 + certificate.spec.withIsCA(true)

                 + certificate.spec.withSecretName($._config.secretRootCAName)

                 + certificate.spec.privateKey.withAlgorithm('RSA')
                 + certificate.spec.privateKey.withSize(4096)
                 + certificate.spec.withUsages([
                   'crl sign',
                   'cert sign',
                 ])

                 + certificate.spec.subject.withCountries('US')
                 + certificate.spec.subject.withOrganizations('Telesto LLC')
                 + certificate.spec.subject.withOrganizationalUnits('Telesto Certificate Authority')
                 + certificate.spec.withCommonName('Telesto Root CA')

                 + certificate.spec.issuerRef.withName('cluster-issuer-self-signed-telesto-root-ca')
                 + certificate.spec.issuerRef.withKind('ClusterIssuer')
                 + certificate.spec.issuerRef.withGroup('cert-manager.io'),
  certManager: helm.template('certs', '../../charts/cert-manager', {
    namespace: $._config._global.namespace,
    values: {
      config: {
        apiVersion: 'controller.config.cert-manager.io/v1alpha1',
        kind: 'ControllerConfiguration',
        enableGatewayAPI: true,
      },
      enableCertificateOwnerRef: false,
      crds: {
        enabled: true,
      },
    },
  }),
  clusterIssuer: clusterIssuer.new($._config.clusterIssuerName)
                 + clusterIssuer.spec.ca.withSecretName($._config.secretRootCAName),
}
