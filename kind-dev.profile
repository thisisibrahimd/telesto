app-sync: reflex -r '.go$' -R '^templates/' -s -- just build-local && kubectl rollout restart deploy/telesto-app
tk-sync: reflex -r '.libsonnet$' -s -- just tk-apply local
