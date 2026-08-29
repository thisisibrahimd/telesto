local gw = import 'github.com/jsonnet-libs/gateway-api-libsonnet/1.5/main.libsonnet';
local gateway = gw.gateway.v1.gateway;
local httpRoute = gw.gateway.v1.httpRoute;
local backendTLSPolicy = gw.gateway.v1.backendTLSPolicy;

{
  reverseHostname(hostname): std.join('-', std.reverse(std.split(hostname, '.'))),
  tlsSecretName(hostname): 'tls-' + $.reverseHostname(hostname),

  gateway: {
    gatewayName(name): 'gateway-' + name,
    plain(name, namespace, gatewayClassName='nginx'): gateway.new($.gateway.gatewayName(name))
                                                      + gateway.metadata.withNamespace(namespace)
                                                      + gateway.spec.withGatewayClassName(gatewayClassName),
    withHttpListener(hostname, port=80): gateway.spec.withListenersMixin(
      gateway.spec.listeners.withName('http')
      + gateway.spec.listeners.withPort(port)
      + gateway.spec.listeners.withProtocol('HTTP')
      + gateway.spec.listeners.withHostname(hostname)
      + gateway.spec.listeners.allowedRoutes.namespaces.withFrom('Same'),
    ),
    withHttpsListener(namespace, hostname, secretName='', templateSecretName=false, port=443): gateway.spec.withListenersMixin(
      gateway.spec.listeners.withName('https')
      + gateway.spec.listeners.withPort(port)
      + gateway.spec.listeners.withProtocol('HTTPS')
      + gateway.spec.listeners.withHostname(hostname)
      + gateway.spec.listeners.allowedRoutes.namespaces.withFrom('Same')
      + gateway.spec.listeners.tls.withMode('Terminate')
      + gateway.spec.listeners.tls.withCertificateRefs(
        gateway.spec.listeners.tls.certificateRefs.withKind('Secret')
        + gateway.spec.listeners.tls.certificateRefs.withNamespace(namespace)
        + if !templateSecretName then
          gateway.spec.listeners.tls.certificateRefs.withName($.tlsSecretName(hostname))
        else
          gateway.spec.listeners.tls.certificateRefs.withName(secretName)

      ),
    ),
    new(name, namespace, hostname, gatewayClassName='nginx', httpPort=80, httpsPort=443): gateway.new($.gateway.gatewayName(name))
                                                                                          + gateway.metadata.withNamespace(namespace)
                                                                                          + gateway.spec.withGatewayClassName(gatewayClassName)
                                                                                          + gateway.spec.allowedListeners.namespaces.withFrom('Same')
                                                                                          + $.gateway.withHttpListener(hostname, httpPort)
                                                                                          + $.gateway.withHttpsListener(namespace, hostname, httpsPort),
    withIssuerRef(name, kind='ClusterIssuer'):
      if kind == 'Issuer' then gateway.metadata.withAnnotationsMixin({ 'cert-manager.io/issuer': name })
      else if kind == 'ClusterIssuer' then gateway.metadata.withAnnotationsMixin({ 'cert-manager.io/cluster-issuer': name })
      else {},
  },

  httpRoute: {
    new(name, namespace, hostname, parentRefName, sectionName='https', serviceName, servicePort): httpRoute.new('hr-' + name)
                                                                                                  + httpRoute.metadata.withNamespace(namespace)
                                                                                                  + httpRoute.spec.withParentRefsMixin(
                                                                                                    httpRoute.spec.parentRefs.withName(parentRefName)
                                                                                                    + httpRoute.spec.parentRefs.withSectionName(sectionName)
                                                                                                  )
                                                                                                  + httpRoute.spec.withHostnamesMixin(hostname)
                                                                                                  + httpRoute.spec.withRulesMixin(
                                                                                                    httpRoute.spec.rules.withMatchesMixin(
                                                                                                      httpRoute.spec.rules.matches.path.withType('PathPrefix')
                                                                                                      + httpRoute.spec.rules.matches.path.withValue('/')

                                                                                                    )
                                                                                                    + httpRoute.spec.rules.withBackendRefsMixin(
                                                                                                      httpRoute.spec.rules.backendRefs.withName(serviceName)
                                                                                                      + httpRoute.spec.rules.backendRefs.withPort(servicePort)
                                                                                                    )
                                                                                                  ),
    newRedirect(name, namespace, hostname, parentRefName, sectionName='http'): httpRoute.new('hr-' + name + '-redirect')
                                                                               + httpRoute.metadata.withNamespace(namespace)
                                                                               + httpRoute.spec.withParentRefsMixin(
                                                                                 httpRoute.spec.parentRefs.withName(parentRefName)
                                                                                 + httpRoute.spec.parentRefs.withSectionName(sectionName)
                                                                               )
                                                                               + httpRoute.spec.withHostnamesMixin(hostname)
                                                                               + httpRoute.spec.withRulesMixin(
                                                                                 httpRoute.spec.rules.withFiltersMixin(
                                                                                   httpRoute.spec.rules.filters.withType('RequestRedirect')
                                                                                   + httpRoute.spec.rules.filters.requestRedirect.withScheme('https')
                                                                                   + httpRoute.spec.rules.filters.requestRedirect.withStatusCode(301)
                                                                                   + httpRoute.spec.rules.filters.requestRedirect.withPort(443)
                                                                                 )
                                                                               ),

  },

  backendTLSPolicy: {
    new(name, namespace, hostname, serviceName, configMapName): backendTLSPolicy.new('tls-' + name)
                                                                + backendTLSPolicy.metadata.withNamespace(namespace)
                                                                + backendTLSPolicy.spec.withTargetRefs(
                                                                  backendTLSPolicy.spec.targetRefs.withKind('Service')
                                                                  + backendTLSPolicy.spec.targetRefs.withName(serviceName)
                                                                  + backendTLSPolicy.spec.targetRefs.withGroup('')
                                                                )

                                                                + backendTLSPolicy.spec.validation.withCaCertificateRefs(
                                                                  backendTLSPolicy.spec.validation.caCertificateRefs.withKind('ConfigMap')
                                                                  + backendTLSPolicy.spec.validation.caCertificateRefs.withName(configMapName)
                                                                  + backendTLSPolicy.spec.validation.caCertificateRefs.withGroup('')
                                                                )
                                                                + backendTLSPolicy.spec.validation.withHostname(hostname),
  },
}
