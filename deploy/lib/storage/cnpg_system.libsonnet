local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  _config:: {
    _global: {
      namespace: 'cnpg-system',
    },
    clusterIssuerRefName: 'cluster-issuer-central',
  },
  // TODO: libsonnetify helm values
  cnpgSystem: helm.template('cnpg', '../../charts/cloudnative-pg', {
    namespace: $._config._global.namespace,
    values: {},
  }),
}
