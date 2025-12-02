INSERT INTO CONSTRUCCION_TIPO (id_construccion_tipo, nombre, descripcion, categoria, max_unidades_por_ronda) 
VALUES (1, 'Puerto', 'Facilita el comercio marítimo y aumenta la capacidad de carga', 'transporte', NULL);

INSERT INTO CONSTRUCCION_TIPO (id_construccion_tipo, nombre, descripcion, categoria, max_unidades_por_ronda) 
VALUES (2, 'Usina Eléctrica', 'Genera energía para las industrias', 'produccion', NULL);

INSERT INTO CONSTRUCCION_TIPO (id_construccion_tipo, nombre, descripcion, categoria, max_unidades_por_ronda) 
VALUES (3, 'Plantación', 'Aumenta la producción de recursos agrícolas', 'produccion', NULL);

INSERT INTO CONSTRUCCION_TIPO (id_construccion_tipo, nombre, descripcion, categoria, max_unidades_por_ronda) 
VALUES (4, 'Astillero', 'Permite construir barcos más grandes', 'transporte', NULL);

INSERT INTO CONSTRUCCION_TIPO (id_construccion_tipo, nombre, descripcion, categoria, max_unidades_por_ronda) 
VALUES (5, 'Manzana de Ciudad', 'Aumenta la población y capacidad de almacenamiento', 'urbano', NULL);

INSERT INTO USUARIO (alias, nombre, correo_electronico, fecha_registro, nacionalidad, telefono, genero, contrasenahash) 
VALUES ('ana_pereira', 'Ana Pereira', 'ana.p@mail.com', TO_DATE('2023-05-15', 'YYYY-MM-DD'), 'Chilena', '+56912345678', 'F', 'hash_pwd_1');

INSERT INTO USUARIO (alias, nombre, correo_electronico, fecha_registro, nacionalidad, telefono, genero, contrasenahash) 
VALUES ('bruno_diaz', 'Bruno Díaz', 'bruno.d@mail.com', TO_DATE('2023-08-20', 'YYYY-MM-DD'), 'Argentino', '+54911223344', 'M', 'hash_pwd_2');

INSERT INTO USUARIO (alias, nombre, correo_electronico, fecha_registro, nacionalidad, telefono, genero, contrasenahash) 
VALUES ('carla_rossi', 'Carla Rossi', 'carla.r@mail.com', TO_DATE('2024-01-10', 'YYYY-MM-DD'), 'Italiana', '+393331234567', 'F', 'hash_pwd_3');

INSERT INTO USUARIO (alias, nombre, correo_electronico, fecha_registro, nacionalidad, telefono, genero, contrasenahash) 
VALUES ('admin_global', 'Admin Global', 'admin@jdp.com', TO_DATE('2022-01-01', 'YYYY-MM-DD'), 'Internacional', '+10000000000', 'M', 'hash_pwd_admin');

INSERT INTO JUGADOR (alias) VALUES ('ana_pereira');
INSERT INTO JUGADOR (alias) VALUES ('bruno_diaz');
INSERT INTO JUGADOR (alias) VALUES ('carla_rossi');

INSERT INTO ADMINISTRADOR (alias) VALUES ('admin_global');

INSERT INTO PARTIDA (codigo_partida, fecha_creacion, turno_actual, nombre) 
VALUES ('MUNDO2024', TO_DATE('2024-01-15', 'YYYY-MM-DD'), 3, 'Mundo Nuevo');

INSERT INTO PAIS (id_pais,contador_rondas_deuda, estado, codigo_partida, nombre_oficial, capital, superficie_km2, manzanas_ciudad) 
VALUES (1,0, 'ACTIVO', 'MUNDO2024', 'República de Andia', 'Andrópolis', 50000 , 10);


INSERT INTO PAIS (id_pais,contador_rondas_deuda, estado, codigo_partida, nombre_oficial, capital, superficie_km2, manzanas_ciudad) 
VALUES (2,0, 'ACTIVO', 'MUNDO2024', 'Reino Boreal', 'Nortia', 75000, 10);

