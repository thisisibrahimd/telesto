local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local kustomize = tanka.kustomize.new(std.thisFile);
local k = import 'ksonnet-util/kausal.libsonnet';

{
  new(): {
    // crds for gateway k8s api
    k8s_gateway_api_crds: kustomize.build('gatewaycrds/localized-gatewaycrds'),
    ns_gateway_nginx: k.core.v1.namespace.new('gateway-nginx'),
    // ca cert for nginx gateway
    gateway_nginx_certificate: {
      apiVersion: 'cert-manager.io/v1',
      kind: 'Certificate',
      metadata: {
        name: 'nginx-gateway-ca',
        namespace: 'gateway-nginx',
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
        namespace: 'gateway-nginx',
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
        namespace: 'gateway-nginx',
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
        namespace: 'gateway-nginx',
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
      namespace: 'gateway-nginx',
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
