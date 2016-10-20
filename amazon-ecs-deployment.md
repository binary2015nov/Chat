## Chat on .NET Core with Deployment to AWS EC2 Container Services
We've updated this repository to work with ServiceStack preview .NET Core support and showing a simple deployment process to AWS EC2 Container Services.

This setup runs the Chat application on a simple custom Docker image based on Microsoft's `microsoft/dotnet:latest` image. The Chat application is then built into this custom image and uploaded to AWS EC2 Container Repository.

Part of the advantage of running .NET Core is being able to use common Linux tooling and services like Travis CI. This Chat Docker image is built and uploaded via Travis CI and then the AWS CLI is used to trigger a deployment and restart of the services.
> Note if this application was setup to run across multiple containers and ports behind and load balancer, this would allow for zero down time deployment, but to keep this tutorial simple we are just restarting the single container service.

## Preparing your ECS Cluster
To set this up, you'll need an AWS account and use of a region that supports EC2 Container Services (ECS). 

First some basics. AWS ECS is an orchestration setup for hosting and deploying Docker applications, it still needs EC2 instances to run the services on. 
AWS provides pre-built AWS EC2 images (AMIs) optimised for ECS, but before we launch one of these images, we'll need to ensure we have the permissions we need to use EC2 and ECS together. To do this, we first need to create an `ecsInstanceRole`. Follow the abridged steps below or goto [AWS Docs for full instructions](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/instance_IAM_role.html).

#### Create `ecsInstanceRole` IAM Role

1. To create the `ecsInstanceRole` IAM role for your container instances

2. Open the Identity and Access Management (IAM) console at https://console.aws.amazon.com/iam/

3. In the navigation pane, choose Roles and then choose **Create New Role**

4. In the Role Name field, type `ecsInstanceRole` to name the role, and then choose **Next Step**

5. In the Select Role Type section, choose **Select** on the right of the **Amazon EC2** Role for EC2 Container Service role

6. In the Attach Policy section, select the `AmazonEC2ContainerServiceforEC2Role` policy and then choose **Next Step**

Review your role information and then choose Create Role to finish.

#### Add Trust relationship between new role and EC2

1. Open the Identity and Access Management (IAM) console at: https://console.aws.amazon.com/iam/

2. In the navigation pane, choose **Roles**

3. Choose the **Permissions** tab

4. In the Managed Policies section, ensure that the `AmazonEC2ContainerServiceforEC2Role` managed policy is attached to the role. If the policy is attached, your Amazon ECS instance role is properly configured. If not, follow the substeps below to attach the policy.

5. Choose **Attach Policy**

6. In the Filter box, type `AmazonEC2ContainerServiceforEC2Role` to narrow the available policies to attach

7. Check the box to the left of the `AmazonEC2ContainerServiceforEC2Role` policy and choose **Attach Policy**

8. Choose the **Trust Relationships** tab, and **Edit Trust Relationship**

9. Verify that the trust relationship contains the following policy. If the trust relationship matches the policy below, choose **Cancel**. If the trust relationship does not match, copy the policy into the Policy Document window and choose **Update Trust Policy**.

