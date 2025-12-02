-- =====================================================
-- REQUERIMIENTO 3: PROCESAMIENTO DE CONSTRUCCIONES
-- =====================================================
-- Este procedimiento procesa los costos periódicos (mantenimiento)
-- y la producción de las construcciones de un país en una ronda.
--
-- Parámetros de entrada:
--   - p_id_pais: Identificador del país
--   - p_codigo_partida: Identificador de la partida
--
-- Lógica del procedimiento:
--   1. Para cada construcción del país, verifica si tiene recursos
--      suficientes para pagar los costos periódicos (mantenimiento)
--   2. Si tiene recursos, descuenta el mantenimiento y marca la
--      construcción como activa
--   3. Si no tiene recursos, marca la construcción como inactiva
--   4. Solo las construcciones activas producen recursos
--   5. Incrementa los recursos según la producción de construcciones activas
--
-- Nota: Este procedimiento se ejecuta al finalizar cada ronda para
--       procesar el mantenimiento y la producción automática.

CREATE OR REPLACE PROCEDURE procesar_construcciones(
    p_id_pais PAIS.id_pais%TYPE,
    p_codigo_partida PARTIDA.codigo_partida%TYPE
) AS
    -- Cursor que obtiene los costos periódicos (mantenimiento) de todas
    -- las construcciones del país, junto con los recursos disponibles
    CURSOR c_costos_periodicos IS
        SELECT ccp.id_construccion, ccp.id_recurso, ccp.cantidad as consumo,
               r.cantidad as cantidad_actual, rp.nombre as recurso_nombre
        FROM CONSTRUCCION_COSTO_PERIODICO ccp
        JOIN RECURSO r ON ccp.id_recurso = r.id_recurso
                      AND ccp.id_pais = r.id_pais
                      AND ccp.codigo_partida = r.codigo_partida
        JOIN RECURSOS_PARTIDA rp ON r.id_recurso = rp.id_recurso
                                 AND r.codigo_partida = rp.codigo_partida
        WHERE ccp.id_pais = p_id_pais
          AND ccp.codigo_partida = p_codigo_partida;
    
    -- Cursor que obtiene la producción de todas las construcciones
    -- que el país tiene en la partida
    CURSOR c_produccion_construcciones IS
        SELECT crp.id_construccion, crp.id_recurso, crp.cantidad_por_ronda as produccion
        FROM CONSTRUCCION_REGISTRO_PRODUCCION crp
        WHERE crp.codigo_partida = p_codigo_partida
          AND EXISTS (
              -- Solo construcciones que el país realmente tiene
              SELECT 1 FROM CONSTRUCCION c
              WHERE c.id_construccion = crp.id_construccion
                AND c.id_pais = p_id_pais
                AND c.codigo_partida = p_codigo_partida
          );
    
    -- Tabla asociativa para rastrear qué construcciones están activas
    -- (tienen recursos suficientes para mantenimiento)
    TYPE t_construcciones_activas IS TABLE OF BOOLEAN INDEX BY BINARY_INTEGER;
    v_construcciones_activas t_construcciones_activas;
    v_costo c_costos_periodicos%ROWTYPE;
    v_produccion c_produccion_construcciones%ROWTYPE;
    
