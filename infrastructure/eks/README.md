## HOW TO

EKS cluster is created using an opensource tool called [eksctl](https://eksctl.io), which is from weaveworks and officially supported by AWS.

Download the tool from `https://github.com/weaveworks/eksctl/releases/tag/v0.72.0`

To use the kubeconfig file from aws, you need aws-authenticator.
Download the aws authenticator from `https://github.com/kubernetes-sigs/aws-iam-authenticator/releases`

Update the cluste config file with details of vpc for specific environment, name of the cluster.
Kubernetes version 1.23 onwards EBS volume driver is not natively installed and needs to be created as a separate addon.
To Create cluster

```
eksctl create cluster -f eks_cluster_config.yaml --profile `aws-profile-name` #use profile with eks full access or create access ex. - git-deploy
```
Create a .yaml file to store the kubeconfig context, set the env KUBECONFIG variable to it.
export KUBECONFIG="~/create-file.yaml"

aws eks update-kubeconfig --name `cluster-name` --profile `aws-profile-name`

try to check kubectl get operations work or not.



To Enable cluster Autoscaler

Add following labels to the node group in aws console
```
k8s.io/cluster-autoscaler/<my-cluster> 	owned
k8s.io/cluster-autoscaler/enabled 	true
```

Create an IAM policy

> Replace the <my-cluster> filed

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/k8s.io/cluster-autoscaler/<my-cluster>": "owned"
                }
            }
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeAutoScalingGroups",
                "ec2:DescribeLaunchTemplateVersions",
                "autoscaling:DescribeTags",
                "autoscaling:DescribeLaunchConfigurations"
            ],
            "Resource": "*"
        }
    ]
}
```

```
aws iam create-policy \
    --policy-name AmazonEKSClusterAutoscalerPolicy \
    --policy-document file://cluster-autoscaler-policy.json
```

Create IAM Role and Attach to IAM policy

```
eksctl create iamserviceaccount \
  --cluster=<my-cluster> \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --attach-policy-arn=arn:aws:iam::<111122223333>:policy/<AmazonEKSClusterAutoscalerPolicy> \
  --override-existing-serviceaccounts \
  --approve
```

Deploy the Cluster Autoscaler

> Change the REPLACE* variables in the file

```
kubectl apply -f cluster-autoscaler-autodiscover.yaml
```

## Note:

To get the complete list of options for the config file, run the below command or, [refer](https://eksctl.io/usage/schema/)
```
eksctl create cluster --dry-run > cluster_config.yaml
```
