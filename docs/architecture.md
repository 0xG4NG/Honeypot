# Arquitectura

## Componentes

- OpenTofu crea red privada, firewall y una VM Debian en Hetzner Cloud.
- `cloud-init` prepara acceso SSH y prerrequisitos de Ansible desde el arranque.
- `cloud-init` mueve el SSH administrativo al puerto `22222` para dejar `22` disponible al honeypot.
- Ansible instala Docker y despliega `cowrie`, `attack-ingestor`, `postgres`, `prometheus`, `grafana`, `postgres-exporter` y `cadvisor`.
- Grafana queda accesible en el puerto `3000`.

## Flujo de datos

1. Un atacante interactúa con Cowrie por SSH.
2. Cowrie genera eventos JSON en un volumen compartido.
3. `attack-ingestor` sigue ese log y guarda eventos en PostgreSQL.
4. Prometheus monitoriza PostgreSQL y contenedores mediante exporters.
5. Grafana visualiza métricas de infraestructura y base de datos.

## Endpoints

- SSH honeypot: `tcp/22`
- SSH administrativo: `tcp/22222`
- Grafana: `tcp/3000`
- Prometheus: `tcp/9090`
- PostgreSQL: solo red interna Docker
