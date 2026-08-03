local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local kustomize = tanka.kustomize.new(std.thisFile);
local k = import 'ksonnet-util/kausal.libsonnet';

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local cmv1 = cm.nogroup.v1;


{
  _config:: {
    _global: {
      namespace: 'cnpg-system',
    },
    clusterIssuerRefName: 'cluster-issuer-central',
  },
  cnpg_system: helm.template('cnpg', '../../charts/cloudnative-pg', {
    namespace: $._config._global.namespace,
    values: {},
  }),
}
