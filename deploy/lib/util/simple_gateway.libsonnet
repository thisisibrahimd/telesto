local netutil = import './net.libsonnet';
local gw = import 'github.com/jsonnet-libs/gateway-api-libsonnet/1.5/main.libsonnet';
local gatewayv1 = gw.gateway.v1;

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
    svc: {
      name: '',
      port: 0,
    },
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
  httproute: gatewayv1.httpRoute.new('hr-' + $._config.name)
             + gatewayv1.httpRoute.metadata.withNamespace($._config._global.namespace)
             + gatewayv1.httpRoute.spec.withParentRefsMixin(
               gatewayv1.httpRoute.spec.parentRefs.withName('gateway-' + $._config.name)
               + gatewayv1.httpRoute.spec.parentRefs.withSectionName('https')
             )
             + gatewayv1.httpRoute.spec.withHostnamesMixin($._config.hostname)
             + gatewayv1.httpRoute.spec.withRulesMixin(
               gatewayv1.httpRoute.spec.rules.withMatchesMixin(
                 gatewayv1.httpRoute.spec.rules.matches.path.withType('PathPrefix')
                 + gatewayv1.httpRoute.spec.rules.matches.path.withValue('/')

               )
               + gatewayv1.httpRoute.spec.rules.withBackendRefsMixin(
                 gatewayv1.httpRoute.spec.rules.backendRefs.withName($._config.svc.name)
                 + gatewayv1.httpRoute.spec.rules.backendRefs.withPort($._config.svc.port)
               )
             ),
  httprouteRedirect: gatewayv1.httpRoute.new('hr-' + $._config.name + '-http-redirect')
                     + gatewayv1.httpRoute.metadata.withNamespace($._config._global.namespace)
                     + gatewayv1.httpRoute.spec.withParentRefsMixin(
                       gatewayv1.httpRoute.spec.parentRefs.withName('gateway-' + $._config.name)
                       + gatewayv1.httpRoute.spec.parentRefs.withSectionName('http')
                     )
                     + gatewayv1.httpRoute.spec.withHostnamesMixin($._config.hostname)
                     + gatewayv1.httpRoute.spec.withRulesMixin(
                       gatewayv1.httpRoute.spec.rules.withFiltersMixin(
                         gatewayv1.httpRoute.spec.rules.filters.withType('RequestRedirect')
                         + gatewayv1.httpRoute.spec.rules.filters.requestRedirect.withScheme('https')
                         + gatewayv1.httpRoute.spec.rules.filters.requestRedirect.withStatusCode(301)
                         + gatewayv1.httpRoute.spec.rules.filters.requestRedirect.withPort(443)
                       )
                     ),

}