BEGIN
    -- ============================================
    -- PASO 1: Procesar costos periódicos (mantenimiento)
    -- ============================================
    OPEN c_costos_periodicos;
    LOOP
        FETCH c_costos_periodicos INTO v_costo;
        EXIT WHEN c_costos_periodicos%NOTFOUND;
        
        -- Si el país tiene recursos suficientes para el mantenimiento
        IF v_costo.cantidad_actual >= v_costo.consumo THEN
            -- Descuenta el costo de mantenimiento
            UPDATE RECURSO 
            SET cantidad = cantidad - v_costo.consumo
            WHERE id_recurso = v_costo.id_recurso
              AND id_pais = p_id_pais
              AND codigo_partida = p_codigo_partida;
          
            -- Marca la construcción como activa (puede producir)
            v_construcciones_activas(v_costo.id_construccion) := TRUE;
        ELSE
            -- Si no tiene recursos, marca la construcción como inactiva (no produce)
            v_construcciones_activas(v_costo.id_construccion) := FALSE;
        END IF;
    END LOOP;
    CLOSE c_costos_periodicos;

    -- ============================================
    -- PASO 2: Procesar producción de construcciones activas
    -- ============================================
    OPEN c_produccion_construcciones;
    LOOP
        FETCH c_produccion_construcciones INTO v_produccion;
        EXIT WHEN c_produccion_construcciones%NOTFOUND;
        
        -- Solo produce si la construcción está activa (tiene recursos para mantenimiento)
        IF v_construcciones_activas.EXISTS(v_produccion.id_construccion) 
           AND v_construcciones_activas(v_produccion.id_construccion) = TRUE THEN
            
            -- Incrementa el recurso según la producción de la construcción
            UPDATE RECURSO
            SET cantidad = cantidad + v_produccion.produccion
            WHERE id_recurso = v_produccion.id_recurso
              AND id_pais = p_id_pais
              AND codigo_partida = p_codigo_partida;
        END IF;
    END LOOP;
    CLOSE c_produccion_construcciones;
    
END procesar_construcciones;
/


-- =====================================================
-- PROCEDIMIENTO AUXILIAR: PROCESAR CONSUMO BÁSICO
-- =====================================================
-- Este procedimiento procesa el consumo de un recurso básico (PBN,
-- alimentos, energía) para un país, calculando deuda si es necesario
-- y actualizando contadores de deuda.
--
-- Parámetros de entrada:
--   - p_id_recurso: Identificador del recurso a consumir
--   - p_id_pais: Identificador del país
--   - p_codigo_partida: Identificador de la partida
--   - p_numero_ronda: Número de la ronda actual
--   - p_consumo_requerido: Cantidad mínima que debe consumir
--   - p_tipo_consumo: Tipo de consumo ('PBN', 'ALIMENTOS', 'ENERGIA')
--   - p_produccion: Cantidad de producción automática (default 0)
--
-- Lógica del procedimiento:
--   1. Obtiene la cantidad actual del recurso
--   2. Calcula consumo efectivo (mínimo entre requerido y disponible)
--   3. Calcula deuda si el consumo es insuficiente
--   4. Si hay deuda anterior, aplica recargo del 50%
--   5. Actualiza contador de rondas de deuda del país
--   6. Registra el consumo y deuda en REGISTRO_RECURSO_RONDA
--   7. Actualiza la cantidad del recurso (descuenta consumo, suma producción)
--
-- Nota: Este procedimiento se llama desde sp_finalizar_ronda para
--       procesar el consumo básico de cada país.

CREATE OR REPLACE PROCEDURE procesar_consumo_basico(
    p_id_recurso IN RECURSO.id_recurso%TYPE,
    p_id_pais IN PAIS.id_pais%TYPE,
    p_codigo_partida IN PARTIDA.codigo_partida%TYPE,
    p_numero_ronda IN NUMBER,
    p_consumo_requerido IN NUMBER,
    p_tipo_consumo IN VARCHAR2,
    p_produccion IN NUMBER DEFAULT 0
) AS
    v_cantidad_actual NUMBER;
    v_tipo_recurso_actual RECURSOS_PARTIDA.tipo_recurso%TYPE;
    v_consumo_efectivo NUMBER;
    v_deuda_generada NUMBER;
    v_deuda_anterior NUMBER := 0;
    v_nuevo_id REGISTRO_RECURSO_RONDA.id_consumo_registro%TYPE;
    v_observacion VARCHAR2(500);
