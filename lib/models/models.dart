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
  bool disahkanKepsek;
  String catatanKepsek;

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
    this.disahkanKepsek = false,
    this.catatanKepsek = '',
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
        'disahkanKepsek': disahkanKepsek,
        'catatanKepsek': catatanKepsek,
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
        disahkanKepsek: (j['disahkanKepsek'] ?? j['disahkan_kepsek']) == true || (j['disahkanKepsek'] ?? j['disahkan_kepsek']) == 1,
        catatanKepsek: j['catatanKepsek'] ?? j['catatan_kepsek'] ?? '',
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

class KategoriKebaikan {
  static const ibadah = 'Ibadah & Akhlak Mulia';
  static const kejujuran = 'Kejujuran & Integritas';
  static const sosial = 'Kepedulian Sosial & Gotong Royong';
  static const prestasi = 'Prestasi & Akademik';
  static const lingkungan = 'Kebersihan & Lingkungan';
  static const kedisiplinan = 'Ketertiban & Kedisiplinan';
  static const lainnya = 'Lainnya';

  static const all = [
    ibadah,
    kejujuran,
    sosial,
    prestasi,
    lingkungan,
    kedisiplinan,
    lainnya,
  ];
}

class CatatanKebaikan {
  String id;
  String siswaId;
  String judul;
  String kategori;
  int poin;
  DateTime tanggal;
  String keterangan;
  String? namaSiswa;
  String? kelasSiswa;
  String? nisSiswa;
  String petugas;
  String apresiasi;

  CatatanKebaikan({
    required this.id,
    required this.siswaId,
    required this.judul,
    this.kategori = KategoriKebaikan.ibadah,
    this.poin = 10,
    required this.tanggal,
    this.keterangan = '',
    this.namaSiswa,
    this.kelasSiswa,
    this.nisSiswa,
    this.petugas = '',
    this.apresiasi = 'Pujian Lisan & Catatan Prestasi',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'siswaId': siswaId,
    'judul': judul,
    'kategori': kategori,
    'poin': poin,
    'tanggal': tanggal.toIso8601String(),
    'keterangan': keterangan,
    if (namaSiswa != null) 'namaSiswa': namaSiswa,
    if (kelasSiswa != null) 'kelasSiswa': kelasSiswa,
    if (nisSiswa != null) 'nisSiswa': nisSiswa,
    'petugas': petugas,
    'apresiasi': apresiasi,
  };

  factory CatatanKebaikan.fromJson(Map<String, dynamic> j) => CatatanKebaikan(
    id: j['id'] ?? '',
    siswaId: j['siswaId'] ?? j['siswa_id'] ?? '',
    judul: j['judul'] ?? j['nama'] ?? 'Aksi Kebaikan',
    kategori: j['kategori'] ?? KategoriKebaikan.ibadah,
    poin: (j['poin'] as num?)?.toInt() ?? 10,
    tanggal: DateTime.parse(j['tanggal'] ?? DateTime.now().toIso8601String()),
    keterangan: j['keterangan'] ?? '',
    namaSiswa: j['namaSiswa'] ?? j['nama_siswa'] ?? j['siswa_nama'],
    kelasSiswa: j['kelasSiswa'] ?? j['kelas_siswa'] ?? j['siswa_kelas'],
    nisSiswa: j['nisSiswa'] ?? j['nis_siswa'] ?? j['siswa_nis'],
    petugas: j['petugas'] ?? '',
    apresiasi: j['apresiasi'] ?? 'Pujian Lisan & Catatan Prestasi',
  );
}

// ── SISTEM KAS & ABSENSI OSIS ──────────────────────────────────────────────

class AnggotaOsis {
  String id;
  String nama;
  String jabatan; // 'Ketua OSIS', 'Wakil Ketua OSIS', 'Sekretaris', 'Bendahara', 'Sekbid 1'...'Sekbid 10', 'Anggota'
  String kelas;
  String nis;
  String noHp;
  bool aktif;

