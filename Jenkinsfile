pipeline {
    agent { label 'windows' }

    options {
        timestamps()
    }

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
                powershell '''
                    $ErrorActionPreference = 'Stop'
                    Write-Host "Flyway validate & checks against QA"
                    flyway -environment=QA -outputType=json `
                      check -changes -drift -code `
                      -reportFilename=reports/qa/check
                '''
                archiveArtifacts artifacts: 'reports/qa/**', onlyIfSuccessful: true
                publishHTML(target: [
                    reportDir: 'reports/qa',
                    reportFiles: 'check.html',
                    reportName: 'QA Flyway Check',
                    keepAll: true,
                    alwaysLinkToLastBuild: true,
                    allowMissing: true
                ])
            }
        }

        stage('QA - Migrate') {
            steps {
                powershell '''
                    $ErrorActionPreference = 'Stop'
                    Write-Host "Deploying to QA"
                    flyway -environment=QA migrate -dryRunOutput=reports/qa/migrate.dryrun.sql

                    Write-Host "Post deploy drift snapshot on QA"
                    flyway -environment=QA -outputType=json `
                      check -drift `
                      -reportFilename=reports/qa/post_migrate_drift
                '''
                archiveArtifacts artifacts: 'reports/qa/**', onlyIfSuccessful: true
                publishHTML(target: [
                    reportDir: 'reports/qa',
                    reportFiles: 'post_migrate_drift.html',
                    reportName: 'QA Post-migrate Drift',
                    keepAll: true,
                    alwaysLinkToLastBuild: true,
                    allowMissing: true
                ])
            }
        }

        stage('Prod - Validate & Checks') {
            steps {
                powershell '''
                    $ErrorActionPreference = 'Stop'
                    Write-Host "Flyway validate & checks against Prod"
                    flyway -environment=Prod -outputType=json `
                      check -changes -drift -code `
                      -reportFilename=reports/prod/check
                '''
                archiveArtifacts artifacts: 'reports/prod/**', onlyIfSuccessful: true
                publishHTML(target: [
                    reportDir: 'reports/prod',
                    reportFiles: 'check.html',
                    reportName: 'Prod Flyway Check',
                    keepAll: true,
                    alwaysLinkToLastBuild: true,
                    allowMissing: true
                ])
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
                            parameters: [
                                text(
                                    defaultValue: 'I Approve The Deployment',
                                    description: 'To Proceed, type I Approve The Deployment',
                                    name: 'Review deployment artifacts before proceeding'
                                )
                            ]
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
                powershell '''
                    $ErrorActionPreference = 'Stop'
                    Write-Host "Deploying to Prod"
                    flyway -environment=Prod migrate -dryRunOutput=reports/prod/migrate.dryrun.sql

                    Write-Host "Post deploy drift snapshot on Prod"
                    flyway -environment=Prod -outputType=json `
                      check -drift `
                      -reportFilename=reports/prod/post_migrate_drift
                '''
                archiveArtifacts artifacts: 'reports/prod/**', onlyIfSuccessful: true
                publishHTML(target: [
                    reportDir: 'reports/prod',
                    reportFiles: 'post_migrate_drift.html',
                    reportName: 'Prod Post-migrate Drift',
                    keepAll: true,
                    alwaysLinkToLastBuild: true,
                    allowMissing: true
                ])
            }
        }
    }
}
