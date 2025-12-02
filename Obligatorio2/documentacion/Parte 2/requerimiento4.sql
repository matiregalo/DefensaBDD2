-- =====================================================
-- REQUERIMIENTO 4: OTORGAMIENTO DE MEDALLA/LOGRO
-- =====================================================
-- Este procedimiento otorga un logro a un país y aplica las recompensas
-- asociadas. Las recompensas pueden incluir recursos que se agregan
-- automáticamente al inventario del país.
--
-- Parámetros de entrada:
--   - p_codigo_partida: Identificador de la partida
--   - p_id_pais: Identificador del país que recibe el logro
--   - p_id_logro: Identificador único del logro
--   - p_nombre: Nombre del logro
--   - p_descripcion: Descripción del logro
--   - p_recompensa: Recompensa en formato "recurso_id:cantidad,recurso_id:cantidad,..."
--                   Ejemplo: "1:5000,2:3000" (recurso 1: 5000 unidades, recurso 2: 3000 unidades)
--
-- Lógica del procedimiento:
--   1. Valida que el logro no haya sido obtenido previamente por el país
--   2. Obtiene el alias del jugador asociado al país
--   3. Registra el logro en la tabla LOGRO
--   4. Parsea la cadena de recompensa (formato: "id:cantidad,id:cantidad,...")
--   5. Para cada recurso en la recompensa:
--      a. Si el país ya tiene el recurso, incrementa la cantidad
--      b. Si no tiene el recurso, lo crea con la cantidad de la recompensa
--   6. Confirma todas las operaciones
--
-- Excepciones:
--   - ex_logro_ya_obtenido: El país ya obtuvo este logro anteriormente
--
-- Nota: El trigger trg_validar_logro también valida algunas condiciones,
--       pero este procedimiento hace validaciones adicionales.

CREATE OR REPLACE PROCEDURE sp_otorgar_medalla_logro(
    p_codigo_partida    IN PARTIDA.codigo_partida%TYPE,
    p_id_pais           IN PAIS.id_pais%TYPE,
    p_id_logro          IN LOGRO.id_logro%TYPE,
    p_nombre            IN LOGRO.nombre%TYPE,
    p_descripcion       IN LOGRO.descripcion%TYPE,
    p_recompensa        IN LOGRO.recompensa%TYPE
) AS
    
    -- Excepción personalizada para manejo de errores
    ex_logro_ya_obtenido    EXCEPTION;
    
    -- Variables para validación y registro
    v_alias_jugador         JUGADOR.alias%TYPE;
    v_logro_existente       NUMBER;
    
    -- Variables para procesamiento de recompensas
    v_recompensa_limpia     VARCHAR2(1000);  -- Recompensa sin espacios
    v_recurso_id         RECURSOS_PARTIDA.id_recurso%TYPE;
    v_cantidad_recurso      NUMBER;
    v_pos_separador         NUMBER;  -- Posición del separador en la cadena
    v_item_recompensa       VARCHAR2(100);  -- Item individual de recompensa
    
    -- Variables auxiliares para crear recursos si no existen
    v_nombre_recurso      RECURSOS_PARTIDA.nombre%TYPE;
    v_tipo_recurso        RECURSOS_PARTIDA.tipo_recurso%TYPE;
    v_limite_produccion   RECURSOS_PARTIDA.limite_produccion%TYPE;

    
