
{
  dnsnames: {
    cnpg: {
      new(name, namespace): [
        std.format('%s-%s%s', [name, perm, domain])
        for perm in ['rw', 'r', 'ro']
        for domain in ['', '.' + namespace, '.' + namespace + '.svc']
      ]
    }
  }
}
