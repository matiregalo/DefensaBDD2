-- =====================================================
-- REQUERIMIENTO 2: REGISTRO DE TRUEQUE
-- =====================================================
-- Lógica del procedimiento:
--   1. Valida que la carga total no exceda la capacidad del transporte
--   2. Valida que el país origen tenga suficiente recurso origen
--   3. Valida que el país destino tenga suficiente recurso destino
--   4. Crea el registro del comercio (tipo TRUEQUE)
--   5. Transfiere recursos: origen -> destino y destino -> origen
--   6. Registra los movimientos en COMERCIO_RECURSO
--   7. Crea recursos si no existen en el país receptor
--
-- Excepciones:
--   - ex_capacidad_excedida: La carga total excede la capacidad del transporte
--   - ex_recurso_origen_insuficiente: El país origen no tiene recursos suficientes
--   - ex_recurso_destino_insuficiente: El país destino no tiene recursos suficientes

CREATE OR REPLACE PROCEDURE sp_registrar_trueque(
    p_codigo_partida         IN PARTIDA.codigo_partida%TYPE,
    p_id_pais_origen         IN PAIS.id_pais%TYPE,
    p_id_pais_destino        IN PAIS.id_pais%TYPE,
    p_id_medio_transporte    IN MEDIODETRANSPORTE.id_medio_transporte%TYPE,
    p_id_pais_responsable    IN PAIS.id_pais%TYPE,
    p_recurso_origen        IN RECURSO.id_recurso%TYPE,
    p_cantidad_origen      IN NUMBER,                   
    p_recurso_destino       IN RECURSO.id_recurso%TYPE,
    p_cantidad_destino     IN NUMBER                       
) AS
    
    ex_capacidad_excedida EXCEPTION;
    ex_recurso_origen_insuficiente EXCEPTION;
    ex_recurso_destino_insuficiente EXCEPTION;

    v_id_comercio       COMERCIO.id_comercio%TYPE;
    v_capacidad_maxima  MEDIODETRANSPORTE.capacidad_carga_maxima%TYPE;
    v_carga_total       NUMBER := 0;
    
    v_nombre            RECURSOS_PARTIDA.nombre%TYPE;
    v_limite_produccion RECURSOS_PARTIDA.limite_produccion%TYPE;
    v_tipo_recurso      RECURSOS_PARTIDA.tipo_recurso%TYPE;
    
    v_cantidad_origen_disponible RECURSO.cantidad%TYPE;
    v_cantidad_destino_disponible RECURSO.cantidad%TYPE;
