# Verificacion: compara SQL Server contra MongoDB despues de migrar
# Ejecutar: python migracion\verificacion.py

import pyodbc
from pymongo import MongoClient

sql = pyodbc.connect("DRIVER={ODBC Driver 18 for SQL Server};SERVER=localhost\\SQLEXPRESS;"
                     "DATABASE=AutoServicioDB;Trusted_Connection=yes;TrustServerCertificate=yes;")
db = MongoClient("mongodb://localhost:27017")["autoservicio"]
cursor = sql.cursor()
reporte = []


def valor_sql(query):
    cursor.execute(query)
    return int(cursor.fetchone()[0])


def comparar(texto, a, b):
    linea = ("OK    " if a == b else "ERROR ") + texto + ": " + str(a) + " | " + str(b)
    print(linea)
    reporte.append(linea)


ordenes = list(db.ordenes.find())
clientes = list(db.clientes.find())

reporte.append("1. Registros en SQL | documentos en Mongo")
for tabla, coleccion in [("Sedes", "sedes"), ("Mecanicos", "mecanicos"), ("CatalogoServicios", "servicios"),
                         ("Proveedores", "proveedores"), ("Repuestos", "repuestos"),
                         ("Clientes", "clientes"), ("OrdenesTrabajo", "ordenes")]:
    comparar(tabla, valor_sql("SELECT COUNT(*) FROM " + tabla), db[coleccion].count_documents({}))

reporte.append("2. Tablas embebidas: filas en SQL | elementos en los arrays")
comparar("Vehiculos", valor_sql("SELECT COUNT(*) FROM Vehiculos"), sum(len(c["vehiculos"]) for c in clientes))
comparar("DetalleOrdenServicio", valor_sql("SELECT COUNT(*) FROM DetalleOrdenServicio"),
         sum(len(o["servicios"]) for o in ordenes))
comparar("DetalleOrdenRepuesto", valor_sql("SELECT COUNT(*) FROM DetalleOrdenRepuesto"),
         sum(len(o["repuestos"]) for o in ordenes))

reporte.append("3. Referencias rotas: esperado | encontrado")
ids = {c: {d["_id"] for d in db[c].find()} for c in ["clientes", "sedes", "mecanicos", "servicios", "repuestos"]}
comparar("ordenes.cliente_id", 0, sum(o["cliente_id"] not in ids["clientes"] for o in ordenes))
comparar("ordenes.sede_id", 0, sum(o["sede_id"] not in ids["sedes"] for o in ordenes))
comparar("ordenes.mecanico_id", 0, sum(o["mecanico_id"] not in ids["mecanicos"] for o in ordenes))
comparar("ordenes.servicios.servicio_id", 0,
         sum(s["servicio_id"] not in ids["servicios"] for o in ordenes for s in o["servicios"]))
comparar("ordenes.repuestos.repuesto_id", 0,
         sum(r["repuesto_id"] not in ids["repuestos"] for o in ordenes for r in o["repuestos"]))

reporte.append("4. Totales en pesos: SQL | Mongo")
comparar("Mano de obra", valor_sql("SELECT SUM(precio_cobrado) FROM DetalleOrdenServicio"),
         sum(o["totales"]["servicios"] for o in ordenes))
comparar("Repuestos", valor_sql("SELECT SUM(CAST(cantidad AS BIGINT) * precio_unitario) FROM DetalleOrdenRepuesto"),
         sum(o["totales"]["repuestos"] for o in ordenes))

reporte.append("5. Orden 4: SQL | Mongo")
cursor.execute("SELECT o.estado, v.placa, o.km_ingreso FROM OrdenesTrabajo o "
               "JOIN Vehiculos v ON v.vehiculo_id = o.vehiculo_id WHERE o.orden_id = 4")
estado, placa, km = cursor.fetchone()
orden = db.ordenes.find_one({"_id": 4})
comparar("estado", estado, orden["estado"])
comparar("placa", placa, orden["vehiculo"]["placa"])
comparar("km", km, orden["vehiculo"]["km_ingreso"])
comparar("servicios", valor_sql("SELECT COUNT(*) FROM DetalleOrdenServicio WHERE orden_id = 4"), len(orden["servicios"]))
comparar("repuestos", valor_sql("SELECT COUNT(*) FROM DetalleOrdenRepuesto WHERE orden_id = 4"), len(orden["repuestos"]))

with open("evidencias/reporte_verificacion.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(reporte))
print("Errores:", sum(1 for l in reporte if l.startswith("ERROR")))
