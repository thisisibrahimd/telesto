local k = import 'ksonnet-util/kausal.libsonnet';

{
  wrap(name): { [name]+: name },
  ns(name): k.core.v1.namespace.new(name),
}
