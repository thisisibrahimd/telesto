local k = import 'ksonnet-util/kausal.libsonnet';

(import './config.libsonnet') +
{
  local deployment = k.apps.v1.deployment,
  local container = k.core.v1.container,
  local cPort = k.core.v1.containerPort,
  local ingress = k.networking.v1.ingress,
  local ingressrule = k.networking.v1.ingressRule,
  local httpingresspath = k.networking.v1.httpIngressPath,
  local configmap = k.core.v1.configMap,
  local volume = k.core.v1.volume,
  local volumeMount = k.core.v1.volumeMount,

  new(name='telesto', replicas=1, port=9000): {
    container::
      k.core.v1.container.new('name', 'quay.io/telesto/telesto:0.0.1')
      + container.withPorts([cPort.new('api', port)])
      + container.withCommand(['/ko-app/telesto', 'serve', '--config', '/etc/telesto/telesto.yaml'])
      + container.withVolumeMountsMixin([
        volumeMount.new('telesto-config', '/etc/telesto', true),
        // k.util.configVolumeMount('telesto-config', '/etc/telesto/telesto.yaml'),
      ]),

    deployment: deployment.new(
      name,
      replicas,
      containers=[
        self.container,
      ],
    ) + deployment.spec.template.spec.withVolumesMixin([
      volume.fromConfigMap('telesto-config', 'telesto-config'),
    ]),

    service: k.util.serviceFor(self.deployment),
    ingress: ingress.new(name)
             + ingress.spec.withRules(
               ingressrule.withHost('telesto.localhost')
               + ingressrule.http.withPaths(
                 httpingresspath.withPath('/')
                 + httpingresspath.withPathType('Prefix')
                 + httpingresspath.backend.service.withName(name)
                 + httpingresspath.backend.service.port.withNumber(port)
               )
             ),
    config: configmap.new('telesto-config', {
      'telesto.yaml': std.toString({

        host: '0.0.0.0',
        port: std.toString(port),
      }),
    }),
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
