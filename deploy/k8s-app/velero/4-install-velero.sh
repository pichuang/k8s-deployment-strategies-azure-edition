#!/bin/bash
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.9.2 \
    --bucket velero-backup \
    --secret-file minio-credentials.conf \
    --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://svc-minio.svc.default:9000 \

kubectl logs deployment/velero -n velero -f