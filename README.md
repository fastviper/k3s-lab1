# k3s-lab1
k3a cluster on AWS that runs simple python app connecting to cloud database. Simply an lab on exploring AWS further after flask1 project.

# setup steps

## Prepare AWS IAM user
### create IAM user on AWS that has full rights to create and manager EC2 instances
There are templates for that while creating user, just select everything with EC2 and Full in name.
Do not use your root AWS user and turn on MFA auth for that account!

### impersonate IAM user locally by pasting into console
```
export AWS_ACCESS_KEY_ID="YOUR IAM ACCESS ID"
export AWS_SECRET_ACCESS_KEY="YOUR IAM ACCESS KEY"
export AWS_DEFAULT_REGION="YOUR REGION LIKE eu-central-1"
ACCOUNT_ID=12_digit_id
```

## Do the terraforming
### init
This will download aws plugin into .terraform
`terraform init`

### take a look at the plan
`terraform plan`

### actually create nodes
```
terraform apply
terraform show
```

## K3s is running
Terraform has ran commands to start k3s cluster via docker-compose, so we are all set
`kubectl` works from user `ec2-user`

## Done with work? Destroy.
```
terraform destroy
```