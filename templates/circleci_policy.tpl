{
   "Version": "2012-10-17",
   "Statement" : [
      {
         "Action" : ["s3:*"],
         "Effect" : "Allow",
         "Resource" : [
            "${bucket_arn}",
            "${bucket_arn}/*"
         ]
      },
      {
          "Action" : [
              "sqs:*"
          ],
          "Effect" : "Allow",
          "Resource" : ["${sqs_queue_arn}"]
      },
      {
          "Action": [
              "ec2:Describe*",
              "ec2:CreateTags",
	      "cloudwatch:*",
              "iam:GetUser",
              "autoscaling:CompleteLifecycleAction"
          ],
          "Resource": ["*"],
          "Effect": "Allow"
      },

      {
              "Action": [
                  "ec2:RunInstances",
                  "ec2:CreateVolume",
                  "ec2:CreateTags"
              ],
              "Effect": "Allow",
              "Resource": "arn:aws:ec2:${aws_region}:*"
          },
          {
              "Action": [
                  "ec2:Describe*"
              ],
              "Effect": "Allow",
              "Resource": "*"
          },
          {
              "Action": [
                  "ec2:StartInstances",
                  "ec2:StopInstances",
                  "ec2:TerminateInstances",
                  "ec2:AttachVolume",
                  "ec2:DetachVolume",
                  "ec2:DeleteVolume"
              ],
              "Effect": "Allow",
              "Resource": "arn:aws:ec2:${aws_region}:*:*/*",
              "Condition": {
                  "StringEquals": {
                      "ec2:ResourceTag/ManagedBy": "circleci-vm-service"
                  }
              }
          },
          {
              "Action": [
                 "sts:AssumeRole"
              ],
              "Resource": [
                  "arn:aws:iam::*:role/${role_name}"
              ],
              "Effect": "Allow"
          },
          {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeAssociation",
                "ssm:GetDeployablePatchSnapshotForInstance",
                "ssm:GetDocument",
                "ssm:DescribeDocument",
                "ssm:GetManifest",
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:ListAssociations",
                "ssm:ListInstanceAssociations",
                "ssm:PutInventory",
                "ssm:PutComplianceItems",
                "ssm:PutConfigurePackageResult",
                "ssm:UpdateAssociationStatus",
                "ssm:UpdateInstanceAssociationStatus",
                "ssm:UpdateInstanceInformation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2messages:AcknowledgeMessage",
                "ec2messages:DeleteMessage",
                "ec2messages:FailMessage",
                "ec2messages:GetEndpoint",
                "ec2messages:GetMessages",
                "ec2messages:SendReply"
            ],
            "Resource": "*"
        }
   ]
}