BEGIN
    -- Obtiene la cantidad actual del recurso y su tipo
    SELECT r.cantidad, rp.tipo_recurso
    INTO v_cantidad_actual, v_tipo_recurso_actual
    FROM RECURSO r
    JOIN RECURSOS_PARTIDA rp ON r.id_recurso = rp.id_recurso
                            AND r.codigo_partida = rp.codigo_partida
    WHERE r.id_recurso = p_id_recurso
      AND r.id_pais = p_id_pais
      AND r.codigo_partida = p_codigo_partida;
    
    -- Calcula el consumo efectivo (no puede consumir más de lo que tiene)
    v_consumo_efectivo := LEAST(p_consumo_requerido, v_cantidad_actual);
    -- Calcula la deuda (diferencia entre requerido y disponible)
    v_deuda_generada := GREATEST(0, p_consumo_requerido - v_cantidad_actual);
    
    -- Si hay deuda, calcula recargos y actualiza contadores
    IF v_deuda_generada > 0 THEN
        -- Busca si hay deuda anterior (de la ronda anterior, 10 rondas atrás)
        BEGIN
            SELECT rrr.deuda_generada INTO v_deuda_anterior
            FROM REGISTRO_RECURSO_RONDA rrr
            JOIN RECURSO r ON rrr.id_recurso = r.id_recurso
                         AND rrr.id_pais = r.id_pais
                         AND rrr.codigo_partida = r.codigo_partida
            JOIN RECURSOS_PARTIDA rp ON r.id_recurso = rp.id_recurso
                                    AND r.codigo_partida = rp.codigo_partida
            WHERE rrr.id_recurso = p_id_recurso
              AND rrr.id_ronda = p_numero_ronda - 10  -- Ronda anterior (checkpoint)
              AND rrr.codigo_partida = p_codigo_partida
              AND rp.tipo_recurso = v_tipo_recurso_actual;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_deuda_anterior := 0;  -- No hay deuda anterior
        END;
        
        -- Aplica recargo del 50% sobre la deuda anterior
        v_deuda_generada := v_deuda_generada + (v_deuda_anterior * 1.5);
        v_observacion := 'Deuda ' || v_tipo_recurso_actual || ' con recargo del 50%';

        -- Incrementa el contador de rondas de deuda del país
        UPDATE PAIS
        SET contador_rondas_deuda = contador_rondas_deuda + 1
        WHERE id_pais = p_id_pais;
    ELSE
        -- Si no hay deuda, consumo normal
        v_observacion := 'Consumo ' || v_tipo_recurso_actual || ' normal';

        -- Reinicia el contador de rondas de deuda
        UPDATE PAIS
        SET contador_rondas_deuda = 0
        WHERE id_pais = p_id_pais;
    END IF;
    
    -- Genera un ID único para el registro
    SELECT NVL(MAX(id_consumo_registro), 0) + 1 INTO v_nuevo_id
    FROM REGISTRO_RECURSO_RONDA;
    
    -- Registra el consumo y deuda en el historial
    INSERT INTO REGISTRO_RECURSO_RONDA (
        id_consumo_registro, id_recurso, id_ronda, codigo_partida,
        unidades_consumidas, deuda_generada, id_pais, observacion
    ) VALUES (
        v_nuevo_id,
        p_id_recurso, p_numero_ronda, p_codigo_partida,
        v_consumo_efectivo, v_deuda_generada, p_id_pais,
        v_observacion
    );
    
    -- Actualiza la cantidad del recurso:
    -- Descuenta el consumo efectivo y suma la producción automática
    UPDATE RECURSO
    SET cantidad = cantidad - v_consumo_efectivo + p_produccion
    WHERE id_recurso = p_id_recurso
      AND id_pais = p_id_pais
      AND codigo_partida = p_codigo_partida;
    
END procesar_consumo_basico;
/








-- =====================================================
-- PROCEDIMIENTO PRINCIPAL: FINALIZAR RONDA
-- =====================================================
-- Este procedimiento coordina todas las operaciones que deben
-- ejecutarse al finalizar una ronda del juego. Es la versión
-- simplificada del procedimiento de la Parte 1, adaptada para
-- los requerimientos específicos de la Parte 2.
--
-- Parámetros de entrada:
--   - p_codigo_partida: Identificador de la partida
--   - p_numero_ronda: Número de la ronda que se está finalizando
--
-- Flujo de ejecución:
--   1. Para cada país activo:
--      a. Aplica producción base de recursos (no PBN)
--      b. Procesa construcciones (mantenimiento y producción)
--      c. Si es ronda múltiplo de 10 (checkpoint):
--         - Procesa consumo básico de alimentos y energía
--   2. Si es ronda múltiplo de 10:
--      a. Procesa producción y consumo de PBN para todos los países
--      b. Elimina países con 3 o más rondas de deuda consecutivas
--   3. Actualiza el turno actual de la partida
--   4. Confirma todas las operaciones
--
-- Nota: Este procedimiento es una versión alternativa del
--       proc_finalizar_ronda de la Parte 1, con lógica simplificada.

