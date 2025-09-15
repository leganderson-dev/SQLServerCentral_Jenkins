pipeline {
    agent { label 'windows' }

    options { timestamps() }

    // If this job is "Pipeline script from SCM", you can keep polling.
    triggers { pollSCM('H/1 * * * *') }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
                powershell 'New-Item -ItemType Directory -Force -Path reports/qa, reports/prod | Out-Null'
            }
        }

        /* ====================== QA ====================== */

        stage('QA - Validate & Checks') {
            steps {
                powershell """
                    \$ErrorActionPreference = 'Stop'
                    Write-Host 'Flyway validate & checks against QA'
                    flyway -environment=Test "-check.buildEnvironment=Check" -outputType=json `
                      -reportFilename=reports/qa/check `
                      check -changes -drift -code
                """
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
                powershell """
                    \$ErrorActionPreference = 'Stop'
                    Write-Host 'Deploying to QA'
                    flyway migrate -environment=Test -dryRunOutput=reports/qa/migrate.dryrun.sql

                    Write-Host 'Post deploy drift snapshot on QA'
                    flyway -environment=Test -outputType=json `
                      -reportFilename=reports/qa/post_migrate_drift `
                      check -drift
                """
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

        /* ===================== PROD ===================== */

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
                    flyway migrate -environment=Prod -dryRunOutput=reports/prod/migrate.dryrun.sql

                    Write-Host 'Post deploy drift snapshot on Prod'
                    flyway -environment=Prod -outputType=json `
                      -reportFilename=reports/prod/post_migrate_drift `
                      check -drift
                """
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
