#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:?usage: ./bootstrap.sh <bootstrap|reset> <host> [user]}"
TARGET="${2:?missing host}"
USER_NAME="${3:-hgi}"

cat > ansible/inventory.ini <<EOF
[k3s]
gaming ansible_host=${TARGET} ansible_user=${USER_NAME} ansible_become=true
EOF

case "$ACTION" in
  bootstrap)
    ansible-playbook -i ansible/inventory.ini ansible/site.yml
    ;;
  reset)
    ansible-playbook -i ansible/inventory.ini ansible/reset.yml
    rm -f kubeconfig
    ;;
  *)
    echo "unknown action: $ACTION"
    exit 1
    ;;
esac
