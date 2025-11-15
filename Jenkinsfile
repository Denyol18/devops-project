pipeline {
  agent any

  tools {
    nodejs 'nodejs'
	terraform 'terraform'
  }

  environment {
    APP_REPO = "https://github.com/Denyol18/prf-projekt.git"
    REGISTRY = "denyol/prf-projekt"
    SERVER_IMAGE = "${env.REGISTRY}:prf-server-${env.BUILD_NUMBER}"
    CLIENT_IMAGE = "${env.REGISTRY}:prf-client-${env.BUILD_NUMBER}"
  }

  stages {
  
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Cleanup Before & Clone App') {
      steps {
        sh """
		  rm -rf build-context
		  rm -rf client-src
		  rm -rf server-src
          rm -rf prf-projekt
          git clone ${APP_REPO}
        """
      }
    }

    stage('Build & Test Server') {
      steps {
        dir('prf-projekt/server') {
          sh 'npm install'
		  sh 'npx ts-node src/seeder.ts'
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
		  mkdir build-context
          cp -r prf-projekt/server build-context/server-src
          cp -r prf-projekt/client build-context/client-src
		  cp -r pm2 build-context/pm2
		  rm -rf prf-projekt
        """
      }
    }

    stage('Build Docker Images') {
      parallel {
		stage('Server Image') {
		  steps { sh "docker build -t $SERVER_IMAGE -f Dockerfile.server build-context" }
		}
		stage('Client Image') {
		  steps { sh "docker build -t $CLIENT_IMAGE -f Dockerfile.client build-context" }
		}
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

	stage('Release & Deploy') {
	  steps {
		sh 'terraform init'
		sh 'terraform plan'
		sh 'terraform apply -auto-approve -var server_image=$SERVER_IMAGE -var client_image=$CLIENT_IMAGE'
	  }
	}
	
	stage('Cleanup Old Images') {
	  steps {
		sh "docker image prune -f"
	  }
	}
	
  }
}
