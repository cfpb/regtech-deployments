## Overview
This document serves as a documented reference to findings found when evaluating `AWS Codebuild Projects` as `Github Action Runners`
All testing and evaluation was done in the `regtech/devpub` IAM account.


### Components and Use Cases Evaluated

- Codebuild project runner for Github Pull Requests
- Log outputs for both AWS Codebuild and Github workflows
- AWS Secrets access from the github action workflow
- AWS Role and Codebuild runner scaling and scope
- Creating Cloudwatch log streams and generating Cloudwatch log events from github actioon workflows
- Reporting Codebuild status back to Github Source
- Passing in `buildspec.yml` (overriding) from GHA to Codebuild project
- Codebuild Runner Project Role and Permissions

### AWS Setup
This section outlines the configurations made in the AWS console to implement the testing that was performed.

- Create new Codebuild Project `cfpb-regtech-gha-test-1`. [Referenced](https://docs.aws.amazon.com/codebuild/latest/userguide/action-runner.html)
    - Create github PAT for AWS webhook and codebuild credential (github account)
    - Create new Service Role for codebuild project `cfpb-dev-regtech-codebuild-gha-test`
    - Create new SecretsManager Secret for PAT `cfpb/team/regtech/gha-codebuild-runner-test` 
- Create Custom inline policy for the role `RegtechCodeBuildGHARunner`.
    - this policy was started from the builtin `AWSCodeBuildDeveloperAccess` policy and upadated as needed.
- Create Cloudformation log group
- 

### Github Setup
This section outlines the configurations made in Github to implement the testing that was performed.
`cfpb/regtech-deployments` was used for this testing.  
[Reference Source Repository/Branch](https://github.com/cfpb/regtech-deployments/tree/test/gha-codebuild-runner)

1. A prerequisite for creating a Codebuild project using Github as the source was to have a Personal Access Token (PAT) configured in the Github account. I used my github account `thetoolsmith` which is configured in the CFPB Github Org.
The PAT needs to be configured with some required options. [Here](https://docs.aws.amazon.com/codebuild/latest/userguide/access-tokens-github.html) is a reference. 
1. Created a test `buildspec.yml` in `regtech-deployments`

### Log Output Codebuild vs Github
Each side of this itegration keep its own logs. Neither Github Action or Codebuild logs are exposed on the other end.
This is a good thing.

All actions taken in GHA workflow, including reading secrets from AWS, are logged only to the GHA output. Nothing shows on the Cloudformation logs.
Example from GHA workflow kicking off the Codebuild Runner.....
```
> 2025-01-17T21:14:03.906Z
> 2025-01-17 21:14:01Z: Running job: test1
> 2025-01-17 21:14:01Z: Running job: test1
> 2025-01-17T21:14:21.926Z
> 2025-01-17 21:14:21Z: Job test1 completed with result: Succeeded
```

### Testing Secrets and Masking in Github Workflow
Github Secrets are automatically transformed into environment variable and automatically masked. This is the default behavior in Github Actions for Github Secrets.

There is no apparent issues with Github Secrets being seen from the Codebuild project runner output.
***Logs on the Codebuild side do not include any of the log output from the Github action workflow run.***

However.....
Since the Github Workflow runner is not running in the context of an AWS Role, there is the capability for secrets to be pulled out of SecretsManager vi a Github Action workflow. ***THESE SECRETS ARE NOT MASKED BY DEFAULT!***

The good thing is that we do not need to setup and establish AWS credentials in the Github action workflow since it's running with a runner in the context of a role that will determine what AWS services and permissions are allowed from the GHA workflow.

For testing, we used the `aws-actions/aws-secretsmanager-get-secrets@v2` action plugin in our GHA workflow.
The [plugin](https://github.com/aws-actions/aws-secretsmanager-get-secrets) is referenced in the [AWS documentation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets_github.html) for managing secrets from GHA workflows.

With the plugin, we can simply specify the AWS Secrets we would like to retreive. The Action automatically creates these secrets and the values as environment variables adding them to the github env context. They are in `plain-text`.
There is a method provided by GHA to mask these. It's an odd filter mechanism, `::add-mask::`, that needs to be passed to shell echo IMMEDIATLEY after the secret is retreived in order to prevent secrets values from leaking and appearing in the Girhub workflow run log output.

The process requires 2 build steps. One to get the secrets and another to pass it to `::add-mask::`.
```
- name: get secrets from aws 
  uses: aws-actions/aws-secretsmanager-get-secrets@v2
  with:
    secret-ids: |
      TEST_SECRET_1, cfpb/team/regtech/gha-codebuild-runner/test-secret-1  
- name: mask the secrets
  run: |
    echo "::add-mask::${{ env.TEST_SECRET_1 }}"
```

From the point where you ***mask*** the secret through the rest of the workflow job, the secret will be masked. 

IF we are getting many secrets, we can pass in the `secret-ids` list easily. But, we will need to write a function to iterate over all the retreived secrets and assure each one is passed to `::add-mask:;`. 
It's not a very user-freindly or smart way to handle secrets. The Action plugin, should just mask them automatically!

We did extensive testing around this to deternine the best way this could be used. Not much options. We tried wrapping both the get and the masking build steps into a Custom Composite Action, but that doesn't make the process anymore easy or secure.

A decision will need to be made if the `aws-actions/aws-secretsmanager-get-secrets@v2` action should be used. We could not allow the Codebuild Project runner role access to SecretsManager which would prevent GHA workflows from being able to pull aws secrets.


### Misc

Passing `Github Action` vaiable to `Codebuild`, you can use the `env-vars-for-codebuild` option in the [AWS Codebuild Marketplace Action](https://github.com/marketplace/actions/aws-codebuild-run-build-action-for-github-actions#aws-codebuild-run-build-for-github-actions) for Github Actions.
This Marketplace Action also provides auto-triggering Codebuild from Github pull requests, mergers etc...


