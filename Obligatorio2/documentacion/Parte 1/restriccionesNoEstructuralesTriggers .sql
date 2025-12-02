SET SERVEROUTPUT ON;

-- Secuencia utilizada para generar IDs únicos en la tabla
-- REGISTRO_RECURSO_RONDA cuando se insertan registros automáticos
-- (producción de construcciones, PBN, etc.)

CREATE SEQUENCE SEQ_REGISTRO_RECURSO
    START WITH 1
    INCREMENT BY 1
    NOCACHE;
/

-- =====================================================
-- FUNCIÓN AUXILIAR: CONTAR INCUMPLIMIENTOS CONSECUTIVOS
-- =====================================================
-- Esta función cuenta cuántas rondas consecutivas (checkpoints cada 10 rondas)
-- un país ha generado deuda para un recurso específico.
--
-- Retorna: Número de incumplimientos consecutivos desde la ronda más reciente
--          hacia atrás. Si encuentra una ronda sin deuda, detiene el conteo.
--
-- Uso: Se utiliza en las Restricciones 13 y 14 para determinar si un país
--      debe ser eliminado por incumplimientos consecutivos de consumo básico.

CREATE OR REPLACE FUNCTION fn_contar_incumplimientos_consecutivos(
    p_codigo_partida    IN VARCHAR2,
    p_id_pais           IN NUMBER,
    p_id_recurso        IN NUMBER,
    p_numero_ronda_hasta IN NUMBER
) RETURN NUMBER IS
    
    v_consecutivos NUMBER := 0;

    -- Cursor que obtiene los checkpoints (rondas múltiplos de 10) ordenados
    -- desde la más reciente hacia atrás, junto con la deuda generada
    CURSOR cur_checkpoints IS
        SELECT
            r.numero,
            rr.deuda_generada
        FROM RONDA r
        JOIN REGISTRO_RECURSO_RONDA rr
          ON rr.id_ronda       = r.id_ronda
         AND rr.codigo_partida = r.codigo_partida
        JOIN RECURSO rec
          ON rr.id_recurso     = rec.id_recurso
         AND rr.id_pais        = rec.id_pais
         AND rr.codigo_partida = rec.codigo_partida
        WHERE r.codigo_partida   = p_codigo_partida
          AND r.numero          <= p_numero_ronda_hasta
          AND MOD(r.numero, 10)  = 0  -- Solo checkpoints (rondas 10, 20, 30, etc.)
          AND rec.id_pais        = p_id_pais
          AND rec.id_recurso     = p_id_recurso
        ORDER BY r.numero DESC;  -- Más reciente primero
BEGIN
    -- Recorre los checkpoints desde el más reciente hacia atrás
    FOR cp IN cur_checkpoints LOOP
        IF cp.deuda_generada > 0 THEN
            v_consecutivos := v_consecutivos + 1;
        ELSE
            -- Si encuentra una ronda sin deuda, detiene el conteo
            -- porque ya no son consecutivos
            EXIT;
        END IF;
    END LOOP;

    RETURN v_consecutivos;
END;
/
-- =====================================================
-- RESTRICCIÓN 1: CONTROL DE SOBREPRODUCCIÓN
-- =====================================================
-- Lógica:
--   1. Verifica si hay unidades producidas (unidades_producidas > 0)
--   2. Obtiene el límite de producción del recurso desde RECURSOS_PARTIDA
--   3. Si la producción excede el límite:
--      - Marca produccion_suspendida = 'S' (Suspender)
--      - Agrega una observación explicativa
--   4. Si no excede, marca produccion_suspendida = 'N' (No suspendido)

CREATE OR REPLACE TRIGGER trg_verificar_sobreproduccion
BEFORE INSERT ON REGISTRO_RECURSO_RONDA
FOR EACH ROW
DECLARE
    v_limite_produccion RECURSOS_PARTIDA.limite_produccion%TYPE;
BEGIN
    -- Solo valida si hay producción registrada
    IF :NEW.unidades_producidas > 0 THEN
        -- Obtiene el límite de producción configurado para este recurso
        SELECT rp.limite_produccion
        INTO v_limite_produccion
        FROM RECURSO r
        JOIN RECURSOS_PARTIDA rp
          ON r.id_recurso     = rp.id_recurso
         AND r.codigo_partida = rp.codigo_partida
        WHERE r.id_recurso     = :NEW.id_recurso
          AND r.id_pais        = :NEW.id_pais
          AND r.codigo_partida = :NEW.codigo_partida

        IF :NEW.unidades_producidas > v_limite_produccion THEN
            :NEW.produccion_suspendida := 'S';
            :NEW.observacion := NVL(:NEW.observacion, '') ||
                ' Sobreproduccion: se suspende produccion para la proxima ronda.';
        ELSE
            -- Si no excede, marca como no suspendido (si no estaba ya definido)
            IF :NEW.produccion_suspendida IS NULL THEN
                :NEW.produccion_suspendida := 'N';
            END IF;
        END IF;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;
END;
/
-- =====================================================
-- RESTRICCIÓN 2: LÍMITE DE ALMACENAMIENTO
-- =====================================================
--
-- Lógica:
--   1. Calcula el límite de almacenamiento como 3 * límite_producción
--   2. Si la nueva cantidad excede el límite, la ajusta al máximo permitido
--   3. Muestra una advertencia informativa

CREATE OR REPLACE TRIGGER trg_suspender_por_almacenamiento
BEFORE UPDATE OF cantidad ON RECURSO
FOR EACH ROW
DECLARE
    v_limite_almacenamiento NUMBER(10);
    v_limite_produccion NUMBER(10);
