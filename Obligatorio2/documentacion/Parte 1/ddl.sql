SET SERVEROUTPUT ON;

DROP TABLE CONSTRUCCION_REGISTRO_PRODUCCION CASCADE CONSTRAINTS;
DROP TABLE CONSTRUCCION_COSTO_PERIODICO CASCADE CONSTRAINTS;
DROP TABLE CONSTRUCCION_COSTO_INICIAL CASCADE CONSTRAINTS;
DROP TABLE CONSTRUCCION CASCADE CONSTRAINTS;
DROP TABLE CONSTRUCCION_TIPO CASCADE CONSTRAINTS;
DROP TABLE COMERCIO CASCADE CONSTRAINTS;
DROP TABLE COMERCIO_RECURSO CASCADE CONSTRAINTS;
DROP TABLE MEDIODETRANSPORTE CASCADE CONSTRAINTS;
DROP TABLE REGISTRO_RECURSO_RONDA CASCADE CONSTRAINTS;
DROP TABLE RONDA CASCADE CONSTRAINTS;
DROP TABLE RECURSO CASCADE CONSTRAINTS;
DROP TABLE RECURSOS_PARTIDA CASCADE CONSTRAINTS;
DROP TABLE LOGRO CASCADE CONSTRAINTS;
DROP TABLE PAIS CASCADE CONSTRAINTS;
DROP TABLE PARTIDA_JUGADOR CASCADE CONSTRAINTS;
DROP TABLE PARTIDA CASCADE CONSTRAINTS;
DROP TABLE ADMINISTRADOR CASCADE CONSTRAINTS;
DROP TABLE JUGADOR CASCADE CONSTRAINTS;
DROP TABLE USUARIO CASCADE CONSTRAINTS;


CREATE TABLE USUARIO (
    alias VARCHAR2(50) PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    correo_electronico VARCHAR2(100) NOT NULL UNIQUE,
    fecha_registro DATE DEFAULT SYSDATE NOT NULL,
    nacionalidad VARCHAR2(100) NOT NULL, 
    telefono VARCHAR2(50),
    genero VARCHAR2(50),
    contrasenahash VARCHAR2(100)  
);

CREATE TABLE JUGADOR (
    alias VARCHAR2(50) PRIMARY KEY,
    CONSTRAINT fk_jugador_usuario FOREIGN KEY (alias) 
        REFERENCES USUARIO(alias) ON DELETE CASCADE
);

CREATE TABLE ADMINISTRADOR (
    alias VARCHAR2(50) PRIMARY KEY,
    CONSTRAINT fk_admin_usuario FOREIGN KEY (alias) 
        REFERENCES USUARIO(alias) ON DELETE CASCADE
);

CREATE TABLE PARTIDA (
    codigo_partida VARCHAR2(80) PRIMARY KEY,
    fecha_creacion DATE DEFAULT SYSDATE NOT NULL,
    turno_actual NUMBER(2),
    nombre VARCHAR2(50) NOT NULL
);

CREATE TABLE PAIS (
    id_pais NUMBER(5),
    contador_rondas_deuda NUMBER(1) NOT NULL,
    estado VARCHAR2(100) NOT NULL,
    codigo_partida VARCHAR2(80),
    nombre_oficial VARCHAR2(100) NOT NULL,
    capital VARCHAR2(100) NOT NULL,
    superficie_km2 NUMBER(10) DEFAULT 0 NOT NULL,
    manzanas_ciudad NUMBER DEFAULT 0,
  CONSTRAINT pais_pk PRIMARY KEY (id_pais, codigo_partida),
  CONSTRAINT pais_to_partida_fk FOREIGN KEY (codigo_partida)
        REFERENCES PARTIDA(codigo_partida) ON DELETE CASCADE,
  CONSTRAINT pais_capital_unique UNIQUE (capital, codigo_partida)
);

