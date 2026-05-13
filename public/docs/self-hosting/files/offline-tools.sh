#!/bin/bash

timestamp() {
  date +"%Y-%m-%d %T"
}

error() {
  flag=$(timestamp)
  echo -e "\033[31m ERROR [$flag] >> $* \033[0m"
  exit 1
}

info() {
  flag=$(timestamp)
  echo -e "\033[36m INFO [$flag] >> $* \033[0m"
}

warn() {
  flag=$(timestamp)
  echo -e "\033[33m WARN [$flag] >> $* \033[0m"
}

debug() {
  flag=$(timestamp)
  echo -e "\033[35m DEBUG [$flag] >> $* \033[0m"
}

print() {
  flag=$(timestamp)
  echo -e "\033[1;32m\033[1m INFO [$flag] >> $* \033[0m"
}

print_duration() {
  local start_time=$1
  # shellcheck disable=SC2155
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  echo -e "\033[1;34m\033[1m INFO [$(timestamp)] >> Duration: $duration seconds \033[0m"
}

wait_cluster_ready() {
    while true; do
        if kubectl get nodes | grep "NotReady" &> /dev/null; then
           warn "Waiting for all nodes to be Ready..."
           sleep 3
        else
           break
        fi
    done
}

# Print supported environment variables and usage (triggered by -h or --help)
print_env_help() {
  cat <<'HELP'
Supported environment variables (loaded from ./sealos.env, required):

Cluster / resource settings
  SEALOS_V2_MAX_POD                  Max pods per node (default: 180)
  SEALOS_V2_OPENEBS_STORAGE          OpenEBS storage path (default: /data/openebs)
  SEALOS_V2_OPENEBS_VGNAME           OpenEBS LVM volume group name (default: "")
  SEALOS_V2_OPENEBS_NFS              OpenEBS NFS endpoint (default: "")
  SEALOS_V2_CONTAINERD_STORAGE       Containerd data path (default: /data/containerd)
  SEALOS_V2_CONTAINERD_RUN_STORAGE   Containerd run path (default: /data/containerd_run)
  SEALOS_V2_CONTAINERS_STORAGE       Containers storage path (default: /data/containers)
  SEALOS_V2_KUBELET_STORAGE          Kubelet data path (default: /data/kubelet)
  SEALOS_V2_ETCD_STORAGE             Etcd data path (default: /var/lib/etcd)
  SEALOS_V2_DATA                     Sealos data path (default: /data/sealos)
  SEALOS_V2_POD_CIDR                 Pod network CIDR (default: 10.0.0.0/10)
  SEALOS_V2_SERVICE_CIDR             Service network CIDR (default: 10.192.0.0/12)
  SEALOS_V2_SERVICE_NODEPORT_RANGE   Service NodePort range (default: 30000-50000)
  SEALOS_V2_VIP                      Cluster VIP (default: 169.254.20.20)
  SEALOS_V2_CILIUM_NATIVE            Enable native cilium route mode (default: false)
  SEALOS_V2_CILIUM_MASKSIZE          Cilium mask size (default: 24)
  SEALOS_V2_CILIUM_INTERFACE         Cilium interface (default: eth0)
  SEALOS_V2_VLOGS_VECTOR             Use vector log collector (default: false)

Nodes / SSH (for cluster install)
  SEALOS_V2_MASTERS                  Master nodes list, comma separated (e.g. 192.0.2.10:22)
  SEALOS_V2_NODES                    Worker nodes list, comma separated
  SEALOS_V2_SSH_KEY                  SSH private key path (default: $HOME/.ssh/id_rsa)
  SEALOS_V2_SSH_PASSWORD             SSH password (optional, not recommended)

Cloud / TLS / runtime
  SEALOS_V2_CLOUD_DOMAIN             Cloud domain to expose Sealos Cloud
  SEALOS_V2_CLOUD_PORT               Cloud HTTPS port (default: 443)
  SEALOS_V2_DRY_RUN                  If "true", perform a dry run (default: false)
  SEALOS_V2_ENABLE_ACME              If "true", enable ACME for automatic TLS certs (default: false)
  SEALOS_V2_CERT_PATH                Path to TLS certificate PEM file
  SEALOS_V2_KEY_PATH                 Path to TLS private key PEM file
  SEALOS_V2_NETWORK_OFFLINE          Enable offline network mode (default: false)
  SEALOS_V2_USE_DNSMASQ              Enable dnsmasq addon (default: false)
  SEALOS_V2_USE_NTP                  Enable ntp addon (default: false)
  SEALOS_V2_NGINX_LOCATION           Nginx data path (default: /data/nginx)

S3 / billing / feature
  SEALOS_V2_S3_PROVIDER              S3 provider (default: s3)
  SEALOS_V2_S3_DEFAULT_SIZE          Default object storage size (default: 10Gi)
  SEALOS_V2_S3_ONE                   Unified S3 account mode (default: true)
  SEALOS_V2_S3_BUCKET                S3 bucket name
  SEALOS_V2_S3_ACCESS_KEY            S3 access key
  SEALOS_V2_S3_SECRET_KEY            S3 secret key
  SEALOS_V2_S3_REGION                S3 region
  SEALOS_V2_S3_REGION_ENDPOINT       S3 region endpoint
  SEALOS_V2_S3_BACKUP_BUCKET         Backup S3 bucket
  SEALOS_V2_S3_BACKUP_ACCESS_KEY     Backup S3 access key
  SEALOS_V2_S3_BACKUP_SECRET_KEY     Backup S3 secret key
  SEALOS_V2_S3_BACKUP_REGION         Backup S3 region
  SEALOS_V2_S3_BACKUP_REGION_ENDPOINT Backup S3 region endpoint
  SEALOS_V2_CURRENCY                 Currency for billing, "cny" or "usd" (default: "cny")
  SEALOS_V2_DB_VERSION               DB version selector (default: v23.1.11)
  SEALOS_V2_FEATURE                  Feature list, comma separated (default: import_ide)
  SEALOS_V2_BINDING_DOCUMENTATION_LINK Binding docs URL
  SEALOS_V2_GTM_ID                   GTM ID
  SEALOS_V2_META_SRC                 Meta script URL

Usage examples
  Edit existing sealos.env and install:
     ./sealos-pro.sh env show SEALOS_V2_CLOUD_DOMAIN
     ./sealos-pro.sh env set SEALOS_V2_CLOUD_DOMAIN example.nip.io
     ./sealos-pro.sh install

  Re-render dynamic defaults (auto domain from hostname -I):
     ./sealos-pro.sh install --default

Configuration file rules
  - ./sealos.env must exist; install exits immediately when it is missing.
  - install --default only refreshes rendered keys (currently SEALOS_V2_CLOUD_DOMAIN).
  - All other values keep the current defaults from the existing sealos.env.

Image handling
  Missing images are detected with a pre-flight inspect when an optional image reference is provided; unavailable components are skipped with warnings and summarized after installation.


Security note
  Do not run random scripts from the internet. Prefer reviewing the script and using exported env vars or secret managers for sensitive values.
HELP
}

