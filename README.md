# Taller 3 - Migración de SQL Server a MongoDB

**Bases de Datos II** · Prof. Juan Carlos Gómez

## Caso de estudio: AutoServicio Antioquia

Escogimos una red de talleres de mantenimiento de carros con 6 sedes (Laureles, Poblado, Envigado, Bello, Itagüí y Rionegro). Cuando un carro llega a una sede se abre una **orden de trabajo**, un mecánico le hace uno o varios **servicios** (cambio de aceite, frenos, alineación, etc.) y se usan **repuestos** del inventario, que se le compran a varios **proveedores**.



La base `AutoServicioDB` tiene 10 tablas y 5.211 registros:

| Tabla | Registros |
|---|---:|
| Sedes | 6 |
| Clientes | 600 |
| Vehiculos | 750 |
| Mecanicos | 40 |
| CatalogoServicios | 30 |
| Proveedores | 15 |
| Repuestos | 120 |
| OrdenesTrabajo | 1.100 |
| DetalleOrdenServicio | 1.350 |
| DetalleOrdenRepuesto | 1.200 |
| **Total** | **5.211** |

Los scripts están en la carpeta `sql`: `01_creacion_bd.sql` crea las tablas, `02_carga_datos.sql` carga los datos y `03_validacion_sql.sql` tiene consultas para revisarlos.

## Modelo documental (MongoDB)

![Modelo documental](docs/modelo_documental.png)

No pasamos cada tabla a una colección. Las 10 tablas quedaron en 7 colecciones:

- `clientes` = Clientes + Vehiculos (los vehículos van dentro del cliente)
- `ordenes` = OrdenesTrabajo + DetalleOrdenServicio + DetalleOrdenRepuesto (los detalles van dentro de la orden)
- `sedes`, `mecanicos`, `servicios`, `repuestos` y `proveedores` quedaron como colecciones aparte

Ejemplo de una orden en MongoDB:

```json
{
  "_id": 4,
  "fecha_ingreso": "2025-01-04T15:15:00",
  "estado": "Finalizada",
  "metodo_pago": "Tarjeta",
  "cliente_id": 271,
  "sede_id": 1,
  "mecanico_id": 6,
  "vehiculo": { "vehiculo_id": 343, "placa": "YLE828", "marca": "Kia", "linea": "Soluto", "anio": 2011, "km_ingreso": 198071 },
  "servicios": [
    { "servicio_id": 1, "nombre": "Cambio de aceite y filtro", "precio_cobrado": 57000, "horas_reales": 0.5 },
    { "servicio_id": 3, "nombre": "Mantenimiento 20.000 km", "precio_cobrado": 260000, "horas_reales": 2.4 }
  ],
  "repuestos": [
    { "repuesto_id": 4, "nombre": "Aceite motor 20W50 (cuarto) Económico", "cantidad": 5, "precio_unitario": 25700, "subtotal": 128500 },
    { "repuesto_id": 17, "nombre": "Filtro de aire Premium", "cantidad": 1, "precio_unitario": 59800, "subtotal": 59800 }
  ],
  "totales": { "servicios": 317000, "repuestos": 188300, "general": 505300 }
}
```

(Se recortaron algunos campos para que se lea mejor.)

### ¿Por qué embebimos?

- **Detalles de la orden dentro de la orden:** un detalle no existe sin su orden, cada orden tiene pocas líneas y siempre se consultan juntos, como una factura. En SQL ver una orden completa necesita varios JOIN; en MongoDB es un solo documento.
- **Vehículos dentro del cliente:** cada cliente tiene pocos carros (máximo 4 en nuestros datos) y casi siempre se ven junto con el cliente.
- **Copia del vehículo en la orden:** el kilometraje es el de ese día, no cambia aunque el carro siga rodando. La placa en la orden también sirve para buscar el historial del carro.
- **Precio y nombre del servicio o repuesto en cada línea:** el precio que se cobró ese día se debe quedar así aunque después cambie el precio del catálogo.

### ¿Por qué referenciamos?

- **Cliente, sede y mecánico en la orden (`cliente_id`, `sede_id`, `mecanico_id`):** son entidades que existen solas y se usan desde muchas órdenes. Si metiéramos todas las órdenes dentro del cliente, un cliente frecuente tendría un array que nunca deja de crecer. Y si copiáramos la sede en cada orden, cambiar su teléfono obligaría a actualizar cientos de documentos.
- **Repuesto con su proveedor (`proveedor_id`):** un proveedor surte muchos repuestos y solo se necesita cuando hay que hacer pedidos.
- **`servicio_id` y `repuesto_id` dentro de las líneas de la orden:** sirven para cruzar con el catálogo y el inventario cuando hace falta (por ejemplo, ver el stock o el proveedor).

Usamos como `_id` el mismo id de SQL Server, así es fácil comparar (la orden 4 en SQL es el documento con `_id: 4`).

## Migración

El proceso está en la carpeta `migracion`, explicado en su propio README. En resumen: un programa en Python lee las tablas de SQL Server con `pyodbc`, arma los documentos y los guarda en MongoDB con `pymongo`. Después, `verificacion.py` compara los dos lados (conteos, arrays embebidos, referencias, totales y una orden completa). El resultado está en `evidencias/reporte_verificacion.txt`.

## Consultas

Las 7 consultas están en `consultas/consultas.js`. Usan Aggregation Pipeline con `$match`, `$group`, `$lookup`, `$unwind`, `$project`, `$sort` y `$limit`.

| # | Consulta | Para qué le sirve al negocio |
|---|---|---|
| 1 | Ingresos por sede | Saber qué sede factura más y cuál va quedada, para decidir dónde invertir |
| 2 | Top 10 clientes | Identificar a los mejores clientes para darles descuentos o atención preferencial |
| 3 | Carros que están en el taller (3 `$lookup`) | Seguimiento del día a día: de quién es el carro, qué mecánico lo tiene y en qué sede |
| 4 | Repuestos más vendidos y su proveedor (2 `$lookup`) | Negociar precios por volumen con los proveedores de lo que más se vende |
| 5 | Repuestos por agotarse | Hacer los pedidos a tiempo para que ningún carro se quede esperando una pieza |
| 6 | Servicios más pedidos | Ver en qué se concentra el negocio para hacer promociones y capacitar a los mecánicos |
| 7 | Historial de un carro por placa | Cuando el carro llega, ver qué se le ha hecho antes y recomendarle el próximo mantenimiento |

## Estructura del repositorio

```
sql/          scripts de SQL Server (creación, carga y revisión)
migracion/    migracion.py y verificacion.py
consultas/    consultas.js
docs/         diagramas relacional y documental (.png y .drawio)
evidencias/   capturas y reporte de verificación
presentacion/ diapositivas de la sustentación
```

## Nota sobre el uso de inteligencia artificial

Los datos de prueba (5.211 registros) se generaron con apoyo de una herramienta de inteligencia artificial. Son datos ficticios: los nombres, placas, documentos y teléfonos no corresponden a personas reales.