CREATE TABLE PARTIDA_JUGADOR (
    alias VARCHAR2(50),
    codigo_partida VARCHAR2(80),
    orden_turno NUMBER(2) DEFAULT 0 NOT NULL,
    fecha_union DATE DEFAULT SYSDATE NOT NULL,
    id_pais NUMBER(5) NOT NULL,
    CONSTRAINT partida_jugador_pk PRIMARY KEY (alias, codigo_partida),
    CONSTRAINT partida_jugador_to_partida_fk FOREIGN KEY (codigo_partida)
        REFERENCES PARTIDA(codigo_partida) ON DELETE CASCADE,
    CONSTRAINT partida_jugador_to_jugador_fk FOREIGN KEY (alias)
        REFERENCES JUGADOR(alias) ON DELETE CASCADE,
    CONSTRAINT partida_jugador_to_pais_fk FOREIGN KEY (id_pais, codigo_partida)
        REFERENCES PAIS(id_pais, codigo_partida)
);

CREATE TABLE LOGRO (
    id_logro NUMBER(5),
    id_pais NUMBER(5),
    codigo_partida VARCHAR2(80),
    nombre VARCHAR2(100) NOT NULL,
    descripcion VARCHAR2(500) NOT NULL,
    recompensa VARCHAR2(200) DEFAULT 0 NOT NULL,
    fecha_logro_completado DATE NOT NULL,
    CONSTRAINT logro_pk PRIMARY KEY (id_logro, id_pais, codigo_partida),
    CONSTRAINT logro_to_pais_fk FOREIGN KEY (id_pais, codigo_partida)
        REFERENCES PAIS(id_pais, codigo_partida) ON DELETE CASCADE
);

CREATE TABLE RECURSOS_PARTIDA (
    id_recurso NUMBER(5),
    codigo_partida VARCHAR2(80),
    nombre VARCHAR2(100) NOT NULL,
    tipo_recurso VARCHAR2(20) CHECK (tipo_recurso IN ('consumo','construccion','pbn')),
    limite_produccion NUMBER(10) DEFAULT 0 NOT NULL,
    produccion_base NUMBER(10) DEFAULT 0 NOT NULL,
    CONSTRAINT recursos_partida_pk PRIMARY KEY (id_recurso, codigo_partida),
    CONSTRAINT fk_recursos_partida_partida FOREIGN KEY (codigo_partida) 
        REFERENCES PARTIDA(codigo_partida) ON DELETE CASCADE
);

CREATE TABLE RECURSO (
    id_recurso NUMBER(5),
    id_pais NUMBER(5),
    codigo_partida VARCHAR2(80),
    cantidad NUMBER(10) DEFAULT 0 NOT NULL,
    CONSTRAINT recurso_pk PRIMARY KEY (id_recurso, id_pais, codigo_partida),
    CONSTRAINT recurso_to_pais_fk FOREIGN KEY (id_pais, codigo_partida)
        REFERENCES PAIS(id_pais, codigo_partida) ON DELETE CASCADE,
    CONSTRAINT recurso_to_recursos_partida_fk FOREIGN KEY (id_recurso, codigo_partida)
        REFERENCES RECURSOS_PARTIDA(id_recurso, codigo_partida) ON DELETE CASCADE
);

CREATE TABLE RONDA (
    id_ronda NUMBER(5),
    codigo_partida VARCHAR2(80),
    numero NUMBER(2) DEFAULT 0,
    fecha_inicio DATE DEFAULT SYSDATE,
    fecha_fin DATE,
    CONSTRAINT ronda_pk PRIMARY KEY (id_ronda, codigo_partida),
    CONSTRAINT ronda_to_partida_fk FOREIGN KEY (codigo_partida)
        REFERENCES PARTIDA(codigo_partida) ON DELETE CASCADE,
    CONSTRAINT chk_ronda_fechas CHECK (fecha_fin IS NULL OR fecha_inicio <= fecha_fin),
    CONSTRAINT ronda_numero_unique UNIQUE (codigo_partida, numero)
);