BEGIN
    SELECT limite_produccion
    INTO v_limite_produccion
    FROM RECURSOS_PARTIDA
    WHERE id_recurso     = :NEW.id_recurso
      AND codigo_partida = :NEW.codigo_partida;
    
    -- El límite de almacenamiento es 3 veces el límite de producción
    v_limite_almacenamiento := v_limite_produccion * 3;

    -- Si la cantidad excede el límite, la trunca al máximo permitido
    IF :NEW.cantidad > v_limite_almacenamiento THEN
        :NEW.cantidad := v_limite_almacenamiento;
        
        -- Muestra advertencia para informar al usuario
        DBMS_OUTPUT.PUT_LINE('ADVERTENCIA: Producción suspendida para recurso ' ||
                             :NEW.id_recurso || ' del país ' || :NEW.id_pais ||
                             ' por exceso de almacenamiento. Cantidad limitada a ' ||
                             v_limite_almacenamiento);
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;
END;
/
-- =====================================================
-- RESTRICCIÓN 3: PRODUCCIÓN AUTOMÁTICA DE CONSTRUCCIONES
-- =====================================================
-- Lógica:
--   1. Busca todas las construcciones de categoría "producción" en la partida
--   2. Para cada construcción, genera la cantidad_por_ronda del recurso asociado
--   3. Actualiza la cantidad del recurso en la tabla RECURSO
--   4. Registra la producción en REGISTRO_RECURSO_RONDA para auditoría
--   5. Evita duplicados verificando si ya se registró producción en esta ronda

CREATE OR REPLACE PROCEDURE proc_producir_construcciones(
    p_codigo_partida IN VARCHAR2,
    p_id_ronda       IN NUMBER
) AS
    -- Cursor que obtiene todas las construcciones de producción activas
    -- con sus recursos asociados y cantidad a producir por ronda
    CURSOR cur_produccion IS
        SELECT
            crp.id_construccion,
            crp.id_recurso,
            crp.id_pais,
            crp.codigo_partida,
            crp.cantidad_por_ronda,
            ct.categoria
        FROM CONSTRUCCION_REGISTRO_PRODUCCION crp
        JOIN CONSTRUCCION c
          ON crp.id_construccion = c.id_construccion
        JOIN CONSTRUCCION_TIPO ct
          ON c.id_construccion_tipo = ct.id_construccion_tipo
        WHERE crp.codigo_partida = p_codigo_partida
          AND ct.categoria       = 'produccion';  

BEGIN
    -- Procesa cada construcción de producción
    FOR rec IN cur_produccion LOOP
        DECLARE
            v_ya_registrado NUMBER;
            v_id_registro NUMBER;
        BEGIN
            -- Verifica si ya se registró producción automática para esta construcción
            -- en esta ronda (evita duplicados)
            SELECT COUNT(*)
            INTO v_ya_registrado
            FROM REGISTRO_RECURSO_RONDA
            WHERE id_recurso     = rec.id_recurso
              AND id_pais        = rec.id_pais
              AND codigo_partida = rec.codigo_partida
              AND id_ronda       = p_id_ronda
              AND unidades_producidas > 0
              AND observacion LIKE '%Produccion automatica de construccion ' || rec.id_construccion || '%';
            
            -- Solo produce si no se ha registrado ya
            IF v_ya_registrado = 0 THEN
                -- Genera ID único para el registro
                BEGIN
                    v_id_registro := SEQ_REGISTRO_RECURSO.NEXTVAL;
                EXCEPTION
                    WHEN OTHERS THEN
                        -- Si falla la secuencia, calcula el máximo manualmente
                        SELECT NVL(MAX(id_consumo_registro), 0) + 1 INTO v_id_registro
                        FROM REGISTRO_RECURSO_RONDA;
                END;
                
                -- Incrementa la cantidad del recurso en el almacén del país
                UPDATE RECURSO
                SET cantidad = cantidad + rec.cantidad_por_ronda
                WHERE id_recurso     = rec.id_recurso
                  AND id_pais        = rec.id_pais
                  AND codigo_partida = rec.codigo_partida;

                BEGIN
                    INSERT INTO REGISTRO_RECURSO_RONDA(
                        id_consumo_registro,
                        id_recurso,
                        id_pais,
                        codigo_partida,
                        id_ronda,
                        unidades_producidas,
                        observacion
                    ) VALUES(
                        v_id_registro,
                        rec.id_recurso,
                        rec.id_pais,
                        rec.codigo_partida,
                        p_id_ronda,
                        rec.cantidad_por_ronda,
                        'Produccion automatica de construccion ' || rec.id_construccion
                    );
                EXCEPTION
                    WHEN DUP_VAL_ON_INDEX THEN
                        -- Si hay duplicado por clave única, genera nuevo ID y reintenta
                        SELECT NVL(MAX(id_consumo_registro), 0) + 1 INTO v_id_registro
                        FROM REGISTRO_RECURSO_RONDA;
                        INSERT INTO REGISTRO_RECURSO_RONDA(
                            id_consumo_registro,
                            id_recurso,
                            id_pais,
                            codigo_partida,
                            id_ronda,
                            unidades_producidas,
                            observacion
                        ) VALUES(
                            v_id_registro,
                            rec.id_recurso,
                            rec.id_pais,
                            rec.codigo_partida,
                            p_id_ronda,
                            rec.cantidad_por_ronda,
                            'Produccion automatica de construccion ' || rec.id_construccion
                        );
                END;
            END IF;
        END;
    END LOOP;
