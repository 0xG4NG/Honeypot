# Honeypot IAC

Proyecto para desplegar un honeypot en una sola VM Debian de Hetzner Cloud usando OpenTofu para la infraestructura y Ansible para instalar una stack de contenedores.

Servicios incluidos:

- `cowrie` como honeypot SSH
- `attack-ingestor` para persistir intentos de ataque en PostgreSQL
- `postgres` para almacenar eventos
- `prometheus` y `grafana` para métricas
- `postgres-exporter` y `cadvisor` para observabilidad

## Estructura

```text
.
├── ansible/
│   ├── group_vars/
│   ├── playbooks/
│   └── roles/
├── docs/
├── local/
├── opentofu/
    ├── modules/
    └── templates/
└── scripts/
```

## Requisitos

- Token de Hetzner Cloud
- Clave SSH local disponible (`id_ed25519` por defecto)
- Debian/Ubuntu local con `sudo` para despliegue completo
- Fedora local con `sudo` para pruebas Docker del stack local

Las dependencias locales (`tofu`, `ansible`, colecciones de Ansible y Docker para pruebas/checks) se instalan automáticamente desde los scripts.

## Despliegue en un click

Ejecuta:

```bash
./scripts/deploy-hetzner.sh
```

El script:

1. Pide el token de Hetzner y la clave SSH local.
2. Instala en tu máquina local las dependencias que falten.
3. Provisiona red, firewall y una VM Debian con OpenTofu.
4. Genera `ansible/inventory.ini`.
5. Espera a que la máquina esté lista y despliega toda la stack Docker automáticamente.

## Flujo manual

Si prefieres separar infraestructura y configuración:

```bash
cd opentofu
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu apply

cd ../ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.ini playbooks/site.yml --private-key ~/.ssh/id_ed25519
```

## Topología

- Una sola VM Debian en Hetzner.
- Cowrie escucha en el puerto público `22`.
- El SSH administrativo del servidor se mueve a `22222` desde `cloud-init`.
- PostgreSQL no se expone públicamente; queda solo dentro de Docker.

## Variables importantes

Las variables de despliegue están centralizadas en:

- `opentofu/variables.tf`
- `ansible/group_vars/all.yml`

## Cloud-init

OpenTofu usa `cloud-init` para:

- crear el usuario `adminops` con sudo sin password
- inyectar la clave SSH pública elegida
- mover el SSH administrativo al puerto `22222`
- instalar Python y dependencias mínimas para que Ansible pueda entrar en el primer intento

## Tests y desarrollo local

Para validar estructura y sintaxis sin tocar Hetzner:

```bash
./scripts/check.sh
```

Ese script comprueba:

- que las dependencias locales requeridas estén instaladas
- sintaxis de los scripts bash
- sintaxis del playbook de Ansible
- validez del `docker compose` local

Para levantar el stack en local con Docker:

```bash
./scripts/test-local.sh
```

Si quieres evitar `git clone` y `git pull`, puedes lanzar siempre la ultima version de `main` con una sola linea:

```bash
curl -fsSL https://raw.githubusercontent.com/0xG4NG/Honeypot/main/scripts/run-local-latest.sh | bash
```

Ese comando descarga un snapshot temporal del repositorio y ejecuta `scripts/test-local.sh`.

Para apagarlo y borrar volúmenes:

```bash
./scripts/stop-local.sh
```

Endpoints locales:

- Cowrie: `ssh -p 2222 root@127.0.0.1`
- Grafana: `http://127.0.0.1:3000`
- Prometheus: `http://127.0.0.1:9090`

Después de generar intentos SSH, puedes verificar persistencia así:

```bash
docker compose -f local/docker-compose.yml --env-file local/.env exec postgres \
  psql -U cowrie -d cowrie -c "select count(*) from cowrie_events;"
```

## Siguientes ajustes recomendados

- Restringir acceso SSH administrativo por IP.
- Añadir backups de PostgreSQL.
- Añadir alertas de Prometheus y dashboards específicos de Cowrie.