  AnggotaOsis({
    required this.id,
    required this.nama,
    required this.jabatan,
    this.kelas = '',
    this.nis = '',
    this.noHp = '',
    this.aktif = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'jabatan': jabatan,
    'kelas': kelas,
    'nis': nis,
    'no_hp': noHp,
    'aktif': aktif,
  };

  factory AnggotaOsis.fromJson(Map<String, dynamic> j) => AnggotaOsis(
    id: j['id']?.toString() ?? '',
    nama: j['nama']?.toString() ?? '',
    jabatan: j['jabatan']?.toString() ?? 'Anggota',
    kelas: j['kelas']?.toString() ?? '',
    nis: j['nis']?.toString() ?? '',
    noHp: j['no_hp']?.toString() ?? j['noHp']?.toString() ?? '',
    aktif: j['aktif'] != false,
  );
}

class KasOsisItem {
  String anggotaId;
  String nama;
  String jabatan;
  String kelas;
  bool sudahBayar;
  int nominalBayar;
  DateTime? tanggalBayar;
  String catatan;

  KasOsisItem({
    required this.anggotaId,
    required this.nama,
    required this.jabatan,
    this.kelas = '',
    this.sudahBayar = false,
    this.nominalBayar = 0,
    this.tanggalBayar,
    this.catatan = '',
  });

  Map<String, dynamic> toJson() => {
    'anggota_id': anggotaId,
    'nama': nama,
    'jabatan': jabatan,
    'kelas': kelas,
    'sudah_bayar': sudahBayar,
    'nominal_bayar': nominalBayar,
    'tanggal_bayar': tanggalBayar?.toIso8601String(),
    'catatan': catatan,
  };

  factory KasOsisItem.fromJson(Map<String, dynamic> j) => KasOsisItem(
    anggotaId: j['anggota_id']?.toString() ?? j['anggotaId']?.toString() ?? '',
    nama: j['nama']?.toString() ?? '',
    jabatan: j['jabatan']?.toString() ?? '',
    kelas: j['kelas']?.toString() ?? '',
    sudahBayar: j['sudah_bayar'] == true || j['sudahBayar'] == true,
    nominalBayar: (j['nominal_bayar'] ?? j['nominalBayar'] as num?)?.toInt() ?? 0,
    tanggalBayar: (j['tanggal_bayar'] ?? j['tanggalBayar']) != null
        ? DateTime.tryParse(j['tanggal_bayar'] ?? j['tanggalBayar'])
        : null,
    catatan: j['catatan']?.toString() ?? '',
  );
}

class KasOsisSession {
  String id;
  DateTime tanggal;
  String judul;
  int nominalWajib;
  String keterangan;
  String petugas;
  List<KasOsisItem> items;
  DateTime updatedAt;

