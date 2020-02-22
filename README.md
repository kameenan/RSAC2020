# Clearing The Clouds

This is the demo code for Kristy Westphal's RSAC 2020 talk **Clearing the Clouds: Incident response in AWS isn't as bad as you thought.**

There are two scripts here:

* **investigateAndDisableKey.sh** does the main work of discovering, auditing, and disabling a potentially compromised AWS Access Key ID.
* **assumerole** is a helper script that helps assume AWS roles using Temporary Security Credentials and MFA. The version of **assumerole** here is lightly modified from the great work done by Rik Tytgat in the [aws-sts-assumerole](https://github.com/rik2803/aws-sts-assumerole) project.

## Assumptions

This is proof of concept code intended to illustrate techniques that you could use in your own organization. It makes several assumptions about the environment it's running in, but could be easily adapted to other AWS account arrangements.

1. We assume that you're working within an [AWS Organization](https://aws.amazon.com/organizations/), that your default AWS credentials are in your organization's Master account, and that you have attached an MFA device to the account that owns your credentials. Establishing and configuring an AWS Organization is outside the scope of this talk. 
2. You have configured **assumerole** as described in [the README](https://github.com/rik2803/aws-sts-assumerole/blob/master/README.md). **assumerole** requires that your credentials have MFA enabled. It's a good idea anyway!

## Usage
**investigateAndDisableKey.sh** takes one command line argument: the AWS Access Key ID that you wish to audit and disable.

When run, it will:

* Search your AWS organization for the Access Key ID and identify which AWS Account that key belongs to
* Prompt for an MFA token for your Master Account credentials
* Use **assumerole** to assume an Administrator role in the target AWS Account.
* Discover the username within the target AWS Account that owns the target key.
* Deactivate the target key and all other keys owned by the target user in the target AWS Account.
* Disable AWS Console login for the target user in the target AWS Account.
* Discover and disable all AWS CodeCommit ssh public keys that the target user owns in the target account. This will prevent the user from reading from or writing to CodeCommit git repoistories, and will also disable ssh access for that user if you're using [aws-ssh-iam](https://cloudonaut.io/manage-aws-ec2-ssh-access-with-iam/) to manage ec2 instance accounts. Disabling [Amazon EC2 Instance Connect](https://aws.amazon.com/blogs/compute/new-using-amazon-ec2-instance-connect-for-ssh-access-to-your-ec2-instances/) or [AWS Systems Manager Session Manager](https://aws.amazon.com/de/blogs/aws/new-session-manager/) keys is left as an exercise for the reader.
* Download a copy of all the IAM Policies attached to the target user so you can analyze what resources _could_ have been affected by a compromised key.
* Finally, it will download the [CloudTrail](https://aws.amazon.com/cloudtrail/) logs for the target user from every AWS Region, allowing you to analyze and audit every action that has been taken by the target user. Events are formatted like this:

```
"Username: louis.leakey"
"  EventTime: 2020-02-17T20:23:08Z"
"  Region: us-east-1"
"  SourceIP: 72.216.83.239"
"  Service: s3.amazonaws.com"
"  Command: ListBuckets"
"  Error Code: AccessDenied"
"Username: louis.leakey"
"  EventTime: 2020-02-17T20:19:12Z"
"  Region: us-east-1"
"  SourceIP: 72.216.83.239"
"  Service: ec2.amazonaws.com"
"  Command: DescribeVpcs"
"  Error Code: Client.UnauthorizedOperation"
```

## Demo
![Image shows live demo of this code discovering, auditing, and disabling an AWS access key](https://github.com/kameenan/RSAC2020/raw/master/images/kmw-rsa-demo.gif)