END;
/
-- =====================================================
-- RESTRICCIÓN 4: PRODUCCIÓN AUTOMÁTICA DE PBN
-- =====================================================
-- Lógica:
--   1. Verifica si la ronda actual es múltiplo de 10 (checkpoint)
--   2. Si es checkpoint, busca todos los países con recurso PBN en la partida
--   3. Para cada país, incrementa su PBN en 10.000 unidades
--   4. Registra la producción en REGISTRO_RECURSO_RONDA para auditoría
--   5. Evita duplicados verificando si ya se registró producción en esta ronda

CREATE OR REPLACE PROCEDURE proc_producir_pbn(
    p_codigo_partida IN VARCHAR2,
    p_id_ronda       IN NUMBER,
    p_numero_ronda   IN NUMBER
) AS
    c_pbn_producir CONSTANT NUMBER := 10000;

    -- Cursor que obtiene todos los países con recurso PBN en la partida
    CURSOR cur_paises_pbn IS
        SELECT
            p.id_pais,
            p.codigo_partida,
            r.id_recurso
        FROM PAIS p
        JOIN RECURSO r
          ON r.id_pais        = p.id_pais
         AND r.codigo_partida = p.codigo_partida
        JOIN RECURSOS_PARTIDA rp
          ON r.id_recurso     = rp.id_recurso
         AND r.codigo_partida = rp.codigo_partida
        WHERE p.codigo_partida = p_codigo_partida
          AND rp.tipo_recurso = 'pbn';  
BEGIN
    IF MOD(p_numero_ronda, 10) != 0 THEN
        RETURN;  
    END IF;

    FOR rec IN cur_paises_pbn LOOP
        -- Verificar si ya se registró producción de PBN para este país en esta ronda
        DECLARE
            v_ya_registrado NUMBER;
        BEGIN
            SELECT COUNT(*)
            INTO v_ya_registrado
            FROM REGISTRO_RECURSO_RONDA
            WHERE id_recurso     = rec.id_recurso
              AND id_pais        = rec.id_pais
              AND codigo_partida = rec.codigo_partida
              AND id_ronda       = p_id_ronda
              AND observacion LIKE '%Produccion automatica de PBN%';
            
            -- Solo producir si no se ha registrado ya (evita duplicados)
            IF v_ya_registrado = 0 THEN
                DECLARE
                    v_id_registro NUMBER;
                BEGIN
                    -- Genera ID único para el registro
                    BEGIN
                        v_id_registro := SEQ_REGISTRO_RECURSO.NEXTVAL;
                    EXCEPTION
                        WHEN OTHERS THEN
                            -- Si falla la secuencia, calcula el máximo manualmente
                            SELECT NVL(MAX(id_consumo_registro), 0) + 1 INTO v_id_registro
                            FROM REGISTRO_RECURSO_RONDA;
                    END;
                    
                    -- Incrementa el PBN del país en 10.000 unidades
                    UPDATE RECURSO
                    SET cantidad = cantidad + c_pbn_producir
                    WHERE id_recurso     = rec.id_recurso
                      AND id_pais        = rec.id_pais
                      AND codigo_partida = rec.codigo_partida;

                    -- Registra la producción en el historial (para auditoría)
                    BEGIN
                        INSERT INTO REGISTRO_RECURSO_RONDA(
                            id_consumo_registro,
                            id_recurso,
                            id_pais,
                            codigo_partida,
                            id_ronda,
                            unidades_producidas,
                            observacion
                        ) VALUES(
                            v_id_registro,
                            rec.id_recurso,
                            rec.id_pais,
                            rec.codigo_partida,
                            p_id_ronda,
                            c_pbn_producir,
                            'Produccion automatica de PBN (10.000 unidades)'
                        );
                    EXCEPTION
                        WHEN DUP_VAL_ON_INDEX THEN
                            -- Si hay duplicado por clave única, genera nuevo ID y reintenta
                            SELECT NVL(MAX(id_consumo_registro), 0) + 1 INTO v_id_registro
                            FROM REGISTRO_RECURSO_RONDA;
                            INSERT INTO REGISTRO_RECURSO_RONDA(
                                id_consumo_registro,
                                id_recurso,
                                id_pais,
                                codigo_partida,
                                id_ronda,
                                unidades_producidas,
                                observacion
                            ) VALUES(
                                v_id_registro,
                                rec.id_recurso,
                                rec.id_pais,
                                rec.codigo_partida,
                                p_id_ronda,
                                c_pbn_producir,
                                'Produccion automatica de PBN (10.000 unidades)'
                            );
                    END;
                END;
            END IF;
        END;
    END LOOP;
END;
/
-- =====================================================
-- RESTRICCIONES 5, 6, 7: CONSUMO OBLIGATORIO DE PBN
-- =====================================================
-- Restricción 5: Define el consumo mínimo obligatorio de PBN
-- Restricción 6: Genera deuda si el consumo es insuficiente
-- Restricción 7: Aplica recargo del 50% sobre la deuda generada
--
-- Lógica:
--   1. Verifica si la ronda actual es múltiplo de 10
--   2. Calcula el consumo de PBN en las últimas 10 rondas (desde ronda-9 hasta ronda actual)
--   3. Si el consumo es menor a 2.000 unidades:
--      - Calcula la deuda como: (2000 - consumo_real) * 1.5 (50% de recargo)
--      - Registra la deuda en REGISTRO_RECURSO_RONDA
--   4. Si el consumo es suficiente, no se genera deuda

CREATE OR REPLACE PROCEDURE proc_validar_consumo_pbn(
    p_codigo_partida IN VARCHAR2,
    p_id_ronda       IN NUMBER,
    p_numero_ronda   IN NUMBER
) AS
    c_consumo_min CONSTANT NUMBER := 2000;  
    v_numero_desde NUMBER;
