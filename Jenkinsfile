pipeline {
    agent {
        label 'mars'
    }

    environment {
        RELEASE_NAME = 'rancher'
        NAMESPACE = 'cattle-system'
        TF_DIR = 'terraform'
        KUBECONFIG = credentials('kubeconfig')
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out repository...'
                checkout scm
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
