awsAccount () {
        if [ "$#" -eq 2 ]
        then
                export AWS_DEFAULT_PROFILE="$1"
                export AWS_DEFAULT_REGION="$2"
                showAWSAccount
        elif [[ "$#" -eq 0 ]]
        then
                showAWSAccount
        else
                e2 "Usage: awsAccount profile region" && return 2
        fi
}

showAWSAccount() {
    [[ ! -v AWS_DEFAULT_PROFILE ]] && echo "No account set" || echo "Account: $AWS_DEFAULT_PROFILE"
    [[ ! -v AWS_DEFAULT_REGION ]] && echo "No region set" || echo "Region: $AWS_DEFAULT_REGION"
}
