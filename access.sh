#!/bin/bash
# Prints ArgoCD, Prometheus and Grafana URLs and credentials.
#
# Before running, give the AWS CLI credentials, for example:
#   export AWS_ACCESS_KEY_ID=...
#   export AWS_SECRET_ACCESS_KEY=...
# (or run `aws configure` once, entering region ap-southeast-2)
#
# Run:
#   chmod a+x access.sh
#   ./access.sh

set -u

REGION="${AWS_REGION:-ap-southeast-2}"
CLUSTER="${CLUSTER_NAME:-amazon-prime-cluster}"

if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "AWS credentials not found. Export AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY or run 'aws configure', then retry."
    exit 1
fi

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" || exit 1

if ! kubectl get nodes > /dev/null 2>&1; then
    echo "kubectl cannot reach the cluster. If you see 'Unauthorized', add an EKS access entry for this IAM user."
    exit 1
fi

# Load balancer hostnames (empty if not provisioned yet)
get_lb() {
    kubectl get svc "$1" -n "$2" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null
}

argo_url=$(get_lb argocd-server argocd)
argo_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode)

prometheus_url=$(get_lb stable-kube-prometheus-sta-prometheus prometheus)
grafana_url=$(get_lb stable-grafana prometheus)
grafana_password=$(kubectl get secret stable-grafana -n prometheus -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode)

echo "------------------------"
echo "ArgoCD URL: https://${argo_url:-<pending>}"
echo "ArgoCD User: admin"
echo "ArgoCD Initial Password: ${argo_password:-<not found>}"
echo
echo "Prometheus URL: http://${prometheus_url:-<pending>}:9090"
echo
echo "Grafana URL: http://${grafana_url:-<pending>}"
echo "Grafana User: admin"
echo "Grafana Password: ${grafana_password:-<not found>}"
echo "------------------------"