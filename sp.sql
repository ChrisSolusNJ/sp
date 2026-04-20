UltimaConfiguracion AS (
    SELECT 
        YEAR(fecha) AS Anio,
        MONTH(fecha) AS Mes,
        clave,
        maquina,
        MAX(configuracion) AS MaxConfiguracion
    FROM TLX002MXDB.dbo.tblProduccionPlan
    WHERE fecha BETWEEN @FechaInicio AND @FechaFin
        AND clave NOT IN ('3421547','3421425','3422046','3421548')
    GROUP BY 
        YEAR(fecha),
        MONTH(fecha),
        clave,
        maquina
),

PlanMensual AS (
    SELECT 
        YEAR(tblPP.fecha) AS Anio,
        MONTH(tblPP.fecha) AS Mes,
        tblPP.maquina,
        tblPP.clave,
        tblPP.STD AS PlanProduccion,
        tblPP.configuracion
    FROM TLX002MXDB.dbo.tblProduccionPlan tblPP
    INNER JOIN UltimaConfiguracion UC
        ON UC.Anio = YEAR(tblPP.fecha)
        AND UC.Mes = MONTH(tblPP.fecha)
        AND UC.clave = tblPP.clave
        AND UC.maquina = tblPP.maquina
        AND UC.MaxConfiguracion = tblPP.configuracion
    WHERE tblPP.fecha BETWEEN @FechaInicio AND @FechaFin
)