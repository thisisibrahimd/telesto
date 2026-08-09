local gw = import 'github.com/jsonnet-libs/gateway-api-libsonnet/1.5/main.libsonnet';
local gatewayv1 = gw.gateway.v1;

{
  _config:: {
    name: '',
    namespace: '',
    gatewayClassName: '',
  },

  gateway: gatewayv1.gateway.new('gateway-' + $._config.name)
           + gatewayv1.gateway.metadata.withNamespace($._config._global.namespace)
           + gatewayv1.gateway.metadata.withAnnotationsMixin({ 'cert-manager.io/cluster-issuer': $._config.issuerRef.name })
           + gatewayv1.gateway.spec.withGatewayClassName($._config.gatewayClassName)
           + gatewayv1.gateway.spec.withListenersMixin(
             gatewayv1.gateway.spec.listeners.withName('http')
             + gatewayv1.gateway.spec.listeners.withPort(80)
             + gatewayv1.gateway.spec.listeners.withProtocol('HTTP')
             + gatewayv1.gateway.spec.listeners.withHostname($._config.hostname)
           )
           + gatewayv1.gateway.spec.withListenersMixin(
             gatewayv1.gateway.spec.listeners.withName('https')
             + gatewayv1.gateway.spec.listeners.withPort(443)
             + gatewayv1.gateway.spec.listeners.withProtocol('HTTPS')
             + gatewayv1.gateway.spec.listeners.withHostname($._config.hostname)
             + gatewayv1.gateway.spec.listeners.allowedRoutes.namespaces.withFrom('Same')
             + gatewayv1.gateway.spec.listeners.tls.withMode('Terminate')
             + gatewayv1.gateway.spec.listeners.tls.withCertificateRefs(
               gatewayv1.gateway.spec.listeners.tls.certificateRefs.withKind('Secret')
               + gatewayv1.gateway.spec.listeners.tls.certificateRefs.withName('tls-' + std.join('-', std.reverse(std.split($._config.hostname, '.'))))
               + gatewayv1.gateway.spec.listeners.tls.certificateRefs.withNamespace($._config._global.namespace)
             )
           ),

}