INSERT INTO PAIS (id_pais,contador_rondas_deuda, estado, codigo_partida, nombre_oficial, capital, superficie_km2, manzanas_ciudad) 
VALUES (3,0, 'ACTIVO', 'MUNDO2024', 'Imperio del Sol', 'Solara', 60000, 10);


INSERT INTO PARTIDA_JUGADOR (alias, codigo_partida, orden_turno, fecha_union, id_pais) 
VALUES ('bruno_diaz', 'MUNDO2024', 2, TO_DATE('2024-01-15', 'YYYY-MM-DD'), 2);

INSERT INTO PARTIDA_JUGADOR (alias, codigo_partida, orden_turno, fecha_union, id_pais) 
VALUES ('carla_rossi', 'MUNDO2024', 3, TO_DATE('2024-01-16', 'YYYY-MM-DD'), 3);

INSERT INTO USUARIO (alias, nombre, correo_electronico, fecha_registro, nacionalidad, telefono, genero, contrasenahash) 
VALUES ('maria_gonzalez', 'María González', 'maria.g@mail.com', TO_DATE('2023-03-20', 'YYYY-MM-DD'), 'Uruguaya', '+59812345678', 'F', 'hash_pwd_4');

INSERT INTO USUARIO (alias, nombre, correo_electronico, fecha_registro, nacionalidad, telefono, genero, contrasenahash) 
VALUES ('lucia_silva', 'Lucía Silva', 'lucia.s@mail.com', TO_DATE('2023-07-15', 'YYYY-MM-DD'), 'Uruguaya', '+59898765432', 'F', 'hash_pwd_5');

INSERT INTO USUARIO (alias, nombre, correo_electronico, fecha_registro, nacionalidad, telefono, genero, contrasenahash) 
VALUES ('juan_perez', 'Juan Pérez', 'juan.p@mail.com', TO_DATE('2023-11-10', 'YYYY-MM-DD'), 'Uruguaya', '+59855556666', 'M', 'hash_pwd_6');

INSERT INTO JUGADOR (alias) VALUES ('maria_gonzalez');
INSERT INTO JUGADOR (alias) VALUES ('lucia_silva');
INSERT INTO JUGADOR (alias) VALUES ('juan_perez');

INSERT INTO PARTIDA (codigo_partida, fecha_creacion, turno_actual, nombre) 
VALUES ('URUGAME2024', TO_DATE('2024-02-01', 'YYYY-MM-DD'), 2, 'Uruguay Game');

INSERT INTO PARTIDA (codigo_partida, fecha_creacion, turno_actual, nombre) 
VALUES ('RIOPLATA2024', TO_DATE('2024-03-15', 'YYYY-MM-DD'), 1, 'Río de la Plata');

INSERT INTO PAIS (id_pais,contador_rondas_deuda, estado, codigo_partida, nombre_oficial, capital, superficie_km2, manzanas_ciudad) 
VALUES (4,0, 'ACTIVO', 'URUGAME2024', 'República Uruguaya', 'Montevideo', 176215, 10);

INSERT INTO PAIS (id_pais,contador_rondas_deuda, estado, codigo_partida, nombre_oficial, capital, superficie_km2, manzanas_ciudad) 
VALUES (5,0, 'ACTIVO','URUGAME2024', 'Confederación Argentina', 'Buenos Aires', 2780400, 10);

INSERT INTO PAIS (id_pais,contador_rondas_deuda, estado, codigo_partida, nombre_oficial, capital, superficie_km2, manzanas_ciudad) 
VALUES (6,0,  'ACTIVO','RIOPLATA2024', 'Nación Uruguaya', 'Colonia', 150000, 10);

INSERT INTO PARTIDA_JUGADOR (alias, codigo_partida, orden_turno, fecha_union, id_pais) 
VALUES ('maria_gonzalez', 'URUGAME2024', 1, TO_DATE('2024-02-01', 'YYYY-MM-DD'), 4);

