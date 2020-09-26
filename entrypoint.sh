#!/bin/bash

function enableDebug() {
  if [ "$INPUT_DEBUG" = "true" ]; then
    set -x
  fi
}

function disableDebug() {
  set +x
}

set -e
set -o pipefail

# Initialize GPG keys

echo "$INPUT_GPG_PUBLIC_KEY" | base64 -d > gpg.pub
trap "{ rm -f gpg.pub; }" EXIT
echo "$INPUT_GPG_PRIVATE_KEY" | base64 -d > gpg.sec
trap "{ rm -f gpg.sec; }" EXIT

enableDebug
gpg --import gpg.pub
gpg --allow-secret-key-import --import gpg.sec
disableDebug

if [ "$INPUT_DEBUG" = "true" ]; then
  echo "=== gcloud version ==="
  gcloud version
  echo "====== gpg keys ======"
  gpg --list-keys
  echo "======================"
fi

# Clone gopass repository
git clone "https://${GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/${INPUT_GOPASS_REPOSITORY:-$GITHUB_REPOSITORY}.git" ~/.password-store

if [ "$INPUT_DEBUG" = "true" ]; then
  echo "=== gopass list ==="
  gopass list -f
  echo "==================="
fi

# Initialize gcloud sdk

echo "$INPUT_SERVICE_ACCOUNT_KEY" | base64 -d >key.json
trap "{ rm -f key.json; }" EXIT

enableDebug
gcloud auth activate-service-account --key-file=key.json --project="$INPUT_PROJECT_ID"
disableDebug

# turn off globbing
set -f
# split on new line
IFS='
'

log=""

# Iterate over secrets
for s in $(gopass list -f); do
  # replace slashes by underscores since they are not allowed as secret identifier
  secret_key=${s/\//_}
  # count revisions since there's no other mapping possibility right now
  gopass_revision=0
  # check if secret does already exist (there's always one line additional output)
  secret_listed=$(gcloud secrets list --filter "$secret_key" 2>&1 | wc -l)
  if [ $secret_listed -eq 1 ]; then
    secret_exists="false"
  else
    secret_exists="true"
  fi
  # Iterate over reverse history (newest entries are first printed by history)
  for h in $(gopass history -p $s | tac); do
    gopass_revision=$(expr $gopass_revision + 1)
    # split history entry into its parts and creates a variable for each, e.g.: "497256fc7f5556b233a805fe0bc54929ba645792 - heubeck <heubeck@mediamarktsaturn.com> - 2020-09-26T15:58:51Z - Save secret to my-service/mySecret: - test-password"
    eval "$(echo $h | awk -F' - ' '{print "commit_sha=\""$1"\" commit_author=\""$2"\" commit_time=\""$3"\" commit_msg=\""$4"\" secret=\""$5"\""}')"
    if [ $secret_exists = "false" ]; then
      # secret does not exist, creating it
      echo "Creating secret $secret_key revision $gopass_revision of $commit_author at $commit_time"
      echo "$secret" | gcloud secrets create "$secret_key" --locations="$INPUT_SECRET_LOCATIONS" --replication-policy=user-managed --labels=create-commit="$commit_sha" --data-file=-
      secret_exists="true"
      log="$log$s($secret_key) created; "
    else
      # count existing secret versions (there's always one line additional output)
      sm_revision=$(expr $(gcloud secrets versions list "$secret_key" 2>&1 | wc -l) - 1)
      if [ $sm_revision -lt $gopass_revision ]; then
        # secret revision does not exist yet, adding it
        echo "Creating secret $secret_key revision $gopass_revision of $commit_author at $commit_time"
        echo "$secret" | gcloud secrets versions add "$secret_key" --data-file=-
        log="$log$s($secret_key) updated to $gopass_revision; "
      fi
    fi
  done
done

echo ::set-output name=log::"$log"
