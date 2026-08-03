local gw = import 'github.com/jsonnet-libs/gateway-api-libsonnet/1.5/main.libsonnet';
local gatewayv1 = gw.gateway.v1;

{
  httproute: {
    new(name, ns, hostname, gwName, svcName, svcPort): gatewayv1.httpRoute.new('hr-' + name)
                                                       + gatewayv1.httpRoute.metadata.withNamespace(ns)
                                                       + gatewayv1.httpRoute.spec.withParentRefsMixin(
                                                         gatewayv1.httpRoute.spec.parentRefs.withName(gwName)
                                                         + gatewayv1.httpRoute.spec.parentRefs.withSectionName('https')
                                                       )
                                                       + gatewayv1.httpRoute.spec.withHostnamesMixin(hostname)
                                                       + gatewayv1.httpRoute.spec.withRulesMixin(
                                                         gatewayv1.httpRoute.spec.rules.withMatchesMixin(
                                                           gatewayv1.httpRoute.spec.rules.matches.path.withType('PathPrefix')
                                                           + gatewayv1.httpRoute.spec.rules.matches.path.withValue('/')

                                                         )
                                                         + gatewayv1.httpRoute.spec.rules.withBackendRefsMixin(
                                                           gatewayv1.httpRoute.spec.rules.backendRefs.withName(svcName)
                                                           + gatewayv1.httpRoute.spec.rules.backendRefs.withPort(svcPort)

                                                         )
                                                       ),
    newRedirect(name, ns, hostname, gwName): gatewayv1.httpRoute.new('hr-' + name)
                                             + gatewayv1.httpRoute.metadata.withNamespace(ns)
                                             + gatewayv1.httpRoute.spec.withParentRefsMixin(
                                               gatewayv1.httpRoute.spec.parentRefs.withName(gwName)
                                               + gatewayv1.httpRoute.spec.parentRefs.withSectionName('http')
                                             )
                                             + gatewayv1.httpRoute.spec.withHostnamesMixin(hostname)
                                             + gatewayv1.httpRoute.spec.withRulesMixin(
                                               gatewayv1.httpRoute.spec.rules.withFiltersMixin(
                                                 gatewayv1.httpRoute.spec.rules.filters.withType('RequestRedirect')
                                                 + gatewayv1.httpRoute.spec.rules.filters.requestRedirect.withScheme('https')
                                                 + gatewayv1.httpRoute.spec.rules.filters.requestRedirect.withStatusCode(301)
                                                 + gatewayv1.httpRoute.spec.rules.filters.requestRedirect.withPort(443)
                                               )
                                             ),
  },
}
