{{/*
_helpers.tpl — reusable template fragments shared across all chart templates.
*/}}

{{/*
Expand the chart name (used as a fallback for the app name).
Truncated at 63 chars — Kubernetes label value limit.
*/}}
{{- define "core-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full release name: "<release>-<chart>" or just "<release>" if it already contains the chart name.
Truncated at 63 chars to satisfy Kubernetes label constraints.
*/}}
{{- define "core-api.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label — "name-version", used in the helm.sh/chart label.
*/}}
{{- define "core-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Standard label set applied to every resource.

These four labels are the Kubernetes recommended label set:
  app.kubernetes.io/name      — the application name
  app.kubernetes.io/instance  — the Helm release name (allows multi-instance)
  app.kubernetes.io/version   — the app version (from Chart.appVersion)
  app.kubernetes.io/managed-by — always "Helm" so tooling can identify chart-managed resources

Using the full kubernetes.io label prefix (not just "app: foo") is the
production convention — it avoids collisions and enables label-based queries
across releases in the same namespace.
*/}}
{{- define "core-api.labels" -}}
helm.sh/chart: {{ include "core-api.chart" . }}
{{ include "core-api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — the minimal set used in spec.selector.matchLabels and
Service spec.selector. These MUST be stable across upgrades because
changing a selector on a Deployment requires deleting and recreating it.

Deliberately not including version here — a version label in the selector
would force a delete/recreate on every app version bump.
*/}}
{{- define "core-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "core-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name: use the override if provided, otherwise the full release name.
*/}}
{{- define "core-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "core-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
