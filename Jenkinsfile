pipeline {
    agent {
        label 'mars'
    }

    parameters {
        string(
            name: 'K3S_HOST',
            defaultValue: 'localhost',
            description: 'Remote host or localhost where k3s will be installed (e.g., 192.168.1.100 or k3s-server.example.com)'
        )
        string(
            name: 'K3S_SSH_USER',
            defaultValue: 'ubuntu',
            description: 'SSH user for remote host (ignored if host is localhost)'
        )
        string(
            name: 'K3S_INSTALL_PATH',
            defaultValue: '/opt/k3s',
            description: 'Path on the remote host where k3s data will be stored'
        )
        string(
            name: 'RANCHER_HOSTNAME',
            defaultValue: '',
            description: 'Rancher FQDN (e.g., rancher.example.com)'
        )
        password(
            name: 'RANCHER_PASSWORD',
            defaultValue: '',
            description: 'Bootstrap password for Rancher admin'
        )
        string(
            name: 'RANCHER_REPLICAS',
            defaultValue: '3',
            description: 'Number of Rancher replicas'
        )
    }

    environment {
        RELEASE_NAME = 'rancher'
        NAMESPACE = 'cattle-system'
        TF_DIR = 'terraform'
        K3S_HOST = "${params.K3S_HOST}"
        K3S_SSH_USER = "${params.K3S_SSH_USER}"
        K3S_INSTALL_PATH = "${params.K3S_INSTALL_PATH}"
        KUBECONFIG_LOCAL = "${TF_DIR}/.kube/config"
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out repository...'
                checkout scm
            }
        }

        stage('Install k3s via SSH') {
            steps {
                script {
                    echo "Installing k3s on host: ${K3S_HOST} at path: ${K3S_INSTALL_PATH}"
                    
                    if ("${K3S_HOST}" == "localhost" || "${K3S_HOST}" == "127.0.0.1") {
                        // Local installation
                        echo 'Installing k3s locally...'
                        sh '''
                            if ! command -v k3s &> /dev/null; then
                                echo "k3s not found, installing..."
                                curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=644 sh -
                                
                                # Wait for k3s to be ready
                                for i in {1..30}; do
                                    if sudo kubectl get nodes > /dev/null 2>&1; then
                                        echo "k3s is ready"
                                        break
                                    fi
                                    echo "Waiting for k3s to be ready... ($i/30)"
                                    sleep 2
                                done
                            else
                                echo "k3s is already installed"
                            fi
                            
                            # Verify k3s status
                            sudo kubectl cluster-info
                        '''
                    } else {
                        // Remote installation via SSH
                        echo "Installing k3s on remote host ${K3S_HOST}..."
                        sh '''
                            SSH_CMD="ssh -o StrictHostKeyChecking=no ${K3S_SSH_USER}@${K3S_HOST}"
                            
                            # Check if SSH key is available
                            if [ -z "${SSH_KEY_PATH}" ]; then
                                echo "Using default SSH key (~/.ssh/id_rsa)"
                                SSH_CMD="$SSH_CMD -i ~/.ssh/id_rsa"
                            else
                                SSH_CMD="$SSH_CMD -i ${SSH_KEY_PATH}"
                            fi
                            
                            # Create install directory
                            $SSH_CMD "sudo mkdir -p ${K3S_INSTALL_PATH} && sudo chown ${K3S_SSH_USER}:${K3S_SSH_USER} ${K3S_INSTALL_PATH}" || true
                            
                            # Check if k3s is already installed
                            if $SSH_CMD "command -v k3s > /dev/null 2>&1"; then
                                echo "k3s is already installed on ${K3S_HOST}"
                            else
                                echo "Installing k3s on ${K3S_HOST}..."
                                $SSH_CMD "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=644 K3S_DATA_DIR=${K3S_INSTALL_PATH} sh -"
                                
                                # Wait for k3s to be ready
                                for i in {1..30}; do
                                    if $SSH_CMD "kubectl get nodes > /dev/null 2>&1"; then
                                        echo "k3s is ready on remote host"
                                        break
                                    fi
                                    echo "Waiting for k3s to be ready... ($i/30)"
                                    sleep 2
                                done
                            fi
                            
                            # Verify k3s status
                            $SSH_CMD "kubectl cluster-info"
                        '''
                    }
                }
            }
        }

        stage('Extract k3s Kubeconfig') {
            steps {
                script {
                    echo 'Extracting k3s kubeconfig...'
                    
                    if ("${K3S_HOST}" == "localhost" || "${K3S_HOST}" == "127.0.0.1") {
                        // Local kubeconfig extraction
                        sh '''
                            mkdir -p ${TF_DIR}/.kube
                            sudo cat /etc/rancher/k3s/k3s.yaml > ${KUBECONFIG_LOCAL}
                            chmod 600 ${KUBECONFIG_LOCAL}
                            
                            # Update kubeconfig to use localhost
                            sed -i.bak 's|https://[^:]*:6443|https://localhost:6443|g' ${KUBECONFIG_LOCAL}
                            
                            echo "Local kubeconfig extracted and saved"
                        '''
                    } else {
                        // Remote kubeconfig extraction via SCP
                        sh '''
                            mkdir -p ${TF_DIR}/.kube
                            
                            SCP_CMD="scp -o StrictHostKeyChecking=no"
                            
                            if [ -z "${SSH_KEY_PATH}" ]; then
                                SCP_CMD="$SCP_CMD -i ~/.ssh/id_rsa"
                            else
                                SCP_CMD="$SCP_CMD -i ${SSH_KEY_PATH}"
                            fi
                            
                            # Copy kubeconfig from remote host
                            echo "Copying kubeconfig from ${K3S_SSH_USER}@${K3S_HOST}:/etc/rancher/k3s/k3s.yaml"
                            $SCP_CMD "${K3S_SSH_USER}@${K3S_HOST}:/etc/rancher/k3s/k3s.yaml" ${KUBECONFIG_LOCAL} || {
                                echo "Failed to copy kubeconfig, trying with sudo..."
                                ssh -o StrictHostKeyChecking=no "${K3S_SSH_USER}@${K3S_HOST}" "sudo cat /etc/rancher/k3s/k3s.yaml" > ${KUBECONFIG_LOCAL}
                            }
                            
                            chmod 600 ${KUBECONFIG_LOCAL}
                            
                            # Update kubeconfig to use the remote host IP/hostname
                            sed -i.bak "s|https://[^:]*:6443|https://${K3S_HOST}:6443|g" ${KUBECONFIG_LOCAL}
                            
                            echo "Remote kubeconfig extracted and saved"
                            echo "Kubeconfig server updated to: https://${K3S_HOST}:6443"
                        '''
                    }
                }
            }
        }

        stage('Save k3s Config to Jenkins Credentials') {
            steps {
                script {
                    echo 'Saving k3s kubeconfig to Jenkins credentials store...'
                    sh '''
                        echo ""
                        echo "=============================================="
                        echo "k3s KUBECONFIG SAVED"
                        echo "=============================================="
                        echo ""
                        echo "Location: ${KUBECONFIG_LOCAL}"
                        echo ""
                        echo "To add this to Jenkins credentials store:"
                        echo "1. Go to Jenkins > Manage Credentials"
                        echo "2. Click 'Add Credentials' > 'Secret file'"
                        echo "3. Upload file: ${KUBECONFIG_LOCAL}"
                        echo "4. Set ID to: 'my_k3s_config'"
                        echo "5. Click Save"
                        echo ""
                        echo "Kubeconfig content preview:"
                        echo "---"
                        head -20 ${KUBECONFIG_LOCAL}
                        echo "---"
                        echo ""
                        echo "Or use the helper script:"
                        echo "  JENKINS_TOKEN=<token> ./scripts/save-kubeconfig-to-jenkins.sh ${KUBECONFIG_LOCAL}"
                        echo ""
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    echo 'Initializing Terraform...'
                    sh '''
                        cd ${TF_DIR}
                        terraform init
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    echo 'Planning Terraform deployment...'
                    sh '''
                        cd ${TF_DIR}
                        terraform plan \
                            -var="release_name=${RELEASE_NAME}" \
                            -var="namespace=${NAMESPACE}" \
                            -var="rancher_hostname=${RANCHER_HOSTNAME}" \
                            -var="rancher_replicas=${RANCHER_REPLICAS}" \
                            -var="rancher_password=${RANCHER_PASSWORD}" \
                            -var="install_k3s=false" \
                            -var="enable_vault=true" \
                            -out=tfplan
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    echo 'Applying Terraform configuration to deploy Rancher...'
                    sh '''
                        cd ${TF_DIR}
                        export KUBECONFIG=${KUBECONFIG_LOCAL}
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    echo 'Verifying Rancher deployment...'
                    sh '''
                        export KUBECONFIG=${KUBECONFIG_LOCAL}
                        kubectl rollout status deployment/rancher \
                            --namespace ${NAMESPACE} \
                            --timeout=5m
                    '''
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline execution completed'
            sh '''
                export KUBECONFIG=${KUBECONFIG_LOCAL}
                cd ${TF_DIR}
                terraform show || true
            '''
        }
        success {
            echo 'Rancher deployment successful!'
            sh '''
                export KUBECONFIG=${KUBECONFIG_LOCAL}
                cd ${TF_DIR}
                echo "=== Deployment Summary ==="
                terraform output -json 2>/dev/null | jq -r '
                  to_entries[] | 
                  select(.value.value != "disabled") |
                  "\(.key): \(.value.value)"
                ' || echo "Outputs not yet available"
            '''
        }
        failure {
            echo 'Rancher deployment failed. Check logs for details.'
        }
    }
}

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out repository...'
                checkout scm
            }
        }

        stage('Install k3s') {
            when {
                expression { return true } // Set to true to enable k3s installation
            }
            steps {
                script {
                    echo 'Installing k3s cluster...'
                    sh '''
                        if ! command -v k3s &> /dev/null; then
                            echo "k3s not found, installing..."
                            curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=644 sh -
                            
                            # Wait for k3s to be ready
                            for i in {1..30}; do
                                if sudo kubectl get nodes > /dev/null 2>&1; then
                                    echo "k3s is ready"
                                    break
                                fi
                                echo "Waiting for k3s to be ready... ($i/30)"
                                sleep 2
                            done
                        else
                            echo "k3s is already installed"
                        fi
                        
                        # Verify k3s status
                        sudo kubectl cluster-info
                    '''
                }
            }
        }

        stage('Extract k3s Kubeconfig') {
            when {
                expression { return true } // Set to true to save kubeconfig
            }
            steps {
                script {
                    echo 'Extracting k3s kubeconfig...'
                    sh '''
                        mkdir -p ${TF_DIR}/.kube
                        sudo cat /etc/rancher/k3s/k3s.yaml > ${TF_DIR}/.kube/config
                        chmod 600 ${TF_DIR}/.kube/config
                        
                        # Update kubeconfig to use localhost
                        sed -i.bak 's|https://[^:]*:6443|https://localhost:6443|g' ${TF_DIR}/.kube/config
                        
                        echo "Kubeconfig extracted and saved"
                    '''
                }
            }
        }

        stage('Save k3s Config to Jenkins Credentials') {
            steps {
                script {
                    echo 'Saving k3s kubeconfig to Jenkins credentials store...'
                    withEnv(["KUBECONFIG_FILE=${TF_DIR}/.kube/config"]) {
                        sh '''
                            # Read the kubeconfig
                            KUBECONFIG_CONTENT=$(cat ${KUBECONFIG_FILE} | base64 -w0)
                            
                            # Create Jenkins credentials using Jenkins CLI or REST API
                            # This uses Jenkins environment to create secret file credential
                            JENKINS_URL=${JENKINS_URL}
                            JENKINS_USER=${JENKINS_USER:-admin}
                            
                            # Alternative: Save to workspace for manual Jenkins credential creation
                            echo "Kubeconfig saved. Instructions to add to Jenkins:"
                            echo "1. Go to Jenkins > Manage Credentials"
                            echo "2. Click 'Add Credentials'"
                            echo "3. Select 'Secret file' as the credential type"
                            echo "4. Upload file: ${KUBECONFIG_FILE}"
                            echo "5. Set ID as: 'my_k3s_config'"
                            echo "6. Click Save"
                        '''
                    }
                }
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    echo 'Initializing Terraform...'
                    sh '''
                        cd ${TF_DIR}
                        terraform init
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    echo 'Planning Terraform deployment...'
                    sh '''
                        cd ${TF_DIR}
                        terraform plan \
                            -var="release_name=${RELEASE_NAME}" \
                            -var="namespace=${NAMESPACE}" \
                            -var="rancher_hostname=${RANCHER_HOSTNAME}" \
                            -var="rancher_replicas=${RANCHER_REPLICAS:-3}" \
                            -var="rancher_password=${RANCHER_PASSWORD}" \
                            -var="install_k3s=true" \
                            -out=tfplan
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    echo 'Applying Terraform configuration to deploy Rancher...'
                    sh '''
                        cd ${TF_DIR}
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    echo 'Verifying Rancher deployment...'
                    sh '''
                        export KUBECONFIG=${TF_DIR}/.kube/config
                        kubectl rollout status deployment/rancher \
                            --namespace ${NAMESPACE} \
                            --timeout=5m
                    '''
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline execution completed'
            sh '''
                cd ${TF_DIR}
                terraform show
            '''
        }
        success {
            echo 'Rancher deployment successful!'
            sh '''
                cd ${TF_DIR}
                echo "=== Deployment Summary ==="
                terraform output -json | jq -r '
                  to_entries[] | 
                  select(.value.value != "disabled") |
                  "\(.key): \(.value.value)"
                '
            '''
        }
        failure {
            echo 'Rancher deployment failed. Check logs for details.'
        }
    }
}