BEGIN
    -- ============================================
    -- PASO 1: Validar capacidad de transporte
    -- ============================================
    -- Obtiene la capacidad máxima del medio de transporte
    SELECT capacidad_carga_maxima
      INTO v_capacidad_maxima
      FROM MEDIODETRANSPORTE
     WHERE id_medio_transporte = p_id_medio_transporte;

    -- Calcula la carga total (suma de ambos recursos)
    v_carga_total := p_cantidad_origen + p_cantidad_destino;
    
    -- Si la carga excede la capacidad, aborta la operación
    IF v_carga_total > v_capacidad_maxima THEN
        RAISE ex_capacidad_excedida;
    END IF;

    -- ============================================
    -- PASO 2: Validar que el país origen tenga recursos suficientes
    -- ============================================
    BEGIN
        SELECT cantidad
        INTO v_cantidad_origen_disponible
        FROM RECURSO
        WHERE id_recurso = p_recurso_origen
          AND id_pais = p_id_pais_origen
          AND codigo_partida = p_codigo_partida;
        
        -- Si no tiene suficiente cantidad, aborta
        IF v_cantidad_origen_disponible < p_cantidad_origen THEN
            RAISE ex_recurso_origen_insuficiente;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Si no tiene el recurso, aborta
            RAISE ex_recurso_origen_insuficiente;
    END;

    -- ============================================
    -- PASO 3: Validar que el país destino tenga recursos suficientes
    -- ============================================
    BEGIN
        SELECT cantidad
        INTO v_cantidad_destino_disponible
        FROM RECURSO
        WHERE id_recurso = p_recurso_destino
          AND id_pais = p_id_pais_destino
          AND codigo_partida = p_codigo_partida;
        
        -- Si no tiene suficiente cantidad, aborta
        IF v_cantidad_destino_disponible < p_cantidad_destino THEN
            RAISE ex_recurso_destino_insuficiente;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Si no tiene el recurso, aborta
            RAISE ex_recurso_destino_insuficiente;
    END;

    -- ============================================
    -- PASO 4: Crear el registro del comercio
    -- ============================================
    -- Genera un ID único para el nuevo comercio
    SELECT NVL(MAX(id_comercio), 0) + 1
    INTO v_id_comercio
    FROM COMERCIO;


    -- Inserta el registro principal del comercio
    INSERT INTO COMERCIO (
        id_comercio,
        codigo_partida,
        id_pais_origen,
        id_pais_destino,
        id_medio_transporte,
        id_pais_responsable_traslado,
        fecha_intercambio,
        tipo_transaccion
    ) VALUES (
        v_id_comercio,
        p_codigo_partida,
        p_id_pais_origen,
        p_id_pais_destino,
        p_id_medio_transporte,
        p_id_pais_responsable,
        SYSDATE,
        'TRUEQUE'  -- Tipo de transacción: trueque
    );

    -- ============================================
    -- PASO 5: Transferir recurso origen (origen -> destino)
    -- ============================================
    -- Descuenta el recurso del país origen
    UPDATE RECURSO
    SET cantidad = cantidad - p_cantidad_origen
    WHERE id_recurso = p_recurso_origen
      AND id_pais = p_id_pais_origen
      AND codigo_partida = p_codigo_partida;

    -- Incrementa el recurso en el país destino
    UPDATE RECURSO
    SET cantidad = cantidad + p_cantidad_origen
    WHERE id_recurso = p_recurso_origen
      AND id_pais = p_id_pais_destino
      AND codigo_partida = p_codigo_partida;

    -- Si el país destino no tenía ese recurso, lo crea
    IF SQL%ROWCOUNT = 0 THEN
        -- Obtiene información del recurso desde RECURSOS_PARTIDA
        SELECT nombre, limite_produccion, tipo_recurso
        INTO v_nombre, v_limite_produccion, v_tipo_recurso
        FROM RECURSOS_PARTIDA
        WHERE id_recurso = p_recurso_origen
          AND codigo_partida = p_codigo_partida;

        -- Crea el recurso para el país destino
        INSERT INTO RECURSO (
            id_recurso, id_pais, codigo_partida,
            cantidad
        ) VALUES (
            p_recurso_origen,
            p_id_pais_destino,
            p_codigo_partida,
            p_cantidad_origen
        );
    END IF;

    -- Registra el ENVIO del recurso origen (desde país origen)
    INSERT INTO COMERCIO_RECURSO (
        id_comercio, id_recurso, id_pais_propietario, codigo_partida,
        cantidad, tipo_movimiento
    ) VALUES (
        v_id_comercio,
        p_recurso_origen,
        p_id_pais_origen,
        p_codigo_partida,
        p_cantidad_origen,
        'ENVIO'
    );

    -- Registra la RECEPCION del recurso origen (en país destino)
    INSERT INTO COMERCIO_RECURSO (
        id_comercio, id_recurso, id_pais_propietario, codigo_partida,
        cantidad, tipo_movimiento
    ) VALUES (
        v_id_comercio,
        p_recurso_origen,
        p_id_pais_destino,
        p_codigo_partida,
        p_cantidad_origen,
        'RECEPCION'
    );

    -- ============================================
    -- PASO 6: Transferir recurso destino (destino -> origen)
    -- ============================================
    -- Descuenta el recurso del país destino
    UPDATE RECURSO
    SET cantidad = cantidad - p_cantidad_destino
    WHERE id_recurso = p_recurso_destino
      AND id_pais = p_id_pais_destino
      AND codigo_partida = p_codigo_partida;

    -- Incrementa el recurso en el país origen
    UPDATE RECURSO
    SET cantidad = cantidad + p_cantidad_destino
    WHERE id_recurso = p_recurso_destino
      AND id_pais = p_id_pais_origen
      AND codigo_partida = p_codigo_partida;

    -- Si el país origen no tenía ese recurso, lo crea
    IF SQL%ROWCOUNT = 0 THEN
        -- Obtiene información del recurso desde RECURSOS_PARTIDA
        SELECT nombre, limite_produccion, tipo_recurso
        INTO v_nombre, v_limite_produccion, v_tipo_recurso
        FROM RECURSOS_PARTIDA
        WHERE id_recurso = p_recurso_destino
          AND codigo_partida = p_codigo_partida;

        -- Crea el recurso para el país origen
        INSERT INTO RECURSO (
            id_recurso, id_pais, codigo_partida,
            cantidad
        ) VALUES (
            p_recurso_destino,
            p_id_pais_origen,
            p_codigo_partida,
            p_cantidad_destino
        );
    END IF;

    -- Registra el ENVIO del recurso destino (desde país destino)
    INSERT INTO COMERCIO_RECURSO (
        id_comercio, id_recurso, id_pais_propietario, codigo_partida,
        cantidad, tipo_movimiento
    ) VALUES (
        v_id_comercio,
        p_recurso_destino,
        p_id_pais_destino,
        p_codigo_partida,
        p_cantidad_destino,
        'ENVIO'
    );

    -- Registra la RECEPCION del recurso destino (en país origen)
    INSERT INTO COMERCIO_RECURSO (
        id_comercio, id_recurso, id_pais_propietario, codigo_partida,
        cantidad, tipo_movimiento
    ) VALUES (
        v_id_comercio,
        p_recurso_destino,
        p_id_pais_origen,
        p_codigo_partida,
        p_cantidad_destino,
        'RECEPCION'
    );
    
    -- Confirma todas las operaciones
    COMMIT;

EXCEPTION
    WHEN ex_capacidad_excedida THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001, 'El medio de transporte no tiene capacidad suficiente.');
    WHEN ex_recurso_origen_insuficiente THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002, 'El país origen no tiene suficientes recursos del tipo especificado para realizar el trueque.');
    WHEN ex_recurso_destino_insuficiente THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20003, 'El país destino no tiene suficientes recursos del tipo especificado para realizar el trueque.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;

END sp_registrar_trueque;
/



