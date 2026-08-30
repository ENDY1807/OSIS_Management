class FileRiwayat {
  String id;
  String namaFile;
  DateTime tanggalUpload;
  List<String> nisList;

  FileRiwayat({
    required this.id,
    required this.namaFile,
    required this.tanggalUpload,
    required this.nisList,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'namaFile': namaFile,
    'tanggalUpload': tanggalUpload.toIso8601String(),
    'nisList': nisList,
  };

  factory FileRiwayat.fromJson(Map<String, dynamic> j) => FileRiwayat(
    id: j['id'] ?? '',
    namaFile: j['namaFile'] ?? '',
    tanggalUpload: DateTime.parse(j['tanggalUpload'] ?? DateTime.now().toIso8601String()),
    nisList: (j['nisList'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );
}

class Siswa {
  String id;
  String nama;
  String kelas;
  String nis;

  Siswa({required this.id, required this.nama, required this.kelas, required this.nis});

  Map<String, dynamic> toJson() => {'id': id, 'nama': nama, 'kelas': kelas, 'nis': nis};
  
  factory Siswa.fromJson(Map<String, dynamic> j) =>
      Siswa(
        id: j['id'] ?? '', 
        nama: j['nama'] ?? '', 
        kelas: j['kelas'] ?? '', 
        nis: j['nis'] ?? ''
      );
}

class JenisPelanggaran {
  String id;
  String nama;
  List<int> hariAktif; // 1=Senin..5=Jumat, kosong=semua hari

  JenisPelanggaran({required this.id, required this.nama, this.hariAktif = const []});

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'hari_aktif': hariAktif,
  };

  factory JenisPelanggaran.fromJson(Map<String, dynamic> j) => JenisPelanggaran(
    id: j['id'] ?? '',
    nama: j['nama'] ?? '',
    hariAktif: (j['hari_aktif'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [],
  );
}

class Pelanggaran {
  String id;
  String siswaId;
  String jenisId;
  DateTime tanggal;
  String keterangan;
  String? namaSiswa;
  String? kelasSiswa;
  String? nisSiswa;

  Pelanggaran({
    required this.id,
    required this.siswaId,
    required this.jenisId,
    required this.tanggal,
    this.keterangan = '',
    this.namaSiswa,
    this.kelasSiswa,
    this.nisSiswa,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'siswaId': siswaId,
        'jenisId': jenisId,
        'tanggal': tanggal.toIso8601String(),
        'keterangan': keterangan,
        if (namaSiswa != null) 'namaSiswa': namaSiswa,
        if (kelasSiswa != null) 'kelasSiswa': kelasSiswa,
        if (nisSiswa != null) 'nisSiswa': nisSiswa,
      };

  factory Pelanggaran.fromJson(Map<String, dynamic> j) => Pelanggaran(
        id: j['id'] ?? '',
        siswaId: j['siswaId'] ?? j['siswa_id'] ?? '',
        jenisId: j['jenisId'] ?? j['jenis_id'] ?? '',
        tanggal: DateTime.parse(j['tanggal'] ?? DateTime.now().toIso8601String()),
        keterangan: j['keterangan'] ?? '',
        namaSiswa: j['namaSiswa'] ?? j['nama_siswa'] ?? j['siswa_nama'],
        kelasSiswa: j['kelasSiswa'] ?? j['kelas_siswa'] ?? j['siswa_kelas'],
        nisSiswa: j['nisSiswa'] ?? j['nis_siswa'] ?? j['siswa_nis'],
      );
}

class StatusProker {
  static const belum = 'Belum';
  static const berjalan = 'Berjalan';
  static const selesai = 'Selesai';
  static const all = [belum, berjalan, selesai];
}

class Proker {
  String id;
  String nama;
  String deskripsi;
  String sekbid;
  String penanggungJawab;
  DateTime tanggalRencana;
  DateTime? tanggalRealisasi;
  String status;
  String keterangan;

  Proker({
    required this.id,
    required this.nama,
    required this.deskripsi,
    required this.sekbid,
    required this.penanggungJawab,
    required this.tanggalRencana,
    this.tanggalRealisasi,
    this.status = StatusProker.belum,
    this.keterangan = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'deskripsi': deskripsi,
        'sekbid': sekbid,
        'penanggungJawab': penanggungJawab,
        'tanggalRencana': tanggalRencana.toIso8601String(),
        'tanggalRealisasi': tanggalRealisasi?.toIso8601String(),
        'status': status,
        'keterangan': keterangan,
      };
  
  factory Proker.fromJson(Map<String, dynamic> j) => Proker(
        id: j['id'] ?? '',
        nama: j['nama'] ?? '',
        deskripsi: j['deskripsi'] ?? '',
        sekbid: j['sekbid'] ?? '',
        penanggungJawab: j['penanggungJawab'] ?? j['penanggung_jawab'] ?? '',
        tanggalRencana: DateTime.parse(j['tanggalRencana'] ?? j['tanggal_rencana'] ?? DateTime.now().toIso8601String()),
        tanggalRealisasi: (j['tanggalRealisasi'] ?? j['tanggal_realisasi']) != null 
            ? DateTime.parse(j['tanggalRealisasi'] ?? j['tanggal_realisasi']) 
            : null,
        status: j['status'] ?? StatusProker.belum,
        keterangan: j['keterangan'] ?? '',
      );
}

class KategoriArsip {
  static const surat = 'Surat';
  static const proposal = 'Proposal';
  static const lpj = 'LPJ';
  static const sk = 'SK';
  static const notulen = 'Notulen';
  static const lainnya = 'Lainnya';
  static const all = [surat, proposal, lpj, sk, notulen, lainnya];
}

class Arsip {
  String id;
  String judul;
  String kategori;
  String deskripsi;
  String nomorSurat;
  DateTime tanggal;
  String pembuatId;
  String fileUrl;
  String keterangan;

  Arsip({
    required this.id,
    required this.judul,
    required this.kategori,
    this.deskripsi = '',
    this.nomorSurat = '',
    required this.tanggal,
    required this.pembuatId,
    this.fileUrl = '',
    this.keterangan = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'judul': judul,
        'kategori': kategori,
        'deskripsi': deskripsi,
        'nomorSurat': nomorSurat,
        'tanggal': tanggal.toIso8601String(),
        'pembuatId': pembuatId,
        'fileUrl': fileUrl,
        'keterangan': keterangan,
      };
  
  factory Arsip.fromJson(Map<String, dynamic> j) => Arsip(
        id: j['id'] ?? '',
        judul: j['judul'] ?? '',
        kategori: j['kategori'] ?? KategoriArsip.lainnya,
        deskripsi: j['deskripsi'] ?? '',
        nomorSurat: j['nomorSurat'] ?? j['nomor_surat'] ?? '',
        tanggal: DateTime.parse(j['tanggal'] ?? DateTime.now().toIso8601String()),
        pembuatId: j['pembuatId'] ?? j['pembuat_id'] ?? '',
        fileUrl: j['fileUrl'] ?? j['file_url'] ?? '',
        keterangan: j['keterangan'] ?? '',
      );
}

class StatusLaporan {
  static const draft = 'Draft';
  static const selesai = 'Selesai';
  static const all = [draft, selesai];
}

class LaporanKegiatan {
  String id;
  String judul;
  String sekbid;
  String penanggungJawab;
  DateTime tanggalKegiatan;
  String lokasi;
  String deskripsi;
  String hasilCapaian;
  String kendalaSaran;
  String status;
  DateTime tanggalBuat;
  List<String> peserta;
  String pembuatId; // username pembuat

  LaporanKegiatan({
    required this.id,
    required this.judul,
    required this.sekbid,
    required this.penanggungJawab,
    required this.tanggalKegiatan,
    this.lokasi = '',
    this.deskripsi = '',
    this.hasilCapaian = '',
    this.kendalaSaran = '',
    this.status = StatusLaporan.draft,
    required this.tanggalBuat,
    this.peserta = const [],
    this.pembuatId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'judul': judul,
        'sekbid': sekbid,
        'penanggungJawab': penanggungJawab,
        'tanggalKegiatan': tanggalKegiatan.toIso8601String(),
        'lokasi': lokasi,
        'deskripsi': deskripsi,
        'hasilCapaian': hasilCapaian,
        'kendalaSaran': kendalaSaran,
        'status': status,
        'tanggalBuat': tanggalBuat.toIso8601String(),
        'peserta': peserta,
        'pembuatId': pembuatId,
      };
  
  factory LaporanKegiatan.fromJson(Map<String, dynamic> j) => LaporanKegiatan(
        id: j['id'] ?? '',
        judul: j['judul'] ?? '',
        sekbid: j['sekbid'] ?? '',
        penanggungJawab: j['penanggungJawab'] ?? j['penanggung_jawab'] ?? '',
        tanggalKegiatan: DateTime.parse(j['tanggalKegiatan'] ?? j['tanggal_kegiatan'] ?? DateTime.now().toIso8601String()),
        lokasi: j['lokasi'] ?? '',
        deskripsi: j['deskripsi'] ?? '',
        hasilCapaian: j['hasilCapaian'] ?? j['hasil_capaian'] ?? '',
        kendalaSaran: j['kendalaSaran'] ?? j['kendala_saran'] ?? '',
        status: j['status'] ?? StatusLaporan.draft,
        tanggalBuat: DateTime.parse(j['tanggalBuat'] ?? j['tanggal_buat'] ?? DateTime.now().toIso8601String()),
        peserta: (j['peserta'] as List?)?.map((e) => e.toString()).toList() ?? [],
        pembuatId: j['pembuatId'] ?? j['pembuat_id'] ?? '',
      );
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String category; // 'arsip', 'laporan', 'proker', 'system'
  final DateTime timestamp;
  final String actor;
  final List<String> targetRoles;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    required this.actor,
    this.targetRoles = const [],
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category,
        'timestamp': timestamp.toIso8601String(),
        'actor': actor,
        'targetRoles': targetRoles,
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        category: j['category'] ?? 'system',
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
        actor: j['actor'] ?? '',
        targetRoles: (j['targetRoles'] as List?)?.map((e) => e.toString()).toList() ?? [],
        isRead: j['isRead'] ?? false,
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        category: category,
        timestamp: timestamp,
        actor: actor,
        targetRoles: targetRoles,
        isRead: isRead ?? this.isRead,
      );
}

class SekbidItem {
  String id;
  String name;
  String deskripsi;
  int urutan;

  SekbidItem({
    required this.id,
    required this.name,
    this.deskripsi = '',
    this.urutan = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'deskripsi': deskripsi,
    'urutan': urutan,
  };

  factory SekbidItem.fromJson(Map<String, dynamic> j) => SekbidItem(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? j['nama']?.toString() ?? '',
    deskripsi: j['deskripsi']?.toString() ?? '',
    urutan: (j['urutan'] as num?)?.toInt() ?? 0,
  );
}

