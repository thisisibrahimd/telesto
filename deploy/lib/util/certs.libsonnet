local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local certificate = cm.nogroup.v1.certificate;

local dnsutil = import '../../lib/util/dns.libsonnet';

// helper for creating certs for web/api servers and mTLS connections between db and clients
{
  defaultKey:: certificate.spec.privateKey.withAlgorithm('RSA')
               + certificate.spec.privateKey.withSize(2048),

  withIssuerRef(name, kind='ClusterIssuer'):: certificate.spec.issuerRef.withName(name)
                                              + certificate.spec.issuerRef.withKind(kind)
                                              + certificate.spec.issuerRef.withGroup('cert-manager.io'),

  secretName(name):: 'cert-' + name,

  usages:: {
    server: certificate.spec.withUsagesMixin(['server auth']),
    client: certificate.spec.withUsagesMixin(['client auth']),

  },
  server: {
    new(name, namespace, commonName, issuerRefName, issuerRefKind='ClusterIssuer'): certificate.new(name)
                                                                                    + certificate.metadata.withNamespace(namespace)
                                                                                    + certificate.spec.withCommonName(commonName)
                                                                                    + certificate.spec.withSecretName($.secretName(name))
                                                                                    + certificate.spec.withDnsNamesMixin(commonName)
                                                                                    + $.usages.server
                                                                                    + $.defaultKey
                                                                                    + $.withIssuerRef(issuerRefName, issuerRefKind),
  },
  client: {
    new(name, namespace, commonName, issuerRefName, issuerRefKind='ClusterIssuer'): certificate.new(name)
                                                                                    + certificate.metadata.withNamespace(namespace)
                                                                                    + certificate.spec.withCommonName(commonName)
                                                                                    + certificate.spec.withSecretName($.secretName(name))
                                                                                    + certificate.spec.withDnsNamesMixin(commonName)
                                                                                    + $.usages.client
                                                                                    + $.defaultKey
                                                                                    + $.withIssuerRef(issuerRefName, issuerRefKind),
  },

  db: {
    cnpgLabel:: certificate.spec.secretTemplate.withLabels({ 'cnpg.io/reload': '' }),
    cluster: {
      new(name, namespace, clusterName, commonName, issuerRefName, issuerRefKind='ClusterIssuer'): certificate.new(name)
                                                                                                   + certificate.metadata.withNamespace(namespace)
                                                                                                   + certificate.spec.withCommonName(commonName)
                                                                                                   + certificate.spec.withSecretName($.secretName(name))
                                                                                                   + certificate.spec.withDnsNames(
                                                                                                     dnsutil.dnsnames.cnpg.new(clusterName, namespace)
                                                                                                   )
                                                                                                   + $.db.cnpgLabel
                                                                                                   + $.usages.server
                                                                                                   + $.defaultKey
                                                                                                   + $.withIssuerRef(issuerRefName, issuerRefKind),
    },

    client: {
      new(name, namespace, commonName, issuerRefName, issuerRefKind='ClusterIssuer'): certificate.new(name)
                                                                                      + certificate.metadata.withNamespace(namespace)
                                                                                      + certificate.spec.withCommonName(commonName)
                                                                                      + certificate.spec.withSecretName($.secretName(name))
                                                                                      + $.db.cnpgLabel
                                                                                      + $.usages.client
                                                                                      + $.defaultKey
                                                                                      + $.withIssuerRef(issuerRefName, issuerRefKind),
    },
  },
}
