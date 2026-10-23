# Migracion SQL Server -> MongoDB (Taller 3 - Bases de Datos II)
# Ejecutar: python migracion\migracion.py

import pyodbc
from pymongo import MongoClient
from decimal import Decimal
from datetime import date, datetime

sql = pyodbc.connect("DRIVER={ODBC Driver 18 for SQL Server};SERVER=localhost\\SQLEXPRESS;"
                     "DATABASE=AutoServicioDB;Trusted_Connection=yes;TrustServerCertificate=yes;")
db = MongoClient("mongodb://localhost:27017")["autoservicio"]


# Mongo no acepta Decimal ni date, hay que convertirlos
def convertir(v):
    if isinstance(v, Decimal):
        return int(v) if v == int(v) else float(v)
    if isinstance(v, date) and not isinstance(v, datetime):
        return datetime(v.year, v.month, v.day)
    return v


# ejecuta un SELECT y devuelve una lista de diccionarios (los NULL no se guardan)
def consultar(query):
    cursor = sql.cursor()
    cursor.execute(query)
    columnas = [c[0] for c in cursor.description]
    return [{col: convertir(val) for col, val in zip(columnas, fila) if val is not None}
            for fila in cursor.fetchall()]


# agrupa filas por un campo, ej: los vehiculos de cada cliente
def agrupar(filas, campo):
    grupos = {}
    for f in filas:
        grupos.setdefault(f.pop(campo), []).append(f)
    return grupos


# --- Colecciones independientes (se referencian por _id) ---
sedes = consultar("SELECT sede_id AS _id, nombre, ciudad, direccion, telefono, capacidad_bahias FROM Sedes")
proveedores = consultar("SELECT proveedor_id AS _id, nit, razon_social, ciudad, telefono, dias_entrega FROM Proveedores")
servicios = consultar("SELECT servicio_id AS _id, nombre, categoria, precio_base, horas_estimadas, km_intervalo "
                      "FROM CatalogoServicios")
mecanicos = consultar("SELECT mecanico_id AS _id, sede_id, nombres, apellidos, especialidad, fecha_ingreso, "
                      "tarifa_hora, activo FROM Mecanicos")
repuestos = consultar("SELECT repuesto_id AS _id, codigo, nombre, categoria, proveedor_id, costo_unitario, "
                      "precio_venta, stock_actual, stock_minimo FROM Repuestos")
for r in repuestos:
    r["stock"] = {"actual": r.pop("stock_actual"), "minimo": r.pop("stock_minimo")}

# --- clientes: Clientes + Vehiculos embebidos ---
vehiculos = agrupar(consultar("SELECT cliente_id, vehiculo_id, placa, marca, linea, anio, color, combustible, "
                              "km_registro FROM Vehiculos ORDER BY vehiculo_id"), "cliente_id")
clientes = []
for c in consultar("SELECT * FROM Clientes"):
    contacto = {"telefono": c["telefono"]}
    if "email" in c:
        contacto["email"] = c["email"]
    clientes.append({
        "_id": c["cliente_id"],
        "documento": {"tipo": c["tipo_documento"], "numero": c["num_documento"]},
        "nombres": c["nombres"],
        "apellidos": c["apellidos"],
        "contacto": contacto,
        "ciudad": c["ciudad"],
        "fecha_registro": c["fecha_registro"],
        "vehiculos": vehiculos.get(c["cliente_id"], [])
    })

# --- ordenes: OrdenesTrabajo + DetalleOrdenServicio + DetalleOrdenRepuesto embebidos ---
serv_orden = agrupar(consultar(
    "SELECT d.orden_id, d.servicio_id, s.nombre, s.categoria, d.precio_cobrado, d.horas_reales "
    "FROM DetalleOrdenServicio d JOIN CatalogoServicios s ON s.servicio_id = d.servicio_id "
    "ORDER BY d.detalle_servicio_id"), "orden_id")
rep_orden = agrupar(consultar(
    "SELECT d.orden_id, d.repuesto_id, r.codigo, r.nombre, d.cantidad, d.precio_unitario, "
    "d.cantidad * d.precio_unitario AS subtotal "
    "FROM DetalleOrdenRepuesto d JOIN Repuestos r ON r.repuesto_id = d.repuesto_id "
    "ORDER BY d.detalle_repuesto_id"), "orden_id")

ordenes = []
for o in consultar("SELECT o.*, v.cliente_id, v.placa, v.marca, v.linea, v.anio FROM OrdenesTrabajo o "
                   "JOIN Vehiculos v ON v.vehiculo_id = o.vehiculo_id ORDER BY o.orden_id"):
    serv = serv_orden.get(o["orden_id"], [])
    rep = rep_orden.get(o["orden_id"], [])
    total_serv = sum(s["precio_cobrado"] for s in serv)
    total_rep = sum(r["subtotal"] for r in rep)
    orden = {
        "_id": o["orden_id"],
        "fecha_ingreso": o["fecha_ingreso"],
        "estado": o["estado"],
        "cliente_id": o["cliente_id"],
        "sede_id": o["sede_id"],
        "mecanico_id": o["mecanico_id"],
        "vehiculo": {"vehiculo_id": o["vehiculo_id"], "placa": o["placa"], "marca": o["marca"],
                     "linea": o["linea"], "anio": o["anio"], "km_ingreso": o["km_ingreso"]},
        "servicios": serv,
        "repuestos": rep,
        "totales": {"servicios": total_serv, "repuestos": total_rep, "general": total_serv + total_rep}
    }
    for campo in ["fecha_entrega", "metodo_pago", "observaciones"]:   # pueden venir NULL
        if campo in o:
            orden[campo] = o[campo]
    ordenes.append(orden)

# --- Guardar en MongoDB ---
colecciones = {"sedes": sedes, "proveedores": proveedores, "servicios": servicios, "mecanicos": mecanicos,
               "repuestos": repuestos, "clientes": clientes, "ordenes": ordenes}
for nombre, documentos in colecciones.items():
    db[nombre].drop()   # para no duplicar si se corre otra vez
    db[nombre].insert_many(documentos)
    print(nombre, "->", len(documentos), "documentos")

db.clientes.create_index("vehiculos.placa", unique=True)
db.ordenes.create_index("cliente_id")
db.ordenes.create_index("vehiculo.placa")
db.ordenes.create_index("estado")
db.repuestos.create_index("proveedor_id")
print("Migracion terminada")
