# Documentación Técnica: Honeypot-IAC
**Versión:** 1.1.0 (Análisis de Estructura)  
**Fecha:** 10 de marzo de 2026

---

## 1. Introducción
Este proyecto despliega un Honeypot SSH (**Cowrie**) con persistencia en **PostgreSQL** y observabilidad mediante **Prometheus/Grafana**. La infraestructura se gestiona con **OpenTofu** (Hetzner Cloud) y la configuración con **Ansible**.

---

## 2. Análisis Detallado de la Estructura (File-by-File)

### 📂 /opentofu (Infraestructura como Código)
Define los recursos en la nube de Hetzner.
*   **`main.tf`**: Orquestador principal. Crea la red privada, el firewall y la instancia Debian.
*   **`variables.tf`**: Declaración de variables (región, tipo de servidor, IPs permitidas).
*   **`providers.tf`**: Configuración del conector con Hetzner Cloud.
*   **`templates/cloud-init.yaml.tftpl`**: Script de arranque. Mueve el SSH administrativo al puerto `22222` y prepara el usuario `adminops`.
*   **`outputs.tf`**: Muestra la IP pública resultante tras el despliegue.

### 📂 /ansible (Configuración de Software)
Automatiza la instalación dentro del servidor una vez creado.
*   **`playbooks/site.yml`**: Punto de entrada que ejecuta los roles en orden.
*   **`roles/common/`**: Tareas base (actualización de paquetes, herramientas esenciales).
*   **`roles/docker/`**: Instalación oficial del motor Docker y Docker Compose.
*   **`roles/stack/`**: Despliegue de los contenedores y sus archivos de configuración (`cowrie.cfg`, `prometheus.yml`).
*   **`group_vars/all.yml`**: Configuración global de puertos y rutas.

### 📂 /local (Entorno de Desarrollo)
Configuración optimizada para pruebas en tu máquina local.
*   **`docker-compose.yml`**: Define los 7 contenedores y cómo se comunican.
*   **`cowrie/`**: Configuración específica del honeypot (puertos, banners).
*   **`ingestor/attack_ingestor.py`**: El "pegamento". Script Python que lee el log de Cowrie y lo inserta en Postgres.
*   **`ingestor/Dockerfile`**: Define cómo empaquetar el script de Python con sus librerías (`psycopg2`).
*   **`prometheus/` & `grafana/`**: Provisionamiento automático de dashboards y fuentes de datos.

### 📂 /scripts (Automatización)
*   **`deploy-hetzner.sh`**: Ejecuta todo el flujo: Tofu Apply -> Generar Inventario -> Ansible Playbook.
*   **`test-local.sh`**: Levanta la stack en tu Docker local usando el puerto `2222`.
*   **`stop-local.sh`**: Apaga y limpia los volúmenes locales.
*   **`check.sh`**: Linter para validar que el código no tiene errores antes de subirlo.

---

## 3. Flujo de Datos y Operaciones

### 3.1. El Ciclo de un Ataque
1. **Entrada:** Atacante conecta al puerto 22.
2. **Registro:** Cowrie escribe en el volumen compartido `cowrie-var` (archivo `cowrie.json`).
3. **Persistencia:** `attack-ingestor` detecta la nueva línea y la guarda en la tabla `cowrie_events` de Postgres.
4. **Métricas:** `postgres-exporter` lee el estado de la DB para Prometheus.
5. **Panel:** Grafana lee de Postgres y Prometheus para pintar los mapas de calor y gráficas.

### 3.2. Comandos de Auditoría Críticos
*   **Ver ataques en tiempo real:**  
    `docker compose -f local/docker-compose.yml logs -f cowrie`
*   **Consultar DB manualmente:**  
    `docker compose -f local/docker-compose.yml exec postgres psql -U cowrie -d cowrie -c "SELECT * FROM cowrie_events LIMIT 5;"`

---

## 4. Seguridad
*   **Puerto 22:** Honeypot (Público).
*   **Puerto 22222:** SSH Real (Restringido por Firewall).
*   **Puerto 3000:** Dashboard Grafana (Protegido por contraseña).

*Documento actualizado para el equipo de desarrollo.*