``` json
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

To push docker images, we'll also need an IAM account with the following permissions by [attaching the following policies to a IAM user](https://console.aws.amazon.com/iam/home):
 
 - AmazonEC2ContainerRegistryFullAccess
 - AmazonEC2ContainerServiceFullAccess
 - AmazonEC2ContainerServiceRole

#### Create your EC2 instance for use with ECS

 1. Goto the [AWS EC2 console](https://console.aws.amazon.com/ec2/v2/home) and select **Launch instance**
 2. Click **AWS Marketplace**
 3. Search for `ecs-optimized`
 4. Select the **Amazon ECS-Optimized Amazon Linux AMI**
 5. Select your preferred instance size, **t2.micro** will be enough for a demo application. Click **Next: Configure Instance Details**
 6. In the Instance Configuration details, **Ensure you've added the `ecsInstanceRole` as the IAM Role**. (If this is not visible, see instructions above)
 7. In the **Tag Instance** tab you can tag the instance so you can easily find it in your **AWS EC2 Console**
 8. In the **Configure Security Group** tab ensure you open appropriate ports like SSH (22), HTTP (80), HTTPS (443), etc that you want to access the instance with. 
 9. Click **Review and Launch**, double-check your Instance details then click **Launch** to Launch your instance

Once your instance has started and is ready to use, navigate to the AWS EC2 Container Services console.

By default, these instances join the EC2 Container Service cluster named `default`. You can use a different cluster, but the instance will have to be configured, [see the AWS documentation](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_container_instance.html) for more details.

If your new EC2 instance has started and is ready, you should see the `default` cluster available. 

Once the EC2 instance is successfully in the `default` cluster, we want to setup an nginx proxy that will automatically pick up our application domain names and ports so every time we push a new application to the cluster, we can easily make it available via a custom subdomain.

To do this, we can use [this nginx proxy](https://github.com/jwilder/nginx-proxy) by SSHing into your new EC2 instance and running the following command.

``` shell
docker run -d -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock:ro jwilder/nginx-proxy
```

Once running, any other docker appications running in `bridge` with specified `VIRTUAL_HOST` and `VIRTUAL_PORT` environment variables will be proxied.

## Building your Docker image
To build a docker image, your application will need a `Dockerfile` in your repository. For this process, we use the Dockerfile to build your application into the Docker image itself. For example,

##### Dockerfile
``` Dockerfile
FROM microsoft/dotnet:latest
COPY src/Chat /app
WORKDIR /app
RUN ["dotnet", "restore"]
RUN ["dotnet", "build"]
EXPOSE 5000/tcp
ENV ASPNETCORE_URLS https://*:5000
ENTRYPOINT ["dotnet", "run", "--server.urls", "http://*:5000"]
```

## Pushing to AWS Docker Repository
To make this process more integrated, AWS also provides a provide Docker repository to upload your images. This will feed into the build process as it is where our built Chat docker image has to be uploaded before it is deployed.

1. Navigate to the `Repositories` menu on the left and click `Create repository`.
2. Name your repository to match your application, eg `netcoreapps-chat`. 

Once this is done, you'll be presented with a help screen that shows you how to push images to the repository, this is already included in the below scripts to help make it easier to setup multiple applications in a single ECS cluster.

## Automate deployment of your .NET Core application to ECS
In this example, we are using Travis CI to build and build our Docker image to our Amzon Elastic Container Repository (ECR). Travis CI is driven off a `.travis.yml` file in the root of the GitHub repository, below is an example of the Beta support for building .NET Core applications on Travis CI.

##### .travis.yml
``` yaml
sudo: required
language: csharp
solution: src/Chat.sln
services:
  - docker
matrix:
  include:
    - os: linux
      dist: trusty
      sudo: required
      dotnet: 1.0.0-preview2-003121
      mono: none
      env: DOTNETCORE=1
script:
  - chmod +x ./deploy-envs.sh
  - chmod +x ./scripts/build.sh
  - chmod +x ./scripts/deploy.sh
  - cd scripts && ./build.sh
  - if [ "$TRAVIS_BRANCH" == "master" ]; then ./deploy.sh; fi
```
The above script it using a `matrix` of one initially just using ubuntu to build the docker .NET Core application, but this could be expanded to include other operating systems by adding to the `matrix` in the future.

Since we need to authenticate with AWS for this deploy process, we will also have to provide credentials to Travis CI via environment variables for the AWS CLI to call the approporate APIs. The variables can be set as private variables via the Travis CI UI or via encrypted variables in the `.travis.yml` itself.

The environment variables that need to be set are:

 - `AWS_ACCESS_KEY_ID` (from the IAM account created above)
 - `AWS_SECRET_ACCESS_KEY` (from the IAM account created above)
 - `AWS_ACCOUNT_NUMBER` (used for generating correct ECR URL for pushing docker images)
 
We also include a `build.sh` and a `deploy.sh` which are already setup to build and deploy a .NET Core application given your specific application build and deploy config set in `deploy-envs.sh` file.

To use these scripts for yourself, start with the following steps.
1. Copy the `build` directory to the root of your repository
2. Copy and modify the `Dockerfile` to build your application docker image
3. Copy and modify the `.travis.yml` file to run your build process (ie, point at your `.sln` file).
4. Copy and modify the `deploy-envs.sh` file to name the docker image and AWS ECS image repository yourself.

For example, the Chat application uses the following configuration. 

##### deploy-envs.sh
``` shell
#!/bin/bash

# Set variables
export IMAGE_NAME=netcoreapps-chat
export IMAGE_VERSION=latest
export AWS_DEFAULT_REGION=us-east-1
export AWS_ECS_CLUSTER_NAME=default

