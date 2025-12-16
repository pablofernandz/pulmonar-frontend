# Pulmonar 2.0 — Frontend (Flutter)

Frontend del sistema “Desarrollo Pulmonar”, modernizado como parte del TFG. Aplicación **Flutter (Web)** con navegación por rutas y control de acceso por rol, que consume la **API REST** del backend.

## Stack
- **Flutter (Dart)**
- **go_router** (enrutado + control de acceso)
- **flutter_riverpod** (gestión de estado)
- **Dio** (cliente HTTP)
- Modelos/DTOs alineados con el backend para mantener tipado homogéneo

## Roles y experiencia de usuario
Tras iniciar sesión, si el usuario dispone de varios roles puede **seleccionar el rol activo**.
Ejemplo de navegación para coordinador/investigador: acceso a **Estadísticas, Formularios, Usuarios y Grupos** desde la pantalla principal.

## Funcionalidades principales
- Autenticación (login + selección de rol)
- Panel principal por rol
- Gestión de usuarios y grupos (según permisos)
- Gestión y creación de formularios/encuestas
- Registro y revisión de evaluaciones
- Listados con **búsqueda / filtrado / paginación** para mejorar usabilidad

## Estructura del proyecto (resumen)
```txt
lib/
  app/               # router, arranque
  core/              # configuración, auth, http, utilidades
  features/          # pantallas/funcionalidades por dominio (auth, users, groups, surveys, evaluations, stats, etc.)
web/
test/

