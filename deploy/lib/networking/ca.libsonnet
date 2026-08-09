local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local k = import "github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet";
local helm = tanka.helm.new(std.thisFile);

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';

{
  _config:: {
    _global: {
      namespace: 'cert-manager',
    },
    caCertificateSecretName: 'ca-cert-central',
    certificateBase64Encoded: '',
    keyBase64Encoded: '',

    clusterIssuerName: 'cluster-issuer-central',
  },
  ca_cert: k.core.v1.secret.new($._config.caCertificateSecretName, {
             'tls.crt': $._config.certificateBase64Encoded,
             'tls.key': $._config.keyBase64Encoded,
           }, 'kubernetes.io/tls')
           + k.core.v1.secret.metadata.withNamespace($._config._global.namespace),
  cert_manager: helm.template('certs', '../../charts/cert-manager', {
    namespace: $._config._global.namespace,
    values: {
      config: {
        apiVersion: 'controller.config.cert-manager.io/v1alpha1',
        kind: 'ControllerConfiguration',
        enableGatewayAPI: true,
      },
      crds: {
        enabled: true,
      },
    },
  }),
  cluster_issuer: cm.nogroup.v1.clusterIssuer.new($._config.clusterIssuerName)
                  + cm.nogroup.v1.clusterIssuer.spec.ca.withSecretName($._config.caCertificateSecretName),
}
