ÍNDICES CREADOS  
chats
// para ordenar chats por fecha de creación
db.chats.createIndex(
  { fecha_creacion: 1 }
);

// para listar chats por último mensaje 
db.chats.createIndex(
  { "estadisticas.ultimo_mensaje": -1 }
);

// buscar participantes activos
db.chats.createIndex(
  { "participantes.alias": 1 },
  { partialFilterExpression: { "participantes.activo": true } }
);

 //Indice único para evitar alias duplicados dentro de un chat
db.chats.createIndex(
  { _id: 1, "participantes.alias": 1 },
  { unique: true }
);

mensajes

// mensajes por chat ordenados por timestamp
db.mensajes.createIndex(
  { chat_id: 1, timestamp: 1 }
);

//Mensajes privados: chat + tipo + remitente + destinatario
db.mensajes.createIndex(
  { chat_id: 1, tipo_mensaje: 1, remitente_alias: 1, destinatario_alias: 1 }
);

// todos los mensajes enviados por un usuario
db.mensajes.createIndex(
  { remitente_alias: 1, timestamp: -1 }
);

// todos los mensajes recibidos por un usuario
db.mensajes.createIndex(
  { destinatario_alias: 1, timestamp: -1 }
);

// contar mensajes enviados por usuario dentro de un chat
db.mensajes.createIndex(
  { chat_id: 1, remitente_alias: 1 }
);  

// Mensajes privados por destinatario  y fecha
db.mensajes.createIndex(
  { destinatario_alias: 1, timestamp: 1 }
);

// Por modo de moderación (buscar mensajes moderados/eliminados)
db.mensajes.createIndex(
  { estado: 1 }
);

//Consultas por tipo de contenido (texto, propuesta, votación, acción...)
db.mensajes.createIndex(
  { "contenido.tipo": 1 }
);
