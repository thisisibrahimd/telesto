local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local kustomize = tanka.kustomize.new(std.thisFile);

{
  new(): {
    // crds for gateway k8s api
    k8s_gateway_api_crds: kustomize.build('gatewaycrds'),
    // ca cert for nginx gateway
    gateway_nginx_certificate: {
      apiVersion: 'cert-manager.io/v1',
      kind: 'Certificate',
      metadata: {
        name: 'nginx-gateway-ca',
        namespace: 'default',
      },
      spec: {
        isCA: true,
        commonName: 'nginx-gateway',
        secretName: 'nginx-gateway-ca',
        privateKey: {
          algorithm: 'RSA',
          size: 2048,
        },
        issuerRef: {
          name: 'local-cluster-issuer',
          kind: 'ClusterIssuer',
          group: 'cert-manager.io',
        },
      },
    },
    // certmanager cert issuer for nginx gateway
    gateway_nginx_issuer: {
      apiVersion: 'cert-manager.io/v1',
      kind: 'ClusterIssuer',
      metadata: {
        name: 'nginx-gateway-issuer',
        namespace: 'default',
      },
      spec: {
        ca: {
          secretName: 'nginx-gateway-ca',
        },
      },
    },
    // server and client certifcates for nginx gateway
    nginx_server_cert: {
      apiVersion: 'cert-manager.io/v1',
      kind: 'Certificate',
      metadata: {
        name: 'nginx-gateway-server-tls',
        namespace: 'default',
      },
      spec: {
        secretName: 'nginx-gateway-server-tls',
        usages: [
          'digital signature',
          'key encipherment',
        ],
        dnsNames: [
          'ngf-nginx-gateway-fabric.default.svc',
        ],
        issuerRef: {
          name: 'nginx-gateway-issuer',
        },
      },
    },
    nginx_agent_cert: {
      apiVersion: 'cert-manager.io/v1',
      kind: 'Certificate',
      metadata: {
        name: 'nginx-gateway-agent-tls',
        namespace: 'default',
      },
      spec: {
        secretName: 'nginx-gateway-agent-tls',
        usages: [
          'digital signature',
          'key encipherment',
        ],
        dnsNames: [
          '*.cluster.local',
        ],
        issuerRef: {
          name: 'nginx-gateway-issuer',
        },
      },
    },
    helm_ngf: helm.template('ngf', '../../charts/nginx-gateway-fabric', {
      namespace: 'default',
      values: {
        nginx: {
          service: {
            type: 'LoadBalancer',
          },
        },
      },
    }),
  },
}