BEGIN
    IF MOD(p_numero_ronda, 10) != 0 THEN
        RETURN;  -- Sale del procedimiento si no es ronda de checkpoint
    END IF;

    -- Calcula desde qué ronda empezar a contar (últimas 10 rondas)
    v_numero_desde := p_numero_ronda - 9;

    -- Procesa cada país en la partida
    FOR pais IN (
        SELECT id_pais, codigo_partida
        FROM PAIS
        WHERE codigo_partida = p_codigo_partida
    ) LOOP

        -- Para cada tipo de recurso PBN en la partida
        FOR pbn_tipo IN (
            SELECT id_recurso
            FROM RECURSOS_PARTIDA
            WHERE codigo_partida = p_codigo_partida
              AND tipo_recurso = 'pbn'
        ) LOOP
            DECLARE
                v_id_recurso          RECURSO.id_recurso%TYPE;
                v_consumido           NUMBER := 0;
                v_deuda               NUMBER := 0;
                v_id_ronda_ini        NUMBER;
                v_id_ronda_fin        NUMBER;
            BEGIN
                -- Buscar si el país tiene este recurso PBN
                BEGIN
                    SELECT r.id_recurso
                    INTO v_id_recurso
                    FROM RECURSO r
                    WHERE r.id_pais          = pais.id_pais
                      AND r.codigo_partida   = pais.codigo_partida
                      AND r.id_recurso       = pbn_tipo.id_recurso;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        v_id_recurso := NULL;
                END;

                -- Si el país tiene PBN, calcula el consumo en las últimas 10 rondas
                IF v_id_recurso IS NOT NULL THEN
                    -- Determina el rango de IDs de ronda para el período
                    SELECT MIN(id_ronda), MAX(id_ronda)
                    INTO v_id_ronda_ini, v_id_ronda_fin
                    FROM RONDA
                    WHERE codigo_partida = p_codigo_partida
                      AND numero BETWEEN v_numero_desde AND p_numero_ronda;

                    -- Suma todas las unidades consumidas en el período
                    IF v_id_ronda_ini IS NOT NULL THEN
                        SELECT NVL(SUM(unidades_consumidas), 0)
                        INTO v_consumido
                        FROM REGISTRO_RECURSO_RONDA
                        WHERE id_recurso     = v_id_recurso
                          AND id_pais        = pais.id_pais
                          AND codigo_partida = pais.codigo_partida
                          AND id_ronda BETWEEN v_id_ronda_ini AND v_id_ronda_fin;
                    END IF;
                END IF;

                -- Si el consumo es insuficiente, genera deuda con recargo
                IF v_consumido < c_consumo_min THEN
                    -- Calcula deuda: cantidad faltante * 1.5 (50% de recargo)
                    v_deuda := (c_consumo_min - v_consumido) * 1.5;

                    -- Registra la deuda en el historial
                    INSERT INTO REGISTRO_RECURSO_RONDA(
                        id_consumo_registro,
                        id_recurso,
                        id_pais,
                        codigo_partida,
                        id_ronda,
                        unidades_consumidas,
                        deuda_generada,
                        observacion
                    ) VALUES(
                        SEQ_REGISTRO_RECURSO.NEXTVAL,
                        v_id_recurso,
                        pais.id_pais,
                        pais.codigo_partida,
                        p_id_ronda,
                        v_consumido,
                        v_deuda,
                        'Consumo insuficiente de PBN (minimo 2000) - deuda con 50% de recargo'
                    );
                END IF;
            END;
        END LOOP;
    END LOOP;
END;
/

-- =====================================================
-- RESTRICCIÓN 8: VALIDACIÓN DE RECURSOS PARA CONSTRUCCIÓN
-- =====================================================
-- Lógica:
--   1. Verifica que el recurso exista para el país
--   2. Compara la cantidad disponible con la cantidad requerida
--   3. Si hay recursos suficientes, los descuenta automáticamente
--   4. Si no hay suficientes, lanza un error y aborta la operación
--
-- Nota: Usa FOR UPDATE para bloquear el registro durante la transacción
--       y evitar condiciones de carrera.

CREATE OR REPLACE TRIGGER trg_verificar_recursos_construccion
BEFORE INSERT ON CONSTRUCCION_COSTO_INICIAL
FOR EACH ROW
DECLARE
    v_cantidad_actual RECURSO.cantidad%TYPE;
BEGIN
    -- Verifica que exista el recurso y obtiene la cantidad disponible
    -- FOR UPDATE bloquea el registro para evitar condiciones de carrera
    SELECT cantidad
    INTO v_cantidad_actual
    FROM RECURSO
    WHERE id_recurso     = :NEW.id_recurso
      AND id_pais        = :NEW.id_pais
      AND codigo_partida = :NEW.codigo_partida
    FOR UPDATE;

    -- Si no hay recursos suficientes, aborta la operación
    IF v_cantidad_actual < :NEW.cantidad THEN
        RAISE_APPLICATION_ERROR(
            -20030,
            'Recursos insuficientes para pagar el costo inicial de la construccion. ' ||
            'Disponible: ' || v_cantidad_actual ||
            ', Requerido: ' || :NEW.cantidad
        );
    END IF;

    -- Si hay recursos suficientes, los descuenta automáticamente
    UPDATE RECURSO
    SET cantidad = cantidad - :NEW.cantidad
    WHERE id_recurso     = :NEW.id_recurso
      AND id_pais        = :NEW.id_pais
      AND codigo_partida = :NEW.codigo_partida;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Si el recurso no existe, aborta la operación
        RAISE_APPLICATION_ERROR(
            -20031,
            'El recurso indicado en el costo de construccion no existe '
        );
END;
/

