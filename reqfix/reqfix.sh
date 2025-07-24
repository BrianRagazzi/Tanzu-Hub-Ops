kubectl -n tanzusm delete secret reqfix-overlay-secret reqfix-secret
kubectl create secret generic -n tanzusm reqfix-secret --from-file=./reqfix.yaml
kubectl patch -n tanzusm --type merge pkgi daedalus --patch '{"metadata":{"annotations":{"ext.packaging.carvel.dev/ytt-paths-from-secret-name.1": "reqfix-secret"}}}'