INSERT INTO PARTIDA_JUGADOR (alias, codigo_partida, orden_turno, fecha_union, id_pais) 
VALUES ('lucia_silva', 'URUGAME2024', 2, TO_DATE('2024-02-01', 'YYYY-MM-DD'), 5);

INSERT INTO PARTIDA_JUGADOR (alias, codigo_partida, orden_turno, fecha_union, id_pais) 
VALUES ('juan_perez', 'RIOPLATA2024', 1, TO_DATE('2024-03-15', 'YYYY-MM-DD'), 6);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (4, 'URUGAME2024', 'Carne Uruguaya', 'pbn', 3000, 8000);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (5, 'URUGAME2024', 'Lana', 'construccion', 3000, 5000);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (6, 'URUGAME2024', 'Granito', 'construccion', 3000, 4000);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (7, 'URUGAME2024', 'Soja', 'pbn', 3000, 10000);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (8, 'URUGAME2024', 'Petróleo', 'construccion', 3000, 3000);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (9, 'URUGAME2024', 'Madera', 'construccion', 3000, 4000);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (10, 'URUGAME2024', 'Pescado', 'pbn', 3000, 5000);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (13, 'URUGAME2024', 'Oro', 'pbn', 3000, 1000);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (4, 'RIOPLATA2024', 'Carne Uruguaya', 'pbn', 3000, 8000);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (5, 'RIOPLATA2024', 'Lana', 'construccion', 3000, 5000);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (6, 'RIOPLATA2024', 'Granito', 'construccion', 3000, 4000);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (4, 4, 'URUGAME2024', 1500);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (5, 4, 'URUGAME2024', 800);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (6, 4, 'URUGAME2024', 600);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (4, 6, 'RIOPLATA2024', 1200);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (5, 6, 'RIOPLATA2024', 400);

INSERT INTO CONSTRUCCION (id_construccion, id_pais, codigo_partida, id_construccion_tipo) 
VALUES (2001, 4, 'URUGAME2024', 1); 

INSERT INTO CONSTRUCCION (id_construccion, id_pais, codigo_partida, id_construccion_tipo) 
VALUES (2002, 6, 'RIOPLATA2024', 1); 

