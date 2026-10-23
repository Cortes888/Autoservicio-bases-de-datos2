/* =====================================================================
   Script 03: consultas de control en SQL Server
   Sirven como "lado SQL" de la verificación: sus resultados deben coincidir
   con los de evidencias/reporte_verificacion.txt y con MongoDB.
   ===================================================================== */
USE AutoServicioDB;
GO

-- 1. Registros por tabla y total (debe dar 5.211)
SELECT 'Sedes' AS tabla, COUNT(*) AS registros FROM Sedes
UNION ALL SELECT 'Clientes', COUNT(*) FROM Clientes
UNION ALL SELECT 'Vehiculos', COUNT(*) FROM Vehiculos
UNION ALL SELECT 'Mecanicos', COUNT(*) FROM Mecanicos
UNION ALL SELECT 'CatalogoServicios', COUNT(*) FROM CatalogoServicios
UNION ALL SELECT 'Proveedores', COUNT(*) FROM Proveedores
UNION ALL SELECT 'Repuestos', COUNT(*) FROM Repuestos
UNION ALL SELECT 'OrdenesTrabajo', COUNT(*) FROM OrdenesTrabajo
UNION ALL SELECT 'DetalleOrdenServicio', COUNT(*) FROM DetalleOrdenServicio
UNION ALL SELECT 'DetalleOrdenRepuesto', COUNT(*) FROM DetalleOrdenRepuesto;

SELECT
  (SELECT COUNT(*) FROM Sedes) + (SELECT COUNT(*) FROM Clientes) + (SELECT COUNT(*) FROM Vehiculos) +
  (SELECT COUNT(*) FROM Mecanicos) + (SELECT COUNT(*) FROM CatalogoServicios) + (SELECT COUNT(*) FROM Proveedores) +
  (SELECT COUNT(*) FROM Repuestos) + (SELECT COUNT(*) FROM OrdenesTrabajo) +
  (SELECT COUNT(*) FROM DetalleOrdenServicio) + (SELECT COUNT(*) FROM DetalleOrdenRepuesto) AS total_registros;

-- 2. Totales monetarios que se comparan con MongoDB
SELECT SUM(precio_cobrado) AS total_mano_obra FROM DetalleOrdenServicio;
SELECT SUM(CAST(cantidad AS BIGINT) * precio_unitario) AS total_repuestos FROM DetalleOrdenRepuesto;

-- 3. Órdenes por estado
SELECT estado, COUNT(*) AS ordenes FROM OrdenesTrabajo GROUP BY estado;

-- 4. Una orden completa con JOINs (comparar contra db.ordenes.findOne({_id: 4}) en MongoDB)
SELECT o.orden_id, o.fecha_ingreso, o.estado, v.placa, c.nombres + ' ' + c.apellidos AS cliente,
       s.nombre AS sede, m.nombres + ' ' + m.apellidos AS mecanico
FROM OrdenesTrabajo o
JOIN Vehiculos v ON v.vehiculo_id = o.vehiculo_id
JOIN Clientes  c ON c.cliente_id  = v.cliente_id
JOIN Sedes     s ON s.sede_id     = o.sede_id
JOIN Mecanicos m ON m.mecanico_id = o.mecanico_id
WHERE o.orden_id = 4;

SELECT d.servicio_id, cs.nombre, d.precio_cobrado, d.horas_reales
FROM DetalleOrdenServicio d JOIN CatalogoServicios cs ON cs.servicio_id = d.servicio_id
WHERE d.orden_id = 4;

SELECT d.repuesto_id, r.nombre, d.cantidad, d.precio_unitario, d.cantidad * d.precio_unitario AS subtotal
FROM DetalleOrdenRepuesto d JOIN Repuestos r ON r.repuesto_id = d.repuesto_id
WHERE d.orden_id = 4;
