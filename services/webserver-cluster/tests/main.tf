provider "aws" {
    region = "us-east-1"
}

module "webserver_cluster" {
    source = "../"
    # source = "git::git@github.com:9ide0n/terraform-modules.git//services/webserver-cluster?ref=enable_new_user_data"
    # source = "git::git@gitlab.com:9ide0n/terraform-modules.git//services/webserver-cluster?ref=enable_new_user_data"
    cluster_name = "webservers-stage"
    db_remote_state_bucket = "9ide0n-s3-terraform-state"
    db_remote_state_key = "stage/data-stores/mysql/terraform.tfstate"
    instance_type = "t2.micro"
    min_size = 1
    max_size = 1
    enable_autoscaling=false
    # enable_new_user_data=true
}

output "app_endpoint" {
    value = "${module.webserver_cluster.elb_dns_name}"   
}
