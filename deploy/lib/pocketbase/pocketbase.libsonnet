local k = import 'ksonnet-util/kausal.libsonnet';

(import './config.libsonnet') +
{
  local deployment = k.apps.v1.deployment,
  local container = k.core.v1.container,
  local port = k.core.v1.containerPort,
  // local service = k.core.v1.service,
  local ingress = k.networking.v1.ingress,
  local ingressrule = k.networking.v1.ingressRule,
  local httpingresspath = k.networking.v1.httpIngressPath,
  local configmap = k.core.v1.configMap,

  // alias our params, too long to type every time
  local c = $._config.pocketbase,

  pocketbase: {
    pocketbase: {
      deployment: deployment.new(
        name=c.pocketbase.name,
        replicas=1,
        containers=[
          container.new(c.pocketbase.name, $._images.pocketbase.pocketbase)
          + container.withPorts([port.new('api', c.pocketbase.port)])
          + container.withCommand(['/ko-app/telesto-pb', 'serve', '--http=0.0.0.0:8080']),
        ],
      ),
      service: k.util.serviceFor(self.deployment),
      // + service.spec.withType('LoadBalancer'),
      ingress: if c.pocketbase.ingress.enabled
      then ingress.new(name=c.pocketbase.name)
           // + ingress.metadata.withAnnotations(c.pocketbase.ingress.rewrite.annotations)
           + ingress.spec.withIngressClassName(c.pocketbase.ingress.className)
           + ingress.spec.withRules(
             ingressrule.withHost(c.pocketbase.ingress.host)
             + ingressrule.http.withPaths(
               httpingresspath.withPath('/')
               + httpingresspath.withPathType('Prefix')
               + httpingresspath.backend.service.withName(c.pocketbase.name)
               + httpingresspath.backend.service.port.withNumber(c.pocketbase.port)
             )
           ),
    },
    argo_cm_plugin: if c.pocketbase.argo_cm_plugin.create
    then configmap.new(
      name=c.pocketbase.argo_cm_plugin.name,
      data={
        token: c.pocketbase.argo_cm_plugin.token,
        baseUrl: c.pocketbase.argo_cm_plugin.baseUrl,
        requestTimeout: c.pocketbase.argo_cm_plugin.requestTimeout,
      }
    ),
  },
}
