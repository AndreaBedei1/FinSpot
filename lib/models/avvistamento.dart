import 'dart:convert';

enum SyncState {
  synced,
  pendingCreate,
  pendingUpdate,
  pendingDelete,
}

SyncState syncStateFromString(String? value) {
  switch (value) {
    case 'pending_create':
      return SyncState.pendingCreate;
    case 'pending_update':
      return SyncState.pendingUpdate;
    case 'pending_delete':
      return SyncState.pendingDelete;
    default:
      return SyncState.synced;
  }
}

String syncStateToString(SyncState state) {
  switch (state) {
    case SyncState.pendingCreate:
      return 'pending_create';
    case SyncState.pendingUpdate:
      return 'pending_update';
    case SyncState.pendingDelete:
      return 'pending_delete';
    case SyncState.synced:
      return 'synced';
  }
}

class UserLite {
  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? img;

  const UserLite({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.img,
  });

  factory UserLite.fromApiJson(Map<String, dynamic> json) {
    return UserLite(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: (json['email'] ?? '').toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      img: json['img']?.toString(),
    );
  }

  factory UserLite.fromLocalJson(Map<String, dynamic> json) {
    return UserLite(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: (json['email'] ?? '').toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      img: json['img']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'img': img,
    };
  }
}

class AnimalOption {
  final int id;
  final String name;
  final String? colorHex;

  const AnimalOption({
    required this.id,
    required this.name,
    this.colorHex,
  });

  factory AnimalOption.fromJson(Map<String, dynamic> json) {
    return AnimalOption(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      colorHex: json['colorHex']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
    };
  }
}

class SpeciesInfoData {
  final String? scientificName;
  final String? description;
  final String? dimension;
  final String? curiosity;

  const SpeciesInfoData({
    this.scientificName,
    this.description,
    this.dimension,
    this.curiosity,
  });

  factory SpeciesInfoData.fromJson(Map<String, dynamic> json) {
    return SpeciesInfoData(
      scientificName: json['scientificName']?.toString(),
      description: json['description']?.toString(),
      dimension: json['dimension']?.toString(),
      curiosity: json['curiosity']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scientificName': scientificName,
      'description': description,
      'dimension': dimension,
      'curiosity': curiosity,
    };
  }
}

class SpeciesOption {
  final int id;
  final String name;
  final int animalId;
  final String? scientificName;
  final SpeciesInfoData? info;

  const SpeciesOption({
    required this.id,
    required this.name,
    required this.animalId,
    this.scientificName,
    this.info,
  });

