local gw = import './gateway.libsonnet';
{
  new(name, namespace, hostname, gatewayClassName, issuerName, issuerKind='ClusterIssuer', serviceName, servicePort, caCertConfigMapName): {
    gateway: gw.gateway.new(
               name=name,
               namespace=namespace,
               hostname=hostname,
               gatewayClassName=gatewayClassName
             )
             + gw.gateway.withIssuerRef(issuerName, issuerKind),
    httpRoute443: gw.httpRoute.new(
      name=name,
      namespace=namespace,
      hostname=hostname,
      parentName=gw.gateway.gatewayName(name),
      serviceName=serviceName,
      servicePort=servicePort,
    ),
    httpRoute80: gw.httpRoute.newRedirect(
      name=name,
      namespace=namespace,
      hostname=hostname,
      parentName=gw.gateway.gatewayName(name),
    ),
    backendTLSPolicy: gw.backendTLSPolicy.new(
      name=name,
      namespace=namespace,
      hostname=hostname,
      serviceName=serviceName,
      configMapName=caCertConfigMapName,
    ),
  },
}
