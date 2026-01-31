{{- define "platform-apps.repoURL" -}}
{{- if eq .Values.environment "homelab" -}}
https://gitlab.home.rottlr.de/idp/platform/idp-argocd-platform-apps.git
{{- else -}}
https://github.com/QuantumDancer/idp-argocd-platform-apps.git
{{- end -}}
{{- end -}}

{{- define "platform-apps.targetRevision" -}}
{{- if or (eq .Values.environment "homelab") (eq .Values.environment "development") -}}
development
{{- else -}}
main
{{- end -}}
{{- end -}}
