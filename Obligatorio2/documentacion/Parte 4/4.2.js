let partidaSeleccionada = "PARTIDA_URU_2025_FINAL";


db.mensajes.aggregate([
    {
      $match: {
        "chat_id": partidaSeleccionada
      }
    },
    {
      $group: {
        _id: "$remitente_alias",
        mensajes_enviados: { $sum: 1 }
      }
    },
    {
      $sort: { mensajes_enviados: -1 }
    },
    {
      $limit: 1
    },
    {
      $project: {
        _id: 0,
        alias: "$_id",
        mensajes_enviados: 1
      }
    }
  ]);
  