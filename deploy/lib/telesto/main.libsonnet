local k = import 'ksonnet-util/kausal.libsonnet';

(import './config.libsonnet') +
{
  local deployment = k.apps.v1.deployment,
  local container = k.core.v1.container,
  local cPort = k.core.v1.containerPort,
  local volume = k.core.v1.volume,
  // local job = k.batch.v1.job,
  // local configmap = k.core.v1.configMap,
  // local volumeMount = k.core.v1.volumeMount,

  new(name='telesto', replicas=1, port=9000): {
    container::
      container.new(name, 'quay.io/telesto/telesto:0.0.1'),

    deployment: deployment.new(
      name,
      replicas,
      containers=[
        self.container
        + container.withPorts(cPort.new('api', port))
        + container.withCommand(['/usr/bin/telesto', 'serve', '--migrate', '--address', '0.0.0.0:' + std.toString(port), '--dsn', 'http://db-rqlite.default.svc.cluster.local', '--kratos-internal-public-endpoint', 'http://auth-kratos-public', '--kratos-public-endpoint', 'https://auth.telesto.test', '--kratos-admin-endpoint', 'http://auth-kratos-admin']),
        // + container.withVolumeMountsMixin([
        //   volumeMount.new('telesto-config', '/etc/telesto', true),
        // ]),
      ],
    ) + deployment.spec.template.spec.withVolumesMixin([
      volume.fromConfigMap('telesto-config', 'telesto-config'),
    ]),

    service: k.util.serviceFor(self.deployment),
    gateway: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'Gateway',
      metadata: {
        name: 'gateway-telesto',
        annotations: {
          'cert-manager.io/cluster-issuer': 'local-cluster-issuer',
        },
      },
      spec: {
        gatewayClassName: 'nginx',
        listeners: [
          {
            name: 'http',
            port: 80,
            protocol: 'HTTP',
            hostname: 'app.telesto.test',
          },
          {
            name: 'https',
            port: 443,
            protocol: 'HTTPS',
            hostname: 'app.telesto.test',
            allowedRoutes: {
              namespaces: {
                from: 'All',
              },
            },
            tls: {
              mode: 'Terminate',
              certificateRefs: [
                {
                  group: '',
                  kind: 'Secret',
                  name: 'test-telesto-app-tls',
                  namespace: 'default',
                },
              ],
            },
          },
        ],
      },
    },
    httproute_telesto_http_to_https_redirect: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'http-route-telesto-http-to-https-redirect',
      },
      spec: {
        parentRefs: [
          {
            name: 'gateway-telesto',
            sectionName: 'http',
            port: 80,
          },
        ],
        hostnames: [
          'app.telesto.test',
        ],
        rules: [
          {
            filters: [
              {
                type: 'RequestRedirect',
                requestRedirect: {
                  scheme: 'https',
                  statusCode: 301,
                  port: 443,
                },
              },
            ],
          },
        ],
      },
    },
    httproute_telesto: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'http-route-telesto',
      },
      spec: {
        parentRefs: [
          {
            name: 'gateway-telesto',
            sectionName: 'https',
            port: 443,
          },
        ],
        hostnames: [
          'app.telesto.test',
        ],
        rules: [
          {
            matches: [
              {
                path: {
                  type: 'PathPrefix',
                  value: '/',
                },
              },
            ],
            backendRefs: [
              {
                name: 'telesto-app',
                port: 9000,
              },
            ],
          },
        ],
      },
    },
  },
  withImage(image): {
    container+:
      k.core.v1.container.withImage(image),
  },
  withPort(port): {
    container+:
      +container.withPorts([cPort.new('api', port)]),
  },
  // withConfig(data): {
  //   config+:
  //     + configmap.withData(data),
  // },
  // argo_cm_plugin: if c.telesto.argo_cm_plugin.create
  // then configmap.new(
  //   name=c.telesto.argo_cm_plugin.name,
  //   data={
  //     token: c.telesto.argo_cm_plugin.token,
  //     baseUrl: c.telesto.argo_cm_plugin.baseUrl,
  //     requestTimeout: c.telesto.argo_cm_plugin.requestTimeout,
  //   }
  // ),
}
