pipeline {

    agent any

    parameters {
        choice(choices: ['development','prod-london'], description: 'please select a deployment target', name: 'INSTANCE')
        //choice(choices: ['development','prod-london'], description: 'Environment to deploy', name: 'Enviro')
        string(defaultValue: env.VERSION, name: 'VERSION', description: 'please select pipeline')
        choice(choices: ['1','2','3','4','5','6'], description: 'please select number of pods', name: 'PODS')

    }

    options {
        ansiColor('xterm')
        buildDiscarder(logRotator(numToKeepStr:'20'))
    }

    stages {

        stage('RW-Initialize') {
            steps {
                sh '''
                    egrep 'root|jenkins' /etc/passwd > passwd
                    mkdir -p .cache
                '''
            }
        }

        stage('Deployment') {
            agent {
                docker {
                    image 'git.autodatacorp.org:5555/infra/docker-containers/alpine-helm'
                    args "-t -v ${env.WORKSPACE}/passwd:/etc/passwd -v ${env.WORKSPACE}/.cache:/var/lib/jenkins/.cache"
                    registryUrl 'https://git.autodatacorp.org:5555/v2/'
                    registryCredentialsId 'cpp-helm-cred'
                }
            }

            environment {
                THYCOTIC_CREDS_BASE64 = credentials('THYCOTIC_CREDS_BASE64')
                VERSION = "${params.VERSION}"
                NEXUS = credentials('nexus-cred')
                REGISTRY = "${params.REGISTRY}"
                INSTANCE = "${params.INSTANCE}"
                REPLICAS = "${params.PODS}"
            }

            steps {
                echo('Initialize stage')
                script {
                    if (env.INSTANCE == "development") {
                       env.CLUSTER = "cpp-monitor-test-config"
                       env.FULL_URL = "cpp-monitor-test.autodatacorp.org"
                       env.NAMESPACE = "develop"
                       env.COMPONENT_NAME = "dev"

                    } else if (env.INSTANCE == "prod-london") {
                       env.CLUSTER = "cpp-monitor-config"
                       env.FULL_URL = "lnoc-prcp-xwa2cpp-monitor.autodatacorp.org"
                       env.NAMESPACE = "prod"
                       env.COMPONENT_NAME = "prod"
                    } else {
                        env.CLUSTER = "kubeconfig"
                        env.FULL_URL = "istest.rancher.autodata.tech"
                    }
                    if (env.REGISTRY == "test") {
                       env.DOCKERHOST = "nexus-docker.autodatacorp.org"
                    } else {
                       env.DOCKERHOST = "docker-pro-pull.autodatacorp.org"
                    }
                    // env.FULL_URL = env.COMPONENT_NAME + "." + env.NAMESPACE + "." + env.DOMAIN
                }

                withCredentials([file(credentialsId: env.CLUSTER, variable: 'KUBECONFIG')]) {
                    sh '''
                        # Replace '.'s with '-'s (e.g. "1.9.0-137361" > "1-9-0-137361")
                        project_version_label=$(echo ${VERSION} | sed -E "s/\\./-/g")

                        # Extract POM Major/Minor version (e.g. "1-9-0-137361" > "1-9")
                        if [ $REGISTRY = "test" ]; then
                          minor_version="snapshot"
                        else
                          minor_version=$(echo ${project_version_label} | sed -E "s/([0-9]+-[0-9]+).*/\\1/g")
                        fi

                        # Extract pipeline/image ID (e.g. "12345")
                        pipeline_id=${VERSION##*-}
                        # Extract namespace (e.g. "gitlab")
                        namespace=${NAMESPACE}

                        # create if not exists instance (namespace)
                        kubectl create ns ${namespace} ||echo -n

                        # replace nexus docker cred within namespace
                        kubectl --namespace=${namespace} delete secret docker-private-nexus-key ||echo -n
                        kubectl --namespace=${namespace} create secret docker-registry docker-private-nexus-key --docker-server=${DOCKERHOST}\
                                --docker-username=${NEXUS_USR} --docker-password=${NEXUS_PSW} --docker-email=siva.ponnaganti@jdpa.com
                        kubectl delete secrets --namespace=${namespace} --ignore-not-found monitoring-ui-${minor_version}

                        # install secrets and artifacts
                        /bin/bash deployment/kubernetes/envs/${INSTANCE}/secrets.sh | \
                        sed 's/monitoring-ui/monitoring-ui-'${minor_version}'/' |kubectl --namespace=${namespace} apply -f -

                        helm3 upgrade --install monitoring-ui-${minor_version} --namespace ${namespace} \
                                      --set secret=monitoring-ui-${minor_version} \
                                      --set image.path=${DOCKERHOST}/cpp/ui/monitoring-ui:${VERSION} \
                                      --set name=monitoring-ui \
                                      --set replicaCount=${REPLICAS} --set full.url=${FULL_URL} \
                                      deployment/kubernetes/helm/monitoring-ui


                    '''
                }
            }
        }
    }
}

