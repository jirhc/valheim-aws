#!/bin/bash
set -e

aws s3 cp s3://${bucket}/update_cname.json /home/${username}/valheim/update_cname.json

# Use IMDSv2 token-based metadata access (required since http_tokens = "required")
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $${IMDS_TOKEN}" http://169.254.169.254/latest/meta-data/instance-id)

PUBLIC_DNS=$(aws ec2 describe-instances --region ${aws_region} --instance-ids "$${INSTANCE_ID}" --query 'Reservations[].Instances[].PublicDnsName' | jq -r '.[]')

cat <<< $(jq --arg public_dns "$${PUBLIC_DNS}" '.Changes[0].ResourceRecordSet.ResourceRecords[0].Value = $public_dns' /home/${username}/valheim/update_cname.json) > /home/${username}/valheim/update_cname.json

aws route53 change-resource-record-sets --hosted-zone-id ${zone_id} --change-batch file:///home/${username}/valheim/update_cname.json
