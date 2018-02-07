# fetch aws_availability_zones datasource from AWS API 
data "aws_availability_zones" "all" {}

# connect to s3 backend and get state from mysql tfstate file to db datasource to later use in variables
data "terraform_remote_state" "db" {
    backend = "s3"
    config {
        bucket = "${var.db_remote_state_bucket}"
        key = "${var.db_remote_state_key}"
        region = "us-east-1"
    }
}
# create datasource that will return rendered template from file read by function file with vars defined in section map  
data "template_file" "user_data" {
    count = "${1 - var.enable_new_user_data}"
    template = "${file("${path.module}/user-data.sh")}"
    vars {
        server_port = "${var.server_port}"
        db_address = "${data.terraform_remote_state.db.address}"
        db_port  = "${data.terraform_remote_state.db.port}"
    }
}
# Add new data source for new template. The desicion whan data source to create will be based on enable_new_user_data
# value (vars.tf). If enable_new_user_data=true(1) then old ds count=1-1=0(not created) and new ds count=1(created).
#  Opposite enable_new_user_data=false(0) then old ds count=1-0=1(created), new ds count=0 (not created)
data "template_file" "user_data_new" {
    count = "${var.enable_new_user_data}"
    template = "${file("${path.module}/user-data-new.sh")}"
    vars {
        server_port = "${var.server_port}"
    }
}