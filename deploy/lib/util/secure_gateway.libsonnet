local gw = import './gateway.libsonnet';
{
  new(name, namespace, hostname, gatewayClassName, issuerRefName='', issuerRefKind='ClusterIssuer', serviceName, servicePort=443, caCertConfigMapName): {
    gateway: gw.gateway.new(
               name=name,
               namespace=namespace,
               hostname=hostname,
               gatewayClassName=gatewayClassName
             )
             + gw.gateway.withIssuerRef(issuerRefName, issuerRefKind),
    httpRoute443: gw.httpRoute.new(
      name=name,
      namespace=namespace,
      hostname=hostname,
      parentRefName=gw.gateway.gatewayName(name),
      serviceName=serviceName,
      servicePort=servicePort,
    ),
    httpRoute80: gw.httpRoute.newRedirect(
      name=name,
      namespace=namespace,
      hostname=hostname,
      parentRefName=gw.gateway.gatewayName(name),
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