: "${DEPLOYED_COUNT:=0}"
: "${SKIPPED_COUNT:=0}"
if ! declare -p DEPLOYED_IMAGES >/dev/null 2>&1; then
  declare -ag DEPLOYED_IMAGES=()
fi
if ! declare -p SKIPPED_IMAGES >/dev/null 2>&1; then
  declare -ag SKIPPED_IMAGES=()
fi
if ! declare -p SKIPPED_REASONS >/dev/null 2>&1; then
  declare -ag SKIPPED_REASONS=()
fi
if ! declare -p IMAGE_PULL_CACHE >/dev/null 2>&1; then
  declare -Ag IMAGE_PULL_CACHE=()
fi

sealos_cloud_config_dir="/root/.sealos/cloud"
run_and_log() {
  local cmd="$2"
  local sealos_cloud_config_dir="${sealos_cloud_config_dir}"
  local dry_run="$1"
  if [[ "${dry_run,,}" == "true" ]]; then
    info "[Dry Run] Command skipped: $cmd"
    return 0
  fi
  echo "$(date '+%Y-%m-%d %H:%M:%S') $cmd" >> "$sealos_cloud_config_dir/install.log"
  eval "$cmd"
  debug "[Step] Command completed: $cmd"
}

run_and_log_graceful() {
  local dry_run="$1"
  local cmd="$2"
  local image_ref="${3:-}"
  if [[ -n "$image_ref" ]]; then
    if [[ "${dry_run,,}" == "true" ]]; then
      info "[Dry Run] Image availability check skipped for - $image_ref"
      run_and_log "$dry_run" "$cmd"
      return 0
    fi
    set +e
    sealos inspect "docker://$image_ref" >/dev/null
    # shellcheck disable=SC2116
    code=$(echo $?)
    # shellcheck disable=SC2181
    warn "Checking image availability - $image_ref; exit code: $code"
    if [[ $code -ne 0 ]]; then
      warn "Image not found, skipping deployment - $image_ref"
      return
    fi
    set -e
    info "Image found, proceeding with deployment - $image_ref"
    run_and_log "$dry_run" "$cmd"
    return
  fi
  run_and_log "$dry_run" "$cmd"
  return
}

