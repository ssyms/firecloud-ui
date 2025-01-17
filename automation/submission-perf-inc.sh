#!/bin/bash
# Include script for perf tests

set -e

checkToken () {
    user=$1

    # Verify that user does not need to refresh their token
    if
        curl \
            -f -v --silent \
            -X GET \
            --header "Accept: application/json" \
            --header "Authorization: Bearer ${ACCESS_TOKEN}" \
            "https://firecloud-orchestration.dsde-${ENV}.broadinstitute.org/api/refresh-token-status" 2>&1 \
        | grep '"requiresRefresh": true'
    then
        echo "$1 needs its refresh token refreshed"
        NEED_TOKEN=true
        export NEED_TOKEN
    fi

}

callbackToNIH() {
    user=$1

    echo "
    Launching calback to NIH for:
    user=$1
    "
    ACCESS_TOKEN=$(
        docker \
            run \
            --rm \
            -v "${WORKING_DIR}:/app/populate" \
            -w /app/populate \
            broadinstitute/dsp-toolbox \
            python get_bearer_token.py "${user}" "${JSON_CREDS}"
    )

    curl \
        -X POST \
        --header "Content-Type: application/json" \
        --header "Accept: application/json" \
        --header "Authorization: Bearer ${ACCESS_TOKEN}" \
        -d "{\"jwt\":\"eyJhbGciOiJIUzI1NiJ9.ZmlyZWNsb3VkLWRldg.NPXbSpTmAOUvJ1HX85TauAARnlMKfqBsPjumCC7zE7s\"}" \
        "https://firecloud-orchestration.dsde-${ENV}.broadinstitute.org/api/nih/callback"
}

launchSubmission() {
    user="$1"
    shift 1
    namespace="$1"
    shift 1
    name="$1"
    shift 1
    methodConfigurationNamespace="$1"
    shift 1
    methodConfigurationName="$1"
    shift 1
    entityType="$1" #optional
    shift 1
    entityName="$1" #optional
    shift 1
    useCallCache="$1"
    shift 1
    deleteIntermediateOutputFiles="$1"
    shift 1

    expression="$1" #optional

    echo "
    Launching submission for:
        user=${user}
        namespace=${namespace}
        name=${name}
        methodConfigurationNamespace=${methodConfigurationNamespace}
        methodConfigurationName=${methodConfigurationName}
        entityType=${entityType}
        entityName=${entityName}
        useCallCache=${useCallCache}
        deleteIntermediateOutputFiles=${deleteIntermediateOutputFiles}
        expression=${expression}
    "

     ACCESS_TOKEN=$(
        docker \
            run \
            --rm \
            -v "${WORKING_DIR}:/app/populate" \
            -w /app/populate \
            broadinstitute/dsp-toolbox \
            python get_bearer_token.py "${user}" "${JSON_CREDS}"
     )

    # check if $expression is set
    if [[ -z ${expression} ]] ; then
        optionalExpressionField=""
    else
        optionalExpressionField="\"expression\":\"${expression}\","
    fi
    if [[ -z ${entityType} ]] ; then
        optionalEntityTypeField=""
    else
        optionalEntityTypeField="\"entityType\":\"${entityType}\","
    fi
    if [[ -z ${entityName} ]] ; then
        optionalEntityNameField=""
    else
        optionalEntityNameField="\"entityName\":\"${entityName}\","
    fi

    curl \
        -f \
        "https://firecloud-orchestration.dsde-${ENV}.broadinstitute.org/api/workspaces/${namespace}/${name}/submissions" \
        -H "origin: https://firecloud.dsde-${ENV}.broadinstitute.org" \
        -H "accept-encoding: gzip, deflate, br" \
        -H "authorization: Bearer ${ACCESS_TOKEN}" \
        -H "content-type: application/json" \
        --data-binary "
        {
            \"deleteIntermediateOutputFiles\":${deleteIntermediateOutputFiles},
            ${optionalExpressionField}
            \"methodConfigurationNamespace\":\"${methodConfigurationNamespace}\",
            \"methodConfigurationName\":\"${methodConfigurationName}\",
            ${optionalEntityTypeField}
            ${optionalEntityNameField}
            \"useCallCache\":${useCallCache}
        }
        " \
        --compressed
}