  factory SpeciesOption.fromJson(Map<String, dynamic> json) {
    return SpeciesOption(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      animalId: (json['animalId'] as num?)?.toInt() ?? 0,
      scientificName: json['scientificName']?.toString(),
      info: json['info'] is Map<String, dynamic>
          ? SpeciesInfoData.fromJson(json['info'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'animalId': animalId,
      'scientificName': scientificName,
      'info': info?.toJson(),
    };
  }
}

class AnnotationItem {
  final int id;
  final double tlX;
  final double tlY;
  final double brX;
  final double brY;
  final int? specimenId;
  final String? specimenName;

  const AnnotationItem({
    required this.id,
    required this.tlX,
    required this.tlY,
    required this.brX,
    required this.brY,
    this.specimenId,
    this.specimenName,
  });

  factory AnnotationItem.fromApiJson(Map<String, dynamic> json) {
    final specimen = json['specimen'];
    return AnnotationItem(
      id: (json['id'] as num).toInt(),
      tlX: (json['tl_x'] as num).toDouble(),
      tlY: (json['tl_y'] as num).toDouble(),
      brX: (json['br_x'] as num).toDouble(),
      brY: (json['br_y'] as num).toDouble(),
      specimenId: (json['specimenId'] as num?)?.toInt(),
      specimenName: specimen is Map<String, dynamic>
          ? specimen['name']?.toString()
          : null,
    );
  }

  factory AnnotationItem.fromLocalJson(Map<String, dynamic> json) {
    return AnnotationItem(
      id: (json['id'] as num).toInt(),
      tlX: (json['tlX'] as num).toDouble(),
      tlY: (json['tlY'] as num).toDouble(),
      brX: (json['brX'] as num).toDouble(),
      brY: (json['brY'] as num).toDouble(),
      specimenId: (json['specimenId'] as num?)?.toInt(),
      specimenName: json['specimenName']?.toString(),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'tlX': tlX,
      'tlY': tlY,
      'brX': brX,
      'brY': brY,
      'specimenId': specimenId,
      'specimenName': specimenName,
    };
  }
}

class SightingImageItem {
  final int id;
  final String url;
  final List<AnnotationItem> annotations;
  final bool pendingUpload;
  final String? localPath;

  const SightingImageItem({
    required this.id,
    required this.url,
    this.annotations = const [],
    this.pendingUpload = false,
    this.localPath,
  });

  factory SightingImageItem.fromApiJson(Map<String, dynamic> json) {
    final annotationsRaw = json['annotations'];
    return SightingImageItem(
      id: (json['id'] as num).toInt(),
      url: (json['url'] ?? '').toString(),
      annotations: annotationsRaw is List
          ? annotationsRaw
              .whereType<Map<String, dynamic>>()
              .map(AnnotationItem.fromApiJson)
              .toList()
          : const [],
    );
  }

  factory SightingImageItem.fromLocalJson(Map<String, dynamic> json) {
    final annotationsRaw = json['annotations'];
    return SightingImageItem(
      id: (json['id'] as num).toInt(),
      url: (json['url'] ?? '').toString(),
      annotations: annotationsRaw is List
          ? annotationsRaw
              .whereType<Map<String, dynamic>>()
              .map(AnnotationItem.fromLocalJson)
              .toList()
          : const [],
      pendingUpload: json['pendingUpload'] == true,
      localPath: json['localPath']?.toString(),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'url': url,
      'annotations': annotations.map((a) => a.toLocalJson()).toList(),
      'pendingUpload': pendingUpload,
      'localPath': localPath,
    };
  }
}

class Avvistamento {
  final int id;
  final String data;
  final double latitudine;
  final double longitudine;
  final String animale;
  final int animalId;
  final int? speciesId;
  final String? specie;
  final List<String> immagini;
  final int numeroEsemplari;
  final String? vento;
  final String? mare;
  final String? note;
  final UserLite user;
  final SyncState syncState;

  const Avvistamento({
    required this.id,
    required this.data,
    required this.latitudine,
    required this.longitudine,
    required this.animale,
    required this.animalId,
    this.speciesId,
    this.specie,
    this.immagini = const [],
    required this.numeroEsemplari,
    this.vento,
    this.mare,
    this.note,
    required this.user,
    this.syncState = SyncState.synced,
  });

  bool get isPending => syncState != SyncState.synced;

  DateTime get dataDateTime {
    return DateTime.tryParse(data) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory Avvistamento.fromApiJson(Map<String, dynamic> json) {
    final animal = json['animal'] as Map<String, dynamic>?;
    final species = json['species'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    return Avvistamento(
      id: (json['id'] as num).toInt(),
      data: (json['date'] ?? '').toString(),
      latitudine: (json['latitude'] as num).toDouble(),
      longitudine: (json['longitude'] as num).toDouble(),
      animale: animal?['name']?.toString() ?? 'Sconosciuto',
      animalId: (animal?['id'] as num?)?.toInt() ??
          (json['animalId'] as num?)?.toInt() ??
          0,
      speciesId: (species?['id'] as num?)?.toInt() ??
          (json['speciesId'] as num?)?.toInt(),
      specie: species?['name']?.toString(),
      immagini: const [],
      numeroEsemplari: (json['specimens'] as num).toInt(),
      vento: json['wind']?.toString(),
      mare: json['sea']?.toString(),
      note: json['notes']?.toString(),
      user: user != null
          ? UserLite.fromApiJson(user)
          : const UserLite(id: 0, email: ''),
      syncState: SyncState.synced,
    );
  }

  factory Avvistamento.fromLocalJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return Avvistamento(
      id: (json['id'] as num).toInt(),
      data: (json['data'] ?? '').toString(),
      latitudine: (json['latitudine'] as num).toDouble(),
      longitudine: (json['longitudine'] as num).toDouble(),
      animale: (json['animale'] ?? '').toString(),
      animalId: (json['animalId'] as num).toInt(),
      speciesId: (json['speciesId'] as num?)?.toInt(),
      specie: json['specie']?.toString(),
      immagini: (json['immagini'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      numeroEsemplari: (json['numeroEsemplari'] as num).toInt(),
      vento: json['vento']?.toString(),
      mare: json['mare']?.toString(),
      note: json['note']?.toString(),
      user: UserLite.fromLocalJson(user),
      syncState: syncStateFromString(json['syncState']?.toString()),
    );
  }

  Avvistamento copyWith({
    int? id,
    String? data,
    double? latitudine,
    double? longitudine,
    String? animale,
    int? animalId,
    int? speciesId,
    String? specie,
    List<String>? immagini,
    int? numeroEsemplari,
    String? vento,
    String? mare,
    String? note,
    UserLite? user,
    SyncState? syncState,
  }) {
    return Avvistamento(
      id: id ?? this.id,
      data: data ?? this.data,
      latitudine: latitudine ?? this.latitudine,
      longitudine: longitudine ?? this.longitudine,
      animale: animale ?? this.animale,
      animalId: animalId ?? this.animalId,
      speciesId: speciesId ?? this.speciesId,
      specie: specie ?? this.specie,
      immagini: immagini ?? this.immagini,
      numeroEsemplari: numeroEsemplari ?? this.numeroEsemplari,
      vento: vento ?? this.vento,
      mare: mare ?? this.mare,
      note: note ?? this.note,
      user: user ?? this.user,
      syncState: syncState ?? this.syncState,
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'data': data,
      'latitudine': latitudine,
      'longitudine': longitudine,
      'animale': animale,
      'animalId': animalId,
      'speciesId': speciesId,
      'specie': specie,
      'immagini': immagini,
      'numeroEsemplari': numeroEsemplari,
      'vento': vento,
      'mare': mare,
      'note': note,
      'user': user.toJson(),
      'syncState': syncStateToString(syncState),
    };
  }
}

class CreateSightingInput {
  final DateTime date;
  final int specimens;
  final String? wind;
  final String? sea;
  final String? notes;
  final double latitude;
  final double longitude;
  final int animalId;
  final int? speciesId;

  const CreateSightingInput({
    required this.date,
    required this.specimens,
    this.wind,
    this.sea,
    this.notes,
    required this.latitude,
    required this.longitude,
    required this.animalId,
    this.speciesId,
  });

  Map<String, dynamic> toApiJson() {
    return {
      'date': date.toUtc().toIso8601String(),
      'specimens': specimens,
      'wind': wind,
      'sea': sea,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'animalId': animalId,
      'speciesId': speciesId,
    };
  }
}

class UpdateSightingInput {
  final int? animalId;
  final int? speciesId;
  final String? wind;
  final String? sea;
  final String? notes;

  const UpdateSightingInput({
    this.animalId,
    this.speciesId,
    this.wind,
    this.sea,
    this.notes,
  });

  Map<String, dynamic> toApiJson() {
    return {
      if (animalId != null) 'animalId': animalId,
      if (speciesId != null) 'speciesId': speciesId,
      if (wind != null) 'wind': wind,
      if (sea != null) 'sea': sea,
      if (notes != null) 'notes': notes,
    };
  }
}

class PendingOperation {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const PendingOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'payload': payload,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  static List<PendingOperation> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <PendingOperation>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <PendingOperation>[];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PendingOperation.fromJson)
        .toList();
  }

  static String encodeList(List<PendingOperation> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }
}
