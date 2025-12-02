let partidaSeleccionada = "PARTIDA_URU_2025_FINAL";

db.mensajes.aggregate([
  [
    {
      $match: {
        "chat_id": partidaSeleccionada,
        "tipo_mensaje": "publico"
      }
    },
    {
      $sort: {
        timestamp: 1
      }
    },
    {
      $project: {
        _id: 0,
        fecha: "$timestamp",
        remitente: "$remitente_alias",
        mensaje: "$contenido.texto",
        total_likes: {
          $size: {
            $ifNull: ["$interacciones.likes_usuarios", []]
          }
        },
        total_denuncias: {
          $size: {
            $ifNull: ["$interacciones.denuncias", []]
          }
        }
      }
    }
  ]
  
]);
