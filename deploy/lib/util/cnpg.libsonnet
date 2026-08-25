local certs = './certs.libsonnet';

local issuers = './issuers.libsonnet';

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';

// helper to deploy the user-managed pki for cloudnative db clusters to support cert auth in replacement of password auth
// doc: https://cloudnative-pg.io/docs/1.30/certificates
// example: https://cloudnative-pg.io/docs/assets/files/cluster-example-cert-manager-70006d78c99f9f121cfba3e797e5f728.yaml
{
  cnpgLabel:: cm.nogroup.v1.certificate.spec.secretTemplate.withLabels({ 'cnpg.io/reload': '' }),
  pki: {
    new(name, namespace, clusterName): {
      caCertServer: certs.server.new(
        name=name,
        namespace=namespace,
      ),
      issuerServer: {},
      caCertClient: {},
      issuerClient: {},
      certServer: {},
      certClient: {},

    },
  },
}