findSubmissionID() {
    user=$1
    namespace=$2
    name=$3

    ACCESS_TOKEN=$(
        docker \
            run \
            --rm \
            -v "${WORKING_DIR}:/app/populate" \
            -w /app/populate \
            broadinstitute/dsp-toolbox \
            python get_bearer_token.py "${user}" "${JSON_CREDS}"
    )

    submissionID=$(
        curl \
            -X GET \
            --header 'Accept: application/json' \
            --header "Authorization: Bearer ${ACCESS_TOKEN}" \
            "https://firecloud-orchestration.dsde-alpha.broadinstitute.org/api/workspaces/$namespace/$name/submissions" \
        | jq -r '.[] | select(.status == ("Submitted")) | .submissionId')

    export ACCESS_TOKEN
    export submissionID
}

findLastSubmissionID() {
    user=$1
    namespace=$2
    name=$3
    methodConfigurationNamespace=${4-} # optional
    methodConfigurationName=${5-}      # optional

    ACCESS_TOKEN=$(
        docker \
            run \
            --rm \
            -v "${WORKING_DIR}:/app/populate" \
            -w /app/populate \
            broadinstitute/dsp-toolbox \
            python get_bearer_token.py "${user}" "${JSON_CREDS}"
    )

    selectorString=".status == (\"Submitted\")"
    if [[ -n "$methodConfigurationNamespace" && -n "$methodConfigurationName" ]]
        then
            selectorString="$selectorString and .methodConfigurationNamespace == (\"$methodConfigurationNamespace\") and .methodConfigurationName == (\"$methodConfigurationName\")"
    fi
    submissionID=$(
        curl \
            -X GET \
            --header 'Accept: application/json' \
            --header "Authorization: Bearer ${ACCESS_TOKEN}" \
            "https://firecloud-orchestration.dsde-alpha.broadinstitute.org/api/workspaces/$namespace/$name/submissions" \
        | jq -r "[.[] | select($selectorString)] | sort_by(.submissionDate) | reverse[0] | .submissionId")

    export ACCESS_TOKEN
    export submissionID
}

findFirstWorkflowIdInSubmission() {
    user=$1
    namespace=$2
    name=$3
    submissionId=$4

    ACCESS_TOKEN=$(
        docker \
            run \
            --rm \
            -v "${WORKING_DIR}:/app/populate" \
            -w /app/populate \
            broadinstitute/dsp-toolbox \
            python get_bearer_token.py "${user}" "${JSON_CREDS}"
    )

    workflowID=$(
        curl \
            -X GET \
            --header 'Accept: application/json' \
            --header "Authorization: Bearer ${ACCESS_TOKEN}" \
            "https://firecloud-orchestration.dsde-alpha.broadinstitute.org/api/workspaces/$namespace/$name/submissions/$submissionId" \
        | jq -r '.workflows[0].workflowId')

    export ACCESS_TOKEN
    export workflowID
}

checkIfWorkflowErrorMessageContainsSubstring() {
    user=$1
    namespace=$2
    name=$3
    workflowId=$4
    expectedSubstring=$5

    ACCESS_TOKEN=$(
        docker \
            run \
            --rm \
            -v "${WORKING_DIR}:/app/populate" \
            -w /app/populate \
            broadinstitute/dsp-toolbox \
            python get_bearer_token.py "${user}" "${JSON_CREDS}"
    )

    workflowErrorMessage=$(
        curl \
            -X GET \
            --header 'Accept: application/json' \
            --header "Authorization: Bearer ${ACCESS_TOKEN}" \
            "https://firecloud-orchestration.dsde-alpha.broadinstitute.org/api/workflows/v1/$workflowId/metadata?includeKey=failures&expandSubWorkflows=false" \
        | jq -r '.failures')

    if [[ "$workflowErrorMessage" != *"$expectedSubstring"* ]]; then
      echo "Workflow error message doesn't contain expected text: $expectedSubstring for workflow $workflowId. Actual error message: $workflowErrorMessage"
      exit 1
    fi
}

