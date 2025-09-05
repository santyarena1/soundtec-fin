# Backend
API para listas de precios con usuarios (Admin/Usuario), pricing y gestiÃ³n de listas.

Estructura principal:
- src/config: carga de entorno, CORS, logger
- src/middleware: authGuard, adminGuard, errorHandler
- src/utils: funciones de utilidad (pricing, paginaciÃ³n)
- src/modules: auth, users, suppliers, products, pricelists, scraping
- src/db: conexiÃ³n y migraciones