-- =====================================================
-- RESTRICCIÓN 9: UNICIDAD DE CONSTRUCCIONES POR TIPO
-- =====================================================
-- Lógica:
--   1. Cuenta cuántas construcciones del mismo tipo tiene el país
--   2. Si ya tiene una, aborta la inserción con un error
--   3. Si no tiene ninguna, permite la inserción

CREATE OR REPLACE TRIGGER trg_construccion_unica_por_tipo
BEFORE INSERT ON CONSTRUCCION
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    -- Cuenta cuántas construcciones del mismo tipo tiene el país
    SELECT COUNT(*)
    INTO v_count
    FROM CONSTRUCCION c
    WHERE c.id_pais              = :NEW.id_pais
      AND c.codigo_partida       = :NEW.codigo_partida
      AND c.id_construccion_tipo = :NEW.id_construccion_tipo;

    -- Si ya tiene una construcción de ese tipo, aborta la operación
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20032,
            'El pais ya tiene una construccion del tipo ' ||
            :NEW.id_construccion_tipo || ' en esta partida.'
        );
    END IF;
END;
/

-- =====================================================
-- RESTRICCIÓN 10: CAPACIDAD DE TRANSPORTE EN COMERCIO
-- =====================================================
-- Lógica:
--   1. Obtiene la capacidad máxima del medio de transporte del comercio
--   2. Suma todas las cantidades ya asignadas al comercio (incluyendo la nueva)
--   3. Si la suma excede la capacidad, aborta la operación
--   4. Si no excede, permite la inserción

CREATE OR REPLACE TRIGGER trg_01_verificar_capacidad_comercio
BEFORE INSERT ON COMERCIO_RECURSO
FOR EACH ROW
DECLARE
    v_capacidad_max   MEDIODETRANSPORTE.capacidad_carga_maxima%TYPE;
    v_total_asignado  NUMBER;
BEGIN
    -- Obtiene la capacidad máxima del medio de transporte del comercio
    SELECT mt.capacidad_carga_maxima
    INTO v_capacidad_max
    FROM COMERCIO c
    JOIN MEDIODETRANSPORTE mt
      ON c.id_medio_transporte = mt.id_medio_transporte
    WHERE c.id_comercio = :NEW.id_comercio;

    -- Calcula el total ya asignado al comercio (suma de ENVIO y RECEPCION)
    SELECT NVL(SUM(cantidad), 0)
    INTO v_total_asignado
    FROM COMERCIO_RECURSO
    WHERE id_comercio = :NEW.id_comercio;

    -- Suma la nueva cantidad que se intenta agregar
    v_total_asignado := v_total_asignado + :NEW.cantidad;

    -- Si excede la capacidad, aborta la operación
    IF v_total_asignado > v_capacidad_max THEN
        RAISE_APPLICATION_ERROR(
            -20040,
            'Capacidad de transporte excedida. ' ||
            'Capacidad máxima: ' || v_capacidad_max ||
            ', Intento total: ' || v_total_asignado
        );
    END IF;
END;

/
-- =====================================================
-- RESTRICCIONES 11, 12, 13, 14: CONSUMO BÁSICO Y ELIMINACIÓN
-- =====================================================
--
-- Restricción 11: Define el consumo mínimo obligatorio de alimentos
-- Restricción 12: Define el consumo mínimo obligatorio de energía
-- Restricción 13: Genera deuda si el consumo es insuficiente (con recargo del 50%)
-- Restricción 14: Elimina el país si tiene más de 2 incumplimientos consecutivos

-- Lógica:
--   1. Identifica los recursos de tipo "consumo" que son alimentos y energía
--   2. Para cada país, calcula el consumo de alimentos y energía en las últimas 10 rondas
--   3. Si el consumo es insuficiente:
--      - Genera deuda con recargo del 50%
--      - Cuenta incumplimientos consecutivos usando la función auxiliar
--   4. Si un país tiene más de 2 incumplimientos consecutivos en alimentos O energía:
--      - Lo elimina de la partida (elimina de PARTIDA_JUGADOR)
--      - Registra el evento en REGISTRO_RECURSO_RONDA

CREATE OR REPLACE PROCEDURE proc_validar_consumo_basico(
    p_codigo_partida IN VARCHAR2,
    p_id_ronda       IN NUMBER,
    p_numero_ronda   IN NUMBER
) AS
    c_req_alimentos CONSTANT NUMBER := 5000;
    c_req_energia   CONSTANT NUMBER := 3000; 

    v_numero_desde NUMBER;

    v_id_rt_ali  RECURSOS_PARTIDA.id_recurso%TYPE;
    v_id_rt_ene  RECURSOS_PARTIDA.id_recurso%TYPE;
