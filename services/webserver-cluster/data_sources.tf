# fetch aws_availability_zones datasource from AWS API 
data "aws_availability_zones" "all" {}

# connect to s3 backend and get state from mysql tfstate file to db datasource to later use in variables
data "terraform_remote_state" "db" {
    backend = "s3"
    config {
        bucket = "9ide0n-s3-terraform-state"
        key = "stage/data-stores/mysql/terraform.tfstate"
        region = "us-east-1"
    }
}
# create datasource that will return rendered template from file read by function file with vars defined in section map  
data "template_file" "user_data" {
    template = "${file("user-data.sh")}"
    vars {
        server_port = "${var.server_port}"
        db_address = "${data.terraform_remote_state.db.address}"
        db_port  = "${data.terraform_remote_state.db.port}"
    }
}