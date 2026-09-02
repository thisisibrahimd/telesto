local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local k = import 'ksonnet-util/kausal.libsonnet';

local certs = import '../util/certs.libsonnet';

local grafanacrds = import '../grafana-crds/5.25.0/main.libsonnet';
local grafana = grafanacrds.grafana.v1beta1.grafana;

local secureGateway = import '../util/secure_gateway.libsonnet';
local simpleGateway = import '../util/simple_gateway.libsonnet';

{
  _config:: {
    _global: {
      namespace: 'monitoring',
    },


    issuerRefName: '',
    issuerRefKind: 'ClusterIssuer',

  },
  grafanaOperator: {
    helm: helm.template('goperator', '../../charts/grafana-operator', {
      skipTests: true,
      namespace: $._config._global.namespace,
      values: {},
    }),
  },
  grafana: {
    certGrafanaInternal: certs.server.new(
      name='grafana-internal',
      namespace=$._config._global.namespace,
      commonName='grafana.telesto.test',
      issuerRefName=$._config.issuerRefName,
      issuerRefKind=$._config.issuerRefKind,
    ),
    internal: grafana.new('grafana-internal')
              + grafana.metadata.withNamespace($._config._global.namespace)
              + grafana.spec.withConfigMixin({
                log: {
                  mode: 'console',
                },
                server: {
                  protocol: 'https',
                  cert_file: '/etc/certs/grafana/tls.crt',
                  cert_key: '/etc/certs/grafana/tls.key',
                },
              })
              + grafana.spec.client.tls.withInsecureSkipVerify(true)
              + grafana.spec.deployment.spec.template.spec.withVolumes({
                name: 'cert-grafana',
                secret: {
                  secretName: 'cert-grafana-internal',
                },
              })
              + grafana.spec.deployment.spec.template.spec.withContainers(
                grafana.spec.deployment.spec.template.spec.containers.withName('grafana')
                + grafana.spec.deployment.spec.template.spec.containers.readinessProbe.httpGet.withScheme('HTTPS')
                + grafana.spec.deployment.spec.template.spec.containers.readinessProbe.httpGet.withPort(3000)
                + grafana.spec.deployment.spec.template.spec.containers.readinessProbe.httpGet.withPath('/api/health')
                + grafana.spec.deployment.spec.template.spec.containers.withVolumeMountsMixin({
                  name: 'cert-grafana',
                  mountPath: '/etc/certs/grafana',
                  readOnly: true,
                }),
              ),
    gatewayGrafanaInternal: secureGateway.new(
      name='grafana',
      namespace=$._config._global.namespace,
      hostname='grafana.telesto.test',
      gatewayClassName='nginx',
      issuerRefName=$._config.issuerRefName,
      issuerRefKind=$._config.issuerRefKind,
      serviceName='grafana-internal-service',
      servicePort=3000,
      caCertConfigMapName='bundle-telesto'
    ),
  },
  loki: {},
  mimir: {},
  tempo: {},
}
