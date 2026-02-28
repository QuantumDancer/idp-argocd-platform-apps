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

{{- define "backstage.repoURL" -}}
{{- if eq .Values.environment "homelab" -}}
https://gitlab.home.rottlr.de/idp/platform/idp-portal-deployment.git
{{- else -}}
https://github.com/QuantumDancer/idp-portal-deployment.git
{{- end -}}
{{- end -}}

{{- define "backstage.targetRevision" -}}
{{- if or (eq .Values.environment "homelab") (eq .Values.environment "development") -}}
development
{{- else -}}
main
{{- end -}}
{{- end -}}

{{- define "crossplane-compositions.repoURL" -}}
{{- if eq .Values.environment "homelab" -}}
https://gitlab.home.rottlr.de/idp/platform/idp-crossplane-compositions.git
{{- else -}}
https://github.com/QuantumDancer/idp-crossplane-compositions.git
{{- end -}}
{{- end -}}

{{- define "crossplane-compositions.targetRevision" -}}
{{- if or (eq .Values.environment "homelab") (eq .Values.environment "development") -}}
development
{{- else -}}
main
{{- end -}}
{{- end -}}