BEGIN
    IF MOD(p_numero_ronda, 10) != 0 THEN
        RETURN;  
    END IF;

    -- Calcula desde qué ronda empezar a contar (últimas 10 rondas)
    v_numero_desde := p_numero_ronda - 9;

    -- Identifica el recurso de tipo "consumo" que representa ALIMENTOS
    -- Busca por nombre que contenga 'ALI' o 'ALIMENTO'
    BEGIN
        SELECT id_recurso INTO v_id_rt_ali
        FROM RECURSOS_PARTIDA
        WHERE codigo_partida = p_codigo_partida
          AND tipo_recurso = 'consumo'
          AND (UPPER(nombre) LIKE '%ALI%' OR UPPER(nombre) LIKE '%ALIMENTO%')
        AND ROWNUM = 1;  -- Toma el primero que encuentre
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_id_rt_ali := NULL;  -- Si no encuentra, no valida alimentos
    END;

    -- Identifica el recurso de tipo "consumo" que representa ENERGÍA
    -- Busca por nombre que contenga 'kW', 'ENERGIA' o 'ENERG'
    BEGIN
        SELECT id_recurso INTO v_id_rt_ene
        FROM RECURSOS_PARTIDA
        WHERE codigo_partida = p_codigo_partida
          AND tipo_recurso = 'consumo'
          AND (UPPER(nombre) LIKE '%kW%' OR UPPER(nombre) LIKE '%ENERGIA%' OR UPPER(nombre) LIKE '%ENERG%')
        AND ROWNUM = 1;  -- Toma el primero que encuentre
        -- KW es kilovatio, la unidad de potencia que mide la cantidad de energia
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_id_rt_ene := NULL;  -- Si no encuentra, no valida energía
    END;

    -- Procesa cada país en la partida
    FOR pais IN (
        SELECT id_pais, codigo_partida
        FROM PAIS
        WHERE codigo_partida = p_codigo_partida
    ) LOOP
        -- Variables para contar incumplimientos consecutivos
        -- (declaradas fuera de bloques anidados para poder usarlas después)
        DECLARE
            v_incumplimientos_ali  NUMBER := 0;  -- Incumplimientos consecutivos de alimentos
            v_incumplimientos_ene  NUMBER := 0;  -- Incumplimientos consecutivos de energía
        BEGIN
        -- ============================================
        -- 1) VALIDAR CONSUMO DE ALIMENTOS
        -- ============================================
        DECLARE
            v_id_recurso_alimentos RECURSO.id_recurso%TYPE;
            v_consumido_ali        NUMBER := 0;
            v_deuda_ali            NUMBER := 0;
            v_ronda_ini            NUMBER;
            v_ronda_fin            NUMBER;
        BEGIN
            -- Busca si el país tiene el recurso de alimentos
            IF v_id_rt_ali IS NOT NULL THEN
                BEGIN
                    SELECT id_recurso
                    INTO v_id_recurso_alimentos
                    FROM RECURSO
                    WHERE id_pais          = pais.id_pais
                      AND codigo_partida   = pais.codigo_partida
                      AND id_recurso       = v_id_rt_ali;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        v_id_recurso_alimentos := NULL;  -- No tiene alimentos
                END;
            ELSE
                v_id_recurso_alimentos := NULL;
            END IF;

            -- Si el país tiene alimentos, calcula el consumo en las últimas 10 rondas
            IF v_id_recurso_alimentos IS NOT NULL THEN
                -- Determina el rango de IDs de ronda para el período
                SELECT MIN(id_ronda), MAX(id_ronda)
                INTO v_ronda_ini, v_ronda_fin
                FROM RONDA
                WHERE codigo_partida = p_codigo_partida
                  AND numero BETWEEN v_numero_desde AND p_numero_ronda;

                -- Suma todas las unidades consumidas en el período
                IF v_ronda_ini IS NOT NULL THEN
                    SELECT NVL(SUM(unidades_consumidas), 0)
                    INTO v_consumido_ali
                    FROM REGISTRO_RECURSO_RONDA
                    WHERE id_recurso     = v_id_recurso_alimentos
                      AND id_pais        = pais.id_pais
                      AND codigo_partida = pais.codigo_partida
                      AND id_ronda BETWEEN v_ronda_ini AND v_ronda_fin;
                END IF;
            END IF;

            -- Si el consumo es insuficiente, genera deuda y cuenta incumplimientos
            IF v_consumido_ali < c_req_alimentos THEN
                -- Calcula deuda: cantidad faltante * 1.5 (50% de recargo)
                v_deuda_ali := (c_req_alimentos - v_consumido_ali) * 1.5;

                -- Registra la deuda en el historial
                INSERT INTO REGISTRO_RECURSO_RONDA(
                    id_consumo_registro,
                    id_recurso,
                    id_pais,
                    codigo_partida,
                    id_ronda,
                    unidades_consumidas,
                    deuda_generada,
                    observacion
                ) VALUES(
                    SEQ_REGISTRO_RECURSO.NEXTVAL,
                    v_id_recurso_alimentos,
                    pais.id_pais,
                    pais.codigo_partida,
                    p_id_ronda,
                    v_consumido_ali,
                    v_deuda_ali,
                    'Consumo insuficiente de alimentos (básico cada 10 rondas)'
                );

                -- Cuenta cuántos incumplimientos consecutivos tiene el país
                v_incumplimientos_ali := fn_contar_incumplimientos_consecutivos(
                    p_codigo_partida   => p_codigo_partida,
                    p_id_pais          => pais.id_pais,
                    p_id_recurso       => v_id_rt_ali,
                    p_numero_ronda_hasta => p_numero_ronda
                );
            ELSE
                -- Si cumplió, no hay incumplimientos
                v_incumplimientos_ali := 0;
            END IF;

            -- ============================================
            -- 2) VALIDAR CONSUMO DE ENERGÍA
            -- ============================================
            DECLARE
                v_id_recurso_energia RECURSO.id_recurso%TYPE;
                v_consumido_ene      NUMBER := 0;
                v_deuda_ene          NUMBER := 0;
            BEGIN
                -- Busca si el país tiene el recurso de energía
                IF v_id_rt_ene IS NOT NULL THEN
                    BEGIN
                        SELECT id_recurso
                        INTO v_id_recurso_energia
                        FROM RECURSO
                        WHERE id_pais          = pais.id_pais
                          AND codigo_partida   = pais.codigo_partida
                          AND id_recurso       = v_id_rt_ene;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            v_id_recurso_energia := NULL;  -- No tiene energía
                    END;
                ELSE
                    v_id_recurso_energia := NULL;
                END IF;

                -- Si el país tiene energía, calcula el consumo en las últimas 10 rondas
                IF v_id_recurso_energia IS NOT NULL THEN
                    -- Determina el rango de IDs de ronda para el período
                    SELECT MIN(id_ronda), MAX(id_ronda)
                    INTO v_ronda_ini, v_ronda_fin
                    FROM RONDA
                    WHERE codigo_partida = p_codigo_partida
                      AND numero BETWEEN v_numero_desde AND p_numero_ronda;

                    -- Suma todas las unidades consumidas en el período
                    IF v_ronda_ini IS NOT NULL THEN
                        SELECT NVL(SUM(unidades_consumidas), 0)
                        INTO v_consumido_ene
                        FROM REGISTRO_RECURSO_RONDA
                        WHERE id_recurso     = v_id_recurso_energia
                          AND id_pais        = pais.id_pais
                          AND codigo_partida = pais.codigo_partida
                          AND id_ronda BETWEEN v_ronda_ini AND v_ronda_fin;
                    END IF;
                END IF;

                -- Si el consumo es insuficiente, genera deuda y cuenta incumplimientos
                IF v_consumido_ene < c_req_energia THEN
                    -- Calcula deuda: cantidad faltante * 1.5 (50% de recargo)
                    v_deuda_ene := (c_req_energia - v_consumido_ene) * 1.5;

                    -- Registra la deuda en el historial
                    INSERT INTO REGISTRO_RECURSO_RONDA(
                        id_consumo_registro,
                        id_recurso,
                        id_pais,
                        codigo_partida,
                        id_ronda,
                        unidades_consumidas,
                        deuda_generada,
                        observacion
                    ) VALUES(
                        SEQ_REGISTRO_RECURSO.NEXTVAL,
                        v_id_recurso_energia,
                        pais.id_pais,
                        pais.codigo_partida,
                        p_id_ronda,
                        v_consumido_ene,
                        v_deuda_ene,
                        'Consumo insuficiente de energía (básico cada 10 rondas)'
                    );

                    -- Cuenta cuántos incumplimientos consecutivos tiene el país
                    v_incumplimientos_ene := fn_contar_incumplimientos_consecutivos(
                        p_codigo_partida    => p_codigo_partida,
                        p_id_pais           => pais.id_pais,
                        p_id_recurso        => v_id_rt_ene,
                        p_numero_ronda_hasta => p_numero_ronda
                    );
                ELSE
                    -- Si cumplió, no hay incumplimientos
                    v_incumplimientos_ene := 0;
                END IF;
            END;
            
            -- ============================================
            -- RESTRICCIÓN 14: ELIMINACIÓN POR INCUMPLIMIENTOS
            -- ============================================
            -- Si el país tiene más de 2 incumplimientos consecutivos
            -- en alimentos O energía, es eliminado de la partida
            IF v_incumplimientos_ali > 2 OR v_incumplimientos_ene > 2 THEN
                -- Elimina al país de la partida (lo saca de PARTIDA_JUGADOR)
                DELETE FROM PARTIDA_JUGADOR
                WHERE id_pais        = pais.id_pais
                  AND codigo_partida = pais.codigo_partida;

                -- Registra el evento de eliminación en el historial
                INSERT INTO REGISTRO_RECURSO_RONDA(
                    id_consumo_registro,
                    id_recurso,
                    id_pais,
                    codigo_partida,
                    id_ronda,
                    observacion
                ) VALUES(
                    SEQ_REGISTRO_RECURSO.NEXTVAL,
                    NULL,
                    pais.id_pais,
                    pais.codigo_partida,
                    p_id_ronda,
                    'País eliminado por más de dos incumplimientos consecutivos de consumo básico (alimentos/energía)'
                );
            END IF;
        END;
        END;
    END LOOP;