monitorSubmission() {
    user=$1
    namespace=$2
    name=$3
    submissionId=$4

    ACCESS_TOKEN=$(
        docker \
            run \
            --rm \
            -v "${WORKING_DIR}:/app/populate" \
            -w /app/populate \
            broadinstitute/dsp-toolbox \
            python get_bearer_token.py "${user}" "${JSON_CREDS}"
    )

    # curl -s -X GET --header 'Accept: application/json' --header "Authorization: Bearer $ACCESS_TOKEN" "https://firecloud-orchestration.dsde-alpha.broadinstitute.org/api/submissions/queueStatus" | jq -r '"\(now),\(.workflowCountsByStatus.Queued),\(.workflowCountsByStatus.Running),\(.workflowCountsByStatus.Submitted)"' | tee -a workflow-progress-$BUILD_NUMBER.csv
    submissionStatus=$(
        curl \
            -X GET \
            --header 'Accept: application/json' \
            --header "Authorization: Bearer ${ACCESS_TOKEN}" \
            "https://firecloud-orchestration.dsde-alpha.broadinstitute.org/api/workspaces/${namespace}/${name}/submissions/${submissionId}" \
        | jq -r '.status'
    )
    workflowsStatus=$(
        curl \
            -X GET \
            --header 'Accept: application/json' \
            --header "Authorization: Bearer ${ACCESS_TOKEN}" \
            "https://firecloud-orchestration.dsde-alpha.broadinstitute.org/api/workspaces/${namespace}/${name}/submissions/${submissionId}" \
         | jq -r '.workflows[] | .status'
    )
    workflowFailures=$(
        curl \
            -X GET \
            --header 'Accept: application/json' \
            --header "Authorization: Bearer ${ACCESS_TOKEN}" \
            "https://firecloud-orchestration.dsde-alpha.broadinstitute.org/api/workspaces/${namespace}/${name}/submissions/${submissionId}" \
         | jq -r '[.workflows[] | select(.status == "Failed")] | length'
    )

    export ACCESS_TOKEN
    export submissionStatus
    export workflowsStatus
    export workflowFailures
}

waitForSubmissionAndWorkflowStatus() {
  numOfAttempts=$1
  expectedSubmissionStatus=$2
  expectedWorkflowStatus=$3
  user=$4
  namespace=$5
  name=$6
  submissionId=$7

  monitorSubmission $user $namespace $name $submissionId
  i=1
  while [ "$submissionStatus" != "$expectedSubmissionStatus" ] && [ "$i" -le "$numOfAttempts" ]
    do
      echo "Submission $submissionId is not yet $expectedSubmissionStatus. Will make attempt $(($i+1)) after 60 seconds"
      sleep 60
      monitorSubmission $user $namespace $name $submissionId
      ((i++))
    done

  if [ "$submissionStatus" == "$expectedSubmissionStatus" ] && [ "$workflowsStatus" == "$expectedWorkflowStatus" ]; then
    echo "Workflow finished within $i minutes with expected status: $workflowsStatus"
    echo "$workflowFailures"
    echo "${submissionStatus}" "${workflowsStatus}" > submissionResults.txt 2>&1
  else
    if [ "$i" -gt "$numOfAttempts" ]; then
      echo "Failed to reach expected submission/workflow $expectedSubmissionStatus/$expectedWorkflowStatus statuses within $i minutes. Last submission/workflow statuses: ${submissionStatus}/${workflowsStatus}"
    else
      echo "Failing with submission status: $submissionStatus and workflow status: $workflowsStatus"
    fi
    echo "${submissionStatus}" "${workflowsStatus}" > submissionResults.txt 2>&1
    exit 1
  fi
}