CREATE OR REPLACE PROCEDURE sp_finalizar_ronda(
    p_codigo_partida IN PARTIDA.codigo_partida%TYPE,
    p_numero_ronda   IN NUMBER
) AS
    -- Constantes para producción y consumo de PBN
    v_produccion_pbn CONSTANT NUMBER := 10000;  -- PBN producido cada 10 rondas
    v_consumo_pbn CONSTANT NUMBER := 2000;      -- PBN mínimo a consumir cada 10 rondas
    v_recargo_deuda CONSTANT NUMBER := 0.5;     -- Recargo del 50% sobre deuda
    
    -- Variable para determinar si es ronda de checkpoint (múltiplo de 10)
    v_es_ronda_pbn BOOLEAN;
    v_nuevo_id REGISTRO_RECURSO_RONDA.id_consumo_registro%TYPE;

    -- Cursor que obtiene todos los países activos en la partida
    CURSOR c_paises IS
        SELECT id_pais, nombre_oficial, manzanas_ciudad
        FROM PAIS 
        WHERE codigo_partida = p_codigo_partida
          AND estado = 'ACTIVO';
    
    -- Cursor que obtiene todos los recursos PBN de países activos
    CURSOR c_pbns_partida IS
        SELECT r.id_recurso, r.cantidad, r.id_pais, rp.nombre
        FROM RECURSO r
        JOIN RECURSOS_PARTIDA rp ON r.id_recurso = rp.id_recurso
                                 AND r.codigo_partida = rp.codigo_partida
        JOIN PAIS p ON r.id_pais = p.id_pais
        WHERE r.codigo_partida = p_codigo_partida
          AND rp.tipo_recurso = 'pbn'
          AND p.estado = 'ACTIVO';

    -- Cursor parametrizado que obtiene recursos no-PBN de un país
    CURSOR c_recursos_pais (p_id_pais PAIS.id_pais%TYPE) IS
        SELECT r.id_recurso, rp.nombre, r.cantidad, rp.tipo_recurso, rp.limite_produccion, rp.produccion_base
        FROM RECURSO r
        JOIN RECURSOS_PARTIDA rp ON r.id_recurso = rp.id_recurso
                                 AND r.codigo_partida = rp.codigo_partida
        WHERE r.id_pais = p_id_pais
          AND r.codigo_partida = p_codigo_partida
          AND rp.tipo_recurso != 'pbn';  -- Excluye PBN

    -- Cursor parametrizado que obtiene recursos de consumo de un país
    CURSOR c_recursos_consumo (p_id_pais PAIS.id_pais%TYPE, p_tipo_recurso RECURSOS_PARTIDA.tipo_recurso%TYPE) IS
        SELECT r.id_recurso, rp.nombre, r.cantidad
        FROM RECURSO r
        JOIN RECURSOS_PARTIDA rp ON r.id_recurso = rp.id_recurso
                                 AND r.codigo_partida = rp.codigo_partida
        WHERE r.id_pais = p_id_pais
          AND r.codigo_partida = p_codigo_partida
          AND rp.tipo_recurso = p_tipo_recurso;
    
    -- Variables para almacenar registros de los cursors
    v_pais c_paises%ROWTYPE;
    v_pbn c_pbns_partida%ROWTYPE;
    v_recurso c_recursos_pais%ROWTYPE;
    v_recurso_consumo c_recursos_consumo%ROWTYPE;

