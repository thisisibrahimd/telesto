local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local issuer = cm.nogroup.v1.issuer;

{
  name(name):: 'issuer-' + name,
  new(name, namespace, secretName): issuer.new($.name(name))
                                    + issuer.metadata.withNamespace(namespace)
                                    + issuer.spec.ca.withSecretName(secretName),
}
