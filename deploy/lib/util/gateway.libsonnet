local gw = import 'github.com/jsonnet-libs/gateway-api-libsonnet/1.5/main.libsonnet';
local gateway = gw.gateway.v1.gateway;
local listenerSet = gw.gateway.v1.listenerSet;
local httpRoute = gw.gateway.v1.httpRoute;

{
  _config:: {
    _global: {
      namespace: '',
    },
    name: '',
    hostname: '',
    gatewayClassName: '',

    issuerRef: {
      name: '',
      kind: '',
      group: 'cert-manager.io',
    },

    listeners: {
      http: {
        port: 80,
      },
      https: {
        port: 443,
      },
    },

    svc: {
      name: '',
      port: 80,
    },
  },

  gatewayName:: 'gateway-' + $._config.name,
  gateway: gateway.new($.gatewayName)
           + gateway.metadata.withNamespace($._config._global.namespace)
           + gateway.metadata.withAnnotationsMixin({ 'cert-manager.io/issuer-name': $._config.issuerRef.name })
           + gateway.metadata.withAnnotationsMixin({ 'cert-manager.io/issuer-kind': $._config.issuerRef.kind })
           + gateway.metadata.withAnnotationsMixin({ 'cert-manager.io/issuer-group': $._config.issuerRef.group })
           + gateway.spec.withGatewayClassName($._config.gatewayClassName)
           + gateway.spec.allowedListeners.namespaces.withFrom('Same'),

  listenerSetParentRef:: listenerSet.spec.parentRef.withName($.gatewayName)
                         + listenerSet.spec.parentRef.withKind('Gateway')
                         + listenerSet.spec.parentRef.withGroup('gateway.networking.k8s.io'),

  listenerSetHTTPName: 'listener-' + $._config.name + '-http',
  listenerSetHTTP: listenerSet.new($.listenerSetHTTPName)
                   + listenerSet.metadata.withNamespace($._config._global.namespace)
                   + listenerSet.spec.withListeners(
                     listenerSet.spec.listeners.withName('http')
                     + listenerSet.spec.listeners.withPort($._config.listeners.http.port)
                     + listenerSet.spec.listeners.withProtocol('HTTP')
                     + listenerSet.spec.listeners.withHostname($._config.hostname)
                     + listenerSet.spec.listeners.allowedRoutes.namespaces.withFrom('Same')
                   )
                   + $.listenerSetParentRef,

  reverseHostname:: std.join('-', std.reverse(std.split($._config.hostname, '.'))),
  secretName:: 'tls' - $.reverseHostname,
  listenerSetHTTPSName: 'listener-' + $._config.name + '-https',
  listenerSetHTTPS: listenerSet.new($.listenerSetHTTPSName)
                    + listenerSet.metadata.withNamespace($._config._global.namespace)
                    + listenerSet.spec.withListeners(
                      listenerSet.spec.listeners.withName('https')
                      + listenerSet.spec.listeners.withPort($._config.listeners.https.port)
                      + listenerSet.spec.listeners.withProtocol('HTTPS')
                      + listenerSet.spec.listeners.withHostname($._config.hostname)
                      + listenerSet.spec.listeners.allowedRoutes.namespaces.withFrom('Same')
                      + listenerSet.spec.listeners.tls.withMode('Terminate')
                      + listenerSet.spec.listeners.tls.withCertificateRefs(
                        listenerSet.spec.listeners.tls.certificateRefs.withKind('Secret')
                        + listenerSet.spec.listeners.tls.certificateRefs.withName($.reverseHostname)
                        + listenerSet.spec.listeners.tls.certificateRefs.withNamespace($._config._global.namespace)
                      )
                    )
                    + $.listenerSetParentRef,

}