CREATE TABLE REGISTRO_RECURSO_RONDA (
    id_consumo_registro NUMBER(5) PRIMARY KEY,
    id_recurso NUMBER(5),
    id_pais NUMBER(5),
    codigo_partida VARCHAR2(80),
    id_ronda NUMBER(5),
    unidades_consumidas NUMBER(10) DEFAULT 0 NOT NULL,
    unidades_producidas NUMBER(10) DEFAULT 0 NOT NULL,
    deuda_generada NUMBER(10) DEFAULT 0 NOT NULL,
    produccion_suspendida CHAR(1) CHECK (produccion_suspendida IN ('S', 'N')), 
    produccion_disminuida CHAR(1) CHECK (produccion_disminuida IN ('S', 'N')),
    observacion VARCHAR2(500),
    CONSTRAINT registro_recurso_ronda_to_recurso_fk FOREIGN KEY (id_recurso, id_pais, codigo_partida) 
        REFERENCES RECURSO(id_recurso, id_pais, codigo_partida) ON DELETE CASCADE,
    CONSTRAINT registro_recurso_ronda_to_ronda_fk FOREIGN KEY (id_ronda, codigo_partida) 
        REFERENCES RONDA(id_ronda, codigo_partida) ON DELETE CASCADE
);

CREATE TABLE MEDIODETRANSPORTE (
    id_medio_transporte NUMBER(5) PRIMARY KEY,
    tipo VARCHAR2(20) CHECK (tipo IN ('barco', 'tren', 'avion')),
    capacidad_carga_maxima NUMBER(10) DEFAULT 0 NOT NULL
);

CREATE TABLE COMERCIO (
    id_comercio NUMBER(5) PRIMARY KEY,
    codigo_partida VARCHAR2(80),
    id_pais_origen NUMBER(5),
    id_pais_destino NUMBER(5),
    id_medio_transporte NUMBER(5),
    id_pais_responsable_traslado NUMBER(5),
    fecha_intercambio DATE DEFAULT SYSDATE,
       tipo_transaccion VARCHAR2(20) 
        CHECK (tipo_transaccion IN ('COMPRA', 'VENTA', 'TRUEQUE')),
    CONSTRAINT chk_comercio_paises CHECK (id_pais_origen != id_pais_destino),
    CONSTRAINT fk_comercio_partida FOREIGN KEY (codigo_partida) 
        REFERENCES PARTIDA(codigo_partida),
    CONSTRAINT fk_comercio_origen FOREIGN KEY (id_pais_origen, codigo_partida) 
        REFERENCES PAIS(id_pais, codigo_partida),
    CONSTRAINT fk_comercio_destino FOREIGN KEY (id_pais_destino, codigo_partida) 
        REFERENCES PAIS(id_pais, codigo_partida),
    CONSTRAINT fk_comercio_medio FOREIGN KEY (id_medio_transporte) 
        REFERENCES MEDIODETRANSPORTE(id_medio_transporte),
    CONSTRAINT fk_comercio_resp FOREIGN KEY (id_pais_responsable_traslado, codigo_partida) 
        REFERENCES PAIS(id_pais, codigo_partida)
);
CREATE TABLE COMERCIO_RECURSO (
    id_comercio NUMBER(5),
    id_recurso NUMBER(5),
    id_pais_propietario NUMBER(5),
    codigo_partida VARCHAR2(80),
    cantidad NUMBER(10,2) DEFAULT 0 NOT NULL,
    tipo_movimiento VARCHAR2(20)
        CHECK (tipo_movimiento IN ('ENVIO', 'RECEPCION')),

    CONSTRAINT comercio_recurso_pk PRIMARY KEY (id_comercio, id_recurso, id_pais_propietario, codigo_partida),
    CONSTRAINT fk_cr_comercio FOREIGN KEY (id_comercio)
        REFERENCES COMERCIO(id_comercio),
    CONSTRAINT fk_cr_recurso FOREIGN KEY (id_recurso, id_pais_propietario, codigo_partida)
        REFERENCES RECURSO(id_recurso, id_pais, codigo_partida)
);

