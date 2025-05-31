#!/usr/bin/env bash

# Script to create a Vast.ai instance that "feels at home" and clones a private GitHub repo via SSH:
# - Injects your local private SSH key (base64-encoded) into the container on startup
# - Clones the repository over SSH into the container's workspace

# -----------------------------
# Configuration: edit these variables
# -----------------------------

# Check if OFFER_ID is provided as command line argument
if [ $# -eq 0 ]; then
    echo "No OFFER_ID provided, searching for cheapest offer..."
    CHEAPEST_OFFER_ID=$(vastai search offers --limit 1 -o "dph" --raw | jq -r '.[].ask_contract_id')
    if [[ -z "${CHEAPEST_OFFER_ID}" ]]; then
        echo "Error: Failed to find any available offers"
        exit 1
    fi
    echo "Found cheapest offer ID: ${CHEAPEST_OFFER_ID}"
    OFFER_ID="${CHEAPEST_OFFER_ID}"
else
    OFFER_ID="$1"
    echo "Using provided offer ID: ${OFFER_ID}"
fi

IMAGE="peterzhizhin/images:modded_nanogpt_dev_container"

# 3) GITHUB_REPO_SSH: the SSH URL of your private Git repository, e.g.:
#      git@github.com:myusername/myprivateproject.git
#    Make sure that the SSH key you'll inject has read access to this repo.
GITHUB_REPO_SSH="git@github.com:PeterZhizhin/modded-nanogpt.git"

# 4) WORKDIR: where inside the container to clone your repo. Vast.ai default workspace is /workspace.
WORKDIR="/root/modded_nanogpt"

# 6) LOCAL_SSH_KEY_PATH: path to your local private SSH key that has access to GitHub.
#    This is a VastAI-specific key that should be added to your GitHub account.
LOCAL_SSH_KEY_PATH="$HOME/.ssh/vastai_key"

# -----------------------------
# Validate that local SSH key exists
# -----------------------------
if [[ ! -f "${LOCAL_SSH_KEY_PATH}" ]]; then
  echo "ERROR: VastAI SSH key not found at ${LOCAL_SSH_KEY_PATH}"
  echo "Please run: ssh-keygen -t ed25519 -f ~/.ssh/vastai_key -N \"\" -C \"vastai-key\""
  echo "Then add the public key to your GitHub account:"
  echo "cat ~/.ssh/vastai_key.pub"
  exit 1
fi

# -----------------------------
# Base64-encode the private SSH key to pass into the container
# -----------------------------
# We use `base64 -w0` on Linux to produce a single-line string.
SSH_KEY_B64=$(base64 -w0 "${LOCAL_SSH_KEY_PATH}")
if [[ -z "${SSH_KEY_B64}" ]]; then
  echo "ERROR: Failed to base64-encode your private key."
  exit 1
fi

# -----------------------------
# Build the onstart command chain
# -----------------------------
# This will run inside the container as root:
#   1. Create /root/.ssh and write the private key (decoded from $SSH_KEY_B64)
#   2. chmod 600 the key, add GitHub to known_hosts
#   3. Clone the private repo via SSH into ${WORKDIR}/myproject

read -r -d '' ONSTART_CMDS << 'EOF'
set -e

# 1) Inject private SSH key:
mkdir -p /root/.ssh
echo "Decoding SSH key into /root/.ssh/id_rsa..."
echo "$SSH_KEY_B64" | base64 -d > /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa

# 2) Add GitHub to known_hosts to avoid interactive prompt:
ssh-keyscan github.com >> /root/.ssh/known_hosts

# 3) Clone the private repo via SSH:
echo "Cloning ${GITHUB_REPO_SSH} into ${WORKDIR}..."
rm -rf "${WORKDIR}" 2>/dev/null || true
git clone "${GITHUB_REPO_SSH}" "${WORKDIR}"

EOF

# Remove leading/trailing whitespace/newlines and join lines with " && ":
ONSTART_CMD_CLEAN="$(
  echo "${ONSTART_CMDS}" \
    | sed ':a;N;$!ba;s/\n/ && /g'
)"

# -----------------------------
# Create the Vast.ai instance
# -----------------------------
# We pass:
#   • OFFER_ID: your chosen offer
#   • --ssh: to allow SSH access for you as root
#   • --direct: so cursor's port is publicly accessible (no proxy)
#   • --env: 
#       -e SSH_KEY_B64=${SSH_KEY_B64}   → the base64-encoded private key
#       -e GITHUB_REPO_SSH=${GITHUB_REPO_SSH}
#       -e WORKDIR=${WORKDIR}
#   • --onstart-cmd: the commands to decode key, clone, and launch Cursor

echo "Creating Vast.ai instance..."
vastai create instance "${OFFER_ID}" \
  --image "${IMAGE}" \
  --ssh \
  --direct \
  --env "-e SSH_KEY_B64=${SSH_KEY_B64} -e GITHUB_REPO_SSH=${GITHUB_REPO_SSH} -e WORKDIR=${WORKDIR}" \
  --onstart-cmd "${ONSTART_CMD_CLEAN}"

echo
echo "▶ Instance create command submitted."
echo "  Use 'vastai show instances -q' to get the new instance ID."
echo "  Then run 'vastai show instance <instance_id> --raw' to retrieve its public IP."

echo "SSH commands to run"
vastai show instances --raw | jq -r '.[] | "ssh -p \(.ssh_port) root@\(.ssh_host) -L 8080:localhost:8080"'