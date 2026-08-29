local certs = import './certs.libsonnet';

local issuers = import './issuers.libsonnet';

local cm = import 'github.com/jsonnet-libs/cert-manager-libsonnet/1.19/main.libsonnet';
local certificate = cm.nogroup.v1.certificate;

// helper to deploy the user-managed pki for cloudnative db clusters to support cert auth in replacement of password auth
// doc: https://cloudnative-pg.io/docs/1.30/certificates
// example: https://cloudnative-pg.io/docs/assets/files/cluster-example-cert-manager-70006d78c99f9f121cfba3e797e5f728.yaml
{
  cnpgLabel:: certificate.spec.secretTemplate.withLabels({ 'cnpg.io/reload': '' }),
  pki: {
    new(name, namespace, clusterName, issuerRefName, issuerRefKind): {
      // we need to CAs. one for server certs and clients certs
      certDBServerCA: certs.db.ca.new(
        name=name + '-server-ca',
        namespace=namespace,
        commonName=name + '-server',
        issuerRefName=issuerRefName,
        issuerRefKind=issuerRefKind
      ),
      certDBClientCA: certs.db.ca.new(
        name=name + '-client-ca',
        namespace=namespace,
        commonName=name + '-client',
        issuerRefName=issuerRefName,
        issuerRefKind=issuerRefKind
      ),

      // then we need issuers for the two CAs to create server and cilent certs
      issuerDBServer: issuers.new(
        name=name + '-server',
        namespace=namespace,
        secretName='cert-ca-' + name + '-server'
      ),
      issuerDBClient: issuers.new(
        name=name + '-client',
        namespace=namespace,
        secretName='cert-ca-' + name + ' -client'
      ),

      // create initial server and client certs for cluster
      certDBServer: certs.db.server.new(
        name=name + '-server',
        namespace=namespace,
        clusterName=clusterName,
        issuerRefName=issuerRefName,
        issuerRefKind=issuerRefKind
      ),
      certDBClient: certs.db.client.new(
        name=name + '-client',
        namespace=namespace,
        commonName='streaming_replica',
        issuerRefName=issuerRefName,
        issuerRefKind=issuerRefKind
      ),
    },
  },
}
