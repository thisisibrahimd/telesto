local k = import '../k.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local ns_cert_manager = "cert-manager";

{
  new(crtB64, keyB64): {
    ns_cert_manager: k.core.v1.namespace.new(ns_cert_manager),
    cert_manager: helm.template('certs', '../../charts/cert-manager', {
      namespace: ns_cert_manager,
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
    local_ca_cert: k.core.v1.secret.new('local-ca-cert', {
      'tls.crt': crtB64,
      'tls.key': keyB64,
    }, 'kubernetes.io/tls')
    + k.core.v1.secret.metadata.withNamespace(ns_cert_manager),
    local_cluster_issuer: {
      apiVersion: 'cert-manager.io/v1',
      kind: 'ClusterIssuer',
      metadata: {
        name: 'local-cluster-issuer',
      },
      spec: {
        ca: {
          secretName: 'local-ca-cert',
        },
      },
    },
  },
}
