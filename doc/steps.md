# setup steps

## let's prepare terraform for running
This will download aws plugin into .terraform
`terraform init`

## start 3 nodes on AWS
### impersonate that user locally by sourcing .secrets/aws_iam_nodes
That file is not found in git, it contains AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

### take a look at the plan
`terraform plan`

### actually create nodes
`terraform apply`
`terraform show`

## K3s is running
Terraform has ran commands to start k3s cluster via docker-compose, so we are set
