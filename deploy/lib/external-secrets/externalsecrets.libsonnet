local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  _config:: {
    _global:: {
      namespace: 'external-secrets',
    },
  },

  // TODO: libsonnetify helm values
  externalSecrets: helm.template('external-secrets', '../../charts/external-secrets', {
    namespace: $._config._global.namespace,
    values: {},
  }),
}
