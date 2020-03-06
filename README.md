#### README

### Installing Helm2
Think of Helm as your App Store for Kubernetes. While Rancher automatically enables Helm for you on the server-side, you need to install the commandline tool in order to deploy things outside of the rancher ui.
```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash
sleep 2
helm init

kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
helm init --service-account tiller --upgrade
```

