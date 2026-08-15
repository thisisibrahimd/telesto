local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local tm = import '../trust-manager-crds/0.24.0/main.libsonnet';
local bundle = tm.trust.v1alpha1.bundle;

{
  _config:: {
    _global: {
      namespace: 'trust-manager',
    },
    rootCASecretName: 'cert-root-ca-telesto',
  },
  trustManager: helm.template('bundle', '../../charts/trust-manager', {
    namespace: $._config._global.namespace,
    values: {},
  }),
  telestoBundle: bundle.new('bundle-telesto')
                 + bundle.spec.withSources([
                   bundle.spec.sources.withUseDefaultCAs(true),
                   bundle.spec.sources.secret.withName($._config.rootCASecretName)
                   + bundle.spec.sources.secret.withKey('tls.crt'),
                 ])
                 + bundle.spec.target.configMap.withKey('bundle.pem'),
}
