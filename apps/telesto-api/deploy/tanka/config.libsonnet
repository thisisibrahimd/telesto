{
  // +:: is important (we don't want to override the
  // _config object, just add to it)
  _config+:: {
    // define a namespace for this library
    telesto: {
      telesto: {
        port: 9000,
        name: 'telesto',
        ingress: {
          enabled: true,
          className: '',
          host: 'telesto.localhost',
        },
        // argo_cm_plugin: {
        //   create: false,
        //   name: 'pocketbase-argo-cm-plugin-config',
        //   token: '$telesto.telesto_plugin.token',
        //   baseUrl: 'http://pocketbase.default.svc.cluster.local.:8080',
        //   requestTimeout: '60',
        // },
      },
    },
  },

  // again, make sure to use +::
  _images+:: {
    telesto: {
      telesto: 'quay.io/telesto/telesto:0.0.2-alpha',
    },
  },
}
