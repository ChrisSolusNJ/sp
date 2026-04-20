CREATE PROCEDURE [dbo].[pa_PRSD_ConsultarProduccionPlan_Mensual]
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @NoDepto INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- 🔥 Fechas automáticas (Año actual)
    IF @FechaInicio IS NULL
        SET @FechaInicio = DATEFROMPARTS(YEAR(GETDATE()), 1, 1);

    IF @FechaFin IS NULL
        SET @FechaFin = GETDATE();

    IF @FechaInicio > @FechaFin
    BEGIN
        RAISERROR('La fecha de inicio no puede ser mayor que la fecha de fin.', 16, 1);
        RETURN;
    END;

    /* =========================================
       1. PLAN DE PRODUCCIÓN (POR MES)
    ========================================= */
    WITH PlanMensual AS (
        SELECT 
            YEAR(fecha) AS Anio,
            MONTH(fecha) AS Mes,
            maquina,
            clave,
            SUM(STD) AS PlanProduccion
        FROM TLX002MXDB.dbo.tblProduccionPlan
        WHERE fecha BETWEEN @FechaInicio AND @FechaFin
            AND clave NOT IN ('3421547','3421425','3422046','3421548')
        GROUP BY 
            YEAR(fecha),
            MONTH(fecha),
            maquina,
            clave
    ),

    /* =========================================
       2. STD ACUMULADO
    ========================================= */
    STDMensual AS (
        SELECT 
            YEAR(tblEB.Fecha) AS Anio,
            MONTH(tblEB.Fecha) AS Mes,
            tblBPE.presentacion AS clave,
            tblEB.NoMaquina AS maquina,
            SUM(tblBPS.std) AS STDAcumulado
        FROM TLX002MXDB.dbo.tblBitPresentacionSub tblBPS
        INNER JOIN TLX002MXDB.dbo.tblBitPresentacionEnc tblBPE
            ON tblBPE.idpresentacionenc = tblBPS.idpresentacionenc
        INNER JOIN TLX004MXDB.dbo.tblEncabezadoBitacora tblEB
            ON tblEB.IdEncabezadoBItacora = tblBPE.folio
        WHERE tblEB.Fecha BETWEEN @FechaInicio AND @FechaFin
            AND tblBPE.presentacion NOT IN ('3421547','3421425','3422046','3421548')
            AND tblBPS.id = (
                SELECT MAX(id)
                FROM TLX002MXDB.dbo.tblBitPresentacionSub
                WHERE idpresentacionenc = tblBPS.idpresentacionenc
            )
        GROUP BY 
            YEAR(tblEB.Fecha),
            MONTH(tblEB.Fecha),
            tblBPE.presentacion,
            tblEB.NoMaquina
    ),

    /* =========================================
       3. PRODUCCIÓN REAL
    ========================================= */
    RankedData AS (
        SELECT 
            YEAR(tblEB.Fecha) AS Anio,
            MONTH(tblEB.Fecha) AS Mes,
            tblEB.NoMaquina,
            tblVEC.NoClave,
            tblBPS.acumulado AS Reales,
            ROW_NUMBER() OVER (
                PARTITION BY tblVEC.NoClave, tblEB.NoMaquina, tblEB.Turno, YEAR(tblEB.Fecha), MONTH(tblEB.Fecha)
                ORDER BY tblBPS.acumulado DESC
            ) AS rn
        FROM TLX004MXDB.dbo.tblEncabezadoBitacora tblEB
        INNER JOIN TLX002MXDB.dbo.tblBitPresentacionEnc tblBPE
            ON tblBPE.folio = tblEB.IdEncabezadoBItacora
        INNER JOIN TLX002MXDB.dbo.tblBitPresentacionSub tblBPS
            ON tblBPS.idpresentacionenc = tblBPE.idpresentacionenc
        INNER JOIN TLX002MXDB.dbo.tblValeEClaves tblVEC
            ON tblVEC.NoClave = tblBPE.presentacion
        INNER JOIN TLX009MXDB.dbo.tblMaquinasCombo tblMC
            ON tblMC.NoMaquina = tblEB.NoMaquina
        WHERE tblEB.Fecha BETWEEN @FechaInicio AND @FechaFin
            AND tblMC.NoDepto = @NoDepto
            AND tblVEC.NoClave NOT IN ('3421547','3421425','3422046','3421548')
    ),

    RealesMensual AS (
        SELECT 
            Anio,
            Mes,
            NoClave AS clave,
            NoMaquina AS maquina,
            SUM(Reales) AS AcumuladoReales
        FROM RankedData
        WHERE rn = 1
        GROUP BY 
            Anio,
            Mes,
            NoClave,
            NoMaquina
    )

    /* =========================================
       4. RESULTADO FINAL
    ========================================= */
    SELECT 
        COALESCE(P.Anio, S.Anio, R.Anio) AS Anio,
        COALESCE(P.Mes, S.Mes, R.Mes) AS Mes,

        FORMAT(DATEFROMPARTS(
            COALESCE(P.Anio, S.Anio, R.Anio),
            COALESCE(P.Mes, S.Mes, R.Mes),
            1
        ), 'yyyy-MM') AS Periodo,

        COALESCE(P.maquina, S.maquina, R.maquina) AS maquina,
        M.NombreMaquina,

        COALESCE(P.clave, S.clave, R.clave) AS clave,
        V.Descripcion_Articulo AS Descripcion,
        V.Categoria,
        PO.Nombre AS NombreCategoria,

        ISNULL(P.PlanProduccion, 0) AS PlanProduccion,
        ISNULL(S.STDAcumulado, 0) AS STDAcumulado,
        ISNULL(R.AcumuladoReales, 0) AS AcumuladoReales,

        (ISNULL(P.PlanProduccion, 0) - ISNULL(S.STDAcumulado, 0)) AS DiferenciaSTD,
        (ISNULL(P.PlanProduccion, 0) - ISNULL(R.AcumuladoReales, 0)) AS DiferenciaReal

    FROM PlanMensual P
    FULL OUTER JOIN STDMensual S
        ON P.Anio = S.Anio
        AND P.Mes = S.Mes
        AND P.maquina = S.maquina
        AND P.clave = S.clave

    FULL OUTER JOIN RealesMensual R
        ON COALESCE(P.Anio, S.Anio) = R.Anio
        AND COALESCE(P.Mes, S.Mes) = R.Mes
        AND COALESCE(P.maquina, S.maquina) = R.maquina
        AND COALESCE(P.clave, S.clave) = R.clave

    LEFT JOIN TLX002MXDB.dbo.tblValeEClaves V
        ON V.NoClave = COALESCE(P.clave, S.clave, R.clave)

    LEFT JOIN TLX009MXDB.dbo.tblMaquinas M
        ON M.NoMaquina = COALESCE(P.maquina, S.maquina, R.maquina)

    LEFT JOIN TLX009MXDB.dbo.tblMaquinasCombo MC
        ON MC.NoMaquina = M.NoMaquina

    LEFT JOIN TLX009MXDB.dbo.tblDepartamentos D
        ON D.NoDepto = MC.NoDepto

    LEFT JOIN TLX004MXDB.dbo.tblProduccionOperaciones PO
        ON PO.idOperacion = V.Categoria

    WHERE (D.NoDepto = @NoDepto OR D.NoDepto IS NULL)

    ORDER BY 
        Anio,
        Mes,
        maquina,
        clave;

END;