is_absolute_path() {
    [[ "$1" = /* ]]
}


fetch_configmap_field() {
    local name=$1
    local jsonpath=$2
    local namespace=${3:-sealos-system}
    local retries=${4:-5}
    local delay=${5:-3}
    local value=""
    for ((attempt=1; attempt<=retries; attempt++)); do
        value=$(kubectl get configmap "${name}" -n "${namespace}" -o "jsonpath=${jsonpath}" --request-timeout=30s 2>/dev/null)
        if [[ -n "${value}" ]]; then
            printf '%s' "${value}"
            return 0
        fi
        sleep "${delay}"
    done
    return 1
}

# ============================================================================
# Feature Flag Utilities - Dynamic feature management for SEALOS_V2_FEATURE
# ============================================================================

# Global variables for feature caching
declare -A ENABLED_FEATURES=()
declare -a KNOWN_FEATURES=("gpu" "gpu_hami" "online_ide" "import_ide" "gitea_template")
FEATURES_INITIALIZED=false

# Initialize feature flags by parsing SEALOS_V2_FEATURE environment variable
# This function caches results to avoid repeated parsing
init_feature_flags() {
    if [[ "$FEATURES_INITIALIZED" == "true" ]]; then
        return 0
    fi

    local feature_var="${SEALOS_V2_FEATURE:-}"

    if [[ -z "$feature_var" ]]; then
        debug "SEALOS_V2_FEATURE is empty or not set"
        FEATURES_INITIALIZED=true
        return 0
    fi

    # Convert to lowercase and fix typo automatically
    feature_var="${feature_var,,}"

    # Split by comma and process each feature
    local feature
    local -a features
    IFS=',' read -ra features <<< "$feature_var"
    for feature in "${features[@]}"; do
        # Trim whitespace
        feature="${feature// /}"

        if [[ -n "$feature" ]]; then
            if [[ " ${KNOWN_FEATURES[*]} " =~ " ${feature} " ]]; then
                ENABLED_FEATURES["$feature"]="true"
                debug "Feature enabled: $feature"
            else
                debug "Unknown feature ignored: $feature"
            fi
        fi
    done

    FEATURES_INITIALIZED=true
    debug "Feature initialization completed. Enabled features: ${!ENABLED_FEATURES[*]}"
}

# Check if a specific feature is enabled
# Usage: if is_feature_enabled "gpu"; then ... fi
# Returns: 0 if feature is enabled, 1 if not enabled
is_feature_enabled() {
    local feature="$1"

    # Ensure features are initialized
    init_feature_flags

    # Convert to lowercase for case-insensitive matching
    feature="${feature,,}"

    if [[ "${ENABLED_FEATURES[$feature]:-false}" == "true" ]]; then
        return 0
    else
        return 1
    fi
}
