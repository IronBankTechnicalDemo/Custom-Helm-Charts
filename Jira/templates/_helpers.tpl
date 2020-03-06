{{/* Generate basic labels */}}
{{- define "jira-chart.labels" }}
  generator: helm
  date: {{ now | htmlDate }}
  chart: {{ .Chart.Name }}
  version: {{ .Chart.Version }}
  app_name: {{ .Chart.Name }}
  app_version: {{ .Values.image.tag }}
  release: {{ .Release.Name }}
  heritage: {{ .Release.Service }}
  app: {{ .Release.Name }}
{{- end }}

{{- define "imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.imagePullSecrets.registry (printf "%s:%s" .Values.imagePullSecrets.username .Values.imagePullSecrets.password | b64enc) | b64enc }}
{{- end }}