CREATE TABLE CONSTRUCCION_TIPO (
    id_construccion_tipo NUMBER(5) PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    descripcion VARCHAR2(500) NOT NULL,
    categoria VARCHAR2(50) CHECK (categoria IN ('transporte','produccion','fabrica','urbano')),
    max_unidades_por_ronda NUMBER(10),
    CONSTRAINT chk_fabrica_max_unidades CHECK (
        (categoria = 'fabrica' AND max_unidades_por_ronda IS NOT NULL) OR
        (categoria != 'fabrica' AND max_unidades_por_ronda IS NULL)
    )
);

CREATE TABLE CONSTRUCCION (
    id_construccion NUMBER(5) PRIMARY KEY,
    id_pais NUMBER(5),
    codigo_partida VARCHAR2(80),
    id_construccion_tipo NUMBER(5),
    CONSTRAINT fk_const_pais FOREIGN KEY (id_pais, codigo_partida) 
        REFERENCES PAIS(id_pais, codigo_partida) ON DELETE CASCADE,
    CONSTRAINT fk_const_tipo FOREIGN KEY (id_construccion_tipo) 
        REFERENCES CONSTRUCCION_TIPO(id_construccion_tipo)
);

CREATE TABLE CONSTRUCCION_COSTO_INICIAL (
    id_construccion NUMBER(5),
    id_recurso NUMBER(5),
    id_pais NUMBER(5),
    codigo_partida VARCHAR2(80),
    cantidad NUMBER(10) DEFAULT 0 NOT NULL,
    PRIMARY KEY (id_construccion, id_recurso, id_pais, codigo_partida),
    CONSTRAINT fk_cci_construccion FOREIGN KEY (id_construccion) 
        REFERENCES CONSTRUCCION(id_construccion),
    CONSTRAINT fk_cci_recurso FOREIGN KEY (id_recurso, id_pais, codigo_partida) 
        REFERENCES RECURSO(id_recurso, id_pais, codigo_partida)
);

CREATE TABLE CONSTRUCCION_COSTO_PERIODICO (
    id_construccion NUMBER(5),
    id_recurso NUMBER(5),
    id_pais NUMBER(5),
    codigo_partida VARCHAR2(80),
    cantidad NUMBER(10) DEFAULT 0 NOT NULL,
    PRIMARY KEY (id_construccion, id_recurso, id_pais, codigo_partida),
    CONSTRAINT fk_ccp_construccion FOREIGN KEY (id_construccion) 
        REFERENCES CONSTRUCCION(id_construccion),
    CONSTRAINT fk_ccp_recurso FOREIGN KEY (id_recurso, id_pais, codigo_partida) 
        REFERENCES RECURSO(id_recurso, id_pais, codigo_partida)
);

CREATE TABLE CONSTRUCCION_REGISTRO_PRODUCCION (
    id_construccion NUMBER(5),
    id_recurso NUMBER(5),
    id_pais NUMBER(5),
    codigo_partida VARCHAR2(80),
    cantidad_por_ronda NUMBER(10) DEFAULT 0 NOT NULL,
    PRIMARY KEY (id_construccion, id_recurso, id_pais, codigo_partida),
    CONSTRAINT fk_crp_construccion FOREIGN KEY (id_construccion) 
        REFERENCES CONSTRUCCION(id_construccion),
    CONSTRAINT fk_crp_recurso FOREIGN KEY (id_recurso, id_pais, codigo_partida) 
        REFERENCES RECURSO(id_recurso, id_pais, codigo_partida)
);

CREATE OR REPLACE VIEW V_JUGADOR_MEDALLAS AS
SELECT 
    j.alias,
    NVL(COUNT(l.id_logro), 0) AS cantidad_medallas_obtenidas
FROM JUGADOR j
LEFT JOIN PARTIDA_JUGADOR pj ON j.alias = pj.alias
LEFT JOIN PAIS p ON pj.id_pais = p.id_pais 
                AND pj.codigo_partida = p.codigo_partida
LEFT JOIN LOGRO l ON p.id_pais = l.id_pais 
                 AND p.codigo_partida = l.codigo_partida
GROUP BY j.alias;



