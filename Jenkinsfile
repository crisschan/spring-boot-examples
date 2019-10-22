pipeline {
  agent {
    label 'java'
  }
  stages {
    stage('clone') {
      steps {
        script {
          env.CODE_REPO = "https://gitlab.enncloud.cn/chenleiap/testexample"
          env.CREDENTIAL_ID = "global-credentials-gitlab-criss-me"
          env.RELATIVE_DIRECTORY = "."
          env.BRANCH = "master"
          def scmVars = checkout([
            $class: 'GitSCM',
            branches: [[name: "${BRANCH}"]],
            extensions: [[
              $class: 'SubmoduleOption',
              recursiveSubmodules: true,
              reference: '',
            ],[
              $class: 'RelativeTargetDirectory',
              relativeTargetDir: "${RELATIVE_DIRECTORY}"
            ]],
            userRemoteConfigs: [[
              credentialsId: "${CREDENTIAL_ID}",
              url: "${CODE_REPO}"
            ]]
          ])
          env.GIT_COMMIT = scmVars.GIT_COMMIT
          env.GIT_BRANCH = scmVars.GIT_BRANCH
          env.GIT_BRANCH_AS_TAG = scmVars.GIT_BRANCH.replaceFirst("origin/","").replaceAll("/","-")
        }

      }
    }
    stage('maven') {
      steps {
        script {
          container('java') {
            sh """mvn clean package"""
          }
        }

      }
    }
    stage('sonar') {
      steps {
        container('tools') {
          script {
            env.CODE_QUALITY_BINDING_NAME = "templatepipeline"
            env.CODE_QUALITY_BINDING_NAMESPACE = "templatepipline"
            env.CODE_REPOSITORY_KEY = "https://gitlab.enncloud.cn/chenleiap/testexample".replace("http://", "").replace("https://", "").replaceAll("/", "-")
            env.CODE_REPOSITORY_NAME = "${CODE_REPOSITORY_KEY}"
            env.BRANCH = "master"
            if (env.BRANCH.equals("*/master")) {
              env.BRANCH = "master"
            }
            if (fileExists('sonar-project.properties')) {
              env.ANALYSIS_PARAMETERS = ""
            }
            else {
              env.ANALYSIS_PARAMETERS = """sonar.sources=./spring-boot-docker/src
              sonar.java.binaries=./spring-boot-docker/target/classes
              sonar.sourceEncoding=UTF-8""".replaceAll("\r\n"," ").replaceAll("\n", " ").replaceAll("sonar", "-D sonar")
            }
            alaudaPlatform.withBindInProjectSonarEnv("${CODE_QUALITY_BINDING_NAMESPACE}", "${CODE_QUALITY_BINDING_NAME}") {
              sh "#!/bin/sh -e\n" + "sonar-scanner -D sonar.host.url=${SONAR_SERVER_URL} -D sonar.login=${SONAR_TOKEN} -D sonar.projectName=${CODE_REPOSITORY_NAME} -D sonar.projectKey=${CODE_REPOSITORY_KEY} ${ANALYSIS_PARAMETERS}"
              timeout(time: 1, unit: 'HOURS') {
                def statusCode = sh script: "#!/bin/sh -e\n" + "cmdclient taskmonitor --host=${SONAR_SERVER_URL} --token=${SONAR_TOKEN}", returnStatus:true
                // status codes come from bergamot cmdclient - https://github.com/alauda/bergamot/blob/master/sonarqube/cmdclient/cmd/task_monitor.go
                def QUALITY_GATE_SUCCESS = 0
                def QUALITY_GATE_WARN = 134
                def QUALITY_GATE_ERROR = 133
                def QUALITY_GATE_UNKNOW = 135
                def projectLink = "${SONAR_SERVER_URL}"
                if (!projectLink.endsWith("/")) {
                  projectLink = projectLink + "/"
                }
                projectLink = projectLink + "dashboard?id=${CODE_REPOSITORY_KEY}"
                switch(statusCode) {
                  case QUALITY_GATE_SUCCESS:
                  sh "echo \"Quality Gate Status of Project ${CODE_REPOSITORY_NAME} is OK\""
                  addBadge icon: 'green.gif', text: 'OK', id: 'QualityGate', link: projectLink
                  break
                  case QUALITY_GATE_WARN:
                  sh "echo \"Quality Gate Status of Project ${CODE_REPOSITORY_NAME} is WARN\""
                  addBadge icon: 'yellow.gif', text: 'WARN', id: 'QualityGate', link: projectLink
                  break
                  case QUALITY_GATE_ERROR:
                  sh "echo \"Quality Gate Status of Project ${CODE_REPOSITORY_NAME} is ERROR\""
                  addBadge icon: 'red.gif', text: 'ERROR', id: 'QualityGate', link: projectLink
                  break
                  default:
                  sh "echo \"Quality Gate Status of Project ${CODE_REPOSITORY_NAME} is UNKOWN\""
                  break
                }
              }
            }
          }

        }

      }
    }
    stage('build-docker') {
      steps {
        script {
          def retryCount = 3
          def repositoryAddr = 'registry.enncloud.cn/enn-test/example'.replace("http://","").replace("https://","")
          env.IMAGE_REPO = repositoryAddr
          def credentialId = ''
          credentialId = "templatepipline-dockercfg--templatepipline--templatepipline"
          dir(RELATIVE_DIRECTORY) {
            container('tools') {
              retry(retryCount) {
                try {
                  if (credentialId != '') {
                    withCredentials([usernamePassword(credentialsId: "${credentialId}", passwordVariable: 'PASSWD', usernameVariable: 'USER')]) {
                      sh "docker login ${IMAGE_REPO} -u ${USER} -p ${PASSWD}"
                    }
                  }
                }
                catch(err) {
                  echo err.getMessage()
                  alaudaDevops.withCluster() {
                    def secretNamespace = "templatepipline"
                    def secretName = "dockercfg--templatepipline--templatepipline"
                    def secret = alaudaDevops.selector( "secret/${secretName}" )
                    alaudaDevops.withProject( "${secretNamespace}" ) {
                      def secretjson = secret.object().data['.dockerconfigjson']
                      def dockerconfigjson = base64Decode("${secretjson}");
                      writeFile file: 'config.json', text: dockerconfigjson
                      sh """
                      set +x
                      mkdir -p ~/.docker
                      mv -f config.json ~/.docker/config.json
                      """
                    }
                  }
                }
                def tagswithcomma = "latest"
                def tags = tagswithcomma.split(",")
                def incubatorimage = "${IMAGE_REPO}:${tags[0]}"
                sh " docker build -t ${incubatorimage} -f Dockerfile  ."
                tags.each {
                  tag ->
                  sh """
                  docker tag ${incubatorimage} ${IMAGE_REPO}:${tag}
                  docker push ${IMAGE_REPO}:${tag}
                  """
                }
                if (credentialId != '') {
                  sh "docker logout ${IMAGE_REPO}"
                }
              }
            }
          }
        }

      }
    }
    stage('deployService') {
      steps {
        script {
          env.CREDENTIAL_ID = "templatepipline-dockercfg--templatepipline--templatepipline"
          env.CREDENTIAL_ID = env.CREDENTIAL_ID.replaceFirst("templatepipline-","")
          def tagwithcomma = "latest"
          def tags = tagwithcomma.split(",")
          env.NEW_IMAGE = "registry.enncloud.cn/enn-test/example:${tags[0]}"
          container('tools') {
            timeout(time:300, unit: "SECONDS") {
              alaudaDevops.withCluster("region") {
                alaudaDevops.withProject("templatepipline-criss") {
                  def p = alaudaDevops.selector('deployment', 'temlatepipeline').object()
                  p.metadata.labels['BUILD_ID']=env.BUILD_ID
                  for(container in p.spec.template.spec.containers) {
                    if(container.name == "temlatepipeline") {
                      container.image = "${NEW_IMAGE}"
                      def cmd = ""
                      def args = ""
                      if(cmd!="") {
                        container.command = [cmd]
                      }
                      if(args!="") {
                        container.args = [args]
                      }
                      break
                    }
                  }
                  if(env.CREDENTIAL_ID != "") {
                    if(p.spec.template.spec.imagePullSecrets != null) {
                      def notFound = true
                      for(secret in p.spec.template.spec.imagePullSecrets) {
                        if(secret == env.CREDENTIAL_ID) {
                          notFound = false
                          break
                        }
                      }
                      if(notFound) {
                        p.spec.template.spec.imagePullSecrets[p.spec.template.spec.imagePullSecrets.size()] = [name: env.CREDENTIAL_ID]
                      }
                    }
                    else {
                      p.spec.template.spec.imagePullSecrets = [[name: env.CREDENTIAL_ID]]
                    }
                  }
                  alaudaDevops.apply(p, "--validate=false")
                }
              }
            }
          }
        }

      }
    }
  }
  environment {
    ALAUDA_PROJECT = 'templatepipline'
  }
  post {
    always {
      script {
        echo "clean up workspace"
        deleteDir()
      }


    }

  }
  options {
    buildDiscarder(logRotator(numToKeepStr: '200'))
  }
}