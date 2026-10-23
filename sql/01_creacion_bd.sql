/* =====================================================================
   TALLER EVALUATIVO 3 - BASES DE DATOS II
   Caso de estudio: AutoServicio Antioquia
   Red de talleres de mantenimiento automotriz (6 sedes)

   Script 01: creación de la base de datos y de las 10 entidades
   Motor: SQL Server 2019 o superior
   ===================================================================== */

IF DB_ID('AutoServicioDB') IS NOT NULL
BEGIN
    ALTER DATABASE AutoServicioDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE AutoServicioDB;
END
GO

CREATE DATABASE AutoServicioDB;
GO

USE AutoServicioDB;
GO

/* ---------------------------------------------------------------------
   1. Sedes: cada taller físico de la red
   --------------------------------------------------------------------- */
CREATE TABLE Sedes (
    sede_id           INT IDENTITY(1,1) CONSTRAINT PK_Sedes PRIMARY KEY,
    nombre            NVARCHAR(80)  NOT NULL,
    ciudad            NVARCHAR(50)  NOT NULL,
    direccion         NVARCHAR(120) NOT NULL,
    telefono          VARCHAR(20)   NOT NULL,
    capacidad_bahias  TINYINT       NOT NULL CONSTRAINT CK_Sedes_Bahias CHECK (capacidad_bahias > 0)
);

/* ---------------------------------------------------------------------
   2. Clientes: propietarios de los vehículos
   --------------------------------------------------------------------- */
CREATE TABLE Clientes (
    cliente_id      INT IDENTITY(1,1) CONSTRAINT PK_Clientes PRIMARY KEY,
    tipo_documento  VARCHAR(3)    NOT NULL CONSTRAINT CK_Clientes_TipoDoc CHECK (tipo_documento IN ('CC','CE','NIT')),
    num_documento   VARCHAR(15)   NOT NULL CONSTRAINT UQ_Clientes_Documento UNIQUE,
    nombres         NVARCHAR(60)  NOT NULL,
    apellidos       NVARCHAR(60)  NOT NULL,
    telefono        VARCHAR(20)   NOT NULL,
    email           VARCHAR(100)  NULL,
    ciudad          NVARCHAR(50)  NOT NULL,
    fecha_registro  DATE          NOT NULL
);

/* ---------------------------------------------------------------------
   3. Vehiculos: cada cliente puede tener uno o varios vehículos (1:N)
   --------------------------------------------------------------------- */
CREATE TABLE Vehiculos (
    vehiculo_id   INT IDENTITY(1,1) CONSTRAINT PK_Vehiculos PRIMARY KEY,
    cliente_id    INT          NOT NULL CONSTRAINT FK_Vehiculos_Clientes REFERENCES Clientes(cliente_id),
    placa         VARCHAR(7)   NOT NULL CONSTRAINT UQ_Vehiculos_Placa UNIQUE,
    marca         NVARCHAR(30) NOT NULL,
    linea         NVARCHAR(30) NOT NULL,
    anio          SMALLINT     NOT NULL CONSTRAINT CK_Vehiculos_Anio CHECK (anio BETWEEN 1990 AND 2027),
    color         NVARCHAR(20) NOT NULL,
    combustible   VARCHAR(15)  NOT NULL CONSTRAINT CK_Vehiculos_Comb CHECK (combustible IN ('Gasolina','Diesel','Hibrido','Electrico')),
    km_registro   INT          NOT NULL CONSTRAINT CK_Vehiculos_Km CHECK (km_registro >= 0)
);

/* ---------------------------------------------------------------------
   4. Mecanicos: personal técnico, cada uno asignado a una sede
   --------------------------------------------------------------------- */
CREATE TABLE Mecanicos (
    mecanico_id    INT IDENTITY(1,1) CONSTRAINT PK_Mecanicos PRIMARY KEY,
    sede_id        INT           NOT NULL CONSTRAINT FK_Mecanicos_Sedes REFERENCES Sedes(sede_id),
    nombres        NVARCHAR(60)  NOT NULL,
    apellidos      NVARCHAR(60)  NOT NULL,
    especialidad   NVARCHAR(40)  NOT NULL,
    fecha_ingreso  DATE          NOT NULL,
    tarifa_hora    DECIMAL(12,0) NOT NULL CONSTRAINT CK_Mecanicos_Tarifa CHECK (tarifa_hora > 0),
    activo         BIT           NOT NULL CONSTRAINT DF_Mecanicos_Activo DEFAULT 1
);

/* ---------------------------------------------------------------------
   5. CatalogoServicios: servicios que ofrece la red (mano de obra)
   --------------------------------------------------------------------- */
CREATE TABLE CatalogoServicios (
    servicio_id      INT IDENTITY(1,1) CONSTRAINT PK_CatalogoServicios PRIMARY KEY,
    nombre           NVARCHAR(80)  NOT NULL,
    categoria        NVARCHAR(40)  NOT NULL,
    precio_base      DECIMAL(12,0) NOT NULL CONSTRAINT CK_Servicios_Precio CHECK (precio_base > 0),
    horas_estimadas  DECIMAL(4,1)  NOT NULL CONSTRAINT CK_Servicios_Horas CHECK (horas_estimadas > 0),
    km_intervalo     INT           NULL      -- cada cuántos km se recomienda repetir (NULL = no aplica)
);

/* ---------------------------------------------------------------------
   6. Proveedores: empresas que suministran repuestos
   --------------------------------------------------------------------- */
