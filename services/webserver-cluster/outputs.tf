output "elb_dns_name" {
    value = "${aws_elb.example.dns_name}"   
}

# export asg name to allow modify asg schedule or events differently in stage/prod
# commented as we move asg schedule to module leaving end user more clear API with enable_autoscaling flag(vars.tf)
# output "asg_name" {
#     value = "${aws_autoscaling_group.example.name}"
# }

# export aws_security_group.elb.id to allow add ports to this rule in  in stage/prod
output "elb_security_group_id" {
    value = "${aws_security_group.elb.id}" 
}

output "version" {
    value = "v0.0.2"
}