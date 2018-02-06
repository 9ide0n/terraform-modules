provider "aws" {
    region = "us-east-1"
}

# instead of instance we use launch_configuration for asg with same params as instance
resource "aws_launch_configuration" "example" {
    image_id = "ami-41e0b93b"
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.instance.id}"]
    # use output of the template_file data sourcre defined in data_sources.tf (rendered with vars user-data.sh)
    user_data = "${data.template_file.user_data.rendered}" 
    # we must sure that instance created by launch_configuration will be successfully created, only then the old-one will be destroyed
    # this attribute should be set to all linked primitives in our case aws_security_group
    lifecycle {
        create_before_destroy = true
    }
}



resource "aws_autoscaling_group" "example" {
    launch_configuration = "${aws_launch_configuration.example.id}"
    # allow asg to work with all AZs we get from AWS with data_source call
    availability_zones = ["${data.aws_availability_zones.all.names}"]
    # when new instance creating/destroying register it into ELB
    load_balancers = ["${aws_elb.example.name}"]
    # use ELB healthchecks to auto replace instances if they are dead/unhealthy
    health_check_type = "ELB"
    min_size = 2
    max_size = 10
    tag {
        key = "Name"
        value = "terraform-asg-example"
        propagate_at_launch = true
    }
}

resource "aws_security_group" "instance" {
    name = "terraform-aws-launch-configuration-instance"

    ingress {
        from_port = "${var.server_port}"
        to_port = "${var.server_port}"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    lifecycle {
        create_before_destroy = true
    }

}

resource "aws_elb" "example" {
    name = "terraform-asg-example"
    availability_zones = ["${data.aws_availability_zones.all.names}"]
    security_groups = ["${aws_security_group.elb.id}"]

    # configure elb to route traffic to instanses port
    listener {
        lb_port = 80
        lb_protocol = "http"
        instance_port = "${var.server_port}"
        instance_protocol = "http"
    }

    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        interval = 30
        # check health by sending HTTP GET request to / uri
        target = "HTTP:${var.server_port}/"
    }

}

resource "aws_security_group" "elb" {
    name = "terraform-example-elb"
    # allow incoming http requests to elb
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # allow outgoing traffic to allow elb to make healthchecks of balanced instances
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

} 
