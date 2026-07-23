# Developer Journal & Setup Guide

A central journal tracking the design, local installation, configuration, and architectural choices of the Geodata Searcher pipeline.

---

## 📝 Roadmap & Todo List

- [x] Get static base data from OSM or UDP using wget
- [x] insert data into PostgreSQL
- [ ] check inserted data
- [ ] real time streaming options
- [ ] Implement Kafka producer for real-time event streaming
- [ ] Setup Elasticsearch index mapping for spatial queries
- [ ] Configure Kibana dashboards for real-time visualization
- [ ] Implement unit tests for spatial data transformation logic
- [ ] Implement integration tests for Kafka-to-Elasticsearch pipeline
- [ ] Setup CI/CD pipeline for automated deployment to staging
- [ ] Monitoring and alerting with Prometheus and Grafana
- [ ] Document API endpoints for spatial search queries
- [ ] Setup automated backup strategy for PostGIS and Elasticsearch data
- [ ] Implement authentication and authorization for API endpoints
- [ ] Implement rate limiting and request logging for the API

---

## 🛠️ Installation & Environment Setup

### 1. Docker & Docker Compose

Install and configure the containerized runtime environment.

```bash
# Install Docker and Compose on Arch Linux
sudo pacman -S docker docker-compose

# Start and enable the Docker daemon
sudo systemctl enable --now docker.service

# Add current user to the docker group (requires re-login to take effect)
sudo usermod -aG docker $USER
```

### 2. Initialize Go Module & Dependencies

Set up the core data ingestion and processing services.

```bash
# Initialize the Go module
go mod init portfolio-geodata-pipeline

# Install the PostgreSQL/PostGIS driver
go get github.com/jackc/pgx/v5

# Install the Elasticsearch v8 client
go get github.com/elastic/go-elasticsearch/v8
```

---

## 🗄️ Database Initialization (PostgreSQL + PostGIS)

### 1. Connect to PostgreSQL

Access the database container via `psql`.

```bash
docker exec -it portfolio-postgres psql -U admin -d geodb
```

### 2. Enable PostGIS & Create Schema

Execute the following SQL queries to enable spatial features and define the geo-features table schema.

```sql
-- Enable the PostGIS spatial database extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create the table for spatial features
CREATE TABLE geo_features (
    id VARCHAR(100) PRIMARY KEY,
    feature_type VARCHAR(50) NOT NULL,
    properties JSONB NOT NULL,
    geom GEOMETRY(Geometry, 4326) NOT NULL -- 4326 represents WGS 84 (latitude/longitude)
);

-- Crucial: Add a spatial index (GIST) for sub-millisecond geographical queries
CREATE INDEX idx_geo_features_geom ON geo_features USING GIST(geom);
```

---

## 🏗️ Architecture Blueprint

```text


                  ┌────────────────────────────────────────────────────────┐
                  │                 REAL-TIME INGESTION LAYER              │
                  └────────────────────────────────────────────────────────┘
                                              │
 ┌──────────────────────┐          ┌──────────────────────┐
 │ GTFS-RT / GPS Stream │          │ OSM Minutely Diffs   │
 └──────────┬───────────┘          └──────────┬───────────┘
            │                                 │
            └──────────────┬──────────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │  Kafka Ingestion Topic  │  <-- Buffers incoming raw geospatial events
              └────────────┬────────────┘
                           │
            ┌──────────────┴──────────────┐  (Distributed Goroutine Workers)
            ▼                             ▼
  ┌──────────────────┐          ┌──────────────────┐
  │  Go Worker A     │          │  Go Worker B     │
  │  (PostGIS Sink)  │          │  (Elastic Sink)  │
  └─────────┬────────┘          └─────────┬────────┘
            │                             │
            ▼                             ▼
  ┌──────────────────┐          ┌──────────────────┐
  │ PostGIS Database │          │  Elasticsearch   │  <-- Powers Bounding-Box
  │ (Spatial Joins)  │          │  (Geo-Aggs)      │      & Geo-Distance Search
  └──────────────────┘          └─────────┬────────┘
                                          │
                                          ▼
                                ┌──────────────────┐
                                │ Kibana Dashboard │  <-- Live Heatmaps & Metrics
                                └──────────────────┘


```

---

## 🚀 Quick Reference Commands

### Start Services

Run the following command to spin up all backend containers (PostgreSQL, Elasticsearch, Kibana, etc.) in detached mode.

```bash
sudo docker compose up -d


```

## Next steps

### get data

Download OSM data for Hamburg at 'https://download.geofabrik.de/europe/germany/hamburg.html'

```bash
wget https://download.geofabrik.de/europe/germany/hamburg-latest.osm.pbf
```

### Information

Everything about the pbf format: https://wiki.openstreetmap.org/wiki/PBF_Format
