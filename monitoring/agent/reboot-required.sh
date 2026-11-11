#!/bin/sh
OUT=/var/lib/prometheus/node-exporter/reboot_required.prom
if [ -f /var/run/reboot-required ]; then v=1; else v=0; fi
echo "node_reboot_required $v" > "$OUT.$$" && mv "$OUT.$$" "$OUT"