END;
/
-- =====================================================
-- RESTRICCIÓN 13: VALIDACIÓN DE LOGROS
-- =====================================================
-- Lógica:
--   1. Verifica que el país exista en la partida
--   2. Valida que la recompensa no esté vacía o sea NULL
--   3. Si alguna validación falla, aborta la inserción con un error

CREATE OR REPLACE TRIGGER trg_validar_logro
BEFORE INSERT ON LOGRO
FOR EACH ROW
DECLARE
    v_existe_pais NUMBER;
BEGIN
    -- Verifica que el país exista en esa partida
    SELECT COUNT(*)
    INTO v_existe_pais
    FROM PAIS
    WHERE id_pais        = :NEW.id_pais
      AND codigo_partida = :NEW.codigo_partida;

    -- Si el país no existe en la partida, aborta la operación
    IF v_existe_pais = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20060,
            'No existe el pais en la partida para registrar el logro.'
        );
    END IF;

    -- Valida que la recompensa no esté vacía o sea NULL
    IF :NEW.recompensa IS NULL OR LENGTH(TRIM(:NEW.recompensa)) = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20061,
            'La recompensa del logro no puede estar vacía.'
        );
    END IF;

END;
/

-- =====================================================
-- PROCEDIMIENTO DE GESTIÓN DE RONDA: FINALIZAR RONDA
-- =====================================================

-- Flujo de ejecución:
--   1. Obtiene el número de la ronda
--   2. Producción automática de construcciones (Restricción 3)
--   3. Producción automática de PBN cada 10 rondas (Restricción 4)
--   4. Validación de consumo de PBN (Restricciones 5, 6, 7)
--   5. Validación de consumo básico (Restricciones 11, 12, 13, 14)
--   6. Cobro de mantenimiento de construcciones (Restricción 17)
--   7. Marca la fecha de fin de la ronda
--   8. Avanza el turno en la partida
--
-- Manejo de errores:
--   - Si ocurre cualquier error, hace ROLLBACK de toda la transacción
--   - Muestra el error y lo propaga (RAISE)

