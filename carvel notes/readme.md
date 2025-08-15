

pause package:
kctrl package installed pause -n tanzusm -i sm -y
kctrl package installed pause -n tanzusm -i ensemble-helm -y
kctrl package installed list -n tanzusm

Get broken deployments:
k get deploy -n tanzusm | grep 0/1

./adjust-deployment-probes.sh ensemble-observability-store tanzusm
./adjust-deployment-probes.sh ensemble-observability-alerts tanzusm
./adjust-deployment-probes.sh ensemble-notifications-service tanzusm
./adjust-deployment-probes.sh ensemble-user-service tanzusm
