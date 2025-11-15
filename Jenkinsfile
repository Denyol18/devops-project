pipeline {
  agent any

  tools {
    nodejs 'nodejs'
    dockerTool 'docker'
  }

  environment {
    APP_REPO = "https://github.com/Denyol18/prf-projekt.git"
    REGISTRY = "denyol/prf-projekt"
    SERVER_IMAGE = "${env.REGISTRY}:server-${env.BUILD_NUMBER}"
    CLIENT_IMAGE = "${env.REGISTRY}:client-${env.BUILD_NUMBER}"
  }

  stages {

    stage('Checkout CI/CD repo') {
      steps {
        checkout scm
      }
    }

    stage('Checkout App Code') {
      steps {
        sh """
          rm -rf prf-projekt
          git clone ${APP_REPO}
        """
      }
    }

    stage('Build & Test Server') {
      steps {
        dir('prf-projekt/server') {
          sh 'npm install'
          sh 'npm test || true'
          sh 'npm run build'
        }
      }
    }

    stage('Build & Test Client') {
      steps {
        dir('prf-projekt/client') {
          sh 'npm install'
          sh 'npm test || true'
          sh 'npm run build'
        }
      }
    }

    stage('Prepare Docker Build Context') {
      steps {
        sh """
          cp -r prf-projekt/server ./server-src
          cp -r prf-projekt/client ./client-src
        """
      }
    }

    stage('Build Docker Images') {
      steps {
        sh "docker build -t $SERVER_IMAGE -f Dockerfile.server ."
        sh "docker build -t $CLIENT_IMAGE -f Dockerfile.client ."
      }
    }

    stage('Push Docker Images') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-creds',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
          sh "docker push $SERVER_IMAGE"
          sh "docker push $CLIENT_IMAGE"
        }
      }
    }
  }
}
