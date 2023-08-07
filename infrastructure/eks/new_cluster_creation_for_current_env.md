New EKS cluster creation for current environments.

Since we are upgrading the cluster and rest of the associated services such as VMs, RDS and VPCs are same, only cluster configuration and creation should be done for current environment.

Clone hcx-devops repo, branch sprint-43 and go to infrastructure directory from root.
Cluster creation is in 2 parts

1. Infrastructure creation using terraform, for current this is already created and can be skipped.

2. EKS Cluster creation, this creates a EKS cluster and addons needed.

Pre-requisites:
    Install eksctl and aws cli tool if not exists.
    Create serviceaccount and roles for EBS and cluster-autoscaler plugins using ekstcl tool
    Note: Change the names according to the environment, for example :-  --cluster hcx-dev-1-27 needs to be changed to staging or prod one

    For EBS Volume:
    eksctl create iamserviceaccount --name ebs-csi-controller-sa --namespace kube-system --cluster hcx-dev-1-27 --attach-policy-arn arn:aws:iam::131795456882:policy/AmazonEKS_EBS_CSI_Driver_Policy --approve --role-name AmazonEKS_DEV_EBS_CSI_DriverRole_Dev --profile git-deploy --override-existing-serviceaccounts


    For ClusterAutoscaler:
    eksctl create iamserviceaccount \\n  --cluster=hcx-dev-1-27 \\n  --namespace=kube-system \\n  --name=cluster-autoscaler \\n  --attach-policy-arn=arn:aws:iam::131795456882:policy/AmazonEKSClusterAutoscalerPolicyDev127 \\n  --approve --profile git-deploy

    Update eks_cluster_config.yaml file with vpc/subnet of existing staging/production values as well as new cluster(Note. cluster cannot be same as cluster name)

Create the cluster:
eksctl create cluster -f eks_cluster_config.yaml --profile `aws-profile-name` #use profile with eks full access or create access ex. - git-deploy
Use aws cli tool to update kubeconfig file in your local
Run :- kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml to enable metrics components
Copy the hcx-ssl and hcx-dashboard-ssl secrets from current environment, this is needed since ssl certs for domains are fetched and stored in these secrets which are then used by nginx and dashboard-nginx.

Deployment of micro-services:
Once the cluster is created, deployment using github actions can be triggered
1. In GitHub Actions settings :- 
   Environment variable STAGING_CLUSTER_NAME/PROD_CLUSTER_NAME needs to be set to staging or prod cluster you have created above.
   Update and configure the DevOps/hcx/ansible/inventory/<environment>/helm yaml files based on dev environment.

2. Deploy the microservices using github jobs.
3. Verify all the jobs are running.
4. Run the test cases using loadbalancer urls of nginx-ingress and keycloak.
5. Get the loadbalancer urls of nginx-ingress and dashboard-ingress services stitched with current domains.