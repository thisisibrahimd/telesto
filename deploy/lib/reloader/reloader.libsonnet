local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{

  _config:: {
    _global: {
      namespace: 'reloader',
    },
  },

  // TODO: libsonnetify helm values
  reloader: helm.template('reloader', '../../charts/reloader', {
    namespace: $._config._global.namespace,
    values: {
      reloader: {
        logFormat: 'json',
        reloadOnCreate: true,
        reloadOnDelete: true,
      },
    },
  }),
}
