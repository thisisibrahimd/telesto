local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local argo = import '../argocd-crds/3.4.1/main.libsonnet';
local project = argo.argoproj.v1alpha1.appProject;
local applicationset = argo.argoproj.v1alpha1.applicationSet;

local certs = import '../util/certs.libsonnet';

local es = import '../external-secrets-crds/2.9.0/main.libsonnet';
local externalSecret = es.nogroup.v1.externalSecret;

local gw = import '../util/gateway.libsonnet';

local metadatautil = import '../util/metadata.libsonnet';

{
  local configmap = k.core.v1.configMap,

  _config:: {
    _global: {
      namespace: 'telestos',
    },

    argocdNamespace: 'argocd',

    issuerRefName: '',
    issuerRefKind: 'ClusterIssuer',

    helmChartRepo: 'https://open-telemetry.github.io/opentelemetry-helm-charts',
    chart: 'opentelemetry-collector',
    chartVersion: '0.158.0',

    telestoDeployerToken: '',
  },
  _images:: {
  },

  domainTemplate:: '{{.telesto.id}}.t.telesto.test',
  secret: k.core.v1.secret.new('telestodeployer-plugin', {
            'plugin.telestodeployer-plugin.token': std.base64($._config.telestoDeployerToken),
          }, 'Opaque')
          + k.core.v1.secret.metadata.withNamespace('argocd')
          + k.core.v1.secret.metadata.withLabelsMixin({
            'app.kubernetes.io/part-of': 'argocd',
          }),
  configmap: configmap.new(
               name='telestodeployer-plugin-config',
               data={
                 token: '$telestodeployer-plugin:plugin.telestodeployer-plugin.token',
                 baseUrl: 'https://telesto-private.app:8443',
                 requestTimeout: '60',
               }
             )
             // currently in argocd namespace due to limits. waiting for this pr: https://github.com/argoproj/argo-cd/pull/21044
             // + configmap.metadata.withNamespace($._config._global.namespace),
             + configmap.metadata.withNamespace('argocd'),
  otelcolHelmChartValues:: {
    mode: 'deployment',
    image: {
      repository: 'otel/opentelemetry-collector-contrib',
    },
    command: {
      name: 'otelcol-contrib',
      extraArgs: [
        '--config=/conf/relay.yaml',
      ],
    },
    annotations: {
      'reloader.stakater.com/auto': 'true',
    },
    ingress: {
      enabled: false,
    },
    ports: {
      otlp: {
        enabled: false,
      },
      'jaeger-compact': {
        enabled: false,
      },
      'jaeger-thrift': {
        enabled: false,
      },
      'jaeger-grpc': {
        enabled: false,
      },
      zipkin: {
        enabled: false,
      },
    },

    extraVolumes: [
      {
        name: 'telesto-tokens',
        secret: {
          secretName: 'telesto-tokens',
          optional: true,
        },
      },
      {
        name: 'telesto-config',
        secret: {
          secretName: 'telesto-config',
          optional: false,
        },
      },
      {
        name: 'otelcol-certs',
        secret: {
          secretName: 'cert-telesto-{{.telesto.id}}',
          optional: false,
        },
      },
    ],

    extraVolumeMounts: [
      {
        name: 'telesto-tokens',
        mountPath: '/etc/secrets/auth',
        readonly: true,
      },
      {
        name: 'telesto-config',
        mountPath: '/conf',
        readonly: true,
      },
      {
        name: 'otelcol-certs',
        mountPath: '/etc/certs/otelcol',
        readonly: true,
      },
    ],

    configMap: {
      create: false,
    },

    enableConfigChecksumAnnotation: false,

    extraManifests: [
      // tokens from users
      externalSecret.new('telesto-tokens')
      + externalSecret.metadata.withNamespace('telesto-{{.telesto.id}}')
      + externalSecret.spec.secretStoreRef.withName('telesto-token-cluster-secret-store')
      + externalSecret.spec.secretStoreRef.withKind('ClusterSecretStore')
      + externalSecret.spec.withRefreshInterval('5s')
      + externalSecret.spec.target.withName('telesto-tokens')
      + externalSecret.spec.target.withDeletionPolicy('Delete')
      + externalSecret.spec.withData(
        externalSecret.spec.data.withSecretKey('tokens.txt')
        + externalSecret.spec.data.remoteRef.withKey('{{.telesto.id}}')
      ),
      externalSecret.new('telesto-config')
      + externalSecret.metadata.withNamespace('telesto-{{.telesto.id}}')
      + externalSecret.spec.secretStoreRef.withName('telesto-config-cluster-secret-store')
      + externalSecret.spec.secretStoreRef.withKind('ClusterSecretStore')
      + externalSecret.spec.withRefreshInterval('5s')
      + externalSecret.spec.target.withName('telesto-config')
      + externalSecret.spec.target.withDeletionPolicy('Delete')
      + externalSecret.spec.withData(
        externalSecret.spec.data.withSecretKey('relay.yaml')
        + externalSecret.spec.data.remoteRef.withKey('{{.telesto.id}}')
      ),
      certs.server.new(
        name='telesto-{{.telesto.id}}',
        namespace='telesto-{{.telesto.id}}',
        commonName='{{.telesto.id}}.t.telesto.test',
        issuerRefName=$._config.issuerRefName,
        issuerRefKind=$._config.issuerRefKind,
      ),
      gw.gateway.plain(
        name='telesto-{{.telesto.id}}',
        namespace='telesto-{{.telesto.id}}',
        gatewayClassName='nginx',
      )
      + gw.gateway.withHttpsListener(
        namespace='telesto-{{.telesto.id}}',
        hostname='{{.telesto.id}}.t.telesto.test',
        secretName='tls-test-telesto-t-{{.telesto.id}}',
        templateSecretName=true,
        port=4318
      )
      + gw.gateway.withIssuerRef(name=$._config.issuerRefName, kind=$._config.issuerRefKind),
      gw.backendTLSPolicy.new(
        name='telesto-{{.telesto.id}}',
        namespace='telesto-{{.telesto.id}}',
        hostname='{{.telesto.id}}.t.telesto.test',
        serviceName='telesto-{{.telesto.id}}-opentelemetry-collector',
        configMapName='bundle-telesto'
      ),
      gw.httpRoute.new(
        name='telesto-{{.telesto.id}}',
        namespace='telesto-{{.telesto.id}}',
        hostname='{{.telesto.id}}.t.telesto.test',
        parentRefName='gateway-telesto-{{.telesto.id}}',
        serviceName='telesto-{{.telesto.id}}-opentelemetry-collector',
        servicePort=4318
      ),
    ],
  },
  telestosProject: project.new('telestos')
                   + project.metadata.withNamespace($._config.argocdNamespace)
                   + project.spec.withSourceRepos('*')
                   + project.spec.withSourceNamespaces($._config._global.namespace)
                   + project.spec.withDestinations(
                     project.spec.destinations.withNamespace('*')
                     + project.spec.destinations.withServer('*')
                   )
                   + project.spec.withClusterResourceWhitelist(
                     project.spec.clusterResourceWhitelist.withKind('*')
                     + project.spec.clusterResourceWhitelist.withGroup('*')
                   ),
  applicationset: applicationset.new('telesto')
                  + applicationset.metadata.withNamespace($._config._global.namespace)
                  + applicationset.spec.withGoTemplate(true)
                  + applicationset.spec.withGoTemplateOptions('missingkey=error')
                  + applicationset.spec.withGenerators(
                    applicationset.spec.generators.plugin.configMapRef.withName('telestodeployer-plugin-config')
                    + applicationset.spec.generators.plugin.withRequeueAfterSeconds(10)
                  )
                  + applicationset.spec.template.metadata.withName('telesto-{{.telesto.id}}')
                  + applicationset.spec.template.metadata.withNamespace('telesto-{{.telesto.id}}')
                  + applicationset.spec.template.spec.withProject('telestos')
                  + applicationset.spec.template.spec.syncPolicy.automated.withEnabled(true)
                  + applicationset.spec.template.spec.syncPolicy.withSyncOptionsMixin('CreateNamespace=true')
                  + applicationset.spec.template.spec.syncPolicy.managedNamespaceMetadata.withLabelsMixin({
                    'telesto-deployed': 'true',
                  })
                  + applicationset.spec.template.spec.syncPolicy.automated.withPrune(true)
                  + applicationset.spec.template.spec.syncPolicy.automated.withSelfHeal(true)
                  + applicationset.spec.template.spec.syncPolicy.automated.withAllowEmpty(true)
                  + applicationset.spec.template.spec.source.withRepoURL($._config.helmChartRepo)
                  + applicationset.spec.template.spec.source.withTargetRevision($._config.chartVersion)
                  + applicationset.spec.template.spec.source.withChart($._config.chart)
                  + applicationset.spec.template.spec.source.helm.withReleaseName('telesto-{{.telesto.id}}')
                  + applicationset.spec.template.spec.source.helm.withValuesObject(self.otelcolHelmChartValues)
                  + applicationset.spec.template.spec.destination.withServer('https://kubernetes.default.svc')
                  + applicationset.spec.template.spec.destination.withNamespace('telesto-{{.telesto.id}}'),
}
