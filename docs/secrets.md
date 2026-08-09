# Secret Operations

Kubernetes Secrets are committed only as SOPS-encrypted YAML. Run these
commands from the repository root with `SOPS_AGE_KEY` loaded by `direnv`.

Never write decrypted output to a file, commit plaintext, edit encrypted values
manually, or change a `sops:` block. Use `sops` as the editor so plaintext
exists only in the editor process and the file is encrypted again on save.

## Check an encrypted file

Confirm that SOPS recognizes the file as encrypted:

```sh
sops filestatus kubernetes/infrastructure/controllers/secret.yaml
```

Verify that the complete file decrypts without printing it:

```sh
sops --decrypt kubernetes/infrastructure/controllers/secret.yaml >/dev/null
```

Inspect one value only when its contents are needed:

```sh
sops --decrypt \
  --extract '["stringData"]["users.yml"]' \
  kubernetes/infrastructure/controllers/secret.yaml
```

Parse an embedded YAML value without displaying it:

```sh
sops --decrypt \
  --extract '["stringData"]["users.yml"]' \
  kubernetes/infrastructure/controllers/secret.yaml \
  | yq eval '.' - >/dev/null
```

## Edit an encrypted file

Open the file through SOPS. Replace `nano` with the preferred editor:

```sh
sops kubernetes/infrastructure/controllers/secret.yaml
```

The editor shows the decrypted YAML. Change only the intended value, save, and
exit. SOPS encrypts the protected fields again before replacing the file.

## Authelia users

Authelia reads its file-backed user database from
`stringData.users.yml` in `kubernetes/infrastructure/controllers/secret.yaml`.

Generate an Argon2id password hash interactively using the running Authelia
version:

```sh
kubectl exec -it --namespace authelia \
  deployment/authelia --container authelia -- \
  authelia crypto hash generate argon2 \
  --iterations 1 \
  --memory 65536 \
  --parallelism 8 \
  --salt-size 16
```

Restart Authelia so it loads the updated database immediately, then check its startup logs:

```sh
kubectl rollout restart deployment/authelia --namespace authelia

kubectl rollout status deployment/authelia --namespace authelia --timeout=180s

kubectl logs --namespace authelia deployment/authelia --since=5m
```
