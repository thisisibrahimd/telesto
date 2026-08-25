local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';

local cnpg = import '../cloudnative-pg-crds/1.30.0/main.libsonnet';

local dnsutil = import '../../lib/util/dns.libsonnet';

{
  new(name, namespace, secretName): cm.nogroup.v1.issuer.new(name)
                                    + cm.nogroup.v1.issuer.metadata.withNamespace(namespace)
                                    + cm.nogroup.v1.issuer.spec.ca.withSecretName(secretName),
}