BEGIN
    -- Determina si es una ronda de checkpoint (múltiplo de 10)
    v_es_ronda_pbn := (MOD(p_numero_ronda, 10) = 0);
    
    -- ============================================
    -- PROCESAMIENTO POR PAÍS
    -- ============================================
    OPEN c_paises;
    LOOP
        FETCH c_paises INTO v_pais;
        EXIT WHEN c_paises%NOTFOUND;
        
        -- Aplica producción base de recursos (no PBN)
        OPEN c_recursos_pais(v_pais.id_pais);
        LOOP
            FETCH c_recursos_pais INTO v_recurso;
            EXIT WHEN c_recursos_pais%NOTFOUND;

            -- Incrementa la cantidad del recurso según su producción base
            UPDATE RECURSO 
            SET cantidad = cantidad + v_recurso.produccion_base
            WHERE id_recurso = v_recurso.id_recurso
              AND id_pais = v_pais.id_pais
              AND codigo_partida = p_codigo_partida;
        END LOOP;
        CLOSE c_recursos_pais;
        
        -- Procesa construcciones (mantenimiento y producción)
        procesar_construcciones(v_pais.id_pais, p_codigo_partida);

        -- Si es ronda de checkpoint, procesa consumo básico
        IF v_es_ronda_pbn THEN
            DECLARE
                -- El consumo básico se calcula según las manzanas de ciudad del país
                v_consumo_alimentos NUMBER := v_pais.manzanas_ciudad;
                v_consumo_energia NUMBER := v_pais.manzanas_ciudad;
            BEGIN
                -- Procesa consumo de alimentos
                OPEN c_recursos_consumo(v_pais.id_pais, 'consumo');
                LOOP
                    FETCH c_recursos_consumo INTO v_recurso_consumo;
                    EXIT WHEN c_recursos_consumo%NOTFOUND;
                    
                    procesar_consumo_basico(
                        v_recurso_consumo.id_recurso,
                        v_pais.id_pais,
                        p_codigo_partida,
                        p_numero_ronda,
                        v_consumo_alimentos,
                        'ALIMENTOS',
                        0  -- Sin producción automática
                    );
                END LOOP;
                CLOSE c_recursos_consumo;
                
                -- Procesa consumo de energía
                OPEN c_recursos_consumo(v_pais.id_pais, 'consumo');
                LOOP
                    FETCH c_recursos_consumo INTO v_recurso_consumo;
                    EXIT WHEN c_recursos_consumo%NOTFOUND;
                    
                    procesar_consumo_basico(
                        v_recurso_consumo.id_recurso,
                        v_pais.id_pais,
                        p_codigo_partida,
                        p_numero_ronda,
                        v_consumo_energia,
                        'ENERGIA',
                        0  -- Sin producción automática
                    );
                END LOOP;
                CLOSE c_recursos_consumo;
            END;
        END IF;
    END LOOP;
    CLOSE c_paises;
    
    -- ============================================
    -- PROCESAMIENTO DE PBN (solo en rondas checkpoint)
    -- ============================================
    IF v_es_ronda_pbn THEN
        -- Procesa producción y consumo de PBN para todos los países
        OPEN c_pbns_partida;
        LOOP
            FETCH c_pbns_partida INTO v_pbn;
            EXIT WHEN c_pbns_partida%NOTFOUND;

            -- Procesa consumo de PBN (con producción automática de 10.000)
            procesar_consumo_basico(
                v_pbn.id_recurso,
                v_pbn.id_pais,
                p_codigo_partida,
                p_numero_ronda,
                v_consumo_pbn,
                'PBN',
                v_produccion_pbn  -- Producción automática de PBN
            );
        END LOOP;
        CLOSE c_pbns_partida;

        -- Elimina países con 3 o más rondas de deuda consecutivas
        UPDATE PAIS
        SET estado = 'ELIMINADO'
        WHERE codigo_partida = p_codigo_partida
          AND contador_rondas_deuda >= 3
          AND estado = 'ACTIVO';
    END IF;
    
    -- ============================================
    -- ACTUALIZACIÓN FINAL
    -- ============================================
    -- Actualiza el turno actual de la partida
    UPDATE PARTIDA 
    SET turno_actual = p_numero_ronda
    WHERE codigo_partida = p_codigo_partida;
    
    -- Confirma todas las operaciones
    COMMIT;
    
END sp_finalizar_ronda;
/



