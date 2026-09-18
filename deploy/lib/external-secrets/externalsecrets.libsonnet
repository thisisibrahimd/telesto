local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local grafanacrds = import '../grafana-crds/5.25.0/main.libsonnet';
local dashboard = grafanacrds.grafana.v1beta1.grafanaDashboard;

{
  _config:: {
    _global:: {
      namespace: 'external-secrets',
    },
  },

  // TODO: libsonnetify helm values
  external_secrets_helm: helm.template('external-secrets', '../../charts/external-secrets', {
    namespace: $._config._global.namespace,
    values: {
      serviceMonitor: {
        enabled: true,
        renderMode: 'alwaysRender',
        namespace: $._config._global.namespace,
        additionalLabels: {
          'ops.telesto.com/target-allocator-instance': 'agent-internal',
        },
      },
      grafanaDashboard: {
        enabled: true,
      },
    },
  }),
  external_secrets_dashboard: dashboard.new('d-external-dashboard')
                              + dashboard.metadata.withNamespace($._config._global.namespace)
                              + dashboard.spec.withAllowCrossNamespaceImport(true)
                              + dashboard.spec.instanceSelector.withMatchLabelsMixin({ instance: 'internal' })
                              + dashboard.spec.configMapRef.withName('external-secrets-dashboard')
                              + dashboard.spec.configMapRef.withKey('external-secrets.json'),


}
