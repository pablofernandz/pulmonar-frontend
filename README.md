
---

## README.md (frontend) — `pulmonar-frontend`

```md
# Pulmonar 2.0 — Frontend (Flutter)

Frontend del sistema “Desarrollo Pulmonar”, modernizado como parte del TFG. Aplicación **Flutter Web** con navegación por rutas y control de acceso por rol, consumiendo la API REST del backend.

## Stack
- **Flutter (Dart)**
- **go_router** (enrutado) + guards (control de acceso) :contentReference[oaicite:9]{index=9}
- **flutter_riverpod** (estado)
- **Dio** (cliente HTTP para consumir la API REST) :contentReference[oaicite:10]{index=10}
- Modelos Dart alineados con DTOs del backend (tipado homogéneo) :contentReference[oaicite:11]{index=11}

## Roles y flujos
Tras iniciar sesión, el usuario puede **seleccionar rol** (si tiene más de uno). :contentReference[oaicite:12]{index=12}

Ejemplo (perfil investigador/coordinador):
- Home con acceso a **Estadísticas, Formularios, Usuarios y Grupos** :contentReference[oaicite:13]{index=13}

## Estructura del proyecto (resumen)
