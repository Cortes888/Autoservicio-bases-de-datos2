
// 1. Ingresos por sede
// Cuanto ha facturado cada sede y cuantas ordenes ha terminado.
// Sirve para ver que sede rinde mas y en cual invertir.
db.ordenes.aggregate([
  { $match: { estado: "Finalizada" } },
  { $group: {
      _id: "$sede_id",
      total_ordenes: { $sum: 1 },
      total_ingresos: { $sum: "$totales.general" }
  } },
  { $lookup: { from: "sedes", localField: "_id", foreignField: "_id", as: "sede" } },
  { $unwind: "$sede" },
  { $project: {
      _id: 0,
      sede: "$sede.nombre",
      ciudad: "$sede.ciudad",
      total_ordenes: 1,
      total_ingresos: 1
  } },
  { $sort: { total_ingresos: -1 } }
])


// 2. Top 10 clientes
// Los clientes que mas han gastado y cuantas veces han venido.
db.ordenes.aggregate([
  { $match: { estado: "Finalizada" } },
  { $group: {
      _id: "$cliente_id",
      visitas: { $sum: 1 },
      total_gastado: { $sum: "$totales.general" }
  } },
  { $sort: { total_gastado: -1 } },
  { $limit: 10 },
  { $lookup: { from: "clientes", localField: "_id", foreignField: "_id", as: "cliente" } },
  { $unwind: "$cliente" },
  { $project: {
      _id: 0,
      nombres: "$cliente.nombres",
      apellidos: "$cliente.apellidos",
      telefono: "$cliente.contacto.telefono",
      visitas: 1,
      total_gastado: 1
  } }
])


// 3. Carros que estan en el taller (3 $lookup)
// Ordenes abiertas o en proceso: de quien es el carro, que mecanico lo tiene y en que sede esta.
// Sirve para el seguimiento del dia a dia y para avisarle al cliente.
db.ordenes.aggregate([
  { $match: { estado: { $in: ["Abierta", "En proceso"] } } },
  { $lookup: { from: "clientes", localField: "cliente_id", foreignField: "_id", as: "cliente" } },
  { $lookup: { from: "mecanicos", localField: "mecanico_id", foreignField: "_id", as: "mecanico" } },
  { $lookup: { from: "sedes", localField: "sede_id", foreignField: "_id", as: "sede" } },
  { $unwind: "$cliente" },
  { $unwind: "$mecanico" },
  { $unwind: "$sede" },
  { $project: {
      _id: 0,
      orden: "$_id",
      estado: 1,
      fecha_ingreso: 1,
      placa: "$vehiculo.placa",
      cliente_nombres: "$cliente.nombres",
      cliente_apellidos: "$cliente.apellidos",
      telefono: "$cliente.contacto.telefono",
      mecanico_nombres: "$mecanico.nombres",
      mecanico_apellidos: "$mecanico.apellidos",
      sede: "$sede.nombre"
  } },
  { $sort: { fecha_ingreso: 1 } }
])


// 4. Repuestos mas vendidos y su proveedor (2 $lookup)
// Los 10 repuestos que mas unidades se han vendido y a quien se le compran.
// Sirve para negociar precios con los proveedores de lo que mas se vende.
db.ordenes.aggregate([
  { $match: { estado: "Finalizada" } },
  { $unwind: "$repuestos" },
  { $group: {
      _id: "$repuestos.repuesto_id",
      unidades_vendidas: { $sum: "$repuestos.cantidad" }
  } },
  { $sort: { unidades_vendidas: -1 } },
  { $limit: 10 },
  { $lookup: { from: "repuestos", localField: "_id", foreignField: "_id", as: "repuesto" } },
  { $unwind: "$repuesto" },
  { $lookup: { from: "proveedores", localField: "repuesto.proveedor_id", foreignField: "_id", as: "proveedor" } },
  { $unwind: "$proveedor" },
  { $project: {
      _id: 0,
      repuesto: "$repuesto.nombre",
      unidades_vendidas: 1,
      proveedor: "$proveedor.razon_social"
  } }
])


// 5. Repuestos por agotarse
// Repuestos con menos de 5 unidades y los datos del proveedor para pedirlos.
// Sirve para hacer los pedidos a tiempo y que ningun carro se quede esperando una pieza.
db.repuestos.aggregate([
  { $match: { "stock.actual": { $lt: 5 } } },
  { $lookup: { from: "proveedores", localField: "proveedor_id", foreignField: "_id", as: "proveedor" } },
  { $unwind: "$proveedor" },
  { $project: {
      _id: 0,
      codigo: 1,
      nombre: 1,
      unidades_en_stock: "$stock.actual",
      proveedor: "$proveedor.razon_social",
      telefono_proveedor: "$proveedor.telefono",
      dias_entrega: "$proveedor.dias_entrega"
  } },
  { $sort: { unidades_en_stock: 1 } }
])


// 6. Servicios mas pedidos
// Los 10 servicios que mas se han hecho y cuanto han dejado.
// Sirve para hacer promociones y capacitar a los mecanicos en lo que mas se pide.
db.ordenes.aggregate([
  { $match: { estado: "Finalizada" } },
  { $unwind: "$servicios" },
  { $group: {
      _id: "$servicios.servicio_id",
      veces: { $sum: 1 },
      ingresos: { $sum: "$servicios.precio_cobrado" }
  } },
  { $sort: { veces: -1 } },
  { $limit: 10 },
  { $lookup: { from: "servicios", localField: "_id", foreignField: "_id", as: "servicio" } },
  { $unwind: "$servicio" },
  { $project: {
      _id: 0,
      servicio: "$servicio.nombre",
      categoria: "$servicio.categoria",
      veces: 1,
      ingresos: 1
  } }
])


// 7. Historial de un carro por placa
// Todas las visitas de un carro: fecha, kilometraje, sede, servicios y total.
// Sirve para saber que se le ha hecho antes y recomendarle el proximo mantenimiento.
// (cambiar la placa para ver otro carro)
db.ordenes.aggregate([
  { $match: { "vehiculo.placa": "VRF801", estado: "Finalizada" } },
  { $lookup: { from: "sedes", localField: "sede_id", foreignField: "_id", as: "sede" } },
  { $unwind: "$sede" },
  { $project: {
      _id: 0,
      fecha_ingreso: 1,
      kilometraje: "$vehiculo.km_ingreso",
      sede: "$sede.nombre",
      servicios: "$servicios.nombre",
      total: "$totales.general"
  } },
  { $sort: { fecha_ingreso: -1 } }
])