BEGIN
    -- ============================================
    -- PASO 1: Validar que el logro no haya sido obtenido previamente
    -- ============================================
    SELECT COUNT(*)
      INTO v_logro_existente
      FROM LOGRO
     WHERE id_logro = p_id_logro
       AND id_pais = p_id_pais
       AND codigo_partida = p_codigo_partida;
    
    -- Si el país ya tiene este logro, aborta la operación
    IF v_logro_existente > 0 THEN
        RAISE ex_logro_ya_obtenido;
    END IF;
    
    -- Obtiene el alias del jugador asociado al país (para referencia)
    SELECT j.alias
      INTO v_alias_jugador
      FROM JUGADOR j
     JOIN PARTIDA_JUGADOR pj ON j.alias = pj.alias
     WHERE pj.id_pais = p_id_pais
       AND pj.codigo_partida = p_codigo_partida;
    
    -- ============================================
    -- PASO 2: Registrar el logro
    -- ============================================
    INSERT INTO LOGRO (
        id_logro,
        id_pais,
        codigo_partida,
        nombre,
        descripcion,
        recompensa,
        fecha_logro_completado
    ) VALUES (
        p_id_logro,
        p_id_pais,
        p_codigo_partida,
        p_nombre,
        p_descripcion,
        p_recompensa,
        SYSDATE  -- Fecha actual
    );
    
    -- ============================================
    -- PASO 3: Procesar recompensas
    -- ============================================
    -- Elimina espacios de la cadena de recompensa para facilitar el parsing
    v_recompensa_limpia := REPLACE(p_recompensa, ' ', '');
    
    -- Procesa cada item de recompensa (separados por comas)
    WHILE LENGTH(v_recompensa_limpia) > 0 LOOP
        -- Busca el separador de items (coma)
        v_pos_separador := INSTR(v_recompensa_limpia, ',');
        
        -- Si no hay más comas, toma el resto de la cadena
        IF v_pos_separador = 0 THEN
            v_item_recompensa := v_recompensa_limpia;
            v_recompensa_limpia := '';
        ELSE
            -- Extrae el item actual y actualiza la cadena
            v_item_recompensa := SUBSTR(v_recompensa_limpia, 1, v_pos_separador - 1);
            v_recompensa_limpia := SUBSTR(v_recompensa_limpia, v_pos_separador + 1);
        END IF;
        
        -- Parsea el item (formato: "recurso_id:cantidad")
        v_pos_separador := INSTR(v_item_recompensa, ':');
        IF v_pos_separador > 0 THEN
            -- Extrae el ID del recurso y la cantidad
            v_recurso_id := TO_NUMBER(SUBSTR(v_item_recompensa, 1, v_pos_separador - 1));
            v_cantidad_recurso := TO_NUMBER(SUBSTR(v_item_recompensa, v_pos_separador + 1));
            
            -- Intenta actualizar el recurso si el país ya lo tiene
            UPDATE RECURSO
            SET cantidad = cantidad + v_cantidad_recurso
            WHERE id_recurso = v_recurso_id
              AND id_pais = p_id_pais
              AND codigo_partida = p_codigo_partida;

            -- Si el país no tenía el recurso, lo crea
            IF SQL%ROWCOUNT = 0 THEN
                -- Obtiene información del recurso desde RECURSOS_PARTIDA
                SELECT nombre, tipo_recurso, limite_produccion
                  INTO v_nombre_recurso, v_tipo_recurso, v_limite_produccion
                  FROM RECURSOS_PARTIDA
                 WHERE id_recurso = v_recurso_id
                   AND codigo_partida = p_codigo_partida;

                -- Crea el recurso para el país con la cantidad de la recompensa
                INSERT INTO RECURSO (
                    id_recurso, id_pais, codigo_partida,
                    cantidad
                ) VALUES (
                    v_recurso_id, p_id_pais, p_codigo_partida,
                    v_cantidad_recurso
                );
            END IF;
        END IF;
    END LOOP;

    -- Confirma todas las operaciones
    COMMIT;
     
EXCEPTION
    WHEN ex_logro_ya_obtenido THEN
        -- Si el logro ya fue obtenido, lanza error con mensaje descriptivo
        RAISE_APPLICATION_ERROR(-20010, 
            'Este logro ya ha sido obtenido previamente por el país ' || p_id_pais);
    
    -- Cualquier otro error se propaga automáticamente
 
END sp_otorgar_medalla_logro;

