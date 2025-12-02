db.mensajes.aggregate([
    {
      $match: {
        chat_id: "PARTIDA_URU_2025_FINAL",     
        tipo_mensaje: "privado",
        $or: [
          { remitente_alias: "Seba" },        
          { destinatario_alias: "Seba" }
        ]
      }
    },
    {
      $project: {
        _id: 0,
        fecha: "$timestamp",
        remitente: "$remitente_alias",
        destinatario: "$destinatario_alias",
        mensaje: "$contenido.texto",
        total_likes: {
          $size: { $ifNull: ["$interacciones.likes_usuarios", []] }
        }
      }
    },
    {
      $sort: { fecha: 1 }    
    }
  ]);
  