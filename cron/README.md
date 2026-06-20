## compose pattern

```yml
services:
  web:
    image: alchatti/drupal:apache-fpm
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - files:/mnt/files
    networks:
      - app

  cron:
    image: alchatti/drupal:apache-fpm
    profiles:
      - cron
    env_file:
      - .env
    volumes:
      - files:/mnt/files
    networks:
      - app
    command: drush --root=/var/www/html/web cron

volumes:
  files:

networks:
  app:
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
