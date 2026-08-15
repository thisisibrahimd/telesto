{
  local d = (import 'doc-util/main.libsonnet'),
  '#':: d.pkg(name='external-secrets', url='2.9.0/main.libsonnet', help='Generated Jsonnet library for External Secrets'),
  generators:: (import '_gen/generators/main.libsonnet'),
  nogroup:: (import '_gen/nogroup/main.libsonnet'),
}