CREATE TABLE Proveedores (
    proveedor_id  INT IDENTITY(1,1) CONSTRAINT PK_Proveedores PRIMARY KEY,
    nit           VARCHAR(15)   NOT NULL CONSTRAINT UQ_Proveedores_Nit UNIQUE,
    razon_social  NVARCHAR(100) NOT NULL,
    ciudad        NVARCHAR(50)  NOT NULL,
    telefono      VARCHAR(20)   NOT NULL,
    dias_entrega  TINYINT       NOT NULL CONSTRAINT CK_Proveedores_Dias CHECK (dias_entrega > 0)
);

/* ---------------------------------------------------------------------
   7. Repuestos: inventario de piezas, cada una con un proveedor principal
   --------------------------------------------------------------------- */
CREATE TABLE Repuestos (
    repuesto_id     INT IDENTITY(1,1) CONSTRAINT PK_Repuestos PRIMARY KEY,
    codigo          VARCHAR(12)   NOT NULL CONSTRAINT UQ_Repuestos_Codigo UNIQUE,
    nombre          NVARCHAR(100) NOT NULL,
    categoria       NVARCHAR(40)  NOT NULL,
    proveedor_id    INT           NOT NULL CONSTRAINT FK_Repuestos_Proveedores REFERENCES Proveedores(proveedor_id),
    costo_unitario  DECIMAL(12,0) NOT NULL CONSTRAINT CK_Repuestos_Costo CHECK (costo_unitario > 0),
    precio_venta    DECIMAL(12,0) NOT NULL,
    stock_actual    INT           NOT NULL CONSTRAINT CK_Repuestos_Stock CHECK (stock_actual >= 0),
    stock_minimo    INT           NOT NULL,
    CONSTRAINT CK_Repuestos_Margen CHECK (precio_venta >= costo_unitario)
);

/* ---------------------------------------------------------------------
   8. OrdenesTrabajo: cada visita de un vehículo al taller
   --------------------------------------------------------------------- */
CREATE TABLE OrdenesTrabajo (
    orden_id       INT IDENTITY(1,1) CONSTRAINT PK_OrdenesTrabajo PRIMARY KEY,
    vehiculo_id    INT           NOT NULL CONSTRAINT FK_Ordenes_Vehiculos REFERENCES Vehiculos(vehiculo_id),
    sede_id        INT           NOT NULL CONSTRAINT FK_Ordenes_Sedes     REFERENCES Sedes(sede_id),
    mecanico_id    INT           NOT NULL CONSTRAINT FK_Ordenes_Mecanicos REFERENCES Mecanicos(mecanico_id),
    fecha_ingreso  DATETIME2(0)  NOT NULL,
    fecha_entrega  DATETIME2(0)  NULL,
    km_ingreso     INT           NOT NULL,
    estado         VARCHAR(12)   NOT NULL CONSTRAINT CK_Ordenes_Estado CHECK (estado IN ('Abierta','En proceso','Finalizada','Cancelada')),
    metodo_pago    VARCHAR(15)   NULL     CONSTRAINT CK_Ordenes_Pago   CHECK (metodo_pago IN ('Efectivo','Tarjeta','Transferencia','Credito')),
    observaciones  NVARCHAR(200) NULL,
    CONSTRAINT CK_Ordenes_Fechas CHECK (fecha_entrega IS NULL OR fecha_entrega >= fecha_ingreso)
);

/* ---------------------------------------------------------------------
   9. DetalleOrdenServicio: servicios (mano de obra) realizados en la orden
   --------------------------------------------------------------------- */
CREATE TABLE DetalleOrdenServicio (
    detalle_servicio_id  INT IDENTITY(1,1) CONSTRAINT PK_DetalleOrdenServicio PRIMARY KEY,
    orden_id             INT           NOT NULL CONSTRAINT FK_DetServ_Ordenes   REFERENCES OrdenesTrabajo(orden_id),
    servicio_id          INT           NOT NULL CONSTRAINT FK_DetServ_Servicios REFERENCES CatalogoServicios(servicio_id),
    precio_cobrado       DECIMAL(12,0) NOT NULL,
    horas_reales         DECIMAL(4,1)  NOT NULL,
    CONSTRAINT UQ_DetServ_Orden_Servicio UNIQUE (orden_id, servicio_id)
);

/* ---------------------------------------------------------------------
   10. DetalleOrdenRepuesto: repuestos instalados en la orden
   --------------------------------------------------------------------- */
CREATE TABLE DetalleOrdenRepuesto (
    detalle_repuesto_id  INT IDENTITY(1,1) CONSTRAINT PK_DetalleOrdenRepuesto PRIMARY KEY,
    orden_id             INT           NOT NULL CONSTRAINT FK_DetRep_Ordenes   REFERENCES OrdenesTrabajo(orden_id),
    repuesto_id          INT           NOT NULL CONSTRAINT FK_DetRep_Repuestos REFERENCES Repuestos(repuesto_id),
    cantidad             SMALLINT      NOT NULL CONSTRAINT CK_DetRep_Cantidad CHECK (cantidad > 0),
    precio_unitario      DECIMAL(12,0) NOT NULL,
    CONSTRAINT UQ_DetRep_Orden_Repuesto UNIQUE (orden_id, repuesto_id)
);
GO

/* Índices de apoyo para las consultas de la migración */
CREATE INDEX IX_Vehiculos_Cliente   ON Vehiculos(cliente_id);
CREATE INDEX IX_Mecanicos_Sede      ON Mecanicos(sede_id);
CREATE INDEX IX_Repuestos_Proveedor ON Repuestos(proveedor_id);
CREATE INDEX IX_Ordenes_Vehiculo    ON OrdenesTrabajo(vehiculo_id);
CREATE INDEX IX_Ordenes_Fecha       ON OrdenesTrabajo(fecha_ingreso);
CREATE INDEX IX_DetServ_Orden       ON DetalleOrdenServicio(orden_id);
CREATE INDEX IX_DetRep_Orden        ON DetalleOrdenRepuesto(orden_id);
GO
