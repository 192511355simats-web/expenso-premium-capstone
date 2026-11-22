pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        skipDefaultCheckout(true)
    }

    // Webhooks can trigger builds sooner; polling keeps local Jenkins usable
    // when GitHub cannot reach the developer machine.
    triggers {
        pollSCM('H/5 * * * *')
    }

    environment {
        IMAGE_NAME = 'expenso-app'
        CONTAINER_NAME = 'expenso-container'
        APP_PORT = '8082'
    }

    stages {
        stage('Checkout Source Code') {
            steps {
                checkout scm
                echo "Checked out ${env.GIT_COMMIT ?: 'the configured SCM revision'}"
            }
        }

        stage('Validate Project Files') {
            steps {
                bat 'if not exist index.html (echo ERROR: index.html is missing & exit /b 1)'
                bat 'if not exist Dockerfile (echo ERROR: Dockerfile is missing & exit /b 1)'
                echo 'Required application and Docker files are present.'
            }
        }

        stage('Build Docker Image') {
            steps {
                bat 'docker build --pull -t %IMAGE_NAME%:%BUILD_NUMBER% -t %IMAGE_NAME%:latest .'
            }
        }

        stage('Test Docker Image') {
            steps {
                bat 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-image.ps1 -Image "%IMAGE_NAME%:%BUILD_NUMBER%" -BuildNumber "%BUILD_NUMBER%"'
            }
        }

        stage('Deploy Docker Container') {
            steps {
                bat 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-image.ps1 -Image "%IMAGE_NAME%:%BUILD_NUMBER%" -ContainerName "%CONTAINER_NAME%" -Port %APP_PORT% -BuildNumber "%BUILD_NUMBER%"'
            }
        }

        stage('Verify Deployment') {
            steps {
                bat 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-deployment.ps1 -Port %APP_PORT%'
            }
        }
    }

    post {
        success {
            echo "Expenso is live at http://localhost:${env.APP_PORT}/ (image ${env.IMAGE_NAME}:${env.BUILD_NUMBER})."
        }
        failure {
            echo 'Pipeline failed. Review the stage logs; the prior container is retained or restored if deployment fails.'
        }
    }
}
