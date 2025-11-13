{
  // +:: is important (we don't want to override the
  // _config object, just add to it)
  _config+:: {
    // define a namespace for this library
    pocketbase: {
      pocketbase: {
        port: 8080,
        name: 'pocketbase',
        ingress: {
          enabled: false,
          className: 'nginx',
          host: 'localhost',
          rewrite: {
            annotations: {
              'nginx.ingress.kubernetes.io/use-regex': 'true',
              'nginx.ingress.kubernetes.io/rewrite-target': '/$2',
            },
          },
        },
        argo_cm_plugin: {
          name: 'pocketbase-argo-cm-plugin-config',
          token: '$telesto.telesto_plugin.token',
          baseUrl: 'http://pocketbase.default.svc.cluster.local.:8080',
          requestTimeout: '60',
        },
      },
    },
  },

  // again, make sure to use +::
  _images+:: {
    pocketbase: {
      pocketbase: 'quay.io/telesto/telesto-pb:0.10.0',
    },
  },
}
