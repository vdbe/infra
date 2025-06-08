# Infra

## TODO
- [ ] Add flake level vars: https://git.clan.lol/clan/clan-core/issues/3821
- [ ] Rotate all shared "flake level" vars after adding flake level vars


## Loki
### Logcli
https://grafana.com/docs/loki/latest/query/logcli/getting-started/

configfile: https://github.com/grafana/loki/pull/433#issuecomment-478200511

### Endpoints
https://grafana.com/docs/loki/latest/reference/loki-http-api/

- [Ingest endpoints](https://grafana.com/docs/loki/latest/reference/loki-http-api/#ingest-endpoints)
  Push endpoint for promtail/alloy

- [Query endpoints](https://grafana.com/docs/loki/latest/reference/loki-http-api/#ingest-endpoints)
  Pull endpoint for grafana/...

- [Status endpoints](https://grafana.com/docs/loki/latest/reference/loki-http-api/#ingest-endpoints)
  Maybe localhost for collector like alloy?

- Remaning endpoints
  SHould only be for loki itself
  

## Grafana