export AWS_VIRTUAL_HOST=chat.netcore.io
```

## Configuring your application container
AWS ECS defines contains via a `task-definition`, in the `deploy.sh` we perform a token replacement via the bash util `sed` for some of the environment variables above so that the only custom settings are related to the container and the host. Settings such as memory, cpu, ports and task specific environment variables such as `VIRTUAL_HOST`, `VIRTUAL_PORT`. For example,

##### task-definition.json

``` json
{
    "family": "__ECS_TASK__",
    "networkMode": "bridge",
    "containerDefinitions": [
        {
            "image": "__AWS_ECS_REPO_DOMAIN__/__IMAGE_NAME__:__IMAGE_VERSION__",
            "name": "__IMAGE_NAME__-container",
            "cpu": 128,
            "memory": 256,
            "essential": true,
            "portMappings": [
                {
                    "containerPort": 5000,
                    "hostPort": 5000,
                    "protocol": "tcp"
                }
            ],
            "environment": [
                {
                    "name": "VIRTUAL_HOST",
                    "value": "chat.layoric.org"
                },
                {
                    "name": "VIRTUAL_PORT",
                    "value": "5000"
                }
            ]
        }
    ]
}
```

The `portMappings` `hostPort` is important as this should be unique per application (ECS service) deployed to your cluster. 

Which leaves the `build.sh` and the `deploy.sh`. `build.sh` sets the configuration via `deploy-envs` and builds the docker image.

##### build.sh
``` build.sh
#!/bin/bash
source ../deploy-envs.sh

#AWS_ACCOUNT_NUMBER={} set in private variable
export AWS_ECS_REPO_DOMAIN=$AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

# Build process
docker build -t $IMAGE_NAME ../
docker tag $IMAGE_NAME $AWS_ECS_REPO_DOMAIN/$IMAGE_NAME:$IMAGE_VERSION
```


The `deploy.sh` contains the logic for deploying to the `default` ECS cluster and should (like `build.sh`) live at the root of your application's repository.

##### deploy.sh
``` deploy.sh
#!/bin/bash
source ../deploy-envs.sh

#AWS_ACCOUNT_NUMBER={} set in private variable
export AWS_ECS_REPO_DOMAIN=$AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
export ECS_SERVICE=$IMAGE_NAME-service
export ECS_TASK=$IMAGE_NAME-task

# install dependencies
sudo apt-get install jq -y #install jq for json parsing
sudo apt-get install gettext -y 
pip install --user awscli # install aws cli w/o sudo
export PATH=$PATH:$HOME/.local/bin # put aws in the path

# replace environment variables in task-definition
envsubst < task-definition.json > new-task-definition.json

eval $(aws ecr get-login --region $AWS_DEFAULT_REGION) #needs AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY envvars
docker push $AWS_ECS_REPO_DOMAIN/$IMAGE_NAME:$IMAGE_VERSION
aws ecs register-task-definition --cli-input-json file://new-task-definition.json --region $AWS_DEFAULT_REGION > /dev/null # Create a new task revision
TASK_REVISION=$(aws ecs describe-task-definition --task-definition $ECS_TASK --region $AWS_DEFAULT_REGION | jq '.taskDefinition.revision') #get latest revision
SERVICE_ARN="arn:aws:ecs:$AWS_DEFAULT_REGION:$AWS_ACCOUNT_NUMBER:service/$ECS_SERVICE"
ECS_SERVICE_EXISTS=$(aws ecs list-services --region $AWS_DEFAULT_REGION --cluster $AWS_ECS_CLUSTER_NAME | jq '.serviceArns' | jq 'contains(["'"$SERVICE_ARN"'"])')
if [ "$ECS_SERVICE_EXISTS" == "true" ]; then
    echo "ECS Service already exists, Updating $ECS_SERVICE ..."
    aws ecs update-service --cluster $AWS_ECS_CLUSTER_NAME --service $ECS_SERVICE --task-definition "$ECS_TASK:$TASK_REVISION" --desired-count 1 --region $AWS_DEFAULT_REGION > /dev/null #update service with latest task revision
else
    echo "Creating ECS Service $ECS_SERVICE ..."
    aws ecs create-service --cluster $AWS_ECS_CLUSTER_NAME --service-name $ECS_SERVICE --task-definition "$ECS_TASK:$TASK_REVISION" --desired-count 1 --region $AWS_DEFAULT_REGION > /dev/null #create service
fi
if [ "$(aws ecs list-tasks --service-name $ECS_SERVICE --region $AWS_DEFAULT_REGION | jq '.taskArns' | jq 'length')" -gt "0" ]; then
    TEMP_ARN=$(aws ecs list-tasks --service-name $ECS_SERVICE --region $AWS_DEFAULT_REGION | jq '.taskArns[0]') # Get current running task ARN
    TASK_ARN="${TEMP_ARN%\"}" # strip double quotes
    TASK_ARN="${TASK_ARN#\"}" # strip double quotes
    aws ecs stop-task --task $TASK_ARN --region $AWS_DEFAULT_REGION > /dev/null # Stop current task to force start of new task revision with new image
fi
```

Now every commit will trigger a `build.sh` to run on Travis CI and every commit to master will build, push and deploy your application's new docker image.
