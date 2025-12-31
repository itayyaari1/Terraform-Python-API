# Design Review – Python API with Automated Deployment and Teardown

## 1. Overview
This document describes the proposed design, architecture, and step-by-step implementation plan for the **Python API Application with Automated Deployment and Teardown** task.  
The goal is to provide a clear, production-oriented design review that can be directly used to guide implementation (e.g., via Cursor) and explained confidently during an interview.

---

## 2. Objectives and Scope

### Objectives
- Build a clean and well-structured Python API using FastAPI
- Containerize the application using Docker with optimized image size
- Fully automate infrastructure provisioning and teardown using Terraform
- Ensure basic security best practices (IP whitelisting, optional API key)
- Provide clear documentation and reproducible setup

### Non-Goals
- High availability or autoscaling
- CI/CD pipelines
- Advanced secret management (e.g., AWS Secrets Manager)

---

## 3. High-Level Architecture

Local Machine  
└── Terraform  
  ├── Creates EC2 Instance  
  ├── Creates Security Group (IP-restricted)  
  └── user_data bootstrap script  
    └── Docker Engine  
      └── Python API Container  
        ├── FastAPI application  
        ├── In-memory shared state  
        └── SQLite database (logs)

---

## 4. Application Design

### Shared State
The application maintains a simple in-memory shared state:
- counter (int)
- message (string)

State is reset on container restart – an accepted trade-off for this task.

### Endpoints
- GET /status
- POST /update
- GET /logs (paginated)

---

## 5. Logging and Persistence
- SQLite database
- Logs include timestamp, old value, and new value
- Database initialized at startup

---

## 6. Security
- EC2 Security Group allows traffic only from the Terraform runner IP
- Optional API Key via X-API-KEY header

---

## 7. Docker Design
- Multi-stage Dockerfile
- Slim runtime image
- Exposes port 5000
- Runs with Uvicorn

---

## 8. Terraform Design
- Amazon Linux 2
- t2.micro instance
- Docker installation via user_data
- Output: public IP

---

## 9. Step-by-Step Implementation Plan
1. Create project skeleton
2. Implement FastAPI app
3. Add validation and update logic
4. Add SQLite logging
5. Dockerize application
6. Write Terraform configuration
7. Deploy and verify
8. Teardown with terraform destroy

---

## 10. Design Decisions
- FastAPI chosen for typing and validation
- SQLite chosen for simplicity
- In-memory state accepted for scope
- user_data preferred over config-management tools

---

## 11. Interview Readiness
This design supports clear discussion of architecture, security, automation, trade-offs, and testing.