INSERT INTO CONSTRUCCION_COSTO_INICIAL (id_construccion, id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (2001, 5, 4, 'URUGAME2024', 800); 

INSERT INTO CONSTRUCCION_COSTO_INICIAL (id_construccion, id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (2001, 6, 4, 'URUGAME2024', 600); 

INSERT INTO CONSTRUCCION_COSTO_INICIAL (id_construccion, id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (2002, 5, 6, 'RIOPLATA2024', 750);
INSERT INTO MEDIODETRANSPORTE (id_medio_transporte, tipo, capacidad_carga_maxima) 
VALUES (1, 'barco', 5000);

INSERT INTO MEDIODETRANSPORTE (id_medio_transporte, tipo, capacidad_carga_maxima) 
VALUES (2, 'tren', 3000);
INSERT INTO PARTIDA_JUGADOR (alias, codigo_partida, orden_turno, fecha_union, id_pais) 
VALUES ('lucia_silva', 'MUNDO2024', 4, TO_DATE('2024-01-20', 'YYYY-MM-DD'), 3);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (7, 5, 'URUGAME2024', 2000);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (8, 5, 'URUGAME2024', 500);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (9, 5, 'URUGAME2024', 700);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (10, 4, 'URUGAME2024', 900);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (6, 6, 'RIOPLATA2024', 300);

INSERT INTO MEDIODETRANSPORTE (id_medio_transporte, tipo, capacidad_carga_maxima) 
VALUES (3, 'avion', 1000);

INSERT INTO MEDIODETRANSPORTE (id_medio_transporte, tipo, capacidad_carga_maxima) 
VALUES (4, 'barco', 8000);


INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (4, 5, 'URUGAME2024', 0);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (5, 5, 'URUGAME2024', 0);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (7, 4, 'URUGAME2024', 0);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (8, 4, 'URUGAME2024', 100);

INSERT INTO PARTIDA_JUGADOR (alias, codigo_partida, orden_turno, fecha_union, id_pais) 
VALUES ('juan_perez', 'MUNDO2024', 4, TO_DATE('2024-01-20', 'YYYY-MM-DD'), 3);

INSERT INTO LOGRO (id_logro, id_pais, codigo_partida, nombre, descripcion, recompensa, fecha_logro_completado) 
VALUES (1, 4, 'URUGAME2024', 'Primer Trueque', 'Realizar el primer intercambio comercial', 1000, SYSDATE);

INSERT INTO RONDA (id_ronda, codigo_partida, numero, fecha_inicio, fecha_fin) 
VALUES (1, 'URUGAME2024', 1, SYSDATE, NULL);

INSERT INTO RONDA (id_ronda, codigo_partida, numero, fecha_inicio, fecha_fin) 
VALUES (5, 'URUGAME2024', 5, SYSDATE, NULL);

INSERT INTO RONDA (id_ronda, codigo_partida, numero, fecha_inicio, fecha_fin) 
VALUES (10, 'URUGAME2024', 10, SYSDATE, NULL);

INSERT INTO RONDA (id_ronda, codigo_partida, numero, fecha_inicio, fecha_fin) 
VALUES (20, 'URUGAME2024', 20, SYSDATE, NULL);

INSERT INTO RONDA (id_ronda, codigo_partida, numero, fecha_inicio, fecha_fin) 
VALUES (30, 'URUGAME2024', 30, SYSDATE, NULL);

INSERT INTO RONDA (id_ronda, codigo_partida, numero, fecha_inicio, fecha_fin) 
VALUES (1, 'MUNDO2024', 1, SYSDATE, NULL);

INSERT INTO RONDA (id_ronda, codigo_partida, numero, fecha_inicio, fecha_fin) 
VALUES (2, 'MUNDO2024', 2, SYSDATE, NULL);

INSERT INTO RONDA (id_ronda, codigo_partida, numero, fecha_inicio, fecha_fin) 
VALUES (3, 'MUNDO2024', 3, SYSDATE, NULL);

INSERT INTO RONDA (id_ronda, codigo_partida, numero, fecha_inicio, fecha_fin) 
VALUES (1, 'RIOPLATA2024', 1, SYSDATE, NULL);


INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (14, 'URUGAME2024', 'Alimentos', 'consumo', 2000, 10000);

INSERT INTO RECURSOS_PARTIDA (id_recurso, codigo_partida, nombre, tipo_recurso, produccion_base, limite_produccion) 
VALUES (15, 'URUGAME2024', 'Energía kW', 'consumo', 1500, 8000);

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (14, 4, 'URUGAME2024', 3000);  

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (15, 4, 'URUGAME2024', 2500);  

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (14, 5, 'URUGAME2024', 2000); 

INSERT INTO RECURSO (id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (15, 5, 'URUGAME2024', 1800); 

INSERT INTO CONSTRUCCION_COSTO_PERIODICO (id_construccion, id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (2001, 5, 4, 'URUGAME2024', 100);  
INSERT INTO CONSTRUCCION_COSTO_PERIODICO (id_construccion, id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (2001, 6, 4, 'URUGAME2024', 50);   

INSERT INTO CONSTRUCCION (id_construccion, id_pais, codigo_partida, id_construccion_tipo) 
VALUES (2003, 4, 'URUGAME2024', 2); 

INSERT INTO CONSTRUCCION_COSTO_INICIAL (id_construccion, id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (2003, 6, 4, 'URUGAME2024', 500);  

INSERT INTO CONSTRUCCION_REGISTRO_PRODUCCION (id_construccion, id_recurso, id_pais, codigo_partida, cantidad_por_ronda) 
VALUES (2003, 15, 4, 'URUGAME2024', 200);  

INSERT INTO CONSTRUCCION_COSTO_PERIODICO (id_construccion, id_recurso, id_pais, codigo_partida, cantidad) 
VALUES (2003, 8, 4, 'URUGAME2024', 30);  


