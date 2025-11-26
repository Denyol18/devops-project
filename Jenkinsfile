pipeline {
  agent any

  tools {
    nodejs 'nodejs'
	terraform 'terraform'
  }

  environment {
    APP_REPO = "https://github.com/Denyol18/prf-projekt.git"
    SERVER_IMAGE  = "prf_server"
    CLIENT_IMAGE  = "prf_client"
  }

  stages {
    stage('Cleanup & Clone App') {
      steps {
		sh 'terraform destroy -auto-approve || true'
        sh """
		  docker system prune -f
          rm -rf prf-projekt
          git clone ${APP_REPO}
        """
      }
    }

    stage('Test Server') {
      steps {
        dir('prf-projekt/server') {
          sh 'npm install'
		  sh 'npx ts-node src/seeder.ts'
          sh 'npm test -- --runInBand --ci --silent'
        }
      }
    }

    stage('Test Client') {
      steps {
        dir('prf-projekt/client') {
          sh 'npm install'
          sh 'npm test -- --runInBand --ci --silent'
        }
      }
    }

    stage('Build Docker Images') {
      parallel {
        stage('Build Server Image') {
          steps {
			sh "docker build -t $SERVER_IMAGE -f Dockerfile.server ."
          }
        }

        stage('Build Client Image') {
          steps {
			sh "docker build -t $CLIENT_IMAGE -f Dockerfile.client ."
          }
        }
      }
    }

	stage('Release & Deploy') {
	  steps {
		sh 'terraform init'
		sh 'terraform plan'
		sh "terraform apply -auto-approve -var server_image=$SERVER_IMAGE -var client_image=$CLIENT_IMAGE"
	  }
	}
	
	stage('Cleanup Unused Images') {
	  steps {
		sh "docker image prune -f"
	  }
	}
  }
}
