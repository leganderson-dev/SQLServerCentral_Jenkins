pipeline {
    agent { label 'windows' }

    options { timestamps() }

    triggers { pollSCM('H/1 * * * *') }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
                powershell 'New-Item -ItemType Directory -Force -Path reports/qa, reports/prod | Out-Null'
            }
        }

        stage('QA - Validate & Checks') {
            steps {
                powershell """
                    \$ErrorActionPreference = 'Stop'
                    Write-Host 'Flyway validate & checks against QA'
                    flyway -environment=QA "-check.buildEnvironment=Check" -outputType=json `
                      -reportFilename=reports/qa/check `
                      check -changes -drift -code
                """
                archiveArtifacts artifacts: 'reports/qa/**', onlyIfSuccessful: true
            }
        }

        stage('QA - Migrate') {
            steps {
                powershell """
                    \$ErrorActionPreference = 'Stop'
                    Write-Host 'Deploying to QA'
                    flyway migrate -environment=QA
                """
                archiveArtifacts artifacts: 'reports/qa/**', onlyIfSuccessful: true
            }
        }

        stage('Prod - Validate & Checks') {
            steps {
                powershell """
                    \$ErrorActionPreference = 'Stop'
                    Write-Host 'Flyway validate & checks against Prod'
                    flyway -environment=Prod "-check.buildEnvironment=Check" -outputType=json `
                      -reportFilename=reports/prod/check `
                      check -changes -drift -code
                """
                archiveArtifacts artifacts: 'reports/prod/**', onlyIfSuccessful: true
            }
        }

        stage('Approval Gate') {
            steps {
                script {
                    def message = "Approve Database Changes Before Proceeding"
                    timeout(time: 30, unit: 'MINUTES') {
                        def userInput = input(
                            id: 'userInput',
                            message: message,
                            parameters: [[
                                $class: 'TextParameterDefinition',
                                defaultValue: 'I Approve The Deployment',
                                description: 'To Proceed, type I Approve The Deployment',
                                name: 'Review deployment artifacts before proceeding'
                            ]]
                        )
                        if (!userInput.contains('I Approve The Deployment')) {
                            currentBuild.result = 'ABORTED'
                            error('Deployment aborted')
                        }
                    }
                }
            }
        }

        stage('Prod - Migrate') {
            steps {
                powershell """
                    \$ErrorActionPreference = 'Stop'
                    Write-Host 'Deploying to Prod'
                    flyway migrate -environment=Prod
                """
                archiveArtifacts artifacts: 'reports/prod/**', onlyIfSuccessful: true
            }
        }
    }
}
