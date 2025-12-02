-- =====================================================
-- REQUERIMIENTO 1: CONSTRUCCIÓN DE INFRAESTRUCTURA
-- =====================================================

-- Lógica del procedimiento:
--   1. Verifica que existan costos definidos para el tipo de construcción
--   2. Valida que el país tenga todos los recursos necesarios
--   3. Descuenta los recursos del país
--   4. Crea el registro de la construcción
--   5. Confirma la transacción
--
-- Excepciones:
--   - ex_recursos_insuficientes: El país no tiene recursos suficientes
--   - ex_costos_no_definidos: No hay costos definidos para este tipo de construcción

CREATE OR REPLACE PROCEDURE sp_construir_infraestructura(
    p_codigo_partida      IN PARTIDA.codigo_partida%TYPE,
    p_id_pais             IN PAIS.id_pais%TYPE,
    p_id_construccion_tipo IN CONSTRUCCION_TIPO.id_construccion_tipo%TYPE
) AS
    ex_recursos_insuficientes EXCEPTION;
    ex_costos_no_definidos EXCEPTION;
    
    -- Variables para almacenar información de la construcción
    v_id_construccion CONSTRUCCION.id_construccion%TYPE;
    v_nombre_construccion CONSTRUCCION_TIPO.nombre%TYPE;
    
    -- Variables para validación de recursos
    v_cantidad_disponible RECURSO.cantidad%TYPE;
    v_hay_costos BOOLEAN := FALSE;
    
    -- Cursor que obtiene todos los recursos requeridos para construir
    -- este tipo de construcción, junto con las cantidades disponibles del país
    CURSOR c_recursos_requeridos IS
        SELECT 
            cci.id_recurso,
            rp.nombre as recurso_nombre,
            cci.cantidad as cantidad_total_requerida,
            NVL(r.cantidad, 0) as cantidad_actual  -- Si no tiene el recurso, cantidad = 0
        FROM CONSTRUCCION_COSTO_INICIAL cci
        JOIN CONSTRUCCION c ON cci.id_construccion = c.id_construccion
        JOIN RECURSOS_PARTIDA rp ON cci.id_recurso = rp.id_recurso
                                 AND cci.codigo_partida = rp.codigo_partida
        LEFT JOIN RECURSO r ON cci.id_recurso = r.id_recurso 
                           AND r.id_pais = p_id_pais
                           AND r.codigo_partida = p_codigo_partida
        WHERE c.id_construccion_tipo = p_id_construccion_tipo
          AND cci.codigo_partida = p_codigo_partida
          -- Toma la primera construcción del tipo (asume que todas tienen los mismos costos)
          AND c.id_construccion = (
              SELECT MIN(c2.id_construccion)
              FROM CONSTRUCCION c2
              WHERE c2.id_construccion_tipo = p_id_construccion_tipo
                AND c2.codigo_partida = p_codigo_partida
          )
        ORDER BY cci.id_recurso;
    
    v_recurso_rec c_recursos_requeridos%ROWTYPE;
    
BEGIN
    -- ============================================
    -- PASO 1: Verificar que existan costos definidos
    -- ============================================
    SELECT COUNT(*)
    INTO v_cantidad_disponible
    FROM CONSTRUCCION_COSTO_INICIAL cci
    JOIN CONSTRUCCION c ON cci.id_construccion = c.id_construccion
    WHERE c.id_construccion_tipo = p_id_construccion_tipo
      AND cci.codigo_partida = p_codigo_partida;
    
    -- Si no hay costos definidos, aborta la operación
    IF v_cantidad_disponible = 0 THEN
        RAISE ex_costos_no_definidos;
    END IF;
    
    -- ============================================
    -- PASO 2: Validar que el país tenga todos los recursos necesarios
    -- ============================================
    OPEN c_recursos_requeridos;
    
    LOOP
        FETCH c_recursos_requeridos INTO v_recurso_rec;
        EXIT WHEN c_recursos_requeridos%NOTFOUND;
        
        v_hay_costos := TRUE;  
        
        -- Si el país no tiene suficiente cantidad de algún recurso, aborta
        IF v_recurso_rec.cantidad_actual < v_recurso_rec.cantidad_total_requerida THEN
            CLOSE c_recursos_requeridos;
            RAISE ex_recursos_insuficientes;
        END IF;
    END LOOP;
    
    CLOSE c_recursos_requeridos;
    
    IF NOT v_hay_costos THEN
        RAISE ex_costos_no_definidos;
    END IF;
    
    -- ============================================
    -- PASO 3: Descontar los recursos del país
    -- ============================================
    OPEN c_recursos_requeridos;
    
    LOOP
        FETCH c_recursos_requeridos INTO v_recurso_rec;
        EXIT WHEN c_recursos_requeridos%NOTFOUND;
        
        UPDATE RECURSO
        SET cantidad = cantidad - v_recurso_rec.cantidad_total_requerida
        WHERE id_recurso = v_recurso_rec.id_recurso
          AND id_pais = p_id_pais
          AND codigo_partida = p_codigo_partida;
        
     END LOOP;
    
    CLOSE c_recursos_requeridos;
    
    -- ============================================
    -- PASO 4: Crear el registro de la construcción
    -- ============================================
    -- Genera un ID único para la nueva construcción
    SELECT NVL(MAX(id_construccion), 0) + 1
    INTO v_id_construccion
    FROM CONSTRUCCION;
    
    -- Inserta el registro de la construcción
    INSERT INTO CONSTRUCCION (
        id_construccion,
        id_pais,
        codigo_partida,
        id_construccion_tipo
    ) VALUES (
        v_id_construccion,
        p_id_pais,
        p_codigo_partida,
        p_id_construccion_tipo
    );
        
    COMMIT;
    
EXCEPTION
    WHEN ex_recursos_insuficientes THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20012, 
            'Recursos insuficientes para construir');
    WHEN ex_costos_no_definidos THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20013, 
            'No se encontraron costos definidos para este tipo de construcción en esta partida');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;

END sp_construir_infraestructura;
/

