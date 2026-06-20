WIP

## Usage example

```yml
services:
  drupal-app:
    image: alchatti/drupal:apache
    environment:
      - DRUPAL_SUBDIR=${DRUPAL_SUBDIR}
    labels:
      - "traefik.enable=true"
      
      # Tell Traefik to look for Apache on port 8080
      - "traefik.http.services.drupal-app.loadbalancer.server.port=8080"

      # --- Dynamic Subsite / Root Router ---
      - "traefik.http.routers.drupal-site.rule=Host(`example.com`) && PathPrefix(`/${DRUPAL_SUBDIR}`)"
      - "traefik.http.routers.drupal-site.entrypoints=websecure"
      - "traefik.http.routers.drupal-site.tls=true"

      # --- Subdomain Router ---
      - "traefik.http.routers.drupal-subdomain.rule=Host(`site.example.com`)"
      - "traefik.http.routers.drupal-subdomain.entrypoints=websecure"
      - "traefik.http.routers.drupal-subdomain.tls=true"
```
