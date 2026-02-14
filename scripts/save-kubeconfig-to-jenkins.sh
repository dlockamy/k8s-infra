#!/bin/bash

# Script to save k3s kubeconfig to Jenkins credentials store
# This script uses the Jenkins CLI to create a secret file credential

set -e

# Configuration
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_TOKEN="${JENKINS_TOKEN}"
KUBECONFIG_FILE="${1:-terraform/.kube/config}"
CREDENTIAL_ID="my_k3s_config"

# Check if kubeconfig file exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG_FILE"
    exit 1
fi

# Check if Jenkins token is provided
if [ -z "$JENKINS_TOKEN" ]; then
    echo "Error: JENKINS_TOKEN environment variable not set"
    echo "Usage: JENKINS_TOKEN=<your-token> $0 [kubeconfig_path]"
    exit 1
fi

echo "Saving kubeconfig to Jenkins credentials store..."
echo "Jenkins URL: $JENKINS_URL"
echo "Credential ID: $CREDENTIAL_ID"
echo "Kubeconfig file: $KUBECONFIG_FILE"

# Create the XML credential payload
KUBECONFIG_CONTENT=$(cat "$KUBECONFIG_FILE")

XML_PAYLOAD=$(cat <<EOF
<org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>$CREDENTIAL_ID</id>
  <description>k3s Kubeconfig</description>
  <fileName>kubeconfig.yaml</fileName>
  <secretBytes>`echo -n "$KUBECONFIG_CONTENT" | base64`</secretBytes>
</org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl>
EOF
)

# Send credential to Jenkins
curl -X POST \
  -u "$JENKINS_USER:$JENKINS_TOKEN" \
  -H "Content-Type: application/xml" \
  -d "$XML_PAYLOAD" \
  "$JENKINS_URL/credentials/store/system/domain/_/createCredentials"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Kubeconfig successfully saved to Jenkins credentials store"
    echo "  Credential ID: $CREDENTIAL_ID"
    echo ""
    echo "You can now use this credential in your Jenkins pipeline:"
    echo "  withCredentials([file(credentialsId: 'my_k3s_config', variable: 'KUBECONFIG')]) {"
    echo "    // Your pipeline steps here"
    echo "  }"
else
    echo "✗ Failed to save kubeconfig to Jenkins"
    exit 1
fi
