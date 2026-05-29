#!/bin/bash
# Creates the Expiring Contracts & Licenses dashboard in Grafana

DS_UID="afnhwvbm6qscge"
GRAFANA="https://grafana-production-49fc.up.railway.app"
AUTH="admin:truespend_grafana_2026"

PAYLOAD=$(cat <<'ENDJSON'
{
  "overwrite": false,
  "dashboard": {
    "uid": "a1b2c3d4-expiry-dash-0001",
    "title": "Expiring Contracts & Licenses",
    "tags": ["truespend"],
    "timezone": "browser",
    "schemaVersion": 38,
    "refresh": "1h",
    "time": {"from": "now", "to": "now+90d"},
    "panels": [
      {
        "id": 1,
        "type": "stat",
        "title": "Contracts Expiring ≤90 Days",
        "gridPos": {"x": 0, "y": 0, "w": 6, "h": 4},
        "datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"},
        "options": {"reduceOptions": {"calcs": ["lastNotNull"]}, "colorMode": "background", "graphMode": "none"},
        "fieldConfig": {
          "defaults": {
            "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}, {"color": "yellow", "value": 3}, {"color": "red", "value": 6}]}
          }
        },
        "targets": [{"datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"}, "rawSql": "SELECT count(*) as value FROM contracts_expiring", "format": "table", "refId": "A"}]
      },
      {
        "id": 2,
        "type": "stat",
        "title": "Contracts Expiring ≤30 Days",
        "gridPos": {"x": 6, "y": 0, "w": 6, "h": 4},
        "datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"},
        "options": {"reduceOptions": {"calcs": ["lastNotNull"]}, "colorMode": "background", "graphMode": "none"},
        "fieldConfig": {
          "defaults": {
            "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}, {"color": "orange", "value": 1}, {"color": "red", "value": 3}]}
          }
        },
        "targets": [{"datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"}, "rawSql": "SELECT count(*) as value FROM contracts_expiring WHERE days_to_expiry <= 30", "format": "table", "refId": "A"}]
      },
      {
        "id": 3,
        "type": "stat",
        "title": "Licenses Expiring ≤90 Days",
        "gridPos": {"x": 12, "y": 0, "w": 6, "h": 4},
        "datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"},
        "options": {"reduceOptions": {"calcs": ["lastNotNull"]}, "colorMode": "background", "graphMode": "none"},
        "fieldConfig": {
          "defaults": {
            "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}, {"color": "yellow", "value": 3}, {"color": "red", "value": 8}]}
          }
        },
        "targets": [{"datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"}, "rawSql": "SELECT count(*) as value FROM license_entitlements WHERE term_end IS NOT NULL AND term_end >= current_date AND (term_end - current_date) <= 90", "format": "table", "refId": "A"}]
      },
      {
        "id": 4,
        "type": "stat",
        "title": "Contract Value at Risk (≤90d)",
        "gridPos": {"x": 18, "y": 0, "w": 6, "h": 4},
        "datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"},
        "options": {"reduceOptions": {"calcs": ["lastNotNull"]}, "colorMode": "value", "graphMode": "none"},
        "fieldConfig": {
          "defaults": {
            "unit": "currencyEUR",
            "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": null}, {"color": "orange", "value": 50000}, {"color": "red", "value": 250000}]}
          }
        },
        "targets": [{"datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"}, "rawSql": "SELECT coalesce(sum(value), 0) as value FROM contracts_expiring", "format": "table", "refId": "A"}]
      },
      {
        "id": 5,
        "type": "table",
        "title": "Contracts Expiring — Action Required",
        "gridPos": {"x": 0, "y": 4, "w": 24, "h": 10},
        "datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"},
        "options": {"sortBy": [{"displayName": "Days Left", "desc": false}], "footer": {"show": false}},
        "fieldConfig": {
          "defaults": {"custom": {"align": "left"}},
          "overrides": [
            {"matcher": {"id": "byName", "options": "Days Left"}, "properties": [
              {"id": "custom.width", "value": 90},
              {"id": "thresholds", "value": {"mode": "absolute", "steps": [{"color": "red", "value": null}, {"color": "orange", "value": 31}, {"color": "yellow", "value": 61}, {"color": "green", "value": 91}]}},
              {"id": "custom.displayMode", "value": "color-background"}
            ]},
            {"matcher": {"id": "byName", "options": "Value (EUR)"}, "properties": [
              {"id": "unit", "value": "currencyEUR"}, {"id": "custom.width", "value": 130}
            ]},
            {"matcher": {"id": "byName", "options": "Auto-Renew"}, "properties": [
              {"id": "custom.width", "value": 100},
              {"id": "mappings", "value": [{"type": "value", "options": {"true": {"text": "Yes", "color": "green"}, "false": {"text": "No", "color": "red"}}}]},
              {"id": "custom.displayMode", "value": "color-background"}
            ]},
            {"matcher": {"id": "byName", "options": "Renewal State"}, "properties": [
              {"id": "custom.width", "value": 150},
              {"id": "mappings", "value": [{"type": "value", "options": {
                "clean": {"text": "Clean", "color": "green"},
                "price_increase": {"text": "Price Increase", "color": "orange"},
                "volume_change": {"text": "Volume Change", "color": "yellow"},
                "scope_change": {"text": "Scope Change", "color": "orange"},
                "manual_required": {"text": "Manual Required", "color": "red"}
              }}]},
              {"id": "custom.displayMode", "value": "color-background"}
            ]}
          ]
        },
        "targets": [{"datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"},
          "rawSql": "SELECT name AS \"Contract\", supplier_name AS \"Supplier\", category AS \"Category\", expiry_date AS \"Expiry Date\", days_to_expiry AS \"Days Left\", notice_days AS \"Notice Days\", auto_renew AS \"Auto-Renew\", renewal_state AS \"Renewal State\", value AS \"Value (EUR)\" FROM contracts_expiring ORDER BY days_to_expiry ASC",
          "format": "table", "refId": "A"}]
      },
      {
        "id": 6,
        "type": "table",
        "title": "Licenses Expiring ≤90 Days",
        "gridPos": {"x": 0, "y": 14, "w": 14, "h": 9},
        "datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"},
        "options": {"sortBy": [{"displayName": "Days Left", "desc": false}], "footer": {"show": false}},
        "fieldConfig": {
          "defaults": {"custom": {"align": "left"}},
          "overrides": [
            {"matcher": {"id": "byName", "options": "Days Left"}, "properties": [
              {"id": "custom.width", "value": 90},
              {"id": "thresholds", "value": {"mode": "absolute", "steps": [{"color": "red", "value": null}, {"color": "orange", "value": 31}, {"color": "yellow", "value": 61}, {"color": "green", "value": 91}]}},
              {"id": "custom.displayMode", "value": "color-background"}
            ]},
            {"matcher": {"id": "byName", "options": "Utilization %"}, "properties": [
              {"id": "unit", "value": "percent"}, {"id": "custom.width", "value": 110},
              {"id": "thresholds", "value": {"mode": "absolute", "steps": [{"color": "red", "value": null}, {"color": "orange", "value": 20}, {"color": "yellow", "value": 50}, {"color": "green", "value": 75}]}},
              {"id": "custom.displayMode", "value": "color-background"}
            ]},
            {"matcher": {"id": "byName", "options": "Annual Cost (EUR)"}, "properties": [
              {"id": "unit", "value": "currencyEUR"}
            ]}
          ]
        },
        "targets": [{"datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"},
          "rawSql": "SELECT le.product_name AS \"Product\", s.name AS \"Supplier\", le.license_type AS \"Type\", le.total_seats AS \"Total Seats\", le.assigned_seats AS \"Assigned\", le.utilization_pct AS \"Utilization %\", le.term_end AS \"Expiry Date\", (le.term_end - current_date) AS \"Days Left\", le.annual_cost_eur AS \"Annual Cost (EUR)\" FROM license_entitlements le LEFT JOIN suppliers s ON s.id = le.supplier_id WHERE le.term_end IS NOT NULL AND le.term_end >= current_date AND (le.term_end - current_date) <= 90 ORDER BY le.term_end ASC",
          "format": "table", "refId": "A"}]
      },
      {
        "id": 7,
        "type": "table",
        "title": "License Waste — Shelfware & Overage",
        "gridPos": {"x": 14, "y": 14, "w": 10, "h": 9},
        "datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"},
        "options": {"footer": {"show": false}},
        "fieldConfig": {
          "defaults": {"custom": {"align": "left"}},
          "overrides": [
            {"matcher": {"id": "byName", "options": "Shelfware Seats"}, "properties": [
              {"id": "thresholds", "value": {"mode": "absolute", "steps": [{"color": "green", "value": null}, {"color": "orange", "value": 1}, {"color": "red", "value": 10}]}},
              {"id": "custom.displayMode", "value": "color-background"}
            ]},
            {"matcher": {"id": "byName", "options": "Waste (EUR/mo)"}, "properties": [
              {"id": "unit", "value": "currencyEUR"},
              {"id": "thresholds", "value": {"mode": "absolute", "steps": [{"color": "green", "value": null}, {"color": "yellow", "value": 500}, {"color": "red", "value": 2000}]}},
              {"id": "custom.displayMode", "value": "color-background"}
            ]}
          ]
        },
        "targets": [{"datasource": {"type": "grafana-postgresql-datasource", "uid": "afnhwvbm6qscge"},
          "rawSql": "SELECT product_name AS \"Product\", supplier_name AS \"Supplier\", shelfware_seats AS \"Shelfware Seats\", overage_seats AS \"Overage Seats\", monthly_waste_eur AS \"Waste (EUR/mo)\", utilization_pct AS \"Utilization %\" FROM license_waste_report ORDER BY monthly_waste_eur DESC NULLS LAST LIMIT 20",
          "format": "table", "refId": "A"}]
      }
    ]
  }
}
ENDJSON
)

curl -s -X POST \
  -u "$AUTH" \
  -H "Content-Type: application/json" \
  "$GRAFANA/api/dashboards/db" \
  -d "$PAYLOAD"
