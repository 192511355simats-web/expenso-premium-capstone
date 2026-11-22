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
                sh 'test -s index.html && test -s Dockerfile && test -s scripts/test-image.sh && test -s scripts/deploy-image.sh && test -s scripts/verify-deployment.sh'
                echo 'Required application and Docker files are present.'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build --pull -t "$IMAGE_NAME:$BUILD_NUMBER" -t "$IMAGE_NAME:latest" .'
            }
        }

        stage('Test Docker Image') {
            steps {
                sh 'bash scripts/test-image.sh "$IMAGE_NAME:$BUILD_NUMBER" "$BUILD_NUMBER"'
            }
        }

        stage('Deploy Docker Container') {
            steps {
                sh 'bash scripts/deploy-image.sh "$IMAGE_NAME:$BUILD_NUMBER" "$CONTAINER_NAME" "$APP_PORT" "$BUILD_NUMBER"'
            }
        }

        stage('Verify Deployment') {
            steps {
                sh 'bash scripts/verify-deployment.sh "$APP_PORT"'
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