CREATE OR REPLACE PROCEDURE proc_finalizar_ronda(
    p_codigo_partida IN VARCHAR2,
    p_id_ronda       IN NUMBER
) AS
    v_numero_ronda RONDA.numero%TYPE;
BEGIN
    -- Obtiene el número de la ronda para validaciones y mensajes
    SELECT numero
    INTO v_numero_ronda
    FROM RONDA
    WHERE id_ronda       = p_id_ronda
      AND codigo_partida = p_codigo_partida;

    -- Muestra información de inicio
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Finalizando ronda ' || v_numero_ronda ||
                         ' de la partida ' || p_codigo_partida);
    DBMS_OUTPUT.PUT_LINE('========================================');

    -- 2. Producción automática de construcciones (Restricción 3)
    --    Genera recursos automáticamente según las construcciones activas
    proc_producir_construcciones(p_codigo_partida, p_id_ronda);

    -- 3. Producción automática de PBN cada 10 rondas (Restricción 4)
    --    Solo produce si es ronda múltiplo de 10
    proc_producir_pbn(p_codigo_partida, p_id_ronda, v_numero_ronda);

    -- 4. Validación de consumo de PBN (Restricciones 5, 6, 7)
    --    Verifica consumo mínimo y genera deuda si es insuficiente
    proc_validar_consumo_pbn(p_codigo_partida, p_id_ronda, v_numero_ronda);

    -- 5. Validación de consumo básico de alimentos y energía (Restricciones 11, 12, 13, 14)
    --    Verifica consumo mínimo y elimina países con más de 2 incumplimientos consecutivos
    proc_validar_consumo_basico(p_codigo_partida, p_id_ronda, v_numero_ronda);

    -- 6. Cobro de mantenimiento de construcciones (Restricción 17)
    --    Descuenta recursos por mantenimiento de construcciones activas
    proc_cobrar_mantenimiento_construcciones(p_codigo_partida, p_id_ronda);

    -- 7. Marca la fecha de fin de la ronda
    UPDATE RONDA
    SET fecha_fin = SYSDATE
    WHERE id_ronda       = p_id_ronda
      AND codigo_partida = p_codigo_partida;

    -- 8. Avanza el turno en la partida
    UPDATE PARTIDA
    SET turno_actual = NVL(turno_actual, 0) + 1
    WHERE codigo_partida = p_codigo_partida;

    DBMS_OUTPUT.PUT_LINE('Ronda finalizada correctamente.');

    -- Confirma todas las operaciones
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        -- Si ocurre cualquier error, revierte todas las operaciones
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR al finalizar ronda: ' || SQLERRM);
        RAISE;  -- Propaga el error para que el llamador pueda manejarlo
END;
/

-- =====================================================
-- PROCEDIMIENTO DE GESTIÓN DE RONDA: INICIAR RONDA
-- =====================================================
--
-- Flujo de ejecución:
--   1. Calcula el número de la nueva ronda (siguiente al máximo existente)
--   2. Genera un ID único para la nueva ronda
--   3. Crea el registro de la nueva ronda con fecha_inicio = SYSDATE
--   4. Identifica recursos con producción suspendida de la ronda anterior
--   5. Muestra advertencias sobre suspensiones activas

CREATE OR REPLACE PROCEDURE proc_iniciar_ronda(
    p_codigo_partida IN VARCHAR2
) AS
    v_numero_ronda   NUMBER;
    v_nueva_ronda_id NUMBER;
BEGIN
    -- Calcula el número de la nueva ronda (siguiente al máximo existente)
    SELECT NVL(MAX(numero), 0) + 1
    INTO v_numero_ronda
    FROM RONDA
    WHERE codigo_partida = p_codigo_partida;

    -- Genera un ID único para la nueva ronda
    SELECT NVL(MAX(id_ronda), 0) + 1
    INTO v_nueva_ronda_id
    FROM RONDA;

    -- Crea el registro de la nueva ronda
    INSERT INTO RONDA(
        id_ronda,
        codigo_partida,
        numero,
        fecha_inicio,
        fecha_fin
    ) VALUES(
        v_nueva_ronda_id,
        p_codigo_partida,
        v_numero_ronda,
        SYSDATE,  -- Fecha de inicio = ahora
        NULL      -- Fecha de fin = NULL (se establecerá al finalizar)
    );

    DBMS_OUTPUT.PUT_LINE('Nueva ronda creada: ' || v_numero_ronda ||
                         ' (ID: ' || v_nueva_ronda_id || ')');

    -- Identifica y muestra advertencias sobre suspensiones de producción
    -- marcadas en la ronda anterior por sobreproducción
    DECLARE
        CURSOR cur_suspensiones IS
            SELECT DISTINCT rr.id_recurso, rr.id_pais, rr.codigo_partida
            FROM REGISTRO_RECURSO_RONDA rr
            WHERE rr.codigo_partida = p_codigo_partida
              AND rr.produccion_suspendida = 'S'  -- Solo recursos suspendidos
              AND rr.id_ronda = (
                    -- Ronda anterior a la nueva
                    SELECT MAX(id_ronda)
                    FROM RONDA
                    WHERE codigo_partida = p_codigo_partida
                      AND id_ronda < v_nueva_ronda_id
                );
    BEGIN
        FOR rec IN cur_suspensiones LOOP
            -- Muestra advertencia informativa
            DBMS_OUTPUT.PUT_LINE('ADVERTENCIA: Producción suspendida para recurso ' ||
                                 rec.id_recurso || ' del país ' || rec.id_pais ||
                                 ' debido a sobreproducción en ronda anterior.');
        END LOOP;
    END;

    -- Confirma la creación de la ronda
    COMMIT;
END;
/
-- =====================================================
-- FIN DEL SCRIPT RESTRICCIONES
-- =====================================================

