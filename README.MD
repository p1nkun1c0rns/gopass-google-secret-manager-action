# Deploy Google Cloud Run Service Action

![inbound-build](https://github.com/p1nkun1c0rns/gopass-google-secret-manager-action/workflows/Pre-Build%20Image/badge.svg)
![event-store-build](https://github.com/p1nkun1c0rns/gopass-google-secret-manager-action/workflows/Test/badge.svg)

A Github Action that synchronizes the contents of a [gopass](https://github.com/gopasspw/gopass) repository to the [Google Cloud Secret Manager](https://cloud.google.com/secret-manager).

## gopass to Secret Manager sync

gopass repository looking like

```sh
# gopass list
gopass
├── my-service
│   ├── mySecret
│   └── yourSecret
└── other-secret
    ├── theSecret
    └── aSecret
```

becomes the following Secret Manager structure:

```sh
# gcloud secrets list
NAME                      CREATED              REPLICATION_POLICY  LOCATIONS
my-service_mySecret     2020-09-26T20:53:06  user_managed        europe-west3
my-service_yourSecret   2020-09-26T22:08:37  user_managed        europe-west3
other-secret_theSecret  2020-09-26T22:08:39  user_managed        europe-west3
other-secret_aSecret    2020-09-26T19:11:09  user_managed        europe-west3
```

Since Secret Manager keys need to match GCP resource id restrictions all slashes (`/`) in gopass are mapped to underscores (`_`).

## gopass secret history

Every history entry of a gopass secret:

```sh
# gopass history my-service/mySecret
6751b67b7a17f372478c9feda7357a28c65da407 - heubeck <heubeck@mediamarktsaturn.com> - 2020-09-27T00:10:27+02:00 - Save secret to my-service/mySecret:
afdd4fdef1ce37935110028923182454c4d76059 - heubeck <heubeck@mediamarktsaturn.com> - 2020-09-26T22:16:48+02:00 - Save secret to my-service/mySecret:
2651a49d85621ca89746d404b8f8f940ec218133 - heubeck <heubeck@mediamarktsaturn.com> - 2020-09-26T18:54:35+02:00 - Save secret to my-service/mySecret:
497256fc7f5556b233a805fe0bc54929ba645792 - heubeck <heubeck@mediamarktsaturn.com> - 2020-09-26T17:58:51+02:00 - Save secret to my-service/mySecret:
```

will become a separate version of the Secret Managers secrets:

```sh
# gcloud secrets versions list my-service_mySecret
NAME  STATE    CREATED              DESTROYED
4     enabled  2020-09-26T22:11:23  -
3     enabled  2020-09-26T22:08:44  -
2     enabled  2020-09-26T22:08:42  -
1     enabled  2020-09-26T22:08:40  -
```

The first history entry will be version 1, the latest entry becomes the highest version.

## Input

### Parameter

| Parameter | Description | Default | Required | Reference |
|---|---|---|---|---|
| `project_id` | GCP project ID |  | true | [gcloud](https://cloud.google.com/sdk/gcloud/reference#--project) |
| `service_account_key` | Base64 encoded JSON key for GCP service account with the "Secret Manager Admin" role granted |  | true | [gcloud auth](https://cloud.google.com/sdk/gcloud/reference/auth/activate-service-account#--key-file) |
| `secret_locations` | GCP locations(s) as comma separated list to replicate the secrets |  | true | [gcloud secrets create](https://cloud.google.com/sdk/gcloud/reference/secrets/create#--locations) |
| `gpg_public_key` | Base64 encoded public part of the GPG key |  | true | [see below](https://github.com/p1nkun1c0rns/gopass-google-secret-manager-action#gpg_public_key) |
| `gpg_private_key` | Base64 encoded private part of the GPG key |  | true | [see below](https://github.com/p1nkun1c0rns/gopass-google-secret-manager-action#gpg_private_key) |
| `github_token` | Token for the repo. Can be passed in using ${{ secrets.GITHUB_TOKEN }} |  | true |  |
| `gopass_repository` | gopass repository to synchronize from | current repo | false |  |
| `debug` | Whether the gcloud commands should be printed to output | `false` | false |  | 

### `gpg_public_key`

Public part of the GPG key used by this action to access the gopass repository.
The value for this parameter can be created as follows:

```sh
# export to file
gpg --output public_key.gpg --armor --export E3C201F1FC162517237EB68F614A1B46F0583426
# create a one line base64 from file
cat public_key.gpg | base64 -w 0
```

### `gpg_private_key`

Private part of the GPG key used by this action to access the gopass repository.
The value for this parameter can be created as follows:

```sh
# export to file
gpg --output private_key.gpg --armor --export-secret-key E3C201F1FC162517237EB68F614A1B46F0583426
# create a one line base64 from file
cat private_key.gpg | base64 -w 0
```

## Output

| Parameter | Description | Example |
|---|---|---|
| log | Text output about the created/updated secrets | my-service/mySecret(my-service_mySecret) created; other-service/theSecret(other-service_theSecret) updated to 2; |

## Usage

The recommended way of use is to create a `.github/workflows/sync.yml` job description like the following in the gopass repository:

```yaml
name: Synchronize
on: push

jobs:
  sync:
    name: Synchronize to Google Secret Manager
    runs-on: ubuntu-latest
    steps:
      - name: gopass Synchronize
        uses: p1nkun1c0rns/gopass-google-secret-manager-action@master
        with:
          service_account_key: ${{ secrets.GOOGLE_SERVICEACCOUNT_KEY }}
          project_id: your-gcp-project-id
          secret_locations: europe-west3
          gpg_public_key: ${{ secrets.GPG_PUBLIC_KEY }}
          gpg_private_key: ${{ secrets.GPG_PRIVATE_KEY }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

Every change in the gopass repository will be immediately synchronized to the GCP Secret Manager, gopass will keep the `.github` folder, you can use it as usual.

### Prebuild latest image

Instead of using the latest (`@master`) or a tagged version there's always a prebuild image in the `action` branch:

```yaml
  - name: gopass Synchronize
    uses: p1nkun1c0rns/gopass-google-secret-manager-action@action
```

## Contribution

***Welcomed***

## Open topics

Right now, the sync is unidirectional and append only.
That means, that new gopass history entries are added as new secret versions and missing secrets are created, 
but removed gopass entries will be deleted in secret manager.

Furthermore, there's no back-sync to the gopass repository, neither about which secrets were created/updated in Secret Manager
nor are manual changes in the Secret Manager corrected by the next sync from gopass.
