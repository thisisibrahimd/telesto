local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local telesto = import '../../../../apps/telesto-api/deploy/tanka/main.libsonnet';
local ocdeployer = import '../../lib/otelcoldeployer/otelcoldeployer.libsonnet';

{
  tele: telesto.new('telesto-api')
        + telesto.withImage('quay.io/telesto/telesto:0.0.2-alpha'),
  argocd: helm.template('customer-captian', '../../charts/argo-cd', {
    namespace: 'default',
    values: {
      global: {
        domain: 'argocd.telesto.localhost',
      },
      configs: {
        params: {
          'server.insecure': true,
        },
        secret: {
          extra: {
            'otelcoldeployer.otelcoldeployer_plugin.token': 'GVsbG8=',
          },
        },
      },
      server: {
        insecure: true,
        ingress: {
          enabled: true,
          hostname: 'argocd.telesto.localhost',
          path: '/',
          ingressClassName: 'cloud-provider-kind',
          tls: false,
        },
      },
    },
  }),
  otelcoldeployer: ocdeployer.otelcoldeployer.new()
}
