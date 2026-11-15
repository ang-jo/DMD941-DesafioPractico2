# Desafío Práctico 2 — Cubo OLAP y Dashboard de Ventas de Adventure Works Cycles

**Asignatura:** Datawarehouse y Minería de Datos (DMD941) — Universidad Don Bosco
**Estudiante:** _[Tu nombre completo]_ — **Carné:** _[Tu carné]_
**Docente:** Ing. Katherine Vigil
**Fecha:** _[Fecha de entrega]_

## Objetivo

Restaurar el data warehouse AdventureWorksDW, construir un cubo OLAP en SQL Server Analysis Services (modo multidimensional) y visualizarlo en Power BI para responder tres preguntas de negocio:

1. ¿Cuáles son las categorías y subcategorías de productos con mayor volumen de ventas por año, y cómo varía esta tendencia trimestre a trimestre?
2. ¿Qué territorios de venta generan mayor rentabilidad, y cómo se comparan las ventas por Internet frente a las ventas por Revendedor en cada uno?
3. ¿Cuáles son los 10 productos más rentables y cómo se distribuye su venta a lo largo del tiempo (por año y trimestre)?

## Herramientas

| Herramienta | Versión | Uso |
| --- | --- | --- |
| SQL Server | 2025 Enterprise Developer | Motor de base de datos y Analysis Services (modo multidimensional) |
| SQL Server Management Studio | 22 | Restauración, scripts SQL y consultas MDX |
| Visual Studio Community + Microsoft Analysis Services Projects 2022+ | 2026 / 2022 | Diseño y procesamiento del cubo |
| Power BI Desktop | Última versión | Dashboard conectado en vivo al cubo |
| Base de datos | AdventureWorksDW2025.bak | [Repositorio oficial de Microsoft](https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks) |

## Estructura del repositorio

```
DMD941-DesafioPractico2/
├── README.md
├── sql/
│   ├── 01_restaurar_base.sql         Restauración por código y verificación
│   ├── 02_exploracion_datos.sql      Exploración de hechos, dimensiones y calidad de datos
│   ├── 03_vistas_cubo.sql            Vistas del esquema bi que alimentan el cubo
│   ├── 04_permisos_ssas.sql          Permiso de lectura para la cuenta de Analysis Services
│   └── 05_consultas_validacion.sql   Consultas SQL que responden las preguntas (validación)
├── ssas/
│   ├── calculos_cubo.mdx             Miembros calculados del cubo
│   └── CuboVentasAW/                 Proyecto de Visual Studio (Analysis Services)
├── mdx/
│   └── consultas_cubo.mdx            Consultas MDX por pregunta de negocio
├── powerbi/
│   └── Dashboard_Ventas_AW.pbix      Dashboard de Power BI
└── docs/
    ├── Informe_DesafioPractico2.pdf  Informe final
    └── capturas/                     Evidencias gráficas
```

## Modelo dimensional

Esquema de constelación: dos tablas de hechos que comparten tres dimensiones.

| Objeto del cubo | Vista de origen | Contenido |
| --- | --- | --- |
| Grupo de medidas **Internet** | `bi.vFactVentasInternet` | Cantidad, Ventas, Costo y Utilidad por Internet |
| Grupo de medidas **Revendedor** | `bi.vFactVentasRevendedor` | Cantidad, Ventas, Costo y Utilidad por Revendedor |
| Dimensión **Fecha** | `bi.vDimFecha` | Jerarquía Calendario: Año > Trimestre > Mes |
| Dimensión **Producto** | `bi.vDimProducto` | Jerarquía Categorías: Categoría > Subcategoría > Producto |
| Dimensión **Territorio** | `bi.vDimTerritorio` | Jerarquía Geografía: Grupo > País > Región |

Medidas calculadas: Unidades Totales, Ventas Totales, Costo Total, Utilidad Total, Margen Internet %, Margen Revendedor %, Margen Total %, % Ventas Internet.

Utilidad = SalesAmount − TotalProductCost (utilidad bruta).

## Cómo reproducir el proyecto

1. Restaurar `AdventureWorksDW2025.bak` en SQL Server (SSMS o `sql/01_restaurar_base.sql`).
2. Ejecutar `sql/02_exploracion_datos.sql` para explorar los datos.
3. Ejecutar `sql/03_vistas_cubo.sql` y `sql/04_permisos_ssas.sql`.
4. Abrir `ssas/CuboVentasAW/CuboVentasAW.sln` en Visual Studio, revisar el servidor de implementación (`localhost`) y elegir **Implementar**.
5. Ejecutar las consultas de `mdx/consultas_cubo.mdx` en SSMS (conexión Analysis Services).
6. Abrir `powerbi/Dashboard_Ventas_AW.pbix` (conexión en vivo a `localhost`, base `CuboVentasAW`).

## Principales hallazgos

_[Resume aquí en 3–5 viñetas los hallazgos de la sección 7 del informe.]_
