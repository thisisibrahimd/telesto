local k = import '../k.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local certPath = importstr '/Users/ibrahimd/.local/share/mkcert/rootCA.pem';
local keyPath = importstr '/Users/ibrahimd/.local/share/mkcert/rootCA-key.pem';

{
  new(): {
    cert_manager: helm.template('certs', '../../charts/cert-manager', {
      namespace: 'default',
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
      'tls.crt': std.base64(certPath),
      'tls.key': std.base64(keyPath),
    }, 'kubernetes.io/tls'),
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