  KasOsisSession({
    required this.id,
    required this.tanggal,
    required this.judul,
    this.nominalWajib = 5000,
    this.keterangan = '',
    this.petugas = 'BENDAHARA',
    required this.items,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  int get totalTerkumpul =>
      items.where((i) => i.sudahBayar).fold(0, (sum, i) => sum + (i.nominalBayar > 0 ? i.nominalBayar : nominalWajib));

  int get jumlahSudahBayar => items.where((i) => i.sudahBayar).length;
  int get jumlahBelumBayar => items.where((i) => !i.sudahBayar).length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tanggal': tanggal.toIso8601String(),
    'judul': judul,
    'nominal_wajib': nominalWajib,
    'keterangan': keterangan,
    'petugas': petugas,
    'items': items.map((i) => i.toJson()).toList(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory KasOsisSession.fromJson(Map<String, dynamic> j) => KasOsisSession(
    id: j['id']?.toString() ?? '',
    tanggal: DateTime.tryParse(j['tanggal']?.toString() ?? '') ?? DateTime.now(),
    judul: j['judul']?.toString() ?? 'Uang Kas OSIS',
    nominalWajib: (j['nominal_wajib'] ?? j['nominalWajib'] as num?)?.toInt() ?? 5000,
    keterangan: j['keterangan']?.toString() ?? '',
    petugas: j['petugas']?.toString() ?? 'BENDAHARA',
    items: (j['items'] as List?)
            ?.map((e) => KasOsisItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [],
    updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.now(),
  );
}

class KasOsisTransaksi {
  String id;
  DateTime tanggal;
  String jenis; // 'masuk' atau 'keluar'
  String judul;
  int nominal;
  String kategori; // 'Kas Mingguan', 'Konsumsi Rapat', 'ATK & Fotokopi', 'Kegiatan Proker', 'Lainnya'
  String penanggungJawab;
  String keterangan;

  KasOsisTransaksi({
    required this.id,
    required this.tanggal,
    required this.jenis,
    required this.judul,
    required this.nominal,
    this.kategori = 'Lainnya',
    this.penanggungJawab = '',
    this.keterangan = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tanggal': tanggal.toIso8601String(),
    'jenis': jenis,
    'judul': judul,
    'nominal': nominal,
    'kategori': kategori,
    'penanggung_jawab': penanggungJawab,
    'keterangan': keterangan,
  };

  factory KasOsisTransaksi.fromJson(Map<String, dynamic> j) => KasOsisTransaksi(
    id: j['id']?.toString() ?? '',
    tanggal: DateTime.tryParse(j['tanggal']?.toString() ?? '') ?? DateTime.now(),
    jenis: j['jenis']?.toString() ?? 'masuk',
    judul: j['judul']?.toString() ?? '',
    nominal: (j['nominal'] as num?)?.toInt() ?? 0,
    kategori: j['kategori']?.toString() ?? 'Lainnya',
    penanggungJawab: j['penanggung_jawab']?.toString() ?? j['penanggungJawab']?.toString() ?? '',
    keterangan: j['keterangan']?.toString() ?? '',
  );
}

class AbsensiOsisItem {
  String anggotaId;
  String nama;
  String jabatan;
  String kelas;
  String status; // 'Hadir', 'Izin', 'Sakit', 'Alpa'
  String keterangan;

  AbsensiOsisItem({
    required this.anggotaId,
    required this.nama,
    required this.jabatan,
    this.kelas = '',
    this.status = 'Hadir',
    this.keterangan = '',
  });

  Map<String, dynamic> toJson() => {
    'anggota_id': anggotaId,
    'nama': nama,
    'jabatan': jabatan,
    'kelas': kelas,
    'status': status,
    'keterangan': keterangan,
  };

  factory AbsensiOsisItem.fromJson(Map<String, dynamic> j) => AbsensiOsisItem(
    anggotaId: j['anggota_id']?.toString() ?? j['anggotaId']?.toString() ?? '',
    nama: j['nama']?.toString() ?? '',
    jabatan: j['jabatan']?.toString() ?? '',
    kelas: j['kelas']?.toString() ?? '',
    status: j['status']?.toString() ?? 'Hadir',
    keterangan: j['keterangan']?.toString() ?? '',
  );
}

class AbsensiOsisSession {
  String id;
  DateTime tanggal;
  String namaKegiatan;
  String lokasi;
  String petugas;
  String keterangan;
  List<AbsensiOsisItem> items;
  DateTime updatedAt;

  AbsensiOsisSession({
    required this.id,
    required this.tanggal,
    required this.namaKegiatan,
    this.lokasi = 'Sekretariat OSIS',
    this.petugas = '',
    this.keterangan = '',
    required this.items,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  int get totalHadir => items.where((i) => i.status == 'Hadir').length;
  int get totalIzin  => items.where((i) => i.status == 'Izin').length;
  int get totalSakit => items.where((i) => i.status == 'Sakit').length;
  int get totalAlpa  => items.where((i) => i.status == 'Alpa').length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tanggal': tanggal.toIso8601String(),
    'nama_kegiatan': namaKegiatan,
    'lokasi': lokasi,
    'petugas': petugas,
    'keterangan': keterangan,
    'items': items.map((i) => i.toJson()).toList(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory AbsensiOsisSession.fromJson(Map<String, dynamic> j) => AbsensiOsisSession(
    id: j['id']?.toString() ?? '',
    tanggal: DateTime.tryParse(j['tanggal']?.toString() ?? '') ?? DateTime.now(),
    namaKegiatan: j['nama_kegiatan']?.toString() ?? j['namaKegiatan']?.toString() ?? 'Kegiatan OSIS',
    lokasi: j['lokasi']?.toString() ?? 'Sekretariat OSIS',
    petugas: j['petugas']?.toString() ?? '',
    keterangan: j['keterangan']?.toString() ?? '',
    items: (j['items'] as List?)
            ?.map((e) => AbsensiOsisItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [],
    updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.now(),
  );
}

