#!/usr/bin/env bats

# global variables ############################################################
IMAGE="deploy-google-cloud-run-action"
CST_VERSION="latest" # version of GoogleContainerTools/container-structure-test
HADOLINT_VERSION="v1.17.6-9-g550ee0d-alpine"

# build container to test the behavior ########################################
@test "build container" {
  docker build -t $IMAGE . >&2
}

# functions ###################################################################

function debug() {
  status="$1"
  output="$2"
  if [[ ! "${status}" -eq "0" ]]; then
  echo "status: ${status}"
  echo "output: ${output}"
  fi
}

###############################################################################
## test cases #################################################################
###############################################################################

## general cases ##############################################################
###############################################################################

@test "markdown linting" {
  docker run --rm -i -v pwd:/workspace wpengine/mdl /workspace
  debug "${status}" "${output}" "${lines}"
  [[ "${status}" -eq 0 ]]
}

@test "yaml linting" {
  docker run --rm -i -v pwd:/data cytopia/yamllint .
  debug "${status}" "${output}" "${lines}"
  [[ "${status}" -eq 0 ]]
}

@test "dockerfile linting" {
  docker run --rm -i hadolint/hadolint:$HADOLINT_VERSION < Dockerfile
  debug "${status}" "${output}" "${lines}"
  [[ "${status}" -eq 0 ]]
}

@test "container-structure-test" {

  # init
  mkdir -p $HOME/bin
  export PATH=$PATH:$HOME/bin

  # check the os
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
          cst_os="linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
          cst_os="darwin"
  else
          skip "This test is not supported on your OS platform 😒"
  fi

  # donwload the container-structure-test binary
  cst_bin_name="container-structure-test-$cst_os-amd64"
  cst_download_url="https://storage.googleapis.com/container-structure-test/$CST_VERSION/$cst_bin_name"

  if [ ! -f "$HOME/bin/container-structure-test" ]; then
    curl -LO $cst_download_url
    chmod +x $cst_bin_name
    mv $cst_bin_name $HOME/bin/container-structure-test
  fi

  container-structure-test test --image ${IMAGE} -q --config tests/structure_test.yaml

  debug "${status}" "${output}" "${lines}"

  [[ "${status}" -eq 0 ]]
}
