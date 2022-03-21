// Defining common variables and functions
commonVariables = {
    completeJobName = sh(returnStdout: true, script: "echo $JOB_NAME")
    jobName = completeJobName.split('/')[-1].trim().toLowerCase()
    appName = params.application ?: jobName
    envName = completeJobName.split('/')[-2].trim().toLowerCase()
    chartPath = "${env.WORKSPACE}/application/helm/core/$jobName"
}

checkoutPrivate = {
          checkout(
            [$class: 'GitSCM', branches: [[name: '*/main']],
            extensions: [
                [$class: 'RelativeTargetDirectory', relativeTargetDir: 'private'],
                [$class: 'CloneOption', noTags: true, reference: '', shallow: true]
            ],
            userRemoteConfigs: [[
                  credentialsId: "${env.GH_REPO_CRED}",
                  url: "${env.GH_PRIVATE_REPO}"
          ]]])
          // Merging public and private repo
          sh """
                set -x
                public_inventory_dir=``
                cp -rf private/hcx/ansible/inventory/${envName}/* `find ./application -iname "inventory" -type d`/
             """
}

// Groovy closure
// Ref: https://groovy-lang.org/closures.html
deployHelm = {
    // Application to deploy, from which job the artifact information to be copied.
    // If null default value will be "build/deployAppName"
    // args can be passed as "-e name=job -e namespace=monitoing"
    appName, copyArtifactJob, args ->
    
    if(copyArtifactJob == null) {
        copyArtifactJob = "build/$appName"
    }
    
    additionalVariables = "-e namespace=${envName} -e chart_path=${chartPath}"
    additionalArgs = args ?: " "
    // Overriding artifact version to deploy
    imageTag = params.artifact_version ?: ""

    // If we deploy generic chart, there's nothing to build and copy.
    if(copyArtifactJob != "false") {
        if(imageTag == "") {
            copyArtifacts filter: 'metadata.json', fingerprintArtifacts: true, projectName: copyArtifactJob
            imageTag = sh(returnStdout: true, script: 'jq -r .image_tag metadata.json').trim()
        }
        additionalVariables = "-e image_tag=${imageTag} -e namespace=${envName} -e chart_path=${chartPath}"
    }

    additionalVariables = additionalVariables + " " + additionalArgs

    sh """
      echo ${appName}:${imageTag}
      cd application/ansible
      ansible-playbook -i inventory/hosts helm.yaml -e application=$appName $additionalVariables -v
    """
}

deployAnsible = {
    // Variable declaration
    ansibleCommands ->
    sh """
      echo ${appName}
      cd application/ansible
      ansible-playbook -i inventory/hosts ${ansibleCommands}
    """
}
// Ref: https://stackoverflow.com/questions/37800195/how-do-you-load-a-groovy-file-and-execute-it
return this
