#!/usr/bin/env bash

set -e

warn() {
    echo "$1" >&2
}

die() {
    warn "$1"
    exit 1
}

inform() {
    echo "$1"
    sleep 1
}

function yorn() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

accessKeyToSearch=${1?"Usage: $0 AccessKeyId"}

awsAccount=$( aws organizations describe-account --account-id $(aws sts get-access-key-info --access-key-id $accessKeyToSearch --output text) 2>/dev/null || die "Unable to locate access key $accessKeyToSearch. Is that what you meant?"
)

awsAccount=$(echo $awsAccount | jq -r .Account.Name)

echo "AWS Access Key $accessKeyToSearch is in our AWS account $awsAccount"
echo ""
read -p "Enter MFA key for your Organization Master account: " mfakey

eval $(assumerole $awsAccount $mfakey 2>/dev/null) || die "Unable to assume incidentResponse role in AWS account $awsAccount"

for username in $(aws iam list-users --query 'Users[*].UserName' --output text); do
    for accessKeyId in $(aws iam list-access-keys --user-name $username --query 'AccessKeyMetadata[*].AccessKeyId' --output text); do
        if [ "$accessKeyToSearch" = "$accessKeyId" ]; then
            echo "$accessKeyToSearch belongs to the user $username in AWS account $awsAccount";
            export BADGUY=$username
            break;
        fi;
    done;
done;

accessKeyCount=0
for accessKey in $(aws iam list-access-keys --user-name $BADGUY --query 'AccessKeyMetadata[*].AccessKeyId' --output text); do
  accessKeyCount=$((++accessKeyCount))
  aws iam update-access-key --access-key-id $accessKey --status Inactive --user-name $BADGUY
done
echo "$BADGUY owns $accessKeyCount AWS access keys in AWS account $awsAccount. They have been deactivated."

if $(aws iam get-login-profile --user-name $BADGUY >/dev/null 2>&1 ); then
    aws iam delete-login-profile --user-name $BADGUY
    echo "We have disabled the AWS console login for $BADGUY"
  else
    echo "$BADGUY has no console access."
fi

echo ""
sshKeyCount=0
for keyId in $(aws iam list-ssh-public-keys --user-name $BADGUY |  jq -r .SSHPublicKeys[].SSHPublicKeyId); do
  sshKeyCount=$((++sshKeyCount))
  aws iam update-ssh-public-key --user-name $BADGUY --ssh-public-key-id $keyId --status Inactive
  echo "Deactivated $BADGUY's ssh public key $keyId"
done

echo ""
echo "Downloading $BADGUY's IAM policy documents..."
for i in $(aws iam list-attached-user-policies --user-name $BADGUY | jq -r .AttachedPolicies[].PolicyArn); do
   policyVersion=$(aws iam get-policy --policy-arn $i --query 'Policy.DefaultVersionId' --output text)
   aws iam get-policy-version --policy-arn $i --version-id $(aws iam get-policy --policy-arn $i --query 'Policy.DefaultVersionId' --output text) >> iamPolicies-$accessKeyToSearch.json
done

echo ""
echo "Gathering CloudTrail events for $accessKeyToSearch."
echo "The list may be long; a text copy will be kept in the file 'events-$accessKeyToSearch'"

sleep 10

for region in $( aws ec2 describe-regions --region us-east-1 --output text | cut -f4); do
  aws cloudtrail lookup-events --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=$accessKeyToSearch \
  --region $region --query 'Events[*].{Ev:CloudTrailEvent,User:Username}'  \
  | jq '.[]| "Username: " + .User, "  " + (.Ev| fromjson | "EventTime: " + .eventTime, "Region: " +.awsRegion, "SourceIP: " + .sourceIPAddress, "Service: " +.eventSource, "Command: " +.eventName, "Error Code: " +.errorCode) ' \
  >> events-$accessKeyToSearch
done

clear
echo ""
echo "Summary: "
echo "We discovered AWS access key $accessKeyToSearch in AWS account $awsAccount."
echo "This key belongs to the user $BADGUY"
echo "$BADGUY had a total of $accessKeyCount AWS access keys. They have all been disabled."
echo "$BADGUY's AWS console access has been revoked."
if (( $sshKeyCount > 0 )); then
  echo "$BADGUY had $sshKeyCount CodeCommit ssh keys. They have been deactivated."
fi
echo "The IAM policies attached to $BADGUY can be reviewed in the file iamPolicies-$accessKeyToSearch.json"
echo "$BADGUY's AWS activity record can be reviewed in the file events-$accessKeyToSearch."
echo "The first two entries are: "
head -14 events-$accessKeyToSearch
echo ""
echo "$0 completed at `date`"
echo ""
