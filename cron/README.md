# Compose pattern

```yml
services:
  web:
    image: alchatti/drupal:apache-fpm
    volumes:
      - files:/mnt/files

  cron:
    image: alchatti/drupal:apache-fpm
    profiles:
      - cron
    volumes:
      - files:/mnt/files
    command: drush --root=/var/www/html/web cron

volumes:
  files:
```

## Usage
- Manual Run
```sh
docker compose run --rm cron
```

- Setup Cron with script
```sh
*/15 * * * * /path/to/run-drush-cron.sh >> /var/log/drush-cron.log 2>&1
```
# Kubernetes
using CronJob, if the Drupal files volume is also mounted by web pods, make sure the storage supports your access pattern. For multiple pods/jobs, RWX storage is usually cleaner. RWO can still work depending on node scheduling, but it is less flexible.

```yml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: drupal-cron
spec:
  schedule: "*/15 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 1
      activeDeadlineSeconds: 900
      template:
        spec:
          restartPolicy: Never
          securityContext:
            runAsUser: 33
            runAsGroup: 33
            fsGroup: 33
          containers:
            - name: drupal-cron
              image: alchatti/drupal:apache-fpm
              imagePullPolicy: IfNotPresent
              command:
                - drush
                - --root=/var/www/html/web
                - cron
              envFrom:
                - configMapRef:
                    name: drupal-config
                - secretRef:
                    name: drupal-secrets
              volumeMounts:
                - name: drupal-files
                  mountPath: /mnt/files
          volumes:
            - name: drupal-files
              persistentVolumeClaim:
                claimName: drupal-files
```
