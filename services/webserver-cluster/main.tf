# instead of instance we use launch_configuration for asg with same params as instance
resource "aws_launch_configuration" "example" {
    image_id = "${var.ami}"
    instance_type = "${var.instance_type}"
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
    # add name with link launch_configuration name to allow the name of asg
    # change every time we change lc (change ami, user_data) - with new name 
    # asg will be marked to delete/create again - 1st thing what we need to achieve 
    # zero-time deployment - if we not recreating the asg it will not recreate its instances
    # so update will be anaviable until we manually delete/create asg or instances or asg scaling 
    # rules will be in place
    name = "${var.cluster_name}-${aws_launch_configuration.example.name}"
    launch_configuration = "${aws_launch_configuration.example.id}"
    # allow asg to work with all AZs we get from AWS with data_source call
    availability_zones = ["${data.aws_availability_zones.all.names}"]
    # when new instance creating/destroying register it into ELB
    load_balancers = ["${aws_elb.example.name}"]
    # use ELB healthchecks to auto replace instances if they are dead/unhealthy
    health_check_type = "ELB"
    min_size = "${var.min_size}"
    max_size = "${var.max_size}"
    # at least so many instances of new asg must be registered in ELB before old ASG and ELB links will be deleted
    min_elb_capacity = "${var.min_size}"
    # our asg with new instances with updated ami/user_data must be created first, register them in ELB
    #  and if all is ok - only then remove old ASG, its instances and ELB links - 2nd thing we need to achieve
    # to have zero-time deployment
    lifecycle {
        create_before_destroy = true
    }

    tag {
        key = "Name"
        value = "${var.cluster_name}-asg"
        propagate_at_launch = true
    }
}

resource "aws_security_group" "instance" {
    name = "${var.cluster_name}-sg-instance"

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_security_group_rule" "allow_http_inbound-instance" {
    type= "ingress"
    security_group_id = "${aws_security_group.instance.id}"
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_elb" "example" {
    name = "${var.cluster_name}-elb"
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
    # need to put here as this resource are dependent on ASG marked by this modificator
    lifecycle {
        create_before_destroy = true
    }

}

resource "aws_security_group" "elb" {
    name = "${var.cluster_name}-sg-elb"
    # need to put here as this resource are dependent on ASG marked by this modificator
    lifecycle {
        create_before_destroy = true
    }
    # move ingress and egress inline blocks to separate resources so we can redefine them in module caller
} 

# allow incoming http requests to elb
resource "aws_security_group_rule" "allow_http_inbound" {
    type= "ingress"
    security_group_id = "${aws_security_group.elb.id}"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

# allow outgoing traffic to allow elb to make healthchecks of balanced instances
resource "aws_security_group_rule" "allow_all_outbound" {
    type = "egress"
    security_group_id = "${aws_security_group.elb.id}"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}

# add two asg shedules based on asg name created at module
# if enable_autoscaling=true then terrafrom treat this as 1 and count=1 will create 1 resource
# like wo count at all. if enable_autoscaling=false then tf treat this as count=0 so recourse will not
# be created at all
resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
    count = "${var.enable_autoscaling}"
    scheduled_action_name = "scale-out-during-business-hours"
    min_size = 2
    max_size = 10
    desired_capacity = 5
    recurrence = "0 6 * * *" #6 at UTS, as we are at UTS+3 6+3=9:00
    autoscaling_group_name ="${aws_autoscaling_group.example.name}"
}
resource "aws_autoscaling_schedule" "scale_in_at_night" {
    count = "${var.enable_autoscaling}"
    scheduled_action_name = "scale-in-at-night"
    min_size = 2
    max_size = 10
    desired_capacity = 2
    recurrence = "0 14 * * *"#14 at UTS, as we are at UTS+3 14+3=17:00
    autoscaling_group_name ="${aws_autoscaling_group.example.name}"
}

# cloudwatch alarm if cpu uti of cluster will be > 90% during 300sec=5min
resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
    alarm_name = "${var.cluster_name}-high-cpu-utilization"
    namespace = "AWS/EC2"
    metric_name = "CPUUtilization"

    dimensions = {
        AutoScalingGroupName = "${aws_autoscaling_group.example.name}"
    }

    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 1 
    period = 300
    statistic = "Average"
    threshold = 90
    unit = "Percent"
}
# cloudwatch alarm which fires when cpucredits < 10% during 5 min. cpu credits only used it t type of
# instances so we must limit creating this resource only to them. "${var.instance_type}" already supply
# an instance type to module so if it it "t2.micro" or so we filter it by 1st letter - if it is 't' then 
# this alarm should be created 
resource "aws_cloudwatch_metric_alarm" "low_cpu_credit_balance" {
    count = "${format("%.1s", var.instance_type) == "t" ? 1 : 0}"

    alarm_name = "${var.cluster_name}-low-cpu-credit-balance"
    namespace = "AWS/EC2"
    metric_name = "CPUCreditBalance"

    dimensions = {
        AutoScalingGroupName = "${aws_autoscaling_group.example.name}"
    }

    comparison_operator = "LessThanThreshold"
    evaluation_periods = 1
    period = 300
    statistic = "Minimum"
    threshold = 10
    unit = "Count"

}