## Overview
This document serves as a documented reference to findings found when evaluating `AWS Codebuild Projects` as `Github Action Runners`
All testing and evaluation was done in the `regtech/devpub` IAM account.

---

### Components and Use Cases Evaluated

- Codebuild project runner for Github Pull Requests
- Log outputs for both AWS Codebuild and Github workflows
- AWS Secrets access from the github action workflow
- AWS Role and Codebuild runner scaling and scope
- Creating Cloudwatch log streams and generating Cloudwatch log events from github actioon workflows
- Reporting Codebuild status back to Github Source
- Passing in `buildspec.yml` (overriding) from GHA to Codebuild project
- Codebuild Runner Project Role and Permissions

---

### AWS Setup
This section outlines the configurations made in the AWS console to implement the testing that was performed.

- Create new Codebuild Project `cfpb-regtech-gha-test-1`. [Referenced](https://docs.aws.amazon.com/codebuild/latest/userguide/action-runner.html)
    - Create github PAT for AWS webhook and codebuild credential (github account)
    - Create new Service Role for codebuild project `cfpb-dev-regtech-codebuild-gha-test`
    - Create new SecretsManager Secret for PAT `cfpb/team/regtech/gha-codebuild-runner-test`
    - Required to set Webhook `WORKFLOW_JOB_QUEUED` for all runners.
- Create Custom inline policy for the role `RegtechCodeBuildGHARunner`.
    - this policy was started from the builtin `AWSCodeBuildDeveloperAccess` policy and upadated as needed.
- Create Cloudformation log group
- Created custom Cloudwatch streams and log events from GHA workflow.

> **NOTE** IAM Roles are region based. We will need a minimum of one Codebuild Runner Role configured for each region. Decisions will need to be made based on implementation requirments for how the runner roles are to be used. Options such as a role per product, per team, per repo etc... should be considered. In addition to the scope of Runner Roles, we need to determine what permissions are needed for each Role. Permission requirements might also determine how many roles we need. Limited risk of secrets expose and such can be achieved by controlling the role permission policies.

---

### Github Setup
This section outlines the configurations made in Github to implement the testing that was performed.
`cfpb/regtech-deployments` was used for this testing.
[Reference Source Repository/Branch](https://github.com/cfpb/regtech-deployments/tree/test/gha-codebuild-runner)

- Prerequisite for creating a Codebuild project using Github as the source was to have a Personal Access Token (PAT) configured in the Github account. I used my github account `thetoolsmith` which is configured in the CFPB Github Org.
The PAT needs to be configured with some required options. [Here](https://docs.aws.amazon.com/codebuild/latest/userguide/access-tokens-github.html) is a reference. 
- Created a test `buildspec.yml` in `regtech-deployments`
    - buildspec overriding in the codebuild runner project
    - passing github context into codebuild via buildspec
    - tested ECR access, Github Container Registry Access and some other basic things
- Created multiple GHA workflows to test basic actions
    - AWS Secrets reading and masking
    - AWS cli commands
    - Custom Composite Actions

---

### Log Output Codebuild vs Github
Each side of this itegration keep its own logs. Neither Github Action or Codebuild logs are exposed on the other end.
This is a good thing.

##### From the Github Side
All actions taken in GHA workflow, including reading secrets from AWS, are logged only to the GHA output. Nothing shows on the Cloudformation logs.
Example from GHA workflow kicking off the Codebuild Runner.....
```
> 2025-01-17T21:14:03.906Z
> 2025-01-17 21:14:01Z: Running job: test1
> 2025-01-17 21:14:01Z: Running job: test1
> 2025-01-17T21:14:21.926Z
> 2025-01-17 21:14:21Z: Job test1 completed with result: Succeeded
```
That ↑ is pretty much all we get in GHA logs when kicking off a job that has many steps but is running on a Codebuild project Runner.

##### From the Codebuild Side
All codebuild project actions are logged to Cloudwatch.
We created the Cloudwatch Log Group `/aws/codebuild/cfpb-regtech-gha-test-1` through AWS console.
All codebuild (runner) instances create logstreams for each `codebuild build run`. The streams can be matched up to the unique identifier in the build run name.
The basis high level Codebuild Steps are logged and whatever the `buildspec.yml` is doing if that was set as an override. See Overriding Buildspec Section.

> **NOTE** There will be one `codebuild build run` in the history for each GHA ***Job*** executed during a single Github Action workflow run. In our test, 3 GHA jobs were run each time the workflow run ocurred (update to the pull request).

> **WARNING** There is no easy visual way to match up a failed `Build run` in the codebuild UI with the matching Github Action Workflow **JOB**. For troubleshooting, you must click on the failed build run in the codebuild run history, and analyze the output to determine which github action workflow job caused it. The Github Action Job specific identifiers are not available on the AWS Codebuild project runner side. This makes sense being that nothing output from GHA workflow is logged on the Codebuild side.

---

### Testing Secrets and Masking in Github Workflow
Github Secrets are automatically transformed into environment variable and automatically masked. This is the default behavior in Github Actions for Github Secrets.

There is no apparent issues with Github Secrets being seen from the Codebuild project runner output.
***Logs on the Codebuild side do not include any of the log output from the Github action workflow run.***

However.....
Since the Github Workflow runner is running in the context of an AWS Role, there is the capability for secrets to be pulled out of SecretsManager vi a Github Action workflow. ***THESE SECRETS ARE NOT MASKED BY DEFAULT!***

The good thing is that we do not need to setup and establish AWS credentials in the Github action workflow since it's running with a runner in the context of a role that will determine what AWS services and permissions are allowed from the GHA workflow.

For testing, we used the `aws-actions/aws-secretsmanager-get-secrets@v2` action plugin in our GHA workflow.
The [plugin](https://github.com/aws-actions/aws-secretsmanager-get-secrets) is referenced in the [AWS documentation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets_github.html) for managing secrets from GHA workflows.

With the plugin, we can simply specify the AWS Secrets we would like to retreive. The Action automatically creates these secrets and the values as environment variables adding them to the github env context. They are in `plain-text`.
There is a method provided by GHA to mask these. It's an odd filter mechanism, `::add-mask::`, that needs to be passed to shell echo IMMEDIATLEY after the secret is retreived in order to prevent secrets values from leaking and appearing in the Github workflow run log output.

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

If we are getting many secrets, we can pass in the `secret-ids` list easily. But, we will need to write a function to iterate over all the retreived secrets and assure each one is passed to `::add-mask:;`. 
It's not a very user-freindly or smart way to handle secrets. The Action plugin, should just mask them automatically!

We did extensive testing around this to determine the best way this could be used. Not much options. We tried wrapping both the get and the masking build steps into a Custom Composite Action, but that doesn't make the process anymore easy or secure.

A decision will need to be made if the `aws-actions/aws-secretsmanager-get-secrets@v2` action should be used. We could not allow the Codebuild Project runner role access to SecretsManager which would prevent GHA workflows from being able to pull aws secrets.

---

### Performance
Without doing high scale performance testing, initial observations are that this implementation is pretty quick and snappy.
It's a matter of seconds before the codebuild runner starts from a new pr commit or whatever trigger we use.

I didn't notice any lag compared to using Github Action default public runners.

There is a 20 concurrent runner limit which is a default in AWS. This can be bumped as needed.
No testing was done on running more that one runner at a time for this initial analysis.

We didn't experience any hang on either the codebuild or github side.

##### Codebuild status via Github
By default, we do not get any status updates from Codebuild runs in the Github workflow run logs when passing in `buildspec.yml` override. [Buildspec Override Reference](https://docs.aws.amazon.com/codebuild/latest/userguide/action-runner.html)

As the aws documentation states, codebuild project runners use `buildspec` as well. So you override some of the codebuild phases by passing in a custom `buildspec.yml` from the Github source repo. But, you cannot use the BUILD phase.

> **NOTE** When passing in buildspec from the source github repo, if it fails during the build run in Codebuild, we do NOT get that failure back on the Github side. The GHA workflow run will show Success. This could lead to some false positve github workflow runs. There are a couple configuration options in Codebuild Projects that talk about providing status back to the provider. This will require some addition research. It appears that we need to configure [api calls](https://docs.github.com/en/rest/pulls/pulls?apiVersion=2022-11-28#update-a-pull-request) to update the Pull Request or other that is triggering the Codebuild run.

##### Report Codebuild Status back to Github
- https://docs.aws.amazon.com/codebuild/latest/userguide/change-project.html
- https://docs.aws.amazon.com/codebuild/latest/userguide/access-tokens-github.html

##### Access Tokens
As noted above, a Github Access Token is required in the Codebuild Project Configuration when creating a Runner project.
This token allows for the AWS to Github webhooks. So the token must have the repo webhook (or higher) permissions along with everything else that it might need.

This token does ***NOT*** grant Codebuild runner (or the IAM role) access to Github Container Registry.
We also noticed that a GHA workflow that is authenticated to GHCR by way of doing a Login in the workflow, does not persist on the Codebuild side when executing a `buildspec.yml` passed in as override.

The `buildspec.yml` runs in the context of the Codebuild project Service Role, but access to the Github Container Registry from within the `buildspec.yml` is not allowed by default even when the Github Action workflow that is passing in the `buildspec.yml` has authenticated to the GHCR.
This was a little unexpected.

If there is a use case for us to build and perform other tasks on an image that will be published to Github Container Registry, we will still need to authenticate to GHCR from within the `buildspec.yml` code.

---

### Misc

For passing `Github Action` variables to `Codebuild`, you can use the `env-vars-for-codebuild` option in the [AWS Codebuild Marketplace Action](https://github.com/marketplace/actions/aws-codebuild-run-build-action-for-github-actions#aws-codebuild-run-build-for-github-actions) for Github Actions.
This Marketplace Action also provides auto-triggering Codebuild project without using codebuild runners from Github pull requests, mergers etc...


