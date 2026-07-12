{
  httproute: {
    redirect: {
      new(name): {
        apiVersion: 'gateway.networking.k8s.io/v1',
        kind: 'HTTPRoute',
        metadata: {
          name: 'http-route-' + name + '-http-to-https-redirect',
        },
        spec: {
          parentRefs: [],
          hostnames: [],
          rules: [
            {
              filters: [
                {
                  type: 'RequestRedirect',
                  requestRedirect: {
                    scheme: 'https',
                    statusCode: 301,
                    port: 443,
                  },
                },
              ],
            },
          ],
        },
      },
      WithGateway(name, section): {
        spec+: {
          parentRefs: [
            {
              name: name,
              sectionName: section,
            },
          ],
        },
      },
      WithHostname(hostname): {
        spec+: {
          hostnames: [
            hostname,
          ],
        },
      },
    },
    new(): {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'http-route-openobserve-console-http-to-https-redirect',
      },
      spec: {
        parentRefs: [
          {
            name: 'gateway-openobserve-console',
            sectionName: 'http',
          },
        ],
        hostnames: [
          'console.openobserve.telesto.test',
        ],
        rules: [
          {
            filters: [
              {
                type: 'RequestRedirect',
                requestRedirect: {
                  scheme: 'https',
                  statusCode: 301,
                  port: 443,
                },
              },
            ],
          },
        ],
      },
    },
  },